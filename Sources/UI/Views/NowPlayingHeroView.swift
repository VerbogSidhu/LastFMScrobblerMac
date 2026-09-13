import SwiftUI
import AppKit

/// A native macOS floating hero banner showing real-time playback telemetry,
/// interactive seeking scrubber, Apple Music volume popover, adaptive ambient artwork glow,
/// quick inspector drill-downs, and social share card generation.
struct NowPlayingHeroView: View {
    @EnvironmentObject var appState: AppState
    @State private var isScrubberHovered = false
    @State private var isScrubbing = false
    @State private var scrubPosition: Double? = nil
    @State private var showVolumePopover = false

    private var monitor: ScrobbleMonitor {
        appState.scrobbleMonitor
    }

    private var volumeIcon: String {
        switch monitor.soundVolume {
        case 0: return "speaker.slash.fill"
        case 1..<33: return "speaker.wave.1.fill"
        case 33..<66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        if let track = monitor.currentTrackName, let artist = monitor.currentArtist {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.xl) {
                    // Artwork with ambient glow
                    ZStack {
                        if let art = monitor.currentAlbumArt {
                            MediaImage(url: art, placeholder: "music.note", size: 68, cornerRadius: DS.Radius.md)
                                .shadow(color: appState.accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
                        } else {
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(appState.accentColor.opacity(0.15))
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 24))
                                        .foregroundStyle(appState.accentColor)
                                )
                        }

                        // Live audio wave indicator when playing
                        if monitor.isPlaying {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    PlayingAnimation()
                                        .padding(4)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .offset(x: 4, y: 4)
                                }
                            }
                            .frame(width: 68, height: 68)
                        }
                    }

                    // Track & Artist Information
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: DS.Spacing.sm) {
                            Text(track)
                                .font(DS.Fonts.heading(16))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)

                            // Status badge
                            statusBadge
                        }

                        HStack(spacing: 4) {
                            Button {
                                appState.inspectorEntity = .artist(name: artist)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            } label: {
                                Text(artist)
                                    .font(DS.Fonts.subheading(13))
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .underline(isScrubberHovered, color: DS.Colors.textTertiary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            .help("Inspect Artist \(artist)")

                            if let album = monitor.currentAlbumName, !album.isEmpty {
                                Text("·")
                                    .foregroundStyle(DS.Colors.textMuted)
                                Button {
                                    appState.inspectorEntity = .album(artist: artist, album: album)
                                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                } label: {
                                    Text(album)
                                        .font(DS.Fonts.caption(12))
                                        .foregroundStyle(DS.Colors.textTertiary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .help("Inspect Album \(album)")
                            }
                        }

                        // Playback Scrubber with Seeking & Scrobble Marker
                        VStack(spacing: 3) {
                            GeometryReader { geo in
                                let totalDur = Double(max(1, monitor.currentDuration))
                                let displayPos = scrubPosition ?? Double(monitor.currentPosition)
                                let progress = min(1.0, max(0.0, displayPos / totalDur))

                                ZStack(alignment: .leading) {
                                    // Hit target container
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 18)
                                        .contentShape(Rectangle())

                                    // Track background bar
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: isScrubberHovered || isScrubbing ? 6 : 4)
                                        .animation(.easeInOut(duration: 0.15), value: isScrubberHovered)

                                    // Playback progress fill
                                    Capsule()
                                        .fill(appState.accentColor.gradient)
                                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: isScrubberHovered || isScrubbing ? 6 : 4)
                                        .animation(.easeInOut(duration: 0.1), value: progress)

                                    // Scrobble threshold marker pip
                                    if monitor.currentDuration > 30 && monitor.scrobbleThresholdSeconds > 0 {
                                        let thresholdRatio = min(1.0, monitor.scrobbleThresholdSeconds / totalDur)
                                        Rectangle()
                                            .fill(monitor.hasCurrentTrackScrobbled ? DS.Colors.success : Color.white.opacity(0.6))
                                            .frame(width: 2, height: 10)
                                            .offset(x: geo.size.width * CGFloat(thresholdRatio) - 1)
                                    }

                                    // Scrubber Draggable Thumb Pip
                                    if isScrubberHovered || isScrubbing {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 10, height: 10)
                                            .shadow(color: Color.black.opacity(0.4), radius: 3)
                                            .offset(x: max(0, min(geo.size.width - 10, geo.size.width * CGFloat(progress) - 5)))
                                    }
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            isScrubbing = true
                                            let ratio = max(0.0, min(1.0, gesture.location.x / geo.size.width))
                                            scrubPosition = ratio * totalDur
                                        }
                                        .onEnded { gesture in
                                            let ratio = max(0.0, min(1.0, gesture.location.x / geo.size.width))
                                            let targetSeconds = ratio * totalDur
                                            monitor.seekTo(position: targetSeconds)
                                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                            scrubPosition = nil
                                            isScrubbing = false
                                        }
                                )
                            }
                            .frame(height: 18)
                            .onHover { hovering in
                                isScrubberHovered = hovering
                            }

                            // Time Labels
                            HStack {
                                let currentSec = Int(scrubPosition ?? Double(monitor.currentPosition))
                                Text(formatTime(currentSec))
                                    .font(DS.Fonts.mono(10))
                                    .foregroundStyle(isScrubbing ? appState.accentColor : DS.Colors.textMuted)

                                Spacer()

                                if monitor.currentDuration > 0 {
                                    Text(formatTime(monitor.currentDuration))
                                        .font(DS.Fonts.mono(10))
                                        .foregroundStyle(DS.Colors.textMuted)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 12)

                    // Controls Section
                    HStack(spacing: 10) {
                        // Love Button
                        Button {
                            monitor.toggleLoveCurrentTrack()
                        } label: {
                            Image(systemName: monitor.isLoved ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                                .foregroundStyle(monitor.isLoved ? DS.Colors.love : DS.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(monitor.isLoved ? "Unlove track (⌘L)" : "Love track on Last.fm (⌘L)")

                        // Volume Popover Slider
                        Button {
                            showVolumePopover.toggle()
                        } label: {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Apple Music Volume")
                        .popover(isPresented: $showVolumePopover, arrowEdge: .bottom) {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DS.Colors.textMuted)
                                Slider(
                                    value: Binding(
                                        get: { Double(monitor.soundVolume) },
                                        set: { monitor.setVolume(Int($0)) }
                                    ),
                                    in: 0...100
                                )
                                .frame(width: 110)
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DS.Colors.textMuted)
                                Text("\(monitor.soundVolume)%")
                                    .font(DS.Fonts.mono(10))
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }

                        // Share Card Button
                        Button {
                            appState.showShareCard = true
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Share Now Playing Card")

                        // Previous Track
                        Button {
                            monitor.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Previous Track")

                        // Play / Pause
                        Button {
                            monitor.togglePlayPause()
                        } label: {
                            Image(systemName: monitor.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(monitor.isPlaying ? "Pause" : "Play")

                        // Next Track
                        Button {
                            monitor.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textPrimary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Next Track")
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 6)
            )
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xl)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if monitor.hasCurrentTrackScrobbled {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                Text("Scrobbled")
                    .font(DS.Fonts.caption(10).weight(.semibold))
            }
            .foregroundStyle(DS.Colors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: Capsule())
        } else if monitor.currentDuration > 0 && monitor.currentDuration <= 30 {
            Text("<30s (No Scrobble)")
                .font(DS.Fonts.caption(9))
                .foregroundStyle(DS.Colors.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.05), in: Capsule())
        } else if monitor.scrobbleThresholdSeconds > 0 {
            let remaining = max(0, Int(monitor.scrobbleThresholdSeconds - monitor.accumulatedSeconds))
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 8))
                Text(remaining == 0 ? "Scrobbling soon" : "Scrobbles in \(remaining)s")
                    .font(DS.Fonts.caption(10).weight(.medium))
            }
            .foregroundStyle(DS.Colors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
