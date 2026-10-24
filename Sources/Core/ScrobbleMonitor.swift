import Foundation
import SwiftUI
import CryptoKit

/// UI state is main-actor owned; all Apple Events execute on one serial queue.
@MainActor
final class ScrobbleMonitor: ObservableObject {
    @Published private(set) var isScrobbling = false
    @Published private(set) var lastScrobbledTrack: String?
    @Published private(set) var currentTrackName: String?
    @Published private(set) var currentArtist: String?
    @Published private(set) var currentAlbumArt: String?
    @Published private(set) var currentAlbumName: String?
    @Published private(set) var currentPosition = 0
    @Published private(set) var currentDuration = 0
    @Published private(set) var accumulatedSeconds = 0.0
    @Published private(set) var scrobbleThresholdSeconds = 0.0
    @Published private(set) var hasCurrentTrackScrobbled = false
    @Published private(set) var justScrobbled = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var queuedScrobbleCount = 0
    @Published private(set) var isLoved = false
    @Published private(set) var soundVolume = 100
    @Published private(set) var authStatus: AuthStatus = .notAuthenticated
    @Published private(set) var authenticatedUsername: String?
    @Published private(set) var lastError: String?
    @Published private(set) var scrobbleLog: [ScrobbleLogEntry] = []
    @Published private(set) var debugLog: [String] = []
    weak var statsManager: ScrobbleStatsManager?

    struct ScrobbleLogEntry: Identifiable {
        let id = UUID()
        let track: String
        let artist: String
        let timestamp: Date
    }
    enum AuthStatus { case notAuthenticated, awaitingAuthorization, authenticated }
    private let detector: MusicDetector
    private let credentials: CredentialStore
    private let offlineQueue: OfflineScrobbleQueue
    private let service: ScrobbleService
    private let defaults: UserDefaults
    private let pollQueue = DispatchQueue(label: "com.lastfmscrobbler.poll", qos: .utility)
    private var pollTimer: Timer?
    private var musicPlayerObserver: NSObjectProtocol?
    private var playback = PlaybackSession()
    private var monitorGeneration = UUID()
    private var trackGeneration = UUID()
    private var authorizationGeneration = UUID()
    private var pollInFlight = false
    private var flushTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var nowPlayingTask: Task<Void, Never>?
    private var pendingCurrentID: UUID?
    private var nextFlush = Date.distantPast
    private var flushFailures = 0
    private var lastNowPlayingAttempt = Date.distantPast
    private var nextArtworkAttempt = Date.distantPast
    private var busyLoving = false
    private var identityTask: Task<Void, Never>?
    private var identityVerified = false
    private var nextIdentityCheck = Date.distantPast
    private var queueAccount: String? {
        if identityVerified { return authenticatedUsername }
        guard let key = sessionKey else { return nil }
        return "session:" + SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    init(detector: MusicDetector = MusicDetector(), credentials: CredentialStore = .shared,
         queue: OfflineScrobbleQueue = OfflineScrobbleQueue(), service: ScrobbleService? = nil,
         defaults: UserDefaults = .standard) {
        self.detector = detector; self.credentials = credentials; offlineQueue = queue
        self.service = service ?? ScrobbleService(credentialStore: credentials)
        self.defaults = defaults
    }

    var sessionKey: String? { credentials.sessionKey }
    var scrobbleProgress: Double {
        if hasCurrentTrackScrobbled { return 1 }
        guard scrobbleThresholdSeconds > 0 else { return 0 }
        return min(1, max(0, accumulatedSeconds / scrobbleThresholdSeconds))
    }

    func setup(apiKey: String = "", apiSecret: String = "") {
        do {
            try credentials.migrateLegacyDefaults()
            if !apiKey.isEmpty || !apiSecret.isEmpty { try credentials.saveCredentials(apiKey: apiKey, apiSecret: apiSecret) }
            authenticatedUsername = credentials.username
            authStatus = sessionKey != nil && service.isConfigured ? .authenticated : .notAuthenticated
            if let username = authenticatedUsername { Constants.setUsername(username) }
            if authStatus == .authenticated, let scope = queueAccount {
                try offlineQueue.bindLegacyItems(to: scope)
                verifyIdentity()
            }
            queuedScrobbleCount = offlineQueue.count
            if let error = offlineQueue.loadError { lastError = "Pending plays could not be loaded: \(error.localizedDescription)" }
        } catch { lastError = error.localizedDescription; authStatus = .notAuthenticated }
    }

    func saveCredentials(apiKey: String, apiSecret: String) {
        authorizationGeneration = UUID()
        do {
            let oldKey = credentials.apiKey
            try credentials.saveCredentials(apiKey: apiKey, apiSecret: apiSecret)
            if oldKey != apiKey || sessionKey == nil { stopMonitoring(); playback.clear() }
            lastError = nil
            setup()
        } catch { lastError = error.localizedDescription }
    }

    func authenticate() async {
        let attempt = UUID(); authorizationGeneration = attempt
        authStatus = .awaitingAuthorization; lastError = nil
        do {
            let token = try await service.getRequestToken()
            try Task.checkCancellation()
            guard authorizationGeneration == attempt else { return }
            service.openAuthorization(token: token)
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                guard authorizationGeneration == attempt else { return }
                do {
                    let result = try await service.getAuthenticatedSession(token: token)
                    guard authorizationGeneration == attempt else { return }
                    try credentials.saveSession(key: result.key, username: result.name)
                    authenticatedUsername = result.name
                    identityVerified = true
                    Constants.setUsername(result.name)
                    authStatus = .authenticated
                    try offlineQueue.bindLegacyItems(to: result.name)
                    NotificationCenter.default.post(name: .accountDidChange, object: nil)
                    return
                } catch ScrobbleError.apiError(let code, _) where code == 14 { continue }
            }
            throw ScrobbleError.noSession
        } catch {
            guard authorizationGeneration == attempt else { return }
            authStatus = .notAuthenticated
            lastError = error is CancellationError ? nil : error.localizedDescription
        }
    }

