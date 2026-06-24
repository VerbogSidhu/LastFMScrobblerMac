import SwiftUI

/// First-launch setup wizard. Walks user through API credentials → authorization → done.
/// Only shown when `lastfm_setup_complete` is not set in UserDefaults.
struct SetupWizardView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Step = .credentials
    @State private var username = ""
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    enum Step {
        case credentials
        case authorize
        case complete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: DS.Spacing.md) {
                stepDot(active: step == .credentials || step == .authorize || step == .complete)
                stepLine()
                stepDot(active: step == .authorize || step == .complete)
                stepLine()
                stepDot(active: step == .complete)
            }
            .padding(.top, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxl)
            
            // Step content
            switch step {
            case .credentials:
                credentialsStep
            case .authorize:
                authorizeStep
            case .complete:
                completeStep
            }
        }
        .frame(width: 480, height: 520)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Step Dots
    
    private func stepDot(active: Bool) -> some View {
        Circle()
            .fill(active ? DS.Colors.accent : DS.Colors.inputBackground)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(active ? DS.Colors.accent : DS.Colors.inputBorder, lineWidth: 1)
            )
    }
    
    private func stepLine() -> some View {
        Rectangle()
            .fill(DS.Colors.inputBorder)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Step 1: Credentials
    
    private var credentialsStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Welcome to Last.fm Scrobbler")
                        .font(DS.Fonts.heading(18))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                
                Text("Automatically scrobble your Apple Music tracks to Last.fm and see your listening stats.")
                    .font(DS.Fonts.body())
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Your Details")
                    .font(DS.Fonts.subheading())
                    .foregroundStyle(DS.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Last.fm Username")
                        .font(DS.Fonts.captionMedium(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                    TextField("your Last.fm username", text: $username)
                        .textFieldStyle(.plain)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.inputBorder, lineWidth: 1)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("API Credentials")
                    .font(DS.Fonts.subheading())
                    .foregroundStyle(DS.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("API Key")
                        .font(DS.Fonts.captionMedium(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                    TextField("paste your API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.inputBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("API Secret")
                        .font(DS.Fonts.captionMedium(11))
                        .foregroundStyle(DS.Colors.textSecondary)
                    SecureField("paste your API secret", text: $apiSecret)
                        .textFieldStyle(.plain)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.inputBorder, lineWidth: 1)
                        )
                }
                
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.textMuted)
                    Text("Register your app at last.fm/api/account/create to get these.")
                        .font(DS.Fonts.caption(10))
                        .foregroundStyle(DS.Colors.textMuted)
                }
            }
            
            if let error = errorMessage {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Colors.error)
                    Text(error)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.error)
                }
            }
            
            Spacer()
            
            // Actions
            HStack {
                Spacer()
                PrimaryButton(
                    title: "Continue",
                    icon: "arrow.right",
                    isLoading: false
                ) {
                    errorMessage = nil
                    guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
                        errorMessage = "Please enter your Last.fm username."
                        return
                    }
                    guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
                        errorMessage = "Please enter your API key."
                        return
                    }
                    guard !apiSecret.trimmingCharacters(in: .whitespaces).isEmpty else {
                        errorMessage = "Please enter your API secret."
                        return
                    }
                    // Save username and credentials, then move to authorization
                    Constants.setUsername(username.trimmingCharacters(in: .whitespaces))
                    appState.scrobbleMonitor.saveCredentials(
                        apiKey: apiKey.trimmingCharacters(in: .whitespaces),
                        apiSecret: apiSecret.trimmingCharacters(in: .whitespaces)
                    )
                    step = .authorize
                }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || apiKey.trimmingCharacters(in: .whitespaces).isEmpty || apiSecret.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Spacing.xxxl)
    }
    
    // MARK: - Step 2: Authorize
    
    private var authorizeStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Connect to Last.fm")
                        .font(DS.Fonts.heading(18))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                
                Text("Your browser will open to authorize this app. Once you approve, we'll detect it automatically.")
                    .font(DS.Fonts.body())
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Status card
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                switch appState.scrobbleMonitor.authStatus {
                case .awaitingAuthorization:
                    HStack(spacing: DS.Spacing.md) {
                        ProgressView()
                            .scaleEffect(0.8)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Waiting for authorization…")
                                .font(DS.Fonts.bodyMedium(12))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("Check your browser. Approve the request, then come back here.")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .padding(DS.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    
                case .authenticated:
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Colors.success)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Connected!")
                                .font(DS.Fonts.bodyMedium(12))
                                .foregroundStyle(DS.Colors.success)
                            Text("You're authorized and ready to scrobble.")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .padding(DS.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.success.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    
                default:
                    EmptyView()
                }
            }
            
            if let error = errorMessage {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Colors.error)
                    Text(error)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.error)
                }
            }
            
            Spacer()
            
            // Actions
            HStack {
                SecondaryButton(title: "Back", icon: "arrow.left") {
                    step = .credentials
                }
                
                Spacer()
                
                if appState.scrobbleMonitor.authStatus == .authenticated {
                    PrimaryButton(title: "Continue", icon: "arrow.right") {
                        step = .complete
                    }
                } else {
                    PrimaryButton(
                        title: "Authorize in Browser",
                        icon: "safari",
                        isLoading: isProcessing
                    ) {
                        errorMessage = nil
                        isProcessing = true
                        Task {
                            await appState.scrobbleMonitor.authenticate()
                            await MainActor.run {
                                isProcessing = false
                                if appState.scrobbleMonitor.authStatus != .authenticated {
                                    errorMessage = "Authorization timed out. Make sure you approved the request in your browser, then try again."
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.xxxl)
    }
    
    // MARK: - Step 3: Complete
    
    private var completeStep: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Colors.success)
                    Text("You're All Set!")
                        .font(DS.Fonts.heading(18))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                
                Text("The scrobbler is now active. It will automatically detect Apple Music tracks and scrobble them to Last.fm.")
                    .font(DS.Fonts.body())
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // What happens now
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                featureRow(icon: "waveform", title: "Auto-Scrobble", description: "Plays are tracked and scrobbled automatically")
                featureRow(icon: "clock.arrow.circlepath", title: "Now Playing", description: "Your current track shows on your Last.fm profile")
                featureRow(icon: "chart.bar.fill", title: "Stats & Reports", description: "View your listening habits in the sidebar")
                featureRow(icon: "menubar.rectangle", title: "Menu Bar", description: "Quick access from the menu bar icon")
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            
            Spacer()
            
            // Actions
            HStack {
                Spacer()
                PrimaryButton(title: "Start Scrobbling", icon: "play.fill") {
                    // Mark setup complete
                    UserDefaults.standard.set(true, forKey: "lastfm_setup_complete")
                    // Start the monitor
                    appState.scrobbleMonitor.startMonitoring()
                    // Load dashboard data
                    appState.loadAll()
                }
            }
        }
        .padding(DS.Spacing.xxxl)
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Fonts.bodyMedium(12))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(description)
                    .font(DS.Fonts.caption(10))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }
}
