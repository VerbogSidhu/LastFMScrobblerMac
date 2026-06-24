import SwiftUI

struct ScrobblerSettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var minDuration: Double = 30
    @State private var scrobbleThreshold: ScrobbleThreshold = .halfOrFourMin
    @State private var pollInterval: Double = 5
    @State private var nowPlayingRefresh: Double = 60

    enum ScrobbleThreshold: String, CaseIterable, Identifiable {
        case halfOrFourMin = "Half duration or 4 min"
        case halfOnly = "Half duration only"
        case fourMinOnly = "4 minutes only"
        case custom = "Custom"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // Scrobble Rules
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Scrobble Rules", icon: "gearshape")

                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        // Min duration
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            HStack {
                                Text("Minimum Track Duration")
                                    .font(DS.Fonts.bodyMedium(12))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Spacer()
                                Text("\(Int(minDuration))s")
                                    .font(DS.Fonts.mono(12))
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            Slider(value: $minDuration, in: 10...120, step: 5)
                                .tint(DS.Colors.accent)
                            Text("Tracks shorter than this are never scrobbled.")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }

                        Divider().background(DS.Colors.inputBorder)

                        // Threshold
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("Scrobble Threshold")
                                .font(DS.Fonts.bodyMedium(12))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Picker("", selection: $scrobbleThreshold) {
                                ForEach(ScrobbleThreshold.allCases) { threshold in
                                    Text(threshold.rawValue).tag(threshold)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            Text("When to count a play as a scrobble.")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                    }
                }
            }

            // Polling
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Polling", icon: "arrow.clockwise")

                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            HStack {
                                Text("Poll Interval")
                                    .font(DS.Fonts.bodyMedium(12))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Spacer()
                                Text("\(Int(pollInterval))s")
                                    .font(DS.Fonts.mono(12))
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            Slider(value: $pollInterval, in: 2...15, step: 1)
                                .tint(DS.Colors.accent)
                            Text("How often to check Apple Music for track changes.")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }

                        Divider().background(DS.Colors.inputBorder)

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            HStack {
                                Text("Now-Playing Refresh")
                                    .font(DS.Fonts.bodyMedium(12))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Spacer()
                                Text("\(Int(nowPlayingRefresh))s")
                                    .font(DS.Fonts.mono(12))
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            Slider(value: $nowPlayingRefresh, in: 30...300, step: 10)
                                .tint(DS.Colors.accent)
                            Text("How often to refresh your Last.fm now-playing status.")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            minDuration = UserDefaults.standard.double(forKey: "scrobble_min_duration").clamped(to: 10...120, default: 30)
            pollInterval = UserDefaults.standard.double(forKey: "scrobble_poll_interval").clamped(to: 2...15, default: 5)
            nowPlayingRefresh = UserDefaults.standard.double(forKey: "scrobble_nowplaying_refresh").clamped(to: 30...300, default: 60)
        }
        .onChange(of: minDuration) { newValue in
            UserDefaults.standard.set(newValue, forKey: "scrobble_min_duration")
        }
        .onChange(of: pollInterval) { newValue in
            UserDefaults.standard.set(newValue, forKey: "scrobble_poll_interval")
        }
        .onChange(of: nowPlayingRefresh) { newValue in
            UserDefaults.standard.set(newValue, forKey: "scrobble_nowplaying_refresh")
        }
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        let stored = self
        return stored >= range.lowerBound && stored <= range.upperBound ? stored : defaultValue
    }
}
