import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var apiKey = ScrobbleService.defaultAPIKey
    @State private var apiSecret = ""
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(DS.Fonts.heading(18))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(DS.Spacing.xxl)

            Divider().background(DS.Colors.sidebarDivider)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    // Scrobbler Section
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        Text("Scrobbler")
                            .font(DS.Fonts.subheading())
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text("Automatically scrobble your Apple Music tracks to Last.fm.")
                            .font(DS.Fonts.caption())
                            .foregroundStyle(DS.Colors.textTertiary)

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("API Key")
                                .font(DS.Fonts.captionMedium(11))
                                .foregroundStyle(DS.Colors.textSecondary)
                            TextField("API Key", text: $apiKey)
                                .inputStyle()
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("API Secret")
                                .font(DS.Fonts.captionMedium(11))
                                .foregroundStyle(DS.Colors.textSecondary)
                            SecureField("API Secret", text: $apiSecret)
                                .inputStyle()
                        }

                        Text("Register your app at last.fm/api/account/create to get an API key and secret.")
                            .font(DS.Fonts.caption(10))
                            .foregroundStyle(DS.Colors.textMuted)

                        if appState.scrobbleMonitor.authStatus == .authenticated {
                            DestructiveButton(title: "Disconnect", icon: "link.circle.fill") {
                                appState.scrobbleMonitor.disconnect()
                            }
                        } else if !apiSecret.isEmpty {
                            PrimaryButton(
                                title: "Connect to Last.fm",
                                icon: "link",
                                isLoading: isAuthenticating
                            ) {
                                isAuthenticating = true
                                appState.scrobbleMonitor.saveCredentials(apiKey: apiKey, apiSecret: apiSecret)
                                Task {
                                    await appState.scrobbleMonitor.authenticate()
                                    await MainActor.run {
                                        isAuthenticating = false
                                        if appState.scrobbleMonitor.authStatus == .authenticated {
                                            appState.scrobbleMonitor.startMonitoring()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Monitor Toggle
                    if appState.scrobbleMonitor.authStatus == .authenticated {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            Text("Auto-Scrobble")
                                .font(DS.Fonts.subheading())
                                .foregroundStyle(DS.Colors.textPrimary)

                            HStack {
                                Text(appState.scrobbleMonitor.isScrobbling ? "Active" : "Paused")
                                    .font(DS.Fonts.caption())
                                    .foregroundStyle(DS.Colors.textSecondary)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { appState.scrobbleMonitor.isScrobbling },
                                    set: { newValue in
                                        if newValue {
                                            appState.scrobbleMonitor.startMonitoring()
                                        } else {
                                            appState.scrobbleMonitor.stopMonitoring()
                                        }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .accessibilityLabel("Auto-scrobble toggle")
                            }
                            .padding(DS.Spacing.lg)
                            .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                }
                .padding(DS.Spacing.xxl)
            }
        }
        .frame(width: 420, height: 480)
        .background(.ultraThinMaterial)
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "lastfm_api_key") ?? ScrobbleService.defaultAPIKey
            apiSecret = UserDefaults.standard.string(forKey: "lastfm_api_secret") ?? ""
        }
    }
}
