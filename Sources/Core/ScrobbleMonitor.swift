import Foundation
import SwiftUI

/// Polls Apple Music and scrobbles tracks to Last.fm when conditions are met.
class ScrobbleMonitor: ObservableObject {
    @Published var isScrobbling = false
    @Published var lastScrobbledTrack: String?
    @Published var currentTrackName: String?
    @Published var currentArtist: String?
    @Published var currentAlbumArt: String?
    @Published var currentAlbumName: String?
    @Published var currentPosition: Int = 0
    @Published var currentDuration: Int = 0
    @Published var accumulatedSeconds: Double = 0
    @Published var scrobbleThresholdSeconds: Double = 0
    @Published var hasCurrentTrackScrobbled: Bool = false
    @Published var justScrobbled: Bool = false
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var queuedScrobbleCount: Int = 0
    @Published var isLoved: Bool = false
    @Published var soundVolume: Int = 100
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
    private var musicPlayerObserver: NSObjectProtocol?
    private let pollQueue = DispatchQueue(label: "com.lastfmscrobbler.poll", qos: .utility)
    weak var statsManager: ScrobbleStatsManager?
    
    private let offlineQueue = OfflineScrobbleQueue()
    private var isFlushingQueue = false
    
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
    private var failedArtworkTrackIDs: Set<Int> = [] // tracks with no artwork to avoid repeated lookups
    
    // Now-playing refresh state
    private var lastNowPlayingTime: Date?
    // Tracks the last now-playing ATTEMPT (success OR failure). The periodic
    // refresh is gated on this so a track whose initial updateNowPlaying call
    // fails is still retried periodically instead of being stranded forever.
    private var lastNowPlayingAttempt: Date?
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
        
        loadOfflineQueue()
        if savedSessionKey != nil && !secret.isEmpty {
            authStatus = .authenticated
            log("Auth status: AUTHENTICATED")
            flushOfflineQueue()
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

        // Listen for Apple Music player state changes for instant skip detection
        if musicPlayerObserver == nil {
            musicPlayerObserver = DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.apple.Music.playerInfo"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.poll()
            }
        }
        
