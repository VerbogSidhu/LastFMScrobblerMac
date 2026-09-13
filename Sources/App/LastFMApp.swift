import SwiftUI
import AppKit

@main
struct LastFMApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Bound network and image caching in RAM to keep memory footprint lean
        URLCache.shared = URLCache(memoryCapacity: 12 * 1024 * 1024, diskCapacity: 48 * 1024 * 1024)

        DispatchQueue.main.async {
            let showInDock = UserDefaults.standard.object(forKey: "show_in_dock") as? Bool ?? true
            NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)

        MenuBarExtra {
            MenuBarPopoverContent(appState: appState)
        } label: {
            HStack(spacing: 5) {
                if appState.scrobbleMonitor.isScrobbling,
                   let track = appState.scrobbleMonitor.currentTrackName {
                    // Mini circular progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(appState.scrobbleMonitor.scrobbleProgress))
                            .stroke(appState.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 12, height: 12)

                    Text(truncate(track, max: 20))
                        .font(.system(size: 11))
                } else {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 14))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func truncate(_ s: String, max: Int) -> String {
        s.count > max ? String(s.prefix(max)) + "…" : s
    }
}
