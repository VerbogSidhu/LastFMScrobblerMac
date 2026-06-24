import Foundation
import SwiftUI

/// Polls Apple Music and scrobbles tracks to Last.fm when conditions are met.
class ScrobbleMonitor: ObservableObject {
    @Published var isScrobbling = false
    @Published var lastScrobbledTrack: String?
    @Published var currentTrackName: String?
    @Published var currentArtist: String?
    @Published var currentAlbumArt: String?
    @Published var authStatus: AuthStatus = .notAuthenticated
    @Published var scrobbleLog: [ScrobbleLogEntry] = []
    @Published var debugLog: [String] = []
    
    struct ScrobbleLogEntry: Identifiable {
        let id = UUID()
        let track: String
        let artist: String
        let timestamp: Date
    }
    
    enum AuthStatus {
        case notAuthenticated
        case awaitingAuthorization
        case authenticated
    }
    
    private let detector = MusicDetector()
    private var scrobbleService: ScrobbleService?
    private var pollTimer: Timer?
    private let pollQueue = DispatchQueue(label: "com.lastfmscrobbler.poll", qos: .utility)
    weak var statsManager: ScrobbleStatsManager?
    
    // Thread safety: protects all shared mutable state accessed from pollQueue
    private let stateLock = NSLock()
    
