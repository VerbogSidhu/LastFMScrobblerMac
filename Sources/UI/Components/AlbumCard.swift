import SwiftUI
import AppKit

struct AlbumCard: View {
    @EnvironmentObject var appState: AppState
    let album: TopAlbum
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            MediaImage(url: album.imageURL, placeholder: "square.stack.fill", size: DS.Layout.cardImageSize, cornerRadius: DS.Radius.lg)
                .shadow(color: isHovered ? Color.black.opacity(0.3) : Color.clear, radius: 8, y: 4)

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
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(isHovered ? appState.accentColor.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .onTapGesture {
            appState.inspectorEntity = .album(artist: album.artist, album: album.name)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                appState.inspectorEntity = .album(artist: album.artist, album: album.name)
            } label: {
                Label("Inspect Album", systemImage: "opticaldisc")
            }

            Button {
                appState.inspectorEntity = .artist(name: album.artist)
            } label: {
                Label("Inspect Artist '\(album.artist)'", systemImage: "person.text.rectangle")
            }

            Button {
                openAlbumOnLastFM()
            } label: {
                Label("Open Album on Last.fm", systemImage: "safari")
            }

            Button {
                searchInAppleMusic()
            } label: {
                Label("Search in Apple Music", systemImage: "music.note")
            }

            Divider()

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("\(album.artist) — \(album.name)", forType: .string)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            } label: {
                Label("Copy Album & Artist", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.name) by \(album.artist), \(album.playcount) plays")
    }

    private func openAlbumOnLastFM() {
        let artistEscaped = album.artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let albumEscaped = album.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        if let url = URL(string: "https://www.last.fm/music/\(artistEscaped)/\(albumEscaped)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func searchInAppleMusic() {
        let query = "\(album.artist) \(album.name)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "music://music.apple.com/search?term=\(query)") {
            NSWorkspace.shared.open(url)
        }
    }
}
