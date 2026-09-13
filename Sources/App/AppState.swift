import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var recentTracks: [RecentTrack] = []
    @Published var topArtists: [TopArtist] = []
    @Published var topAlbums: [TopAlbum] = []
    @Published var topTracks: [TopTrack] = []
    @Published var userInfo: UserInfo?
    @Published var selectedTab: SidebarTab = .recent
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var accentColorName: String = UserDefaults.standard.string(forKey: "accent_color") ?? "red"
    
    var accentColor: Color {
        DS.Colors.color(for: accentColorName)
    }
    
    func setAccentColor(_ name: String) {
        accentColorName = name
        UserDefaults.standard.set(name, forKey: "accent_color")
    }
    
    // Menu bar stats (from Last.fm API)
    @Published var menuBarTodayCount: Int = 0
    @Published var menuBarWeekCount: Int = 0
    @Published var menuBarMonthCount: Int = 0

    // Modals & Drill-downs
    @Published var inspectorEntity: InspectorEntity? = nil
    @Published var showManualScrobble: Bool = false
    @Published var showShareCard: Bool = false
    
    let scrobbleMonitor = ScrobbleMonitor()
    let statsManager = ScrobbleStatsManager()
    let service = LastFMService()
    let scrobbleService = ScrobbleService()
    
    /// Tracks which tabs have already loaded to avoid redundant fetches.
    private var loadedTabs: Set<SidebarTab> = []
    private var refreshTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastScrobbledTrack: String?
    private var lastMenuBarStatsFetch: Date = .distantPast
    
    init() {
        scrobbleMonitor.statsManager = statsManager
        startAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    /// Auto-refresh data in background periodically and immediately after scrobbles or track skips.
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only poll if music is actively playing
                if self?.scrobbleMonitor.isPlaying == true {
                    self?.refreshAfterScrobble()
                }
            }
        }
        
        // Observe scrobble events for immediate refresh
        let scrobbleObs = NotificationCenter.default.addObserver(
            forName: .scrobbleDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAfterScrobble()
            }
        }
        notificationObservers.append(scrobbleObs)

        // Observe track skip / change events to immediately refresh recent tracks
        let skipObs = NotificationCenter.default.addObserver(
            forName: .trackDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRecentTracks()
            }
        }
        notificationObservers.append(skipObs)

        // When Last.fm updates now-playing, re-query after a slight delay to ensure the new track is indexed
        let nowPlayingObs = NotificationCenter.default.addObserver(
            forName: .nowPlayingDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s delay for Last.fm propagation
                self?.refreshRecentTracks()
            }
        }
        notificationObservers.append(nowPlayingObs)
    }
    
    /// Lightweight refresh — only updates recent tracks and menu bar stats.
    func refreshRecentTracks() {
        Task {
            do {
                let (tracks, _, _) = try await service.getRecentTracks(username: Constants.lastFMUsername, limit: 20)
                await MainActor.run {
                    self.recentTracks = tracks
                }
            } catch {
                // Silent fail for background refresh
            }
        }
    }

    /// Refresh called after a confirmed scrobble.
    private func refreshAfterScrobble() {
        refreshRecentTracks()
        
        Task {
            let now = Date()
            if now.timeIntervalSince(lastMenuBarStatsFetch) >= 300 {
                lastMenuBarStatsFetch = now
                
                // Refresh menu bar stats from API
                async let todayCount = service.getScrobbleCount(username: Constants.lastFMUsername, period: "7day")
                async let weekCount = service.getScrobbleCount(username: Constants.lastFMUsername, period: "1month")
                async let monthCount = service.getScrobbleCount(username: Constants.lastFMUsername, period: "3month")
                
                do {
                    let today = try await todayCount
                    let week = try await weekCount
                    let month = try await monthCount
                    await MainActor.run {
                        self.menuBarTodayCount = today
                        self.menuBarWeekCount = week
                        self.menuBarMonthCount = month
                    }
                } catch {}
            }
        }
    }
    
    /// Load all data on first launch — runs all API calls in parallel.
    func loadAll() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        // Also push now-playing when user manually refreshes
        scrobbleMonitor.forceNowPlayingUpdate()
        
        Task {
            do {
                // All 5 calls run concurrently
                async let tracksResult = service.getRecentTracks(username: Constants.lastFMUsername, limit: 20)
                async let artistsResult = service.getTopArtists(username: Constants.lastFMUsername, limit: 12)
                async let albumsResult = service.getTopAlbums(username: Constants.lastFMUsername, limit: 12)
                async let tracksTopResult = service.getTopTracks(username: Constants.lastFMUsername, limit: 12)
                async let userResult = service.getUserInfo(username: Constants.lastFMUsername)
                
                let (tracks, _, _) = try await tracksResult
                let artists = try await artistsResult
                let albums = try await albumsResult
                let tracksTop = try await tracksTopResult
                let user = try await userResult
                
                self.recentTracks = tracks
                self.topArtists = artists
                self.topAlbums = albums
                self.topTracks = tracksTop
                self.userInfo = user
                self.isLoading = false
                self.loadedTabs = Set(SidebarTab.allCases)
                
                // Fetch menu bar stats from API
                async let todayCount = self.service.getScrobbleCount(username: Constants.lastFMUsername, period: "7day")
                async let weekCount = self.service.getScrobbleCount(username: Constants.lastFMUsername, period: "1month")
                async let monthCount = self.service.getScrobbleCount(username: Constants.lastFMUsername, period: "3month")
                self.menuBarTodayCount = try await todayCount
                self.menuBarWeekCount = try await weekCount
                self.menuBarMonthCount = try await monthCount
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Load data for a specific tab. Skips if already loaded.
    func loadTab(_ tab: SidebarTab) {
        guard !loadedTabs.contains(tab) else { return }
        loadedTabs.insert(tab)
        
        Task {
            do {
                switch tab {
                case .recent:
                    let (tracks, _, _) = try await service.getRecentTracks(username: Constants.lastFMUsername, limit: 20)
                    self.recentTracks = tracks
                case .artists:
                    self.topArtists = try await service.getTopArtists(username: Constants.lastFMUsername, limit: 12)
                case .albums:
                    self.topAlbums = try await service.getTopAlbums(username: Constants.lastFMUsername, limit: 12)
                case .stats:
                    // Stats loads its own data independently
                    break
                case .reports:
                    // Reports loads its own data independently
                    break
                }
            } catch {
                // Silently fail for tab loads — user can retry by switching tabs
            }
        }
    }
    
    /// Force-reload a tab's data (for pull-to-refresh, etc.).
    func refreshTab(_ tab: SidebarTab) {
        loadedTabs.remove(tab)
        loadTab(tab)
    }

    /// Remove a track locally from recent scrobbles and open Last.fm library edit page.
    func removeRecentTrack(id: UUID, openLibraryWeb: Bool = true) {
        recentTracks.removeAll { $0.id == id }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        if openLibraryWeb {
            let username = Constants.lastFMUsername
            if let url = URL(string: "https://www.last.fm/user/\(username)/library") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
