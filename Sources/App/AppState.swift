import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var recentTracks: [RecentTrack] = []
    @Published var topArtists: [TopArtist] = []
    @Published var topAlbums: [TopAlbum] = []
    @Published var topTracks: [TopTrack] = []
    @Published var userInfo: UserInfo?
    @Published var selectedTab: SidebarTab = .recent
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var accentColorName = UserDefaults.standard.string(forKey: "accent_color") ?? "red"
    @Published var menuBarTodayCount = 0
    @Published var menuBarWeekCount = 0
    @Published var menuBarMonthCount = 0
    @Published var inspectorEntity: InspectorEntity?
    @Published var showManualScrobble = false
    @Published var showShareCard = false
    @Published var showSettings = false

    let scrobbleMonitor = ScrobbleMonitor()
    let statsManager = ScrobbleStatsManager()
    let service = LastFMService()
    let scrobbleService = ScrobbleService()
    private var subscriptions = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var loadTask: Task<Void, Never>?
    private var recentTask: Task<Void, Never>?
    private var countsTask: Task<Void, Never>?
    private var started = false
    private var accountGeneration = UUID()
    private var loadGeneration = UUID()

    var accentColor: Color { DS.Colors.color(for: accentColorName) }

    init() {
        scrobbleMonitor.statsManager = statsManager
        scrobbleMonitor.objectWillChange
            .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
        for name in [Notification.Name.scrobbleDidComplete, .trackDidChange, .nowPlayingDidUpdate] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.service.invalidateCache()
                    self?.refreshRecentTracks()
                    if name == .scrobbleDidComplete { self?.refreshCounts() }
                }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: .accountDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.accountChanged() }
            .store(in: &subscriptions)
    }

    deinit { refreshTimer?.invalidate() }

    func startup() {
        guard !started else { return }
        started = true
        scrobbleMonitor.setup()
        if scrobbleMonitor.authStatus == .authenticated {
            // Existing installations should not be forced through onboarding again.
            UserDefaults.standard.set(true, forKey: "lastfm_setup_complete")
            scrobbleMonitor.startMonitoring()
        }
        loadAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRecentTracks()
                self?.refreshCounts()
            }
        }
    }

    func setAccentColor(_ name: String) {
        accentColorName = name
        UserDefaults.standard.set(name, forKey: "accent_color")
    }

    private func accountChanged() {
        accountGeneration = UUID()
        loadTask?.cancel(); recentTask?.cancel(); countsTask?.cancel()
        recentTracks = []; topArtists = []; topAlbums = []; topTracks = []; userInfo = nil
        menuBarTodayCount = 0; menuBarWeekCount = 0; menuBarMonthCount = 0
        service.invalidateCache()
        loadAll()
    }

    func refreshRecentTracks() {
        let username = Constants.lastFMUsername
        guard !username.isEmpty else { return }
        recentTask?.cancel()
        let generation = accountGeneration
        recentTask = Task {
            do {
                let result = try await service.getRecentTracks(username: username, limit: 20, forceRefresh: true)
                guard !Task.isCancelled, generation == accountGeneration else { return }
                recentTracks = result.tracks
            } catch is CancellationError { }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        }
    }

    func refreshCounts() {
        let username = Constants.lastFMUsername
        guard !username.isEmpty else { return }
        countsTask?.cancel()
        let generation = accountGeneration
        let now = Date()
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? day
        let month = calendar.dateInterval(of: .month, for: now)?.start ?? day
        countsTask = Task {
            do {
                async let today = service.getScrobbleCount(username: username, from: day, to: now)
                async let weekly = service.getScrobbleCount(username: username, from: week, to: now)
                async let monthly = service.getScrobbleCount(username: username, from: month, to: now)
                let values = try await (today, weekly, monthly)
                guard !Task.isCancelled, generation == accountGeneration else { return }
                menuBarTodayCount = values.0
                menuBarWeekCount = values.1
                menuBarMonthCount = values.2
            } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        }
    }

    /// A deliberate refresh invalidates cache and refreshes the visible independent view.
    func loadAll() {
        loadTask?.cancel()
        service.invalidateCache()
        NotificationCenter.default.post(name: .dashboardDidRefresh, object: nil)
        let username = Constants.lastFMUsername
        guard !username.isEmpty else { isLoading = false; return }
        isLoading = true
        let request = UUID()
        loadGeneration = request
        errorMessage = nil
        let generation = accountGeneration
        refreshCounts()
        loadTask = Task {
            defer { if generation == accountGeneration, request == loadGeneration { isLoading = false } }
            do {
                async let recent = service.getRecentTracks(username: username, limit: 20, forceRefresh: true)
                async let artists = service.getTopArtists(username: username, limit: 12)
                async let albums = service.getTopAlbums(username: username, limit: 12)
                async let tracks = service.getTopTracks(username: username, limit: 12)
                async let user = service.getUserInfo(username: username)
                let result = try await (recent, artists, albums, tracks, user)
                guard !Task.isCancelled, generation == accountGeneration else { return }
                recentTracks = result.0.tracks
                topArtists = result.1
                topAlbums = result.2
                topTracks = result.3
                userInfo = result.4
            } catch { if !Task.isCancelled, generation == accountGeneration { errorMessage = error.localizedDescription } }
        }
    }

    func loadTab(_ tab: SidebarTab) { refreshTab(tab) }
    func refreshTab(_ tab: SidebarTab) { loadAll() }

    func removeRecentTrack(id: UUID, openLibraryWeb: Bool = true) {
        recentTracks.removeAll { $0.id == id }
        if openLibraryWeb, let url = URL(string: "https://www.last.fm/user/\(Constants.lastFMUsername)/library") {
            NSWorkspace.shared.open(url)
        }
    }
}
