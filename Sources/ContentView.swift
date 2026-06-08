import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView()
            
            // Divider
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
            
            // Main Content
            MainContentView()
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(.ultraThinMaterial)
        .onAppear {
            appState.loadAll()
            appState.scrobbleMonitor.setup()
            // Delay slightly to let setup() @Published updates propagate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if appState.scrobbleMonitor.authStatus == .authenticated {
                    appState.scrobbleMonitor.startMonitoring()
                }
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.purple.gradient)
                Text("Last.fm")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)
            .padding(.bottom, 8)
            
            // User info card
            if let user = appState.userInfo {
                VStack(spacing: 8) {
                    CachedAsyncImage(url: user.imageURL) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 2))
                    
                    Text(user.realname ?? user.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("@\(user.name)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    HStack(spacing: 16) {
                        StatBadge(value: user.playcount, label: "Scrobbles")
                        StatBadge(value: user.artistCount, label: "Artists")
                        StatBadge(value: user.albumCount, label: "Albums")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            
            // Scrobbler Status Card
            ScrobblerStatusCard()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            // Navigation
            VStack(spacing: 4) {
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
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Bottom buttons
            HStack(spacing: 8) {
                // Settings button
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                // Refresh button
                Button {
                    appState.loadAll()
                } label: {
                    HStack {
                        if appState.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .frame(width: 220)
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

struct ScrobblerStatusCard: View {
    @EnvironmentObject var appState: AppState
    @State private var showDebug = false
    
    var body: some View {
        let monitor = appState.scrobbleMonitor
        
        return VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(monitor.isScrobbling ? .green : .white.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text(monitor.isScrobbling ? "Scrobbling" : "Scrobbler Off")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if monitor.isScrobbling {
                    Button {
                        showDebug.toggle()
                    } label: {
                        Image(systemName: "ladybug")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(showDebug ? 0.7 : 0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if monitor.isScrobbling {
                if let track = monitor.currentTrackName, let artist = monitor.currentArtist {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Waiting for music...")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !monitor.scrobbleLog.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(monitor.scrobbleLog.prefix(3)) { entry in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 7))
                                Text(entry.track)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.green.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if showDebug && !monitor.debugLog.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(monitor.debugLog.prefix(6), id: \.self) { entry in
                            Text(entry)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                }
            } else if monitor.authStatus == .notAuthenticated {
                Text("Connect your Last.fm account in Settings to start scrobbling.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}

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
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.purple)
            }
            .padding(20)
            
            Divider().background(.white.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Scrobbler Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scrobbler")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text("Automatically scrobble your Apple Music tracks to Last.fm.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            TextField("API Key", text: $apiKey)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.08), lineWidth: 1))
                                .foregroundStyle(.white)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Secret")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            SecureField("API Secret", text: $apiSecret)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.08), lineWidth: 1))
                                .foregroundStyle(.white)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        Text("Register your app at last.fm/api/account/create to get an API key and secret.")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        if appState.scrobbleMonitor.authStatus == .authenticated {
                            Button {
                                appState.scrobbleMonitor.disconnect()
                            } label: {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                    Text("Disconnect")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        } else if !apiSecret.isEmpty {
                            Button {
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
                            } label: {
                                HStack {
                                    if isAuthenticating {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "link")
                                    }
                                    Text("Connect to Last.fm")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.purple, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(isAuthenticating)
                        }
                    }
                    
                    // Monitor Toggle
                    if appState.scrobbleMonitor.authStatus == .authenticated {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Auto-Scrobble")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack {
                                Text(appState.scrobbleMonitor.isScrobbling ? "Active" : "Paused")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                                
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
                            }
                            .padding(12)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(20)
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

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .white.opacity(0.1) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .white.opacity(0.08) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(formatNumber(value))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
    
    private func formatNumber(_ str: String) -> String {
        guard let num = Int(str) else { return str }
        if num >= 1000000 {
            return String(format: "%.1fM", Double(num) / 1000000.0)
        } else if num >= 1000 {
            return String(format: "%.1fK", Double(num) / 1000.0)
        }
        return str
    }
}

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(headerTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                
                if let error = appState.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
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
        .background(Color.black.opacity(0.02))
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

struct RecentTracksView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        LazyVStack(spacing: 2) {
            ForEach(appState.recentTracks) { track in
                TrackRow(track: track)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

struct TrackRow: View {
    let track: RecentTrack
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            CachedAsyncImage(url: track.imageURL) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.05))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.2)))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                
                if !track.album.isEmpty {
                    Text(track.album)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Now playing indicator or timestamp
            if track.nowPlaying {
                HStack(spacing: 4) {
                    PlayingAnimation()
                    Text("NOW PLAYING")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.green)
            } else if let uts = track.date, let timestamp = TimeInterval(uts) {
                Text(timeAgo(from: timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.04), lineWidth: 1))
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
                    .fill(.green)
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

struct TopArtistsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(appState.topArtists) { artist in
                ArtistCard(artist: artist)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

struct ArtistCard: View {
    let artist: TopArtist
    
    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: artist.imageURL) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.05))
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.2)))
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(artist.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text("\(artist.playcount) plays")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}

struct TopAlbumsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(appState.topAlbums) { album in
                AlbumCard(album: album)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

struct AlbumCard: View {
    let album: TopAlbum
    
    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: album.imageURL) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.05))
                    .overlay(Image(systemName: "square.stack.fill").foregroundStyle(.white.opacity(0.2)))
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(album.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
            
            Text("\(album.playcount) plays")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}
