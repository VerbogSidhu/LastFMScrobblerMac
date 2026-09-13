import SwiftUI
import AppKit

struct TrackRow: View {
    @EnvironmentObject var appState: AppState
    let track: RecentTrack

    @State private var isHovered = false
    @State private var isLoved = false
    @State private var showCopiedAlert = false

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

                HStack(spacing: 4) {
                    Button {
                        appState.inspectorEntity = .artist(name: track.artist)
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    } label: {
                        Text(track.artist)
                            .font(DS.Fonts.caption(12))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    if !track.album.isEmpty {
                        Text("·")
                            .foregroundStyle(DS.Colors.textMuted)
                        Button {
                            appState.inspectorEntity = .album(artist: track.artist, album: track.album)
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        } label: {
                            Text(track.album)
                                .font(DS.Fonts.caption(11))
                                .foregroundStyle(DS.Colors.textMuted)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Hover quick-action buttons
            if isHovered {
                HStack(spacing: 6) {
                    // Share Card button
                    Button {
                        appState.showShareCard = true
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Share Track Card")

                    // Love button
                    Button {
                        toggleLove()
                    } label: {
                        Image(systemName: isLoved ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundStyle(isLoved ? DS.Colors.love : DS.Colors.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isLoved ? "Unlove on Last.fm" : "Love on Last.fm")

                    // Open on Last.fm
                    Button {
                        openOnLastFM()
                    } label: {
                        Image(systemName: "safari")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open on Last.fm")

                    // Copy button
                    Button {
                        copyTrackInfo()
                    } label: {
                        Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(showCopiedAlert ? DS.Colors.success : DS.Colors.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy Title and Artist")
                }
                .transition(.opacity)
            }

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
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isHovered ? appState.accentColor.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                appState.inspectorEntity = .artist(name: track.artist)
            } label: {
                Label("Inspect Artist '\(track.artist)'", systemImage: "person.text.rectangle")
            }

            if !track.album.isEmpty {
                Button {
                    appState.inspectorEntity = .album(artist: track.artist, album: track.album)
                } label: {
                    Label("Inspect Album '\(track.album)'", systemImage: "opticaldisc")
                }
            }

            Button {
                toggleLove()
            } label: {
                Label(isLoved ? "Unlove on Last.fm" : "Love on Last.fm", systemImage: isLoved ? "heart.slash" : "heart")
            }

            Button {
                openOnLastFM()
            } label: {
                Label("Open Track on Last.fm", systemImage: "safari")
            }

            Button {
                searchInAppleMusic()
            } label: {
                Label("Search in Apple Music", systemImage: "music.note")
            }

            Divider()

            Button {
                copyTrackInfo()
            } label: {
                Label("Copy Title & Artist", systemImage: "doc.on.doc")
            }

            Button {
                appState.showShareCard = true
            } label: {
                Label("Share Track Card…", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                appState.removeRecentTrack(id: track.id, openLibraryWeb: true)
            } label: {
                Label("Remove Play & Open Library…", systemImage: "trash")
            }
        }
    }

    private func toggleLove() {
        guard let sessionKey = appState.scrobbleMonitor.sessionKey else { return }
        let shouldLove = !isLoved
        Task {
            do {
                if shouldLove {
                    try await appState.scrobbleService.loveTrack(track: track.name, artist: track.artist, sessionKey: sessionKey)
                    await MainActor.run { isLoved = true }
                } else {
                    try await appState.scrobbleService.unloveTrack(track: track.name, artist: track.artist, sessionKey: sessionKey)
                    await MainActor.run { isLoved = false }
                }
            } catch {
                NSLog("[TrackRow] Love toggle error: %@", "\(error)")
            }
        }
    }

    private func openOnLastFM() {
        let artistEscaped = track.artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let trackEscaped = track.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        if let url = URL(string: "https://www.last.fm/music/\(artistEscaped)/_/\(trackEscaped)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openArtistOnLastFM() {
        let artistEscaped = track.artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        if let url = URL(string: "https://www.last.fm/music/\(artistEscaped)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func searchInAppleMusic() {
        let query = "\(track.artist) \(track.name)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "music://music.apple.com/search?term=\(query)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyTrackInfo() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(track.artist) — \(track.name)", forType: .string)
        withAnimation {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedAlert = false
            }
        }
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
