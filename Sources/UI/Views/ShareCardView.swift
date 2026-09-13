import SwiftUI
import AppKit

/// A high-resolution social share card generator using ImageRenderer.
/// Allows copying directly to macOS clipboard or saving as PNG file.
struct ShareCardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let track: String
    let artist: String
    let album: String?
    let artworkURL: String?

    @State private var copiedToClipboard = false
    @State private var saveMessage: String? = nil

    init(track: String? = nil, artist: String? = nil, album: String? = nil, artworkURL: String? = nil) {
        self.track = track ?? ""
        self.artist = artist ?? ""
        self.album = album
        self.artworkURL = artworkURL
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(appState.accentColor)
                    Text("Share Scrobbled Track")
                        .font(DS.Fonts.heading(16))
                        .foregroundStyle(DS.Colors.textPrimary)
                }

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
            .padding(.top, DS.Spacing.lg)

            // Card Preview container
            cardRenderView
                .frame(width: 440, height: 440)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)

            // Actions
            HStack(spacing: DS.Spacing.lg) {
                // Copy to Clipboard
                Button {
                    copyCardToClipboard()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(copiedToClipboard ? "Copied!" : "Copy Image")
                            .font(DS.Fonts.bodyMedium(13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(appState.accentColor, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Save PNG
                Button {
                    saveCardAsPNG()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Save PNG…")
                            .font(DS.Fonts.bodyMedium(13))
                    }
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, DS.Spacing.xl)

            if let msg = saveMessage {
                Text(msg)
                    .font(DS.Fonts.caption(11))
                    .foregroundStyle(DS.Colors.success)
                    .transition(.opacity)
            }
        }
        .frame(width: 520, height: 580)
        .background(DS.Colors.cardBackground)
    }

    // MARK: - The View to be Rendered

    private var cardRenderView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.05, green: 0.05, blue: 0.07),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient background flare
            Circle()
                .fill(appState.accentColor.opacity(0.25))
                .blur(radius: 80)
                .frame(width: 300, height: 300)
                .offset(x: -80, y: -100)

            VStack(spacing: DS.Spacing.xl) {
                // Top Branding
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(appState.accentColor)
                        Text("LAST.FM FOR MAC")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Spacer()

                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.Colors.textMuted)
                }

                Spacer()

                // Album Artwork
                ZStack {
                    if let url = artworkURL, !url.isEmpty {
                        MediaImage(url: url, placeholder: "music.note", size: 180, cornerRadius: 18)
                            .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(appState.accentColor.opacity(0.15))
                            .frame(width: 180, height: 180)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundStyle(appState.accentColor)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 16)
                    }
                }

                Spacer()

                // Metadata
                VStack(spacing: 4) {
                    Text(track.isEmpty ? "Now Playing" : track)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(artist.isEmpty ? "Unknown Artist" : artist)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(appState.accentColor)
                        .lineLimit(1)

                    if let album = album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textMuted)
                            .lineLimit(1)
                    }
                }

                // Bottom badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.success)
                    Text("Scrobbled to Last.fm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: Capsule())
            }
            .padding(28)
        }
    }

    // MARK: - ImageRenderer Export

    @MainActor
    private func renderImage() -> NSImage? {
        let renderer = ImageRenderer(content: cardRenderView.frame(width: 600, height: 600))
        renderer.scale = 2.0 // Crisp Retina output (1200x1200)
        return renderer.nsImage
    }

    private func copyCardToClipboard() {
        guard let image = renderImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        withAnimation {
            copiedToClipboard = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }

    private func saveCardAsPNG() {
        guard let image = renderImage() else { return }

        let panel = NSSavePanel()
        let safeTrack = track.replacingOccurrences(of: "/", with: "-")
        let safeArtist = artist.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "Scrobble-\(safeArtist)-\(safeTrack).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                withAnimation {
                    saveMessage = "Saved to \(url.lastPathComponent)!"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { saveMessage = nil }
                }
            }
        }
    }
}
