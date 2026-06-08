import SwiftUI

@main
struct LastFMApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
        
        MenuBarExtra {
            MenuBarPopoverContent(appState: appState)
        } label: {
            HStack(spacing: 4) {
                if appState.scrobbleMonitor.isScrobbling,
                   let track = appState.scrobbleMonitor.currentTrackName {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text(truncate(track, max: 20))
                        .font(.system(size: 11))
                } else {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 14))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private func truncate(_ s: String, max: Int) -> String {
        s.count > max ? String(s.prefix(max)) + "…" : s
    }
}

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
    
    // Menu bar stats (from Last.fm API)
    @Published var menuBarTodayCount: Int = 0
    @Published var menuBarWeekCount: Int = 0
    @Published var menuBarMonthCount: Int = 0
    
    let scrobbleMonitor = ScrobbleMonitor()
    let statsManager = ScrobbleStatsManager()
    let service = LastFMService()
    let scrobbleService = ScrobbleService()
    
    /// Tracks which tabs have already loaded to avoid redundant fetches.
    private var loadedTabs: Set<SidebarTab> = []
    private var refreshTimer: Timer?
    private var lastScrobbledTrack: String?
    
    init() {
        scrobbleMonitor.statsManager = statsManager
        startAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    /// Auto-refresh data every 30 seconds and immediately after scrobbles.
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAfterScrobble()
            }
        }
        
        // Observe scrobble events for immediate refresh
        NotificationCenter.default.addObserver(
            forName: .scrobbleDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAfterScrobble()
            }
        }
    }
    
    /// Lightweight refresh — only updates recent tracks and menu bar stats.
    private func refreshAfterScrobble() {
        Task {
            do {
                let (tracks, _, _) = try await service.getRecentTracks(username: "verbog", limit: 20)
                self.recentTracks = tracks
                
                // Also refresh menu bar stats from API
                async let todayCount = service.getScrobbleCount(username: "verbog", period: "7day")
                async let weekCount = service.getScrobbleCount(username: "verbog", period: "1month")
                async let monthCount = service.getScrobbleCount(username: "verbog", period: "3month")
                
                self.menuBarTodayCount = try await todayCount
                self.menuBarWeekCount = try await weekCount
                self.menuBarMonthCount = try await monthCount
            } catch {
                // Silent fail for background refresh
            }
        }
    }
    
    /// Load all data on first launch — runs all API calls in parallel.
    func loadAll() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // All 5 calls run concurrently
                async let tracksResult = service.getRecentTracks(username: "verbog", limit: 20)
                async let artistsResult = service.getTopArtists(username: "verbog", limit: 12)
                async let albumsResult = service.getTopAlbums(username: "verbog", limit: 12)
                async let tracksTopResult = service.getTopTracks(username: "verbog", limit: 12)
                async let userResult = service.getUserInfo(username: "verbog")
                
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
                async let todayCount = self.service.getScrobbleCount(username: "verbog", period: "7day")
                async let weekCount = self.service.getScrobbleCount(username: "verbog", period: "1month")
                async let monthCount = self.service.getScrobbleCount(username: "verbog", period: "3month")
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
                    let (tracks, _, _) = try await service.getRecentTracks(username: "verbog", limit: 20)
                    self.recentTracks = tracks
                case .artists:
                    self.topArtists = try await service.getTopArtists(username: "verbog", limit: 12)
                case .albums:
                    self.topAlbums = try await service.getTopAlbums(username: "verbog", limit: 12)
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
}

enum SidebarTab: String, CaseIterable {
    case recent = "Recent"
    case artists = "Top Artists"
    case albums = "Top Albums"
    case stats = "Stats"
    case reports = "Reports"
}
