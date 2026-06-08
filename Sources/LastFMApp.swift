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

class AppState: ObservableObject {
    @Published var selectedTab: SidebarTab = .recent
    @Published var recentTracks: [RecentTrack] = []
    @Published var topArtists: [TopArtist] = []
    @Published var topAlbums: [TopAlbum] = []
    @Published var topTracks: [TopTrack] = []
    @Published var userInfo: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let scrobbleMonitor = ScrobbleMonitor()
    let statsManager = ScrobbleStatsManager()
    let service = LastFMService()
    let scrobbleService = ScrobbleService()
    
    init() {
        scrobbleMonitor.statsManager = statsManager
    }
    
    func loadAll() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (tracks, _, _) = try await service.getRecentTracks(username: "verbog", limit: 20)
                let artists = try await service.getTopArtists(username: "verbog", limit: 12)
                let albums = try await service.getTopAlbums(username: "verbog", limit: 12)
                let tracksTop = try await service.getTopTracks(username: "verbog", limit: 12)
                let user = try await service.getUserInfo(username: "verbog")
                
                await MainActor.run {
                    self.recentTracks = tracks
                    self.topArtists = artists
                    self.topAlbums = albums
                    self.topTracks = tracksTop
                    self.userInfo = user
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

enum SidebarTab: String, CaseIterable {
    case recent = "Recent"
    case artists = "Top Artists"
    case albums = "Top Albums"
    case stats = "Stats"
    case reports = "Reports"
}
