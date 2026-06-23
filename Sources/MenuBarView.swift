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
                    .font(DS.Fonts.body(16))
                    .foregroundStyle(DS.Colors.accent)
                Text("Last.fm Scrobbler")
                    .font(DS.Fonts.body(13).weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last.fm Scrobbler Menu")

            Divider()

            // Now Playing
            if monitor.isScrobbling, let track = monitor.currentTrackName, let artist = monitor.currentArtist {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        StatusDot(isActive: true, size: 6)
                        Text("Now Playing")
                            .font(DS.Fonts.caption(10).weight(.medium))
                            .foregroundStyle(DS.Colors.success)
                    }

                    Text(track)
                        .font(DS.Fonts.body(12).weight(.semibold))
                        .lineLimit(1)
                    Text(artist)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)

                    // Love button
                    HStack(spacing: DS.Spacing.lg) {
                        Button {
                            loveTrack(track: track, artist: artist)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "heart")
                                Text("Love")
                            }
                            .font(DS.Fonts.caption(11))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.Colors.love.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Love this track")

                        if let error = loveError {
                            Text(error)
                                .font(DS.Fonts.caption(9))
                                .foregroundStyle(DS.Colors.error)
                                .accessibilityLabel("Error: \(error)")
                        }
                    }
                    .padding(.top, DS.Spacing.xs)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Now playing: \(track) by \(artist)")

            } else if monitor.isScrobbling {
                HStack(spacing: 4) {
                    StatusDot(isActive: true, size: 6)
                    Text("Scrobbling — waiting for track…")
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            } else {
                HStack(spacing: 4) {
                    StatusDot(isActive: false, size: 6)
                    Text("Scrobbler off")
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider()

            // Stats Summary
            HStack(spacing: DS.Spacing.xl) {
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
                    .font(DS.Fonts.body(12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .accessibilityLabel("Open main dashboard")

            if monitor.isScrobbling {
                Button {
                    monitor.stopMonitoring()
                } label: {
                    Label("Pause Scrobbler", systemImage: "pause.circle")
                        .font(DS.Fonts.body(12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .accessibilityLabel("Pause scrobbler")

            } else if monitor.authStatus == .authenticated {
                Button {
                    monitor.startMonitoring()
                } label: {
                    Label("Resume Scrobbler", systemImage: "play.circle")
                        .font(DS.Fonts.body(12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .accessibilityLabel("Resume scrobbler")
            }

            Divider()

            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
                    .font(DS.Fonts.body(12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .padding(.bottom, 8)
            .accessibilityLabel("Quit application")
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
                .font(DS.Fonts.statNumber(14))
            Text(label)
                .font(DS.Fonts.caption(9))
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
