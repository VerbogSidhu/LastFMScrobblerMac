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
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        StatusDot(isActive: monitor.isPlaying, size: 6)
                        Text(monitor.isPlaying ? "Now Playing" : "Paused")
                            .font(DS.Fonts.caption(10).weight(.medium))
                            .foregroundStyle(monitor.isPlaying ? DS.Colors.success : DS.Colors.textMuted)

                        Spacer()

                        // Scrobble progress status
                        if monitor.hasCurrentTrackScrobbled {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 8))
                                Text("Scrobbled")
                                    .font(DS.Fonts.caption(9).weight(.semibold))
                            }
                            .foregroundStyle(DS.Colors.success)
                        } else if monitor.scrobbleThresholdSeconds > 0 {
                            let rem = max(0, Int(monitor.scrobbleThresholdSeconds - monitor.accumulatedSeconds))
                            Text(rem == 0 ? "Scrobbling soon" : "Scrobbles in \(rem)s")
                                .font(DS.Fonts.caption(9))
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                    }

                    HStack(spacing: 10) {
                        if let art = monitor.currentAlbumArt {
                            MediaImage(url: art, placeholder: "music.note", size: 36, cornerRadius: 6)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(appState.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 14))
                                        .foregroundStyle(appState.accentColor)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track)
                                .font(DS.Fonts.body(12).weight(.semibold))
                                .lineLimit(1)
                            Text(artist)
                                .font(DS.Fonts.caption(11))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Progress bar
                    if monitor.currentDuration > 0 {
                        GeometryReader { geo in
                            let progress = min(1.0, Double(monitor.currentPosition) / Double(monitor.currentDuration))
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(appState.accentColor.gradient)
                                    .frame(width: geo.size.width * CGFloat(progress), height: 3)
                            }
                        }
                        .frame(height: 3)
                    }

                    // Playback Controls Row
                    HStack(spacing: 10) {
                        Button {
                            monitor.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            monitor.togglePlayPause()
                        } label: {
                            Image(systemName: monitor.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            monitor.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Love button
                        Button {
                            monitor.toggleLoveCurrentTrack()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: monitor.isLoved ? "heart.fill" : "heart")
                                    .foregroundStyle(monitor.isLoved ? DS.Colors.love : DS.Colors.textSecondary)
                                Text(monitor.isLoved ? "Loved" : "Love")
                            }
                            .font(DS.Fonts.caption(10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(monitor.isLoved ? DS.Colors.love.opacity(0.15) : Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
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

            // Offline queue notification
            if monitor.queuedScrobbleCount > 0 {
                Divider()
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                    Text("\(monitor.queuedScrobbleCount) queued offline")
                        .font(DS.Fonts.caption(10))
                }
                .foregroundStyle(DS.Colors.warning)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
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
