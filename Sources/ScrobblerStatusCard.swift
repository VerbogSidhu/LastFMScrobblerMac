import SwiftUI

struct ScrobblerStatusCard: View {
    @EnvironmentObject var appState: AppState
    @State private var showDebug = false

    var body: some View {
        let monitor = appState.scrobbleMonitor

        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    StatusDot(isActive: monitor.isScrobbling)
                    Text(monitor.isScrobbling ? "Scrobbling" : "Scrobbler Off")
                        .font(DS.Fonts.captionMedium(12))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    if monitor.isScrobbling {
                        IconButton(icon: "ladybug", label: "Toggle debug log", isActive: showDebug) {
                            showDebug.toggle()
                        }
                    }
                }

                if monitor.isScrobbling {
                    if let track = monitor.currentTrackName, let artist = monitor.currentArtist {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(track)
                                .font(DS.Fonts.captionMedium(11))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)
                            Text(artist)
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Now playing: \(track) by \(artist)")
                    } else {
                        Text("Waiting for music…")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !monitor.scrobbleLog.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(monitor.scrobbleLog.prefix(3)) { entry in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 7))
                                    Text(entry.track)
                                        .font(DS.Fonts.caption(9))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(DS.Colors.success.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if showDebug && !monitor.debugLog.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(monitor.debugLog.prefix(6), id: \.self) { entry in
                                Text(entry)
                                    .font(DS.Fonts.mono(7))
                                    .foregroundStyle(DS.Colors.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .accessibilityLabel("Debug log")
                    }
                } else if monitor.authStatus == .notAuthenticated {
                    Text("Connect your Last.fm account in Settings to start scrobbling.")
                        .font(DS.Fonts.caption(10))
                        .foregroundStyle(DS.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
