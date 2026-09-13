import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isAuthenticating = false
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // Connection Status
            Card {
                HStack(spacing: DS.Spacing.lg) {
                    Circle()
                        .fill(appState.scrobbleMonitor.authStatus == .authenticated
                              ? DS.Colors.success
                              : DS.Colors.error)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(appState.scrobbleMonitor.authStatus == .authenticated
                             ? "Connected to Last.fm"
                             : "Not Connected")
                            .font(DS.Fonts.bodyMedium(12))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Username: \(Constants.lastFMUsername.isEmpty ? "not set" : Constants.lastFMUsername)")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                    if appState.scrobbleMonitor.authStatus == .authenticated {
                        SecondaryButton(title: "Profile", icon: "arrow.up.right") {
                            if let url = URL(string: "https://www.last.fm/user/\(Constants.lastFMUsername)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            // Username
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Last.fm Username")
                    .font(DS.Fonts.captionMedium(11))
                    .foregroundStyle(DS.Colors.textSecondary)
                TextField("your Last.fm username", text: $username)
                    .inputStyle()
                    .onChange(of: username) { newValue in
                        Constants.setUsername(newValue.trimmingCharacters(in: .whitespaces))
                    }
            }

            // API Credentials
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("API Credentials")
                    .font(DS.Fonts.subheading(13))

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
            }

            // Actions
            if appState.scrobbleMonitor.authStatus == .authenticated {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    DestructiveButton(title: "Disconnect", icon: "link.circle.fill") {
                        appState.scrobbleMonitor.disconnect()
                    }
                    DestructiveButton(title: "Reset & Re-authorize", icon: "arrow.counterclockwise") {
                        showResetConfirmation = true
                    }
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

            Spacer()
        }
        .onAppear {
            username = UserDefaults.standard.string(forKey: "lastfm_username") ?? ""
            apiKey = UserDefaults.standard.string(forKey: "lastfm_api_key") ?? ""
            apiSecret = UserDefaults.standard.string(forKey: "lastfm_api_secret") ?? ""
        }
        .alert("Reset All Credentials?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.scrobbleMonitor.resetCredentials()
                apiKey = ""
                apiSecret = ""
            }
        } message: {
            Text("This will remove your API key, secret, and session. You'll need to re-authorize with Last.fm.")
        }
    }
}
