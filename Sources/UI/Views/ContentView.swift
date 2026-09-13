import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Full-window ambient artwork backdrop
            AmbientArtworkBackground(artworkURL: appState.scrobbleMonitor.currentAlbumArt)

            HStack(spacing: 0) {
                SidebarView()
                Rectangle()
                    .fill(DS.Colors.sidebarDivider)
                    .frame(width: 1)
                MainContentView()
            }
        }
        .frame(minWidth: DS.Layout.minWindowWidth, minHeight: DS.Layout.minWindowHeight)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        .sheet(item: $appState.inspectorEntity) { entity in
            EntityInspectorSheet(entity: entity)
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showManualScrobble) {
            ManualScrobbleSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showShareCard) {
            ShareCardView(
                track: appState.scrobbleMonitor.currentTrackName,
                artist: appState.scrobbleMonitor.currentArtist,
                album: appState.scrobbleMonitor.currentAlbumName,
                artworkURL: appState.scrobbleMonitor.currentAlbumArt
            )
            .environmentObject(appState)
        }
        // Global Keyboard Shortcuts
        .background(
            Group {
                Button("") {
                    appState.scrobbleMonitor.toggleLoveCurrentTrack()
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button("") {
                    appState.showManualScrobble = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("") {
                    appState.refreshRecentTracks()
                    appState.refreshTab(appState.selectedTab)
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("") { appState.selectedTab = .recent }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("") { appState.selectedTab = .artists }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("") { appState.selectedTab = .albums }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("") { appState.selectedTab = .stats }
                    .keyboardShortcut("4", modifiers: [.command])
                Button("") { appState.selectedTab = .reports }
                    .keyboardShortcut("5", modifiers: [.command])
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
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
            HStack(alignment: .center) {
                Text(headerTitle)
                    .font(DS.Fonts.heading(22))
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                if let error = appState.errorMessage {
                    Text(error)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.error.opacity(0.8))
                        .padding(.leading, 8)
                }

                HStack(spacing: 8) {
                    // Manual Scrobble Button
                    Button {
                        appState.showManualScrobble = true
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Scrobble")
                                .font(DS.Fonts.bodyMedium(12))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(appState.accentColor, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Manual Scrobble (⌘N)")

                    // Refresh Button
                    Button {
                        appState.refreshRecentTracks()
                        appState.refreshTab(appState.selectedTab)
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Refresh (⌘R)")
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.lg)

            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // Now Playing Hero Banner
                    NowPlayingHeroView()

                    // Tab Content
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
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.clear)
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