    private func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }
    
    // Track state
    private var currentTrackID: Int?
    private var trackStartTime: Date?
    private var hasScrobbled = false
    private var accumulatedPlayTime: TimeInterval = 0
    private var lastPollTime: Date?
    private var wasPlaying = false
    private var durationCache: [Int: Int] = [:] // trackID -> duration (for tracks that initially report 0)
    private var lastPlayerPosition: Int = 0 // track player position to detect loops
    
    // Now-playing refresh state
    private var lastNowPlayingTime: Date?
    private var nowPlayingRetryCount = 0
    private var nowPlayingRefreshInterval: TimeInterval {
        UserDefaults.standard.double(forKey: "scrobble_nowplaying_refresh").clamped(to: 30...300, default: 60)
    }
    private let nowPlayingMaxRetries = 3
    
    // Session key stored in UserDefaults
    private let sessionKeyKey = "lastfm_session_key"
    private let apiSecretKey = "lastfm_api_secret"
    private let apiKeyKey = "lastfm_api_key"
    
    var sessionKey: String? {
        UserDefaults.standard.string(forKey: sessionKeyKey)
    }
    
    // MARK: - Debug Logging
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        NSLog("[ScrobbleMonitor] %@", message)
        DispatchQueue.main.async {
            self.debugLog.insert(entry, at: 0)
            if self.debugLog.count > 50 {
                self.debugLog = Array(self.debugLog.prefix(50))
            }
        }
    }
    
    // MARK: - Setup
    
    func setup(apiKey: String = "", apiSecret: String = "") {
        let secret = apiSecret.isEmpty ? (UserDefaults.standard.string(forKey: apiSecretKey) ?? "") : apiSecret
        let key = apiKey.isEmpty ? (UserDefaults.standard.string(forKey: apiKeyKey) ?? ScrobbleService.defaultAPIKey) : apiKey
        
        scrobbleService = ScrobbleService(apiKey: key, apiSecret: secret)
        
        let savedSessionKey = sessionKey
        log("Setup: apiKey=\(key.prefix(8))..., apiSecret=\(secret.isEmpty ? "EMPTY" : "SET"), sessionKey=\(savedSessionKey == nil ? "NIL" : "SET")")
        
        if savedSessionKey != nil && !secret.isEmpty {
            authStatus = .authenticated
            log("Auth status: AUTHENTICATED")
        } else {
            authStatus = .notAuthenticated
            log("Auth status: NOT AUTHENTICATED")
        }
    }
    
    func saveCredentials(apiKey: String, apiSecret: String) {
        UserDefaults.standard.set(apiKey, forKey: apiKeyKey)
        UserDefaults.standard.set(apiSecret, forKey: apiSecretKey)
        log("Credentials saved")
        setup(apiKey: apiKey, apiSecret: apiSecret)
    }
    
    // MARK: - Authentication
    
    func authenticate() async {
        guard let service = scrobbleService else { return }
        
        do {
            authStatus = .awaitingAuthorization
            let token = try await service.getRequestToken()
            log("Got request token: \(token.prefix(8))...")
            service.openAuthorization(token: token)
            
            // Poll for session (user needs to authorize in browser first)
            for i in 0..<30 {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                do {
                    let sessionKey = try await service.getSession(token: token)
                    UserDefaults.standard.set(sessionKey, forKey: sessionKeyKey)
                    log("Got session key: \(sessionKey.prefix(8))...")
                    await MainActor.run {
                        self.authStatus = .authenticated
                    }
                    return
                } catch {
                    // Not authorized yet, keep waiting
                    if i % 5 == 0 {
                        log("Waiting for authorization... (\(i + 1)/30)")
                    }
                    continue
                }
            }
            
            log("Auth timed out after 60 seconds")
            await MainActor.run {
                self.authStatus = .notAuthenticated
            }
        } catch {
            log("Auth error: \(error)")
            await MainActor.run {
                self.authStatus = .notAuthenticated
            }
        }
    }
    
    func disconnect() {
        UserDefaults.standard.removeObject(forKey: sessionKeyKey)
        UserDefaults.standard.removeObject(forKey: apiSecretKey)
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
        stopMonitoring()
        scrobbleService = nil
        authStatus = .notAuthenticated
        log("Disconnected")
    }
    
    func resetCredentials() {
        UserDefaults.standard.removeObject(forKey: sessionKeyKey)
        UserDefaults.standard.removeObject(forKey: apiSecretKey)
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
        UserDefaults.standard.removeObject(forKey: "lastfm_setup_complete")
        stopMonitoring()
        scrobbleService = nil
        authStatus = .notAuthenticated
        log("Credentials reset — setup wizard will show on next launch")
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        guard authStatus == .authenticated else {
            log("Cannot start monitoring: not authenticated (status=\(String(describing: authStatus)))")
            return
        }
        
        guard sessionKey != nil else {
            log("Cannot start monitoring: no session key")
            return
        }
        
        // Don't stack timers — stop any existing one first
        stopMonitoring()
        
        isScrobbling = true
        log("Starting monitor — session key present, polling every 5s")
        
        // Create timer WITHOUT scheduledTimer (which adds to .default mode)
        // Then add to .common mode so it fires even during UI tracking/scrolling
        let pollInterval = UserDefaults.standard.double(forKey: "scrobble_poll_interval").clamped(to: 2...15, default: 5)
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        
        // Immediate first poll
        poll()
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        isScrobbling = false
        withStateLock {
            currentTrackID = nil
            trackStartTime = nil
            hasScrobbled = false
            accumulatedPlayTime = 0
            wasPlaying = false
            durationCache = [:]
            lastPlayerPosition = 0
            lastNowPlayingTime = nil
            nowPlayingRetryCount = 0
        }
        currentTrackName = nil
        currentArtist = nil
        currentAlbumArt = nil
    }
    
    private func poll() {
        guard let service = scrobbleService else {
            log("Poll: no scrobble service")
            return
        }
        guard let sessionKey = sessionKey else {
            log("Poll: no session key — re-checking auth")
            DispatchQueue.main.async {
                self.setup()
                if self.authStatus == .authenticated {
                    self.startMonitoring()
                }
            }
            return
        }
        
        // Run AppleScript off the main thread
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Snapshot shared state under lock for safe access on pollQueue
            var (currentTrackID, trackStartTime, hasScrobbled, accumulatedPlayTime,
                 lastPollTime, wasPlaying, lastPlayerPosition, lastNowPlayingTime,
                 nowPlayingRetryCount, durationCache) = self.withStateLock {
                (self.currentTrackID, self.trackStartTime, self.hasScrobbled,
                 self.accumulatedPlayTime, self.lastPollTime, self.wasPlaying,
                 self.lastPlayerPosition, self.lastNowPlayingTime,
                 self.nowPlayingRetryCount, self.durationCache)
            }
            
            // Write back shared state to self on exit (including early returns)
            defer {
                self.withStateLock {
                    self.currentTrackID = currentTrackID
                    self.trackStartTime = trackStartTime
                    self.hasScrobbled = hasScrobbled
                    self.accumulatedPlayTime = accumulatedPlayTime
                    self.lastPollTime = lastPollTime
                    self.wasPlaying = wasPlaying
                    self.lastPlayerPosition = lastPlayerPosition
                    self.lastNowPlayingTime = lastNowPlayingTime
                    self.nowPlayingRetryCount = nowPlayingRetryCount
                    self.durationCache = durationCache
                }
            }
            
            let info = self.detector.getCurrentTrack()
            
            // Read current @Published state for comparison
            let oldName = self.currentTrackName
            let oldArtist = self.currentArtist
            
            let newName = info?.name
            let newArtist = info?.artist
            
            // Only update @Published properties when values actually change
            if oldName != newName || oldArtist != newArtist {
                DispatchQueue.main.async {
                    self.currentTrackName = newName
                    self.currentArtist = newArtist
                }
            }
            
            guard let trackInfo = info else {
                // Nothing playing
                if currentTrackID != nil {
                    self.log("Track ended — resetting state")
                    currentTrackID = nil
                    trackStartTime = nil
                    hasScrobbled = false
                    accumulatedPlayTime = 0
                    wasPlaying = false
                }
                return
            }
            
            let trackID = trackInfo.databaseID
            let isPlaying = trackInfo.playerState == "playing"
            
            // Cache duration if non-zero
            if trackInfo.duration > 0 {
                durationCache[trackID] = trackInfo.duration
            }
            // Use cached duration if current is 0
            let effectiveDuration = trackInfo.duration > 0 ? trackInfo.duration : (durationCache[trackID] ?? 0)
            
            // Track changed
            if trackID != currentTrackID {
                self.log("New track: \(trackInfo.name) — \(trackInfo.artist) [ID:\(trackID), dur:\(effectiveDuration)s, state:\(trackInfo.playerState)]")
                currentTrackID = trackID
                trackStartTime = Date()
                hasScrobbled = false
                accumulatedPlayTime = 0
                lastPollTime = Date()
                wasPlaying = isPlaying
                lastPlayerPosition = trackInfo.playerPosition
                lastNowPlayingTime = nil  // reset refresh timer
                nowPlayingRetryCount = 0
                
                // Send now-playing update
                self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
                return
            }
            
            // Track same, accumulate play time
            if isPlaying {
                let now = Date()
                
                // Detect loop via player position reset:
                // Position dropped from near end (>60% of duration) to near start (<30%)
                if effectiveDuration > 0 {
                    let posRatio = Double(trackInfo.playerPosition) / Double(effectiveDuration)
                    let lastRatio = Double(lastPlayerPosition) / Double(effectiveDuration)
                    
                    if lastRatio > 0.6 && posRatio < 0.3 {
                        self.log("Loop detected via position reset (\(lastPlayerPosition)s → \(trackInfo.playerPosition)s)")
                        
                        // Send now-playing update for the new loop iteration
                        lastNowPlayingTime = nil
                        nowPlayingRetryCount = 0
                        self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
                        
                        // Reset scrobble state for new loop
                        hasScrobbled = false
                        accumulatedPlayTime = 0
                        trackStartTime = now
                    }
                }
                
                // Fallback: if accumulated time exceeds track duration without
                // position reset detection, still reset for next scrobble
                if hasScrobbled && effectiveDuration > 0 && accumulatedPlayTime >= Double(effectiveDuration) {
                    self.log("Track looped (fallback: \(Int(accumulatedPlayTime))s played, \(effectiveDuration)s track) — resetting for next scrobble")
                    hasScrobbled = false
                    accumulatedPlayTime = 0
                    trackStartTime = now
                }
                
                if let last = lastPollTime {
                    accumulatedPlayTime += now.timeIntervalSince(last)
                }
                lastPollTime = now
                lastPlayerPosition = trackInfo.playerPosition
                wasPlaying = true
                
                // Periodic now-playing refresh — keeps Last.fm status alive
                if let lastNP = lastNowPlayingTime,
                   now.timeIntervalSince(lastNP) >= self.nowPlayingRefreshInterval {
                    self.log("Periodic now-playing refresh (every \(Int(self.nowPlayingRefreshInterval))s)")
                    self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
                }
            } else if wasPlaying && !isPlaying {
                // Just paused
                self.log("Track paused — accumulated \(Int(accumulatedPlayTime))s so far")
                lastPollTime = Date()
                wasPlaying = false
            }
            
            // Check scrobble conditions
            let minDuration = UserDefaults.standard.double(forKey: "scrobble_min_duration").clamped(to: 10...120, default: 30)
            if !hasScrobbled && isPlaying && Double(effectiveDuration) > minDuration {
                let threshold = min(Double(effectiveDuration) / 2.0, 240.0) // half or 4 min
                
                if accumulatedPlayTime >= threshold, let startTime = trackStartTime {
                    hasScrobbled = true
                    let timestamp = Int(startTime.timeIntervalSince1970)
                    
                    self.log("Scrobble triggered! \(trackInfo.name) — \(trackInfo.artist) (played \(Int(accumulatedPlayTime))s of \(trackInfo.duration)s, threshold: \(Int(threshold))s)")
                    
                    Task {
                        do {
                            try await service.scrobble(
                                track: trackInfo.name,
                                artist: trackInfo.artist,
                                album: trackInfo.album,
                                duration: effectiveDuration,
                                timestamp: timestamp,
                                sessionKey: sessionKey
                            )
                            self.log("SCROBBLE ACCEPTED: \(trackInfo.name) — \(trackInfo.artist)")
                            self.statsManager?.recordScrobble(track: trackInfo.name, artist: trackInfo.artist, album: trackInfo.album)
                        
                            // Notify observers (AppState) to refresh UI
                            NotificationCenter.default.post(name: .scrobbleDidComplete, object: nil)
                            await MainActor.run {
                                self.lastScrobbledTrack = "\(trackInfo.name) — \(trackInfo.artist)"
                                self.scrobbleLog.insert(
                                    ScrobbleLogEntry(
                                        track: trackInfo.name,
                                        artist: trackInfo.artist,
                                        timestamp: Date()
                                    ),
                                    at: 0
                                )
                                // Keep log to last 20 entries
                                if self.scrobbleLog.count > 20 {
                                    self.scrobbleLog = Array(self.scrobbleLog.prefix(20))
                                }
                            }
                        } catch {
                            self.log("SCROBBLE FAILED: \(error)")
                        }
                    }
                } else if isPlaying {
                    // Log progress periodically
                    let remaining = Int(threshold - accumulatedPlayTime)
                    if remaining > 0 && remaining % 30 < 5 {
                        self.log("Play time: \(Int(accumulatedPlayTime))s / \(Int(threshold))s threshold — \(remaining)s to scrobble")
                    }
                }
            }
        }
    }
    
    // MARK: - Now-Playing Helper
    
    /// Force a now-playing update right now (called by refresh button).
    func forceNowPlayingUpdate() {
        guard authStatus == .authenticated, let sessionKey = sessionKey else { return }
        guard let info = detector.getCurrentTrack(), info.playerState == "playing" else { return }
        
        let effectiveDuration = withStateLock {
            info.duration > 0 ? info.duration : (durationCache[info.databaseID] ?? 0)
        }
        log("Manual now-playing refresh triggered")
        sendNowPlaying(trackInfo: info, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
    }
    
    private func sendNowPlaying(trackInfo: MusicTrackInfo, effectiveDuration: Int, sessionKey: String, isRetry: Bool) {
        guard let service = scrobbleService else { return }
        
        Task {
            do {
                try await service.updateNowPlaying(
                    track: trackInfo.name,
                    artist: trackInfo.artist,
                    album: trackInfo.album,
                    duration: effectiveDuration,
                    sessionKey: sessionKey
                )
                self.log("Now-playing sent: \(trackInfo.name)")
                self.withStateLock {
                    self.lastNowPlayingTime = Date()
                    self.nowPlayingRetryCount = 0
                }
            } catch {
                self.log("Now-playing failed: \(error)")
                // Retry up to 3 times with backoff
                let (retryCount, shouldRetry) = self.withStateLock {
                    self.nowPlayingRetryCount += 1
                    return (self.nowPlayingRetryCount, self.nowPlayingRetryCount <= self.nowPlayingMaxRetries)
                }
                if shouldRetry {
                    let delay = Double(retryCount) * 5.0 // 5s, 10s, 15s
                    self.log("Now-playing retry \(retryCount)/\(self.nowPlayingMaxRetries) in \(Int(delay))s")
                    Task.detached { [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        await MainActor.run {
                            self?.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: true)
                        }
                    }
                } else {
                    self.log("Now-playing gave up after \(self.nowPlayingMaxRetries) retries")
                }
            }
        }
    }
}

// MARK: - UserDefaults Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        let stored = self
        return stored >= range.lowerBound && stored <= range.upperBound ? stored : defaultValue
    }
}
