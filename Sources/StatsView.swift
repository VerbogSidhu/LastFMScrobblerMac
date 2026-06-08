import SwiftUI

/// Quick stats view — fetches data directly from the Last.fm API.
struct StatsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var userInfo: UserInfo?
    @State private var topArtistsWeek: [TopArtist] = []
    @State private var topAlbumsWeek: [TopAlbum] = []
    @State private var topTracksWeek: [TopTrack] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading stats…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Big Numbers
                    if let user = userInfo {
                        HStack(spacing: 16) {
                            BigStat(value: formatCount(user.playcount), label: "Total Scrobbles", color: .purple)
                            BigStat(value: formatCount(user.artistCount), label: "Artists", color: .blue)
                            BigStat(value: formatCount(user.albumCount), label: "Albums", color: .orange)
                            BigStat(value: formatCount(user.trackCount), label: "Tracks", color: .green)
                        }
                    }
                    
                    // Top Artists (this week)
                    if !topArtistsWeek.isEmpty {
                        QuickTopList(
                            title: "Top Artists (7 Days)",
                            icon: "person.fill",
                            items: topArtistsWeek.prefix(5).enumerated().map { (i, a) in
                                QuickTopItem(rank: i + 1, name: a.name, detail: "\(a.playcount) scrobbles", progress: Double(a.playcount) ?? 0 > 0 ? min(1.0, Double(a.playcount)!) : nil)
                            }
                        )
                    }
                    
                    // Top Albums (this week)
                    if !topAlbumsWeek.isEmpty {
                        QuickTopList(
                            title: "Top Albums (7 Days)",
                            icon: "square.stack.fill",
                            items: topAlbumsWeek.prefix(5).enumerated().map { (i, a) in
                                QuickTopItem(rank: i + 1, name: a.name, detail: "\(a.artist) · \(a.playcount)", progress: nil)
                            }
                        )
                    }
                    
                    // Top Tracks (this week)
                    if !topTracksWeek.isEmpty {
                        QuickTopList(
                            title: "Top Tracks (7 Days)",
                            icon: "music.note",
                            items: topTracksWeek.prefix(5).enumerated().map { (i, t) in
                                QuickTopItem(rank: i + 1, name: t.name, detail: "\(t.artist) · \(t.playcount)", progress: nil)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .task { await loadData() }
    }
    
    private func loadData() async {
        isLoading = true
        let username = "verbog"
        let service = appState.service
        
        do {
            async let user = service.getUserInfo(username: username)
            async let artists = service.getTopArtists(username: username, limit: 5, period: "7day")
            async let albums = service.getTopAlbums(username: username, limit: 5, period: "7day")
            async let tracks = service.getTopTracks(username: username, limit: 5, period: "7day")
            
            let (u, ar, al, tr) = try await (user, artists, albums, tracks)
            
            await MainActor.run {
                userInfo = u
                topArtistsWeek = ar
                topAlbumsWeek = al
                topTracksWeek = tr
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func formatCount(_ s: String) -> String {
        guard let n = Int(s) else { return s }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

struct BigStat: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}

struct QuickTopItem: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let detail: String
    let progress: Double?
}

struct QuickTopList: View {
    let title: String
    let icon: String
    let items: [QuickTopItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Text("\(item.rank)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 16, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(item.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        if let p = item.progress, p > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.white.opacity(0.05))
                                        .frame(height: 3)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.purple.gradient)
                                        .frame(width: geo.size.width * min(p, 1.0), height: 3)
                                }
                            }
                            .frame(height: 3)
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}
