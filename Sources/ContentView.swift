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

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(DS.Colors.accent.gradient)
                Text("Last.fm")
                    .font(DS.Fonts.heading(24))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(.top, 24)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last.fm Scrobbler")

            // User info card
            if let user = appState.userInfo {
                Card(padding: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.md) {
                        MediaImage(url: user.imageURL, placeholder: "person.circle.fill", size: DS.Layout.avatarSize, cornerRadius: 40)
                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))

                        Text(user.realname ?? user.name)
                            .font(DS.Fonts.body(16).weight(.semibold))
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text("@\(user.name)")
                            .font(DS.Fonts.caption())
                            .foregroundStyle(DS.Colors.textTertiary)

                        HStack(spacing: DS.Spacing.xl) {
                            StatBadge(value: user.playcount, label: "Scrobbles")
                            StatBadge(value: user.artistCount, label: "Artists")
                            StatBadge(value: user.albumCount, label: "Albums")
                        }
                        .padding(.top, DS.Spacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
            }

            // Scrobbler status
            ScrobblerStatusCard()
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)

            // Navigation
            VStack(spacing: DS.Spacing.sm) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarButton(
                        title: tab.rawValue,
                        icon: iconForTab(tab),
                        isSelected: appState.selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()

            // Bottom buttons
            HStack(spacing: DS.Spacing.md) {
                IconButton(icon: "gearshape.fill", label: "Settings") {
                    showSettings = true
                }

                SecondaryButton(title: "Refresh", icon: appState.isLoading ? nil : "arrow.clockwise") {
                    appState.loadAll()
                }
            }
            .padding(.bottom, DS.Spacing.xl)
            .padding(.horizontal, DS.Spacing.xl)
        }
        .frame(width: DS.Layout.sidebarWidth)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private func iconForTab(_ tab: SidebarTab) -> String {
        switch tab {
        case .recent: return "clock.fill"
        case .artists: return "person.2.fill"
        case .albums: return "square.stack.fill"
        case .stats: return "chart.bar.fill"
        case .reports: return "doc.text.fill"
        }
    }
}

// MARK: - Scrobbler Status Card

struct ScrobblerStatusCard: View {
    @EnvironmentObject var appState: AppState
    @State private var showDebug = false

    var body: some View {
        let monitor = appState.scrobbleMonitor

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    StatusDot(isActive: monitor.isScrobbling)
                    Text(monitor.isScrobbling ? "Scrobbling" : "Scrobbler Off")
                        .font(DS.Fonts.captionMedium(12))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    if monitor.isScrobbling {
                        IconButton(icon: "ladybug", label: "Toggle debug log", isActive: showDebug) {
                            showDebug.toggle()
                        }
                    }
                }

