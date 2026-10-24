import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isAuthenticating = false
    @State private var showResetConfirmation = false
    @State private var errorMessage: String?
    @State private var authenticationTask: Task<Void, Never>?

    private var connected: Bool { appState.scrobbleMonitor.authStatus == .authenticated }
    private var validCredentials: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            Card {
                HStack(spacing: DS.Spacing.lg) {
                    StatusDot(isActive: connected)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(connected ? "Connected to Last.fm" : isAuthenticating ? "Waiting for authorization…" : "Not Connected")
                            .font(DS.Fonts.bodyMedium(12))
                        if let name = CredentialStore.shared.username, connected {
                            Text("@\(name)")
                                .font(DS.Fonts.caption(11))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    Spacer()
                    if let name = CredentialStore.shared.username, connected,
                       let url = URL(string: "https://www.last.fm/user/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)") {
                        Link(destination: url) { Label("Profile", systemImage: "arrow.up.right") }
                            .font(DS.Fonts.caption(11))
                    }
                }
            }

            Text("The account you authorize in your browser is used for both your dashboard and scrobbles. Disconnect to switch accounts.")
                .font(DS.Fonts.caption(11))
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("API Credentials").font(DS.Fonts.subheading(13))
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("API Key").font(DS.Fonts.captionMedium(11))
                    TextField("API Key", text: $apiKey).inputStyle()
                        .accessibilityLabel("Last.fm API key")
                }
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("API Secret").font(DS.Fonts.captionMedium(11))
                    SecureField("API Secret", text: $apiSecret).inputStyle()
                        .accessibilityLabel("Last.fm API secret")
                }
                Link("Get an API key and secret from Last.fm", destination: URL(string: "https://www.last.fm/api/account/create")!)
                    .font(DS.Fonts.caption(11))
                Text("Your secret and session are stored securely in macOS Keychain.")
                    .font(DS.Fonts.caption(10))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .disabled(connected || isAuthenticating)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(DS.Fonts.caption(11))
                    .foregroundStyle(DS.Colors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if connected {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    DestructiveButton(title: "Disconnect", icon: "link.circle.fill") {
                        authenticationTask?.cancel()
                        appState.scrobbleMonitor.disconnect()
                        loadCredentials()
                    }
                    DestructiveButton(title: "Reset & Re-authorize", icon: "arrow.counterclockwise") {
                        showResetConfirmation = true
                    }
                }
            } else {
                PrimaryButton(title: "Connect to Last.fm", icon: "link", isLoading: isAuthenticating) {
                    connect()
                }
                .disabled(!validCredentials)
            }
        }
        .onAppear { loadCredentials() }
        .onDisappear { authenticationTask?.cancel() }
        .alert("Reset All Credentials?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                authenticationTask?.cancel()
                appState.scrobbleMonitor.resetCredentials()
                loadCredentials()
            }
        } message: {
            Text("This removes the saved API credentials and session. Your listening history is kept, and setup will guide you through reconnecting.")
        }
    }

    private func loadCredentials() {
        do {
            try CredentialStore.shared.migrateLegacyDefaults()
            apiKey = CredentialStore.shared.apiKey
            apiSecret = CredentialStore.shared.apiSecret
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func connect() {
        errorMessage = nil
        do {
            try CredentialStore.shared.saveCredentials(apiKey: apiKey, apiSecret: apiSecret)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        appState.scrobbleMonitor.setup()
        isAuthenticating = true
        authenticationTask?.cancel()
        authenticationTask = Task { @MainActor in
            await appState.scrobbleMonitor.authenticate()
            guard !Task.isCancelled else { isAuthenticating = false; return }
            isAuthenticating = false
            if connected {
                UserDefaults.standard.set(true, forKey: "lastfm_setup_complete")
                appState.scrobbleMonitor.startMonitoring()
                appState.loadAll()
            } else {
                errorMessage = appState.scrobbleMonitor.lastError ?? "Authorization did not finish. Approve the request in your browser and try again."
            }
        }
    }
}
