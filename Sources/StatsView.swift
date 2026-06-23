import SwiftUI

/// Quick stats view — fetches data directly from the Last.fm API.
struct StatsView: View {
    @EnvironmentObject var appState: AppState

    @State private var userInfo: UserInfo?
    @State private var topArtistsWeek: [TopArtist] = []
    @State private var topAlbumsWeek: [TopAlbum] = []
    @State private var topTracksWeek: [TopTrack] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: DS.Spacing.lg) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: DS.Spacing.lg) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: DS.Radius.xl)
                                    .fill(DS.Colors.inputBackground)
                                    .frame(height: 80)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xxxl)
                    .padding(.bottom, DS.Spacing.xxxl)
                }
                .accessibilityHidden(true)

            } else if let error {
                ErrorState(message: error) {
                    Task { await loadData() }
                }

            } else if let user = userInfo {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    // Big Numbers
                    HStack(spacing: DS.Spacing.lg) {
                        StatCard(value: formatCount(user.playcount), label: "Total Scrobbles", color: DS.Colors.accent)
                        StatCard(value: formatCount(user.artistCount), label: "Artists", color: DS.Colors.info)
                        StatCard(value: formatCount(user.albumCount), label: "Albums", color: DS.Colors.warning)
                        StatCard(value: formatCount(user.trackCount), label: "Tracks", color: DS.Colors.success)
                    }

                    // Top Artists (this week)
                    if !topArtistsWeek.isEmpty {
                        RankedList(title: "Top Artists (7 Days)", icon: "person.fill", items: topArtistsWeek.prefix(5), id: \.name) { i, a in
                            RankedListRow(
                                rank: i,
                                primary: a.name,
                                secondary: "\(a.playcount) scrobbles",
                                progress: Double(a.playcount) ?? 0 > 0 ? min(1.0, Double(a.playcount)!) : nil
                            )
                        }
                    }

                    // Top Albums (this week)
                    if !topAlbumsWeek.isEmpty {
                        RankedList(title: "Top Albums (7 Days)", icon: "square.stack.fill", items: topAlbumsWeek.prefix(5), id: \.name) { i, a in
                            RankedListRow(rank: i, primary: a.name, secondary: "\(a.artist) · \(a.playcount)")
                        }
                    }

                    // Top Tracks (this week)
                    if !topTracksWeek.isEmpty {
                        RankedList(title: "Top Tracks (7 Days)", icon: "music.note", items: topTracksWeek.prefix(5), id: \.name) { i, t in
                            RankedListRow(rank: i, primary: t.name, secondary: "\(t.artist) · \(t.playcount)")
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.xxxl)

            } else {
                EmptyState(
                    icon: "chart.bar",
                    title: "No stats available",
                    subtitle: "Check your connection and try again."
                )
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        let username = Constants.lastFMUsername
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
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func formatCount(_ s: String) -> String {
        guard let n = Int(s) else { return s }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
