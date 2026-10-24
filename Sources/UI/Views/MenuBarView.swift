import SwiftUI

struct MenuBarPopoverContent: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    private var monitor: ScrobbleMonitor { appState.scrobbleMonitor }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 25)).foregroundStyle(appState.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Last.fm").font(DS.Fonts.subheading(14))
                    Text(monitor.authenticatedUsername.map { "@\($0)" } ?? "Your listening companion")
                        .font(DS.Fonts.caption(11)).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Button {
                    openDashboard()
                    appState.showSettings = true
                } label: {
                    Image(systemName: "gearshape").frame(width: 30, height: 30)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain).help("Settings").accessibilityLabel("Settings")
            }
            .padding(.horizontal, 5).padding(.top, 3)

            player
                .padding(14)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.07)))

            if let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(DS.Fonts.caption(11)).foregroundStyle(DS.Colors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if monitor.queuedScrobbleCount > 0 {
                Label("\(monitor.queuedScrobbleCount) waiting to sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(DS.Fonts.caption(11)).foregroundStyle(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 5)
            }

            HStack(spacing: 0) {
                StatPill(value: "\(appState.menuBarTodayCount)", label: "Today")
                StatPill(value: "\(appState.menuBarWeekCount)", label: "This Week")
                StatPill(value: "\(appState.menuBarMonthCount)", label: "This Month")
            }
            .padding(.vertical, 12)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(spacing: 2) {
                MenuActionRow(title: "Open Dashboard", icon: "macwindow", trailing: "↗", action: openDashboard)
                if monitor.authStatus == .authenticated {
                    MenuActionRow(title: monitor.isScrobbling ? "Pause Scrobbler" : "Resume Scrobbler",
                                  icon: monitor.isScrobbling ? "pause.circle" : "play.circle") {
                        if monitor.isScrobbling { monitor.stopMonitoring() }
                        else { monitor.startMonitoring() }
                    }
                } else {
                    MenuActionRow(title: "Connect to Last.fm", icon: "link") {
                        openDashboard(); appState.showSettings = true
                    }
                }
                MenuActionRow(title: "Quit Last.fm", icon: "power", trailing: "⌘Q") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 332)
        .foregroundStyle(DS.Colors.textPrimary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var player: some View {
        if let track = monitor.currentTrackName, let artist = monitor.currentArtist {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 5) {
                    Circle().fill(monitor.isPlaying && monitor.isScrobbling ? DS.Colors.success : DS.Colors.textMuted)
                        .frame(width: 5, height: 5)
                    Text(!monitor.isScrobbling ? "Scrobbler paused" : monitor.isPlaying ? "Now playing" : "Playback paused")
                        .font(DS.Fonts.captionMedium(11)).foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    if monitor.hasCurrentTrackScrobbled {
                        Label("Scrobbled", systemImage: "checkmark.circle.fill")
                            .font(DS.Fonts.caption(10)).foregroundStyle(DS.Colors.success)
                    }
                }
                HStack(spacing: 12) {
                    MediaImage(url: monitor.currentAlbumArt, placeholder: "music.note", size: 58, cornerRadius: 13)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track).font(DS.Fonts.body(14).weight(.semibold)).lineLimit(2)
                        Text(artist).font(DS.Fonts.body(12)).foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                        if let album = monitor.currentAlbumName, !album.isEmpty {
                            Text(album).font(DS.Fonts.caption(11)).foregroundStyle(DS.Colors.textTertiary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if monitor.currentDuration > 0 {
                    ProgressView(value: min(1, max(0, Double(monitor.currentPosition) / Double(monitor.currentDuration))))
                        .tint(appState.accentColor)
                        .accessibilityLabel("Playback progress")
                }
                HStack(spacing: 13) {
                    playbackButton("backward.fill", label: "Previous track", size: 30, action: monitor.previousTrack)
                    playbackButton(monitor.isPlaying ? "pause.fill" : "play.fill",
                                   label: monitor.isPlaying ? "Pause playback" : "Play", size: 38, action: monitor.togglePlayPause)
                    playbackButton("forward.fill", label: "Next track", size: 30, action: monitor.nextTrack)
                    Spacer()
                    playbackButton(monitor.isLoved ? "heart.fill" : "heart",
                                   label: monitor.isLoved ? "Unlove track" : "Love track", size: 32,
                                   action: monitor.toggleLoveCurrentTrack)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: monitor.isScrobbling ? "music.note" : "waveform.slash")
                    .font(.system(size: 25)).foregroundStyle(appState.accentColor)
                Text(monitor.isScrobbling ? "Ready for your next track" : "Scrobbler paused")
                    .font(DS.Fonts.bodyMedium(13))
                Text(monitor.isScrobbling ? "Play something in Apple Music." : "Resume to keep tracking your music.")
                    .font(DS.Fonts.caption(11)).foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }

    private func playbackButton(_ icon: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size > 35 ? 14 : 12, weight: .semibold))
                .frame(width: size, height: size)
                .background(.white.opacity(size > 35 ? 0.13 : 0.07), in: Circle())
                .contentShape(Circle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuActionRow: View {
    let title: String
    let icon: String
    var trailing: String? = nil
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 18)
                Text(title).font(DS.Fonts.body(12))
                Spacer()
                if let trailing { Text(trailing).font(DS.Fonts.caption(11)).foregroundStyle(DS.Colors.textTertiary) }
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(.white.opacity(hovered ? 0.09 : 0), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }.accessibilityLabel(title)
    }
}

struct StatPill: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(DS.Fonts.statNumber(17)).monospacedDigit()
            Text(label).font(DS.Fonts.caption(10)).foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine).accessibilityLabel("\(label): \(value)")
    }
}
