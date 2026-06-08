import SwiftUI

/// Menu bar extra showing now-playing info, scrobble count, and quick actions.
struct MenuBarPopoverContent: View {
    @ObservedObject var appState: AppState
    @State private var loveError: String?
    
    private var monitor: ScrobbleMonitor { appState.scrobbleMonitor }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.purple)
                Text("Last.fm Scrobbler")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Now Playing
            if monitor.isScrobbling, let track = monitor.currentTrackName, let artist = monitor.currentArtist {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Now Playing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    
                    Text(track)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    // Love button
                    HStack(spacing: 12) {
                        Button {
                            loveTrack(track: track, artist: artist)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "heart")
                                Text("Love")
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.pink.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        
                        if let error = loveError {
                            Text(error)
                                .font(.system(size: 9))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else if monitor.isScrobbling {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Scrobbling — waiting for track…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text("Scrobbler off")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            
            Divider()
            
            // Stats Summary (from Last.fm API)
            HStack(spacing: 16) {
                StatPill(value: "\(appState.menuBarTodayCount)", label: "7 Days")
                StatPill(value: "\(appState.menuBarWeekCount)", label: "Month")
                StatPill(value: "\(appState.menuBarMonthCount)", label: "3 Months")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            // Actions
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Last") }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Open Dashboard", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            
            if monitor.isScrobbling {
                Button {
                    monitor.stopMonitoring()
                } label: {
                    Label("Pause Scrobbler", systemImage: "pause.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            } else if monitor.authStatus == .authenticated {
                Button {
                    monitor.startMonitoring()
                } label: {
                    Label("Resume Scrobbler", systemImage: "play.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            
            Divider()
            
            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .padding(.bottom, 8)
        }
        .frame(width: 240)
    }
    
    private func loveTrack(track: String, artist: String) {
        guard let sessionKey = monitor.sessionKey else { return }
        loveError = nil
        Task {
            do {
                try await appState.scrobbleService.loveTrack(track: track, artist: artist, sessionKey: sessionKey)
            } catch {
                await MainActor.run { loveError = "Failed" }
            }
        }
    }
}

struct StatPill: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