                if monitor.isScrobbling {
                    if let track = monitor.currentTrackName, let artist = monitor.currentArtist {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(track)
                                .font(DS.Fonts.captionMedium(11))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)
                            Text(artist)
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Now playing: \(track) by \(artist)")
                    } else {
                        Text("Waiting for music…")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !monitor.scrobbleLog.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(monitor.scrobbleLog.prefix(3)) { entry in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 7))
                                    Text(entry.track)
                                        .font(DS.Fonts.caption(9))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(DS.Colors.success.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if showDebug && !monitor.debugLog.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(monitor.debugLog.prefix(6), id: \.self) { entry in
                                Text(entry)
                                    .font(DS.Fonts.mono(7))
                                    .foregroundStyle(DS.Colors.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .accessibilityLabel("Debug log")
                    }
                } else if monitor.authStatus == .notAuthenticated {
                    Text("Connect your Last.fm account in Settings to start scrobbling.")
                        .font(DS.Fonts.caption(10))
                        .foregroundStyle(DS.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var apiKey = ScrobbleService.defaultAPIKey
    @State private var apiSecret = ""
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(DS.Fonts.heading(18))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(DS.Spacing.xxl)

            Divider().background(DS.Colors.sidebarDivider)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    // Scrobbler Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        Text("Scrobbler")
                            .font(DS.Fonts.subheading())
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text("Automatically scrobble your Apple Music tracks to Last.fm.")
                            .font(DS.Fonts.caption())
                            .foregroundStyle(DS.Colors.textTertiary)

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("API Key")
                                .font(DS.Fonts.captionMedium(11))
                                .foregroundStyle(DS.Colors.textSecondary)
                            TextField("API Key", text: $apiKey)
                                .inputStyle()
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("API Secret")
                                .font(DS.Fonts.captionMedium(11))
                                .foregroundStyle(DS.Colors.textSecondary)
                            SecureField("API Secret", text: $apiSecret)
                                .inputStyle()
                        }

                        Text("Register your app at last.fm/api/account/create to get an API key and secret.")
                            .font(DS.Fonts.caption(10))
                            .foregroundStyle(DS.Colors.textMuted)

                        if appState.scrobbleMonitor.authStatus == .authenticated {
                            DestructiveButton(title: "Disconnect", icon: "link.circle.fill") {
                                appState.scrobbleMonitor.disconnect()
                            }
                        } else if !apiSecret.isEmpty {
                            PrimaryButton(
                                title: "Connect to Last.fm",
                                icon: "link",
                                isLoading: isAuthenticating
                            ) {
                                isAuthenticating = true
                                appState.scrobbleMonitor.saveCredentials(apiKey: apiKey, apiSecret: apiSecret)
                                Task {
                                    await appState.scrobbleMonitor.authenticate()
                                    await MainActor.run {
                                        isAuthenticating = false
                                        if appState.scrobbleMonitor.authStatus == .authenticated {
                                            appState.scrobbleMonitor.startMonitoring()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Monitor Toggle
                    if appState.scrobbleMonitor.authStatus == .authenticated {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            Text("Auto-Scrobble")
                                .font(DS.Fonts.subheading())
                                .foregroundStyle(DS.Colors.textPrimary)

                            HStack {
                                Text(appState.scrobbleMonitor.isScrobbling ? "Active" : "Paused")
                                    .font(DS.Fonts.caption())
                                    .foregroundStyle(DS.Colors.textSecondary)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { appState.scrobbleMonitor.isScrobbling },
                                    set: { newValue in
                                        if newValue {
                                            appState.scrobbleMonitor.startMonitoring()
                                        } else {
                                            appState.scrobbleMonitor.stopMonitoring()
                                        }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .accessibilityLabel("Auto-scrobble toggle")
                            }
                            .padding(DS.Spacing.lg)
                            .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                }
                .padding(DS.Spacing.xxl)
            }
        }
        .frame(width: 420, height: 480)
        .background(.ultraThinMaterial)
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "lastfm_api_key") ?? ScrobbleService.defaultAPIKey
            apiSecret = UserDefaults.standard.string(forKey: "lastfm_api_secret") ?? ""
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

struct TrackRow: View {
    let track: RecentTrack

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Album art
            MediaImage(url: track.imageURL, placeholder: "music.note", size: DS.Layout.trackRowHeight, cornerRadius: DS.Radius.sm)

            // Track info
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(track.name)
                    .font(DS.Fonts.body(14).weight(.semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(DS.Fonts.caption(12))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)

                if !track.album.isEmpty {
                    Text(track.album)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Now playing indicator or timestamp
            if track.nowPlaying {
                HStack(spacing: DS.Spacing.sm) {
                    PlayingAnimation()
                    Text("NOW PLAYING")
                        .font(DS.Fonts.caption(10).weight(.bold))
                }
                .foregroundStyle(DS.Colors.success)
                .accessibilityLabel("Currently playing")
            } else if let uts = track.date, let timestamp = TimeInterval(uts) {
                Text(timeAgo(from: timestamp))
                    .font(DS.Fonts.caption(11))
                    .foregroundStyle(DS.Colors.textMuted)
                    .accessibilityLabel("Played \(timeAgo(from: timestamp))")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .cardStyle()
    }

    private func timeAgo(from timestamp: TimeInterval) -> String {
        let now = Date().timeIntervalSince1970
        let diff = now - timestamp

        if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}

struct PlayingAnimation: View {
    @State private var phase = 0
    @State private var timer: Timer?

    private let heights: [[CGFloat]] = [
        [6, 10, 8],
        [10, 6, 10],
        [8, 10, 6]
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.Colors.success)
                    .frame(width: 2, height: heights[phase][i])
            }
        }
        .frame(width: 10, height: 14)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % heights.count
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
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

struct ArtistCard: View {
    let artist: TopArtist

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            MediaImage(url: artist.imageURL, placeholder: "person.fill", size: DS.Layout.cardImageSize, cornerRadius: DS.Radius.lg)

            Text(artist.name)
                .font(DS.Fonts.body(12).weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Text("\(artist.playcount) plays")
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted)
        }
        .padding(DS.Spacing.lg)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artist.name), \(artist.playcount) plays")
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

struct AlbumCard: View {
    let album: TopAlbum

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            MediaImage(url: album.imageURL, placeholder: "square.stack.fill", size: DS.Layout.cardImageSize, cornerRadius: DS.Radius.lg)

            Text(album.name)
                .font(DS.Fonts.body(12).weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Text(album.artist)
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted)
                .lineLimit(1)

            Text("\(album.playcount) plays")
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted.opacity(0.7))
        }
        .padding(DS.Spacing.lg)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.name) by \(album.artist), \(album.playcount) plays")
    }
}
