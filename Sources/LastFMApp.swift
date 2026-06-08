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
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: SidebarTab = .recent
    @Published var recentTracks: [RecentTrack] = []
    @Published var topArtists: [TopArtist] = []
    @Published var topAlbums: [TopAlbum] = []
    @Published var userInfo: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let scrobbleMonitor = ScrobbleMonitor()
    private let service = LastFMService()
    
    func loadAll() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let tracks = try await service.getRecentTracks(username: "verbog", limit: 20)
                let artists = try await service.getTopArtists(username: "verbog", limit: 12)
                let albums = try await service.getTopAlbums(username: "verbog", limit: 12)
                let user = try await service.getUserInfo(username: "verbog")
                
                await MainActor.run {
                    self.recentTracks = tracks
                    self.topArtists = artists
                    self.topAlbums = albums
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
}