        // Immediate first poll
        poll()
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let obs = musicPlayerObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
            musicPlayerObserver = nil
        }
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
            lastNowPlayingAttempt = nil
            nowPlayingRetryCount = 0
            failedArtworkTrackIDs.removeAll()
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
                 lastNowPlayingAttempt, nowPlayingRetryCount, durationCache) = self.withStateLock {
                (self.currentTrackID, self.trackStartTime, self.hasScrobbled,
                 self.accumulatedPlayTime, self.lastPollTime, self.wasPlaying,
                 self.lastPlayerPosition, self.lastNowPlayingTime,
                 self.lastNowPlayingAttempt, self.nowPlayingRetryCount, self.durationCache)
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
                    self.lastNowPlayingAttempt = lastNowPlayingAttempt
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
                // Only dispatch to main and publish if state is not already idle
                if self.currentTrackName != nil || self.isPlaying || self.isPaused {
                    DispatchQueue.main.async {
                        self.currentTrackName = nil
                        self.currentArtist = nil
                        self.currentAlbumName = nil
                        self.currentAlbumArt = nil
                        self.currentPosition = 0
                        self.currentDuration = 0
                        self.accumulatedSeconds = 0
                        self.scrobbleThresholdSeconds = 0
                        self.hasCurrentTrackScrobbled = false
                        self.justScrobbled = false
                        self.isPlaying = false
                        self.isPaused = false
                    }
                }
                return
            }
            
            let trackID = trackInfo.databaseID
            let isPlaying = trackInfo.playerState == "playing"
            
            // Cache duration if non-zero
            if trackInfo.duration > 0 {
                durationCache[trackID] = trackInfo.duration
                // Bound the cache to most recent entries (prevents unbounded
                // growth over long sessions of unique tracks).
                if durationCache.count > 200 {
                    let trimmed = durationCache
                        .sorted { $0.key > $1.key }   // largest IDs = most recent
                        .prefix(200)
                    durationCache = Dictionary(uniqueKeysWithValues: Array(trimmed))
                }
            }
            // Use cached duration if current is 0
            let effectiveDuration = trackInfo.duration > 0 ? trackInfo.duration : (durationCache[trackID] ?? 0)
            
            // Track changed
            if trackID != currentTrackID {
                self.log("New track: \(trackInfo.name) — \(trackInfo.artist) [ID:\(trackID), dur:\(effectiveDuration)s, pos:\(trackInfo.playerPosition)s, state:\(trackInfo.playerState)]")
                currentTrackID = trackID
                trackStartTime = Date()
                hasScrobbled = false
                accumulatedPlayTime = Double(trackInfo.playerPosition)
                lastPollTime = Date()
                wasPlaying = isPlaying
                lastPlayerPosition = trackInfo.playerPosition
                lastNowPlayingTime = nil  // reset refresh timer
                lastNowPlayingAttempt = Date()  // mark initial attempt
                nowPlayingRetryCount = 0
                
                // Immediately publish the new track info to the UI so it displays with zero lag
                let threshold = min(Double(effectiveDuration) / 2.0, 240.0)
                let newName = trackInfo.name
                let newArtist = trackInfo.artist
                let newAlbum = trackInfo.album
                let newPos = trackInfo.playerPosition
                let newDur = effectiveDuration
                let curPlaying = isPlaying
                let curPaused = (trackInfo.playerState == "paused")
                let localArt = self.detector.getArtwork(databaseID: trackID)

                DispatchQueue.main.async {
                    self.currentTrackName = newName
                    self.currentArtist = newArtist
                    self.currentAlbumName = newAlbum
                    self.currentAlbumArt = localArt
                    self.currentPosition = newPos
                    self.currentDuration = newDur
                    self.accumulatedSeconds = Double(newPos)
                    self.scrobbleThresholdSeconds = threshold
                    self.hasCurrentTrackScrobbled = false
                    self.justScrobbled = false
                    self.isPlaying = curPlaying
                    self.isPaused = curPaused
                    self.isLoved = false

                    NotificationCenter.default.post(name: .trackDidChange, object: nil)
                }

                if localArt == nil {
                    Task {
                        let fallbackCover = await ArtistImageService.shared.fetchAlbumCover(
                            artist: newArtist,
                            trackOrAlbum: newAlbum.isEmpty ? newName : newAlbum
                        )
                        if let cover = fallbackCover {
                            await MainActor.run {
                                if self.currentTrackName == newName {
                                    self.currentAlbumArt = cover
                                }
                            }
                        }
                    }
                }

                // Send now-playing update
                self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
                return
            }

            // If track is the same but currentAlbumArt is still missing, attempt resolution only once
            let alreadyAttempted = self.withStateLock { self.failedArtworkTrackIDs.contains(trackID) }
            if self.currentAlbumArt == nil && !alreadyAttempted {
                if let localArt = self.detector.getArtwork(databaseID: trackID) {
                    DispatchQueue.main.async {
                        self.currentAlbumArt = localArt
                    }
                } else {
                    self.withStateLock { _ = self.failedArtworkTrackIDs.insert(trackID) }
                    Task {
                        let fallbackCover = await ArtistImageService.shared.fetchAlbumCover(
                            artist: trackInfo.artist,
                            trackOrAlbum: trackInfo.album.isEmpty ? trackInfo.name : trackInfo.album
                        )
                        if let cover = fallbackCover {
                            await MainActor.run {
                                if self.currentTrackName == trackInfo.name {
                                    self.currentAlbumArt = cover
                                }
                            }
                        }
                    }
                }
            }
            
            // Track same, accumulate play time
            let now = Date()
            if isPlaying {
                
                // Detect loop via player position reset:
                // Position dropped from near end (>60% of duration) to near start (<30%)
                if effectiveDuration > 0 {
                    let posRatio = Double(trackInfo.playerPosition) / Double(effectiveDuration)
                    let lastRatio = Double(lastPlayerPosition) / Double(effectiveDuration)
                    
                    if lastRatio > 0.6 && posRatio < 0.3 {
                        self.log("Loop detected via position reset (\(lastPlayerPosition)s → \(trackInfo.playerPosition)s)")
                        
                        // Send now-playing update for the new loop iteration
                        lastNowPlayingTime = nil
                        lastNowPlayingAttempt = Date()
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
                
                // Only accumulate play time between two *consecutive playing*
                // polls. While paused, lastPollTime is refreshed every poll, so
                // the resume poll must not add the entire pause duration to
                // accumulatedPlayTime — that would falsely push the total past
                // the track duration, trigger the fallback loop reset below,
                // and cause a second scrobble for the same play.
                if wasPlaying, let last = lastPollTime {
                    accumulatedPlayTime += now.timeIntervalSince(last)
                }
                lastPollTime = now
                lastPlayerPosition = trackInfo.playerPosition
                wasPlaying = true
                
                // Periodic now-playing refresh — keeps Last.fm status alive.
                // Gated on the last ATTEMPT (not last success) + a fresh retry
                // budget, so a track whose initial call failed is still retried
                // periodically rather than being stranded with no now-playing.
                if now.timeIntervalSince(lastNowPlayingAttempt ?? .distantPast) >= self.nowPlayingRefreshInterval {
                    self.log("Periodic now-playing refresh (makes a new attempt after \(Int(self.nowPlayingRefreshInterval))s)")
                    lastNowPlayingAttempt = now  // start a fresh cycle
                    nowPlayingRetryCount = 0
                    self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
                }
            } else {
                // Paused (or stopped): keep lastPollTime fresh on every poll so
                // a later resume doesn't accumulate the pause duration as play
                // time. Only log the transition playing -> paused once.
                lastPollTime = now
                if wasPlaying {
                    self.log("Track paused — accumulated \(Int(accumulatedPlayTime))s so far")
                }
                wasPlaying = false
            }
            
            // Check scrobble conditions
            let minDuration = UserDefaults.standard.double(forKey: "scrobble_min_duration").clamped(to: 10...120, default: 30)
            if !hasScrobbled && isPlaying {
                if Double(effectiveDuration) <= minDuration {
                    // Log why this track won't scrobble
                    self.log("Scrobble skipped: \(trackInfo.name) duration \(effectiveDuration)s <= minDuration \(Int(minDuration))s")
                } else {
                    let threshold = min(Double(effectiveDuration) / 2.0, 240.0) // half or 4 min
                    
                    if accumulatedPlayTime >= threshold, let startTime = trackStartTime {
                        hasScrobbled = true
                        let timestamp = Int(startTime.timeIntervalSince1970)
                        
                        self.log("Scrobble triggered! \(trackInfo.name) — \(trackInfo.artist) (played \(Int(accumulatedPlayTime))s of \(effectiveDuration)s, threshold: \(Int(threshold))s)")
                        
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
                                    self.hasCurrentTrackScrobbled = true
                                    self.justScrobbled = true
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
                                self.queueOfflineScrobble(
                                    track: trackInfo.name,
                                    artist: trackInfo.artist,
                                    album: trackInfo.album,
                                    duration: effectiveDuration,
                                    timestamp: timestamp
                                )
                            }
                        }
                    }
                }
            }
            
            // Publish live telemetry for UI
            let threshold = min(Double(effectiveDuration) / 2.0, 240.0)
            let curPos = trackInfo.playerPosition
            let curDur = effectiveDuration
            let curAcc = accumulatedPlayTime
            let curScrobbled = hasScrobbled
            let curAlbum = trackInfo.album
            let curPlaying = isPlaying
            let curPaused = (trackInfo.playerState == "paused")
            
            DispatchQueue.main.async {
                self.currentAlbumName = curAlbum
                self.currentPosition = curPos
                self.currentDuration = curDur
                self.accumulatedSeconds = curAcc
                self.scrobbleThresholdSeconds = threshold
                self.hasCurrentTrackScrobbled = curScrobbled
                self.isPlaying = curPlaying
                self.isPaused = curPaused
            }
            
            self.flushOfflineQueue()
        }
    }
    
    // MARK: - Now-Playing Helper
    
    /// Force a now-playing update right now (called by refresh button).
    /// Runs AppleScript off the main thread and retries once on failure,
    /// falling back to cached track info if AppleScript fails entirely.
    func forceNowPlayingUpdate() {
        guard authStatus == .authenticated, let sessionKey = sessionKey else { return }
        
        log("Manual now-playing refresh triggered")
        
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Try AppleScript first
            let info = self.detector.getCurrentTrack()
            
            if let trackInfo = info, trackInfo.playerState == "playing" {
                let effectiveDuration = self.withStateLock {
                    trackInfo.duration > 0 ? trackInfo.duration : (self.durationCache[trackInfo.databaseID] ?? 0)
                }
                self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: false)
                return
            }
            
            // AppleScript failed or returned non-playing state — fall back to cached track info
            let (cachedName, cachedArtist) = self.withStateLock {
                // Use whatever the poll loop last saw
                (self.currentTrackName, self.currentArtist)
            }
            
            guard let name = cachedName, let artist = cachedArtist else {
                self.log("forceNowPlaying: no cached track to send")
                return
            }
            
            self.log("forceNowPlaying: AppleScript unavailable, using cached track: \(name) — \(artist)")
            
            // Build a minimal MusicTrackInfo from cached state
            let fallbackInfo = MusicTrackInfo(
                name: name,
                artist: artist,
                album: "",
                duration: 0,
                playerPosition: 0,
                playerState: "playing",
                databaseID: 0
            )
            self.sendNowPlaying(trackInfo: fallbackInfo, effectiveDuration: 0, sessionKey: sessionKey, isRetry: false)
        }
    }
    
    private func sendNowPlaying(trackInfo: MusicTrackInfo, effectiveDuration: Int, sessionKey: String, isRetry: Bool) {
        guard let service = scrobbleService else { return }
        
        Task {
            do {
                let (statusCode, body) = try await service.updateNowPlaying(
                    track: trackInfo.name,
                    artist: trackInfo.artist,
                    album: trackInfo.album,
                    duration: effectiveDuration,
                    sessionKey: sessionKey
                )
                self.log("Now-playing sent: \(trackInfo.name) [HTTP \(statusCode)] \(body.prefix(200))")
                self.withStateLock {
                    self.lastNowPlayingTime = Date()
                    self.nowPlayingRetryCount = 0
                }
                NotificationCenter.default.post(name: .nowPlayingDidUpdate, object: nil)
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
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    self.sendNowPlaying(trackInfo: trackInfo, effectiveDuration: effectiveDuration, sessionKey: sessionKey, isRetry: true)
                } else {
                    self.log("Now-playing gave up after \(self.nowPlayingMaxRetries) retries")
                }
            }
        }
    }
    
    // MARK: - Offline Queue
    
    func queueOfflineScrobble(track: String, artist: String, album: String, duration: Int, timestamp: Int) {
        offlineQueue.enqueue(track: track, artist: artist, album: album, duration: duration, timestamp: timestamp)
        let count = offlineQueue.count
        DispatchQueue.main.async {
            self.queuedScrobbleCount = count
        }
        log("Queued offline scrobble: \(track) — \(artist) (total queued: \(count))")
    }
    
    func loadOfflineQueue() {
        offlineQueue.load()
        let count = offlineQueue.count
        DispatchQueue.main.async {
            self.queuedScrobbleCount = count
        }
    }
    
    func flushOfflineQueue() {
        guard !isFlushingQueue, offlineQueue.count > 0, let service = scrobbleService, let sessionKey = sessionKey else { return }
        isFlushingQueue = true
        
        let items = offlineQueue.items
        Task {
            var remaining: [QueuedScrobble] = []
            for item in items {
                do {
                    try await service.scrobble(
                        track: item.track,
                        artist: item.artist,
                        album: item.album,
                        duration: item.duration,
                        timestamp: item.timestamp,
                        sessionKey: sessionKey
                    )
                    self.statsManager?.recordScrobble(track: item.track, artist: item.artist, album: item.album)
                    self.log("Flushed offline scrobble: \(item.track)")
                } catch {
                    self.log("Failed to flush offline scrobble \(item.track), keeping in queue: \(error)")
                    remaining.append(item)
                }
            }
            self.offlineQueue.setRemaining(remaining)
            let count = remaining.count
            let isEmpty = remaining.isEmpty
            await MainActor.run {
                self.queuedScrobbleCount = count
                if isEmpty {
                    NotificationCenter.default.post(name: .scrobbleDidComplete, object: nil)
                }
            }
            self.isFlushingQueue = false
        }
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        detector.playPause()
        pollQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.poll()
        }
    }
    
    func nextTrack() {
        detector.nextTrack()
        pollQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.poll()
        }
        pollQueue.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.poll()
        }
    }
    
    func previousTrack() {
        detector.previousTrack()
        pollQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.poll()
        }
        pollQueue.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.poll()
        }
    }
    
    func seekTo(position: Double) {
        currentPosition = Int(position)
        detector.setPlayerPosition(position)
        pollQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.poll()
        }
    }
    
    func setVolume(_ volume: Int) {
        soundVolume = volume
        detector.setSoundVolume(volume)
    }
    
    func toggleLoveCurrentTrack() {
        guard let service = scrobbleService, let sessionKey = sessionKey,
              let track = currentTrackName, let artist = currentArtist else { return }
        
        let shouldLove = !isLoved
        Task {
            do {
                if shouldLove {
                    try await service.loveTrack(track: track, artist: artist, sessionKey: sessionKey)
                    await MainActor.run {
                        self.isLoved = true
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
                    self.log("Loved track: \(track)")
                } else {
                    try await service.unloveTrack(track: track, artist: artist, sessionKey: sessionKey)
                    await MainActor.run {
                        self.isLoved = false
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
                    self.log("Unloved track: \(track)")
                }
            } catch {
                self.log("Failed to love/unlove track: \(error)")
            }
        }
    }

    var scrobbleProgress: Double {
        if hasCurrentTrackScrobbled { return 1.0 }
        guard scrobbleThresholdSeconds > 0 else { return 0.0 }
        return min(1.0, max(0.0, accumulatedSeconds / scrobbleThresholdSeconds))
    }

    func manualScrobble(track: String, artist: String, album: String, timestamp: Date) async throws {
        guard let service = scrobbleService, let sessionKey = sessionKey else {
            throw ScrobbleError.noSession
        }

        let ts = Int(timestamp.timeIntervalSince1970)
        try await service.scrobble(track: track, artist: artist, album: album, duration: 180, timestamp: ts, sessionKey: sessionKey)

        await MainActor.run {
            self.scrobbleLog.insert(ScrobbleLogEntry(track: track, artist: artist, timestamp: timestamp), at: 0)
            self.statsManager?.recordScrobble(track: track, artist: artist, album: album)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            NotificationCenter.default.post(name: .scrobbleDidComplete, object: nil)
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