    func disconnect() {
        authorizationGeneration = UUID()
        stopMonitoring(); flushTask?.cancel(); identityTask?.cancel(); playback.clear()
        identityVerified = false
        do {
            try credentials.clear()
            authenticatedUsername = nil; authStatus = .notAuthenticated
            lastError = nil
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch { lastError = error.localizedDescription }
    }
    func resetCredentials() {
        disconnect()
        defaults.set(false, forKey: "lastfm_setup_complete")
    }

    func startMonitoring() {
        guard authStatus == .authenticated, sessionKey != nil else {
            lastError = "Connect your Last.fm account in Settings to start scrobbling."; return
        }
        guard !isScrobbling else { reconfigurePolling(); return }
        isScrobbling = true
        monitorGeneration = UUID()
        playback.suspend()
        reconfigurePolling()
        if musicPlayerObserver == nil {
            musicPlayerObserver = DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main
            ) { [weak self] _ in Task { @MainActor in self?.poll() } }
        }
        if currentAlbumArt == nil, let track = playback.track { requestArtwork(track) }
        poll()
        flushOfflineQueue()
    }

    func reconfigurePolling() {
        pollTimer?.invalidate(); pollTimer = nil
        guard isScrobbling else { return }
        playback.suspend()
        let interval = pollInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopMonitoring() {
        pollTimer?.invalidate(); pollTimer = nil
        if let observer = musicPlayerObserver { DistributedNotificationCenter.default().removeObserver(observer) }
        musicPlayerObserver = nil
        isScrobbling = false; isPlaying = false; isPaused = false
        currentTrackName = nil; currentArtist = nil; currentAlbumName = nil; currentAlbumArt = nil
        currentPosition = 0
        monitorGeneration = UUID(); pollInFlight = false
        artworkTask?.cancel(); nowPlayingTask?.cancel()
        playback.suspend()
    }

    private var pollInterval: Double { validPreference("scrobble_poll_interval", range: 2...15, fallback: 5) }
    private func validPreference(_ key: String, range: ClosedRange<Double>, fallback: Double) -> Double {
        let value = defaults.double(forKey: key)
        return range.contains(value) ? value : fallback
    }
    private func threshold(for duration: Int) -> Double {
        switch defaults.string(forKey: "scrobble_threshold") {
        case "half": return Double(duration) / 2
        case "fourMinutes": return 240
        default: return min(Double(duration) / 2, 240)
        }
    }

    private func update<Value: Equatable>(_ key: ReferenceWritableKeyPath<ScrobbleMonitor, Value>, _ value: Value) {
        if self[keyPath: key] != value { self[keyPath: key] = value }
    }

    private func poll() {
        guard isScrobbling, !pollInFlight else { return }
        pollInFlight = true
        let generation = monitorGeneration
        let detector = detector
        Task {
            let result: (MusicTrackInfo?, String?, Int) = await withCheckedContinuation { continuation in
                pollQueue.async {
                    let track = detector.getCurrentTrack()
                    continuation.resume(returning: (track, detector.lastError, detector.getSoundVolume()))
                }
            }
            guard generation == monitorGeneration, isScrobbling else { return }
            pollInFlight = false
            if let error = result.1 { lastError = error; return }
            update(\.soundVolume, result.2)
            processSample(result.0, now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            flushOfflineQueue()
        }
    }

    /// The same transition path is used by real samples and deterministic regression tests.
    func processSample(_ info: MusicTrackInfo?, now: Date, uptime: TimeInterval) {
        guard isScrobbling else { return }
        guard let info else {
            playback.clear(); trackGeneration = UUID()
            artworkTask?.cancel(); nowPlayingTask?.cancel()
            currentTrackName = nil; currentArtist = nil; currentAlbumName = nil; currentAlbumArt = nil
            currentPosition = 0; currentDuration = 0; accumulatedSeconds = 0
            hasCurrentTrackScrobbled = false; justScrobbled = false; isPlaying = false; isPaused = false
            return
        }
        let changed = playback.observe(info, now: now, uptime: uptime, pollInterval: pollInterval)
        if changed {
            trackGeneration = UUID(); pendingCurrentID = nil
            nowPlayingTask?.cancel(); artworkTask?.cancel()
            currentAlbumArt = nil; isLoved = false; justScrobbled = false
            nextArtworkAttempt = .distantPast
            lastNowPlayingAttempt = .distantPast
            requestArtwork(info)
            NotificationCenter.default.post(name: .trackDidChange, object: nil)
        }
        update(\.currentTrackName, info.name); update(\.currentArtist, info.artist); update(\.currentAlbumName, info.album)
        update(\.currentPosition, info.playerPosition); update(\.currentDuration, info.duration)
        update(\.accumulatedSeconds, playback.listened)
        update(\.scrobbleThresholdSeconds, threshold(for: info.duration))
        update(\.isPlaying, info.playerState == "playing"); update(\.isPaused, info.playerState == "paused")
        if !isPlaying { nowPlayingTask?.cancel() }
        if currentAlbumArt == nil, artworkTask == nil, now >= nextArtworkAttempt { requestArtwork(info) }
        if isPlaying && now.timeIntervalSince(lastNowPlayingAttempt) >= validPreference("scrobble_nowplaying_refresh", range: 30...300, fallback: 60) {
            lastNowPlayingAttempt = now
            sendNowPlaying(info)
        }
        let minDuration = validPreference("scrobble_min_duration", range: 30...120, fallback: 30)
        if !playback.submitted, isPlaying, Double(info.duration) > minDuration,
           playback.listened >= threshold(for: info.duration), let start = playback.startedAt {
            do {
                let pending = try offlineQueue.enqueue(track: info.name, artist: info.artist, album: info.album,
                    duration: info.duration, timestamp: Int(start.timeIntervalSince1970), account: queueAccount)
                pendingCurrentID = pending.id
                playback.markSubmitted()
                queuedScrobbleCount = offlineQueue.count
                flushOfflineQueue()
            } catch { lastError = "Could not save this play for delivery: \(error.localizedDescription)" }
        }
    }

    private func requestArtwork(_ info: MusicTrackInfo) {
        let token = trackGeneration
        let monitoring = monitorGeneration
        let detector = detector
        artworkTask = Task {
            defer {
                if token == trackGeneration, monitoring == monitorGeneration {
                    artworkTask = nil
                    nextArtworkAttempt = Date().addingTimeInterval(15)
                }
            }
            let local: String? = await withCheckedContinuation { continuation in
                pollQueue.async { continuation.resume(returning: detector.getArtwork(for: info)) }
            }
            guard !Task.isCancelled, token == trackGeneration, monitoring == monitorGeneration else { return }
            if let local { currentAlbumArt = local; return }
            let fallback = await ArtistImageService.shared.fetchAlbumCover(artist: info.artist, album: info.album, track: info.name)
            guard !Task.isCancelled, token == trackGeneration, monitoring == monitorGeneration else { return }
            currentAlbumArt = fallback
        }
    }

    func forceNowPlayingUpdate() {
        guard isScrobbling, isPlaying, let info = playback.track else { return }
        sendNowPlaying(info)
    }
    private func sendNowPlaying(_ info: MusicTrackInfo) {
        guard isScrobbling, isPlaying || info.playerState == "playing", let key = sessionKey else { return }
        let token = trackGeneration; let monitoring = monitorGeneration
        nowPlayingTask?.cancel()
        nowPlayingTask = Task {
            do {
                try Task.checkCancellation()
                guard token == trackGeneration, monitoring == monitorGeneration else { return }
                _ = try await service.updateNowPlaying(track: info.name, artist: info.artist, album: info.album, duration: info.duration, sessionKey: key)
                guard !Task.isCancelled, token == trackGeneration, monitoring == monitorGeneration else { return }
                NotificationCenter.default.post(name: .nowPlayingDidUpdate, object: nil)
            } catch {
                guard !Task.isCancelled, token == trackGeneration else { return }
                handle(error)
            }
        }
    }

    func queueOfflineScrobble(track: String, artist: String, album: String, duration: Int, timestamp: Int) {
        do {
            try offlineQueue.enqueue(track: track, artist: artist, album: album, duration: duration, timestamp: timestamp, account: queueAccount)
            queuedScrobbleCount = offlineQueue.count
        } catch { lastError = error.localizedDescription }
    }
    func loadOfflineQueue() { queuedScrobbleCount = offlineQueue.count }

    private func verifyIdentity() {
        guard !identityVerified, identityTask == nil, Date() >= nextIdentityCheck, let key = sessionKey else { return }
        let scope = queueAccount
        identityTask = Task {
            defer { identityTask = nil }
            do {
                let owner = try await service.getAuthenticatedUsername(sessionKey: key)
                guard !Task.isCancelled, key == sessionKey else { return }
                try credentials.saveSession(key: key, username: owner)
                if let scope { try offlineQueue.rebind(from: scope, to: owner) }
                authenticatedUsername = owner; identityVerified = true; lastError = nil
                Constants.setUsername(owner)
                NotificationCenter.default.post(name: .accountDidChange, object: nil)
                flushOfflineQueue()
            } catch {
                guard !Task.isCancelled else { return }
                nextIdentityCheck = Date().addingTimeInterval(30)
                handle(error)
            }
        }
    }

    func flushOfflineQueue() {
        guard identityVerified else { verifyIdentity(); return }
        guard flushTask == nil, Date() >= nextFlush, authStatus == .authenticated,
              let key = sessionKey, let account = authenticatedUsername else { return }
        let items = offlineQueue.items.filter { $0.account?.caseInsensitiveCompare(account) == .orderedSame }
        guard !items.isEmpty else { return }
        flushTask = Task {
            defer { flushTask = nil; queuedScrobbleCount = offlineQueue.count }
            for item in items {
                guard !Task.isCancelled, key == sessionKey, authenticatedUsername == account else { return }
                do {
                    try await service.scrobble(track: item.track, artist: item.artist, album: item.album,
                        duration: item.duration, timestamp: item.timestamp, sessionKey: key)
                    // Accepted is an account-scoped durable event, even if playback moved on.
                    try offlineQueue.remove(id: item.id)
                    statsManager?.recordScrobble(track: item.track, artist: item.artist, album: item.album,
                        timestamp: Date(timeIntervalSince1970: Double(item.timestamp)))
                    lastScrobbledTrack = "\(item.track) — \(item.artist)"
                    scrobbleLog.insert(ScrobbleLogEntry(track: item.track, artist: item.artist,
                        timestamp: Date(timeIntervalSince1970: Double(item.timestamp))), at: 0)
                    scrobbleLog = Array(scrobbleLog.prefix(20))
                    if item.id == pendingCurrentID { hasCurrentTrackScrobbled = true; justScrobbled = true }
                    flushFailures = 0; nextFlush = .distantPast
                    lastError = nil
                    NotificationCenter.default.post(name: .scrobbleDidComplete, object: nil)
                } catch {
                    guard !Task.isCancelled else { return }
                    handle(error)
                    if let failure = error as? ScrobbleError, !failure.isRetryable, !failure.isAuthenticationError {
                        // An explicit rejection is final, never a successful local scrobble.
                        do { try offlineQueue.remove(id: item.id) }
                        catch { lastError = error.localizedDescription; return }
                        continue
                    }
                    flushFailures += 1
                    nextFlush = Date().addingTimeInterval(min(300, pow(2, Double(min(flushFailures, 6))) * 5))
                    return
                }
            }
        }
    }

    private func handle(_ error: Error) {
        lastError = error.localizedDescription
        log(error.localizedDescription)
        if let failure = error as? ScrobbleError, failure.isAuthenticationError {
            authStatus = .notAuthenticated
            stopMonitoring()
        }
    }
    private func log(_ message: String) {
        debugLog.insert(message, at: 0)
        debugLog = Array(debugLog.prefix(50))
    }

    private func control(_ action: @escaping (MusicDetector) -> Void) {
        let detector = detector
        pollQueue.async { action(detector) }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            poll()
            try? await Task.sleep(nanoseconds: 500_000_000)
            poll()
        }
    }
    func togglePlayPause() { control { $0.playPause() } }
    func nextTrack() { control { $0.nextTrack() } }
    func previousTrack() { control { $0.previousTrack() } }
    func seekTo(position: Double) {
        playback.seek(); currentPosition = max(0, Int(position))
        control { $0.setPlayerPosition(position) }
    }
    func setVolume(_ volume: Int) { soundVolume = max(0, min(100, volume)); control { $0.setSoundVolume(volume) } }
    func toggleLoveCurrentTrack() {
        guard !busyLoving, let key = sessionKey, let info = playback.track else { return }
        busyLoving = true
        let token = trackGeneration; let loved = !isLoved
        Task {
            defer { busyLoving = false }
            do {
                if loved { try await service.loveTrack(track: info.name, artist: info.artist, sessionKey: key) }
                else { try await service.unloveTrack(track: info.name, artist: info.artist, sessionKey: key) }
                guard token == trackGeneration else { return }
                isLoved = loved
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            } catch { handle(error) }
        }
    }
    func manualScrobble(track: String, artist: String, album: String, timestamp: Date) async throws {
        guard let key = sessionKey else { throw ScrobbleError.noSession }
        try await service.scrobble(track: track, artist: artist, album: album, duration: 180,
            timestamp: Int(timestamp.timeIntervalSince1970), sessionKey: key)
        statsManager?.recordScrobble(track: track, artist: artist, album: album, timestamp: timestamp)
        scrobbleLog.insert(ScrobbleLogEntry(track: track, artist: artist, timestamp: timestamp), at: 0)
        NotificationCenter.default.post(name: .scrobbleDidComplete, object: nil)
    }
}
