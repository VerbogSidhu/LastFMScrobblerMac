import SwiftUI

/// A full-window ambient artwork background that bathes the macOS window
/// in a luxurious, smoothly feathered atmospheric glow derived from the current album art.
/// Spans edge-to-edge across the entire window without abrupt cutoffs or card clipping.
struct AmbientArtworkBackground: View {
    let artworkURL: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base deep dark canvas
                Color(red: 0.06, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()

                if let art = artworkURL, !art.isEmpty {
                    CachedAsyncImage(url: art) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .blur(radius: 80)
                            .scaleEffect(1.3)
                            .opacity(0.35)
                    } placeholder: {
                        Color.clear
                    }
                    .overlay(
                        // Seamless top-to-bottom dissolve:
                        // Luminous colored wash across the top under header and hero player,
                        // gracefully deepening towards the bottom so lists and charts remain crisp
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.black.opacity(0.12), location: 0.25),
                                .init(color: Color.black.opacity(0.45), location: 0.6),
                                .init(color: Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.85), location: 0.9),
                                .init(color: Color(red: 0.06, green: 0.06, blue: 0.08), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        // Subtle horizontal vignette to keep sidebar text ultra-crisp
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.18), location: 0.0),
                                .init(color: .clear, location: 0.28)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .compositingGroup()
                    .id(art)
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.8), value: artworkURL)
    }
}
