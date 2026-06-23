import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            Rectangle()
                .fill(DS.Colors.sidebarDivider)
                .frame(width: 1)
            MainContentView()
        }
        .frame(minWidth: DS.Layout.minWindowWidth, minHeight: DS.Layout.minWindowHeight)
        .background(.ultraThinMaterial)
        .onAppear {
            appState.loadAll()
            appState.scrobbleMonitor.setup()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if appState.scrobbleMonitor.authStatus == .authenticated {
                    appState.scrobbleMonitor.startMonitoring()
                }
            }
        }
    }
}

// MARK: - Main Content

struct MainContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(headerTitle)
                    .font(DS.Fonts.heading())
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()

                if let error = appState.errorMessage {
                    Text(error)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.error.opacity(0.8))
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xl)

            // Content
            ScrollView {
                switch appState.selectedTab {
                case .recent:
                    RecentTracksView()
                case .artists:
                    TopArtistsView()
                case .albums:
                    TopAlbumsView()
                case .stats:
                    StatsView()
                case .reports:
                    ReportsView()
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(DS.Colors.background)
    }

    private var headerTitle: String {
        switch appState.selectedTab {
        case .recent: return "Recently Played"
        case .artists: return "Top Artists"
        case .albums: return "Top Albums"
        case .stats: return "Scrobble Stats"
        case .reports: return "Listening Reports"
        }
    }
}

// MARK: - Recent Tracks

struct RecentTracksView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isLoading {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    SkeletonTrackRow()
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        } else if appState.recentTracks.isEmpty {
            EmptyState(
                icon: "clock",
                title: "No recent tracks",
                subtitle: "Play some music on Apple Music to see your scrobbles here."
            )
        } else {
            LazyVStack(spacing: 2) {
                ForEach(appState.recentTracks) { track in
                    TrackRow(track: track)
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
    }
}

// MARK: - Top Artists

struct TopArtistsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isLoading {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg)
            ], spacing: DS.Spacing.lg) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonGridCard()
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        } else if appState.topArtists.isEmpty {
            EmptyState(
                icon: "person.2",
                title: "No artists yet",
                subtitle: "Your top artists will appear here once you start scrobbling."
            )
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg)
            ], spacing: DS.Spacing.lg) {
                ForEach(appState.topArtists) { artist in
                    ArtistCard(artist: artist)
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
    }
}

// MARK: - Top Albums

struct TopAlbumsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isLoading {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg)
            ], spacing: DS.Spacing.lg) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonGridCard()
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        } else if appState.topAlbums.isEmpty {
            EmptyState(
                icon: "square.stack",
                title: "No albums yet",
                subtitle: "Your top albums will appear here once you start scrobbling."
            )
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg),
                GridItem(.flexible(), spacing: DS.Spacing.lg)
            ], spacing: DS.Spacing.lg) {
                ForEach(appState.topAlbums) { album in
                    AlbumCard(album: album)
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
    }
}
