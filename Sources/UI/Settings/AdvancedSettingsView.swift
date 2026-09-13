import SwiftUI
import ServiceManagement

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin = false
    @State private var showClearStatsConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // Launch at Login
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "General", icon: "gearshape")

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Launch at login")
                                .font(DS.Fonts.bodyMedium(12))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("Start the scrobbler automatically when you log in")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .onChange(of: launchAtLogin) { newValue in
                                setLaunchAtLogin(newValue)
                            }
                    }
                }
            }

            // Data
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Data", icon: "externaldrive")

                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        HStack {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Export scrobble history")
                                    .font(DS.Fonts.bodyMedium(12))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Text("Save your local scrobble data as a JSON file")
                                    .font(DS.Fonts.caption(10))
                                    .foregroundStyle(DS.Colors.textMuted)
                            }
                            Spacer()
                            SecondaryButton(title: "Export", icon: "square.and.arrow.up") {
                                exportScrobbleHistory()
                            }
                        }

                        Divider().background(DS.Colors.inputBorder)

                        HStack {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Clear local stats")
                                    .font(DS.Fonts.bodyMedium(12))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Text("Delete all locally recorded scrobble events")
                                    .font(DS.Fonts.caption(10))
                                    .foregroundStyle(DS.Colors.textMuted)
                            }
                            Spacer()
                            DestructiveButton(title: "Clear", icon: "trash") {
                                showClearStatsConfirmation = true
                            }
                        }
                    }
                }
            }

            // Debug
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Debug", icon: "ladybug")

                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Recent activity")
                            .font(DS.Fonts.bodyMedium(12))
                            .foregroundStyle(DS.Colors.textPrimary)

                        if appState.scrobbleMonitor.debugLog.isEmpty {
                            Text("No recent activity")
                                .font(DS.Fonts.caption(11))
                                .foregroundStyle(DS.Colors.textMuted)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    ForEach(appState.scrobbleMonitor.debugLog.prefix(15), id: \.self) { entry in
                                        Text(entry)
                                            .font(DS.Fonts.mono(10))
                                            .foregroundStyle(DS.Colors.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        }
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .alert("Clear All Local Stats?", isPresented: $showClearStatsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearLocalStats()
            }
        } message: {
            Text("This permanently deletes all locally recorded scrobble events. This does not affect your Last.fm profile.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[Settings] Launch at login error: %@", error.localizedDescription)
        }
    }

    private func exportScrobbleHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "lastfm_scrobble_history.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let source = appSupport.appendingPathComponent("LastFM/scrobble_stats.json")
            try? FileManager.default.copyItem(at: source, to: url)
        }
    }

    private func clearLocalStats() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let statsFile = appSupport.appendingPathComponent("LastFM/scrobble_stats.json")
        try? FileManager.default.removeItem(at: statsFile)
    }
}
