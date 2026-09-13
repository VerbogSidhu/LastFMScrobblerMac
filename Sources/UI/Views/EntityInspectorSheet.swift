import SwiftUI
import AppKit

/// In-App Inspector modal displaying rich metadata, biographies, tracklists,
/// listener playcounts, and tags for any Artist or Album.
struct EntityInspectorSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let entity: InspectorEntity

    @State private var artistDetail: ArtistDetailInfo?
    @State private var albumDetail: AlbumDetailInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBioExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header Bar
            HStack {
                Text(sheetTitle)
                    .font(DS.Fonts.caption(11).weight(.semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.cardBackground)

            Divider()

            // Content Area
            if isLoading {
                VStack(spacing: DS.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading metadata from Last.fm…")
                        .font(DS.Fonts.caption(12))
                        .foregroundStyle(DS.Colors.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(DS.Colors.warning)
                    Text(error)
                        .font(DS.Fonts.body(13))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Button("Retry") {
                        loadEntityData()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        switch entity {
                        case .artist:
                            if let artist = artistDetail {
                                artistContent(artist)
                            }
                        case .album:
                            if let album = albumDetail {
                                albumContent(album)
                            }
                        }
                    }
                    .padding(DS.Spacing.xl)
                }
            }
        }
        .frame(width: 580, height: 640)
        .background(DS.Colors.background)
        .onAppear {
            loadEntityData()
        }
    }

    private var sheetTitle: String {
        switch entity {
        case .artist(let name): return "Artist Inspector · \(name)"
        case .album(_, let album): return "Album Inspector · \(album)"
        }
    }

    // MARK: - Artist View

    @ViewBuilder
    private func artistContent(_ artist: ArtistDetailInfo) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            MediaImage(url: artist.imageURL, placeholder: "person.fill", size: 100, cornerRadius: 50)
                .shadow(color: appState.accentColor.opacity(0.3), radius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(DS.Fonts.heading(22))
                    .foregroundStyle(DS.Colors.textPrimary)

                HStack(spacing: DS.Spacing.md) {
                    metricBadge(label: "Listeners", value: formatCount(artist.listeners))
                    metricBadge(label: "Scrobbles", value: formatCount(artist.playcount))
                    if let userPlays = artist.userPlaycount, userPlays > 0 {
                        metricBadge(label: "Your Scrobbles", value: "\(userPlays)", highlight: true)
                    }
                }
                .padding(.top, 4)
            }
        }

        // Tags
        if !artist.tags.isEmpty {
            tagsView(artist.tags)
        }

        // Action Buttons
        HStack(spacing: DS.Spacing.md) {
            if let url = artist.webURL {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                        Text("View on Last.fm")
                            .font(DS.Fonts.bodyMedium(12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Button {
                searchInAppleMusic(query: artist.name)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                    Text("Search in Apple Music")
                        .font(DS.Fonts.bodyMedium(12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }

        // Bio
        if !artist.bioSummary.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Biography")
                    .font(DS.Fonts.subheading(13))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(artist.bioSummary)
                    .font(DS.Fonts.body(12))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(isBioExpanded ? nil : 4)

                if artist.bioSummary.count > 250 {
                    Button(isBioExpanded ? "Show Less" : "Read More") {
                        withAnimation { isBioExpanded.toggle() }
                    }
                    .font(DS.Fonts.caption(11).weight(.semibold))
                    .foregroundStyle(appState.accentColor)
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        }

        // Top Tracks
        if !artist.topTracks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Tracks")
                    .font(DS.Fonts.subheading(13))
                    .foregroundStyle(DS.Colors.textPrimary)

                VStack(spacing: 4) {
                    ForEach(Array(artist.topTracks.enumerated()), id: \.offset) { idx, track in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(DS.Fonts.mono(11))
                                .foregroundStyle(DS.Colors.textMuted)
                                .frame(width: 20, alignment: .center)

                            Text(track.name)
                                .font(DS.Fonts.body(13))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(formatCount(track.playcount)) plays")
                                .font(DS.Fonts.caption(11))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(idx % 2 == 0 ? Color.white.opacity(0.02) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(14)
            .background(DS.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Album View

    @ViewBuilder
    private func albumContent(_ album: AlbumDetailInfo) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            MediaImage(url: album.imageURL, placeholder: "opticaldisc", size: 100, cornerRadius: 10)
                .shadow(color: appState.accentColor.opacity(0.3), radius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.name)
                    .font(DS.Fonts.heading(20))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)

                Text(album.artist)
                    .font(DS.Fonts.subheading(14))
                    .foregroundStyle(appState.accentColor)

                HStack(spacing: DS.Spacing.md) {
                    metricBadge(label: "Listeners", value: formatCount(album.listeners))
                    metricBadge(label: "Scrobbles", value: formatCount(album.playcount))
                    if let userPlays = album.userPlaycount, userPlays > 0 {
                        metricBadge(label: "Your Scrobbles", value: "\(userPlays)", highlight: true)
                    }
                }
                .padding(.top, 4)
            }
        }

        // Action Buttons
        HStack(spacing: DS.Spacing.md) {
            if let url = album.webURL {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                        Text("View on Last.fm")
                            .font(DS.Fonts.bodyMedium(12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Button {
                searchInAppleMusic(query: "\(album.artist) \(album.name)")
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                    Text("Search in Apple Music")
                        .font(DS.Fonts.bodyMedium(12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }

        // Wiki
        if let wiki = album.wikiSummary, !wiki.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("About this Album")
                    .font(DS.Fonts.subheading(13))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(wiki)
                    .font(DS.Fonts.body(12))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(isBioExpanded ? nil : 4)

                if wiki.count > 250 {
                    Button(isBioExpanded ? "Show Less" : "Read More") {
                        withAnimation { isBioExpanded.toggle() }
                    }
                    .font(DS.Fonts.caption(11).weight(.semibold))
                    .foregroundStyle(appState.accentColor)
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        }

        // Tracklist
        if !album.tracks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tracklist")
                        .font(DS.Fonts.subheading(13))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    Text("\(album.tracks.count) tracks")
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textMuted)
                }

                VStack(spacing: 2) {
                    ForEach(album.tracks) { track in
                        HStack(spacing: 12) {
                            Text("\(track.rank)")
                                .font(DS.Fonts.mono(11))
                                .foregroundStyle(DS.Colors.textMuted)
                                .frame(width: 22, alignment: .center)

                            Text(track.name)
                                .font(DS.Fonts.body(12))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if track.duration > 0 {
                                Text(formatDuration(track.duration))
                                    .font(DS.Fonts.mono(11))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(track.rank % 2 == 0 ? Color.white.opacity(0.02) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(14)
            .background(DS.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Reusable Subviews & Helpers

    private func metricBadge(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(DS.Fonts.mono(12).weight(.semibold))
                .foregroundStyle(highlight ? appState.accentColor : DS.Colors.textPrimary)
            Text(label)
                .font(DS.Fonts.caption(9))
                .foregroundStyle(DS.Colors.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }

    private func tagsView(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags.prefix(6), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func loadEntityData() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch entity {
                case .artist(let name):
                    let detail = try await appState.service.getArtistInfo(artist: name, username: Constants.lastFMUsername)
                    await MainActor.run {
                        self.artistDetail = detail
                        self.isLoading = false
                    }
                case .album(let artist, let album):
                    let detail = try await appState.service.getAlbumInfo(artist: artist, album: album, username: Constants.lastFMUsername)
                    await MainActor.run {
                        self.albumDetail = detail
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func searchInAppleMusic(query: String) {
        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "music://music.apple.com/search?term=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
