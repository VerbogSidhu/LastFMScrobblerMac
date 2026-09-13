import SwiftUI
import AppKit

struct ArtistCard: View {
    @EnvironmentObject var appState: AppState
    let artist: TopArtist
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            MediaImage(url: artist.imageURL, placeholder: "person.fill", size: DS.Layout.cardImageSize, cornerRadius: DS.Radius.lg)
                .shadow(color: isHovered ? Color.black.opacity(0.3) : Color.clear, radius: 8, y: 4)

            Text(artist.name)
                .font(DS.Fonts.body(12).weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Text("\(artist.playcount) plays")
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted)
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
            appState.inspectorEntity = .artist(name: artist.name)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                appState.inspectorEntity = .artist(name: artist.name)
            } label: {
                Label("Inspect Artist", systemImage: "person.text.rectangle")
            }

            Button {
                openOnLastFM()
            } label: {
                Label("Open on Last.fm", systemImage: "safari")
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
                pasteboard.setString(artist.name, forType: .string)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            } label: {
                Label("Copy Artist Name", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artist.name), \(artist.playcount) plays")
    }

    private func openOnLastFM() {
        let escaped = artist.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        if let url = URL(string: "https://www.last.fm/music/\(escaped)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func searchInAppleMusic() {
        let query = artist.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "music://music.apple.com/search?term=\(query)") {
            NSWorkspace.shared.open(url)
        }
    }
}
