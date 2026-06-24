# Settings Menu Improvements — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Transform the flat, single-scroll SettingsView into a polished, tabbed settings panel with account management, scrobble configuration, appearance options, data tools, and an about section.

**Architecture:** Replace the current monolithic `SettingsView.swift` with a `SettingsView` container that switches between tab content views. Each tab is its own SwiftUI file. Scrobble rules (min duration, threshold) become configurable via UserDefaults with safe defaults matching current behavior.

**Tech Stack:** SwiftUI (macOS 13+), UserDefaults for persistence, existing DS design system tokens and components.

---

## Current State

- **SettingsView.swift** (153 lines) — flat ScrollView with username, API key/secret, connect/disconnect, scrobble toggle
- **ScrobbleMonitor.swift** — hardcoded poll interval (5s), now-playing refresh (60s), scrobble threshold (half duration or 4 min, whichever first), min duration (30s)
- **Design system** — `DS` tokens (DSTokens.swift), reusable components (DSComponents.swift): `Card`, `SectionHeader`, `PrimaryButton`, `SecondaryButton`, `DestructiveButton`, `StatCard`
- **No** theme settings, scrobble rule config, notification prefs, data export, about section, or debug tools in settings

---

## Task 1: Create Settings Tab Enum and Container

**Objective:** Create the tabbed container that switches between settings sections.

**Files:**
- Create: `Sources/Settings/SettingsContainer.swift`
- Modify: `Sources/SettingsView.swift` (replace content)

**Steps:**

1. Create `Sources/Settings/` directory.

2. Create `SettingsContainer.swift`:

```swift
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case account = "Account"
    case scrobbler = "Scrobbler"
    case appearance = "Appearance"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .account: return "person.circle"
        case .scrobbler: return "waveform"
        case .appearance: return "paintbrush"
        case .advanced: return "gearshape.2"
        case .about: return "info.circle"
        }
    }
}

struct SettingsContainer: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .account

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

            HStack(spacing: 0) {
                // Tab sidebar
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(SettingsTab.allCases) { tab in
                        tabButton(tab)
                    }
                    Spacer()
                }
                .frame(width: 140)
                .padding(.vertical, DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.md)

                Divider().background(DS.Colors.sidebarDivider)

                // Tab content
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 580, height: 480)
        .background(.ultraThinMaterial)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(DS.Fonts.bodyMedium(12))
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(selectedTab == tab ? DS.Colors.accent : DS.Colors.textSecondary)
            .background(
                selectedTab == tab
                    ? DS.Colors.accent.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                switch selectedTab {
                case .account:
                    AccountSettingsView()
                case .scrobbler:
                    ScrobblerSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .advanced:
                    AdvancedSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .padding(DS.Spacing.xxl)
        }
    }
}
```

3. Replace `SettingsView.swift` content to just be a wrapper (or delete it and update references in ContentView/SidebarView to use `SettingsContainer` instead).

4. Build: `cd /Users/verbog/LastFMSwift && swift build 2>&1`
   Expected: Build may fail — that's OK, we'll create the tab views next.

5. Commit:
```bash
git add Sources/Settings/
git commit -m "feat(settings): add tabbed settings container"
```

---

## Task 2: Account Tab

**Objective:** Account management — username, API credentials, connection status, disconnect/reset.

**Files:**
- Create: `Sources/Settings/AccountSettingsView.swift`

**Steps:**

1. Create `AccountSettingsView.swift`:

```swift
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
```

2. Build and verify: `swift build 2>&1`

3. Commit:
```bash
git add Sources/Settings/AccountSettingsView.swift
git commit -m "feat(settings): add account tab with connection status and credentials"
```

---

## Task 3: Scrobbler Tab

**Objective:** Scrobble rules configuration — min duration, scrobble threshold, now-playing refresh, poll interval.

**Files:**
- Create: `Sources/Settings/ScrobblerSettingsView.swift`
- Modify: `Sources/ScrobbleMonitor.swift` (read from UserDefaults instead of hardcoded values)

**Steps:**

1. Create `ScrobblerSettingsView.swift`:

```swift
import SwiftUI

struct ScrobblerSettingsView: View {
    @EnvironmentObject var appState: AppState

    // Scrobble rules — loaded from UserDefaults with safe defaults
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
```

2. Update `ScrobbleMonitor.swift` to read from UserDefaults:

Replace the hardcoded constants (lines ~56-57, ~194, ~383-384):

```swift
// In ScrobbleMonitor, replace:
private let nowPlayingRefreshInterval: TimeInterval = 60
// With:
private var nowPlayingRefreshInterval: TimeInterval {
    UserDefaults.standard.double(forKey: "scrobble_nowplaying_refresh").clamped(to: 30...300, default: 60)
}

// Replace the timer interval:
let timer = Timer(timeInterval: 5.0, repeats: true) { ... }
// With:
let pollInterval = UserDefaults.standard.double(forKey: "scrobble_poll_interval").clamped(to: 2...15, default: 5)
let timer = Timer(timeInterval: pollInterval, repeats: true) { ... }

// Replace scrobble condition (line ~383):
if !hasScrobbled && isPlaying && effectiveDuration > 30 {
    let threshold = min(Double(effectiveDuration) / 2.0, 240.0)
// With:
let minDuration = UserDefaults.standard.double(forKey: "scrobble_min_duration").clamped(to: 10...120, default: 30)
if !hasScrobbled && isPlaying && Double(effectiveDuration) > minDuration {
    let threshold = min(Double(effectiveDuration) / 2.0, 240.0)
```

Add the `clamped` extension to ScrobbleMonitor.swift (or a shared extensions file):

```swift
private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        let stored = self
        return stored >= range.lowerBound && stored <= range.upperBound ? stored : defaultValue
    }
}
```

3. Build: `swift build 2>&1`

4. Commit:
```bash
git add Sources/Settings/ScrobblerSettingsView.swift Sources/ScrobbleMonitor.swift
git commit -m "feat(settings): add scrobbler rules tab with configurable thresholds"
```

---

## Task 4: Appearance Tab

**Objective:** Theme/appearance settings — accent color, menu bar icon style.

**Files:**
- Create: `Sources/Settings/AppearanceSettingsView.swift`
- Modify: `Sources/DSTokens.swift` (make accent color configurable)

**Steps:**

1. Create `AppearanceSettingsView.swift`:

```swift
import SwiftUI

struct AppearanceSettingsView: View {
    @State private var accentColorName: String = UserDefaults.standard.string(forKey: "accent_color") ?? "purple"
    @State private var showMenuBarCount: Bool = UserDefaults.standard.object(forKey: "menu_bar_show_count") as? Bool ?? true

    private let accentColors: [(name: String, color: Color)] = [
        ("purple", .purple),
        ("blue", .blue),
        ("pink", .pink),
        ("green", .green),
        ("orange", .orange),
        ("red", .red),
        ("cyan", .cyan),
        ("yellow", .yellow),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // Accent Color
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Accent Color", icon: "paintbrush")

                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        Text("Choose the app's accent color")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DS.Spacing.md) {
                            ForEach(accentColors, id: \.name) { item in
                                Button {
                                    accentColorName = item.name
                                    UserDefaults.standard.set(item.name, forKey: "accent_color")
                                } label: {
                                    VStack(spacing: DS.Spacing.sm) {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(accentColorName == item.name ? DS.Colors.textPrimary : Color.clear, lineWidth: 2)
                                            )
                                        Text(item.name.capitalized)
                                            .font(DS.Fonts.caption(10))
                                            .foregroundStyle(DS.Colors.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Menu Bar
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Menu Bar", icon: "menubar.rectangle")

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Show scrobble count")
                                .font(DS.Fonts.bodyMedium(12))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("Display today's scrobble count next to the menu bar icon")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $showMenuBarCount)
                            .toggleStyle(.switch)
                            .onChange(of: showMenuBarCount) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "menu_bar_show_count")
                            }
                    }
                }
            }

            Spacer()
        }
    }
}
```

2. Update `DSTokens.swift` to read accent color from UserDefaults:

Replace line 12:
```swift
static let accent = Color.purple
// With:
static var accent: Color {
    let name = UserDefaults.standard.string(forKey: "accent_color") ?? "purple"
    switch name {
    case "blue": return .blue
    case "pink": return .pink
    case "green": return .green
    case "orange": return .orange
    case "red": return .red
    case "cyan": return .cyan
    case "yellow": return .yellow
    default: return .purple
    }
}
```

3. Build: `swift build 2>&1`

4. Commit:
```bash
git add Sources/Settings/AppearanceSettingsView.swift Sources/DSTokens.swift
git commit -m "feat(settings): add appearance tab with accent color picker"
```

---

## Task 5: Advanced Tab

**Objective:** Debug tools, data management, launch-at-login toggle.

**Files:**
- Create: `Sources/Settings/AdvancedSettingsView.swift`

**Steps:**

1. Create `AdvancedSettingsView.swift`:

```swift
import SwiftUI
import ServiceManagement

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin = false
    @State private var showClearStatsConfirmation = false
    @State private var showExportSheet = false

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
```

2. Build: `swift build 2>&1`

3. Commit:
```bash
git add Sources/Settings/AdvancedSettingsView.swift
git commit -m "feat(settings): add advanced tab with launch-at-login, export, debug log"
```

---

## Task 6: About Tab

**Objective:** App info, version, credits, links.

**Files:**
- Create: `Sources/Settings/AboutSettingsView.swift`

**Steps:**

1. Create `AboutSettingsView.swift`:

```swift
import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // App Info
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.lg) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Last.fm Scrobbler")
                            .font(DS.Fonts.heading(18))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Version \(appVersion)")
                            .font(DS.Fonts.body(12))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("Auto-scrobble Apple Music to Last.fm")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textMuted)
                    }
                }
            }

            // Links
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Links", icon: "link")

                Card {
                    VStack(spacing: 0) {
                        linkRow(icon: "globe", title: "Last.fm", url: "https://www.last.fm")
                        Divider().background(DS.Colors.inputBorder).padding(.horizontal)
                        linkRow(icon: "hammer", title: "API Console", url: "https://www.last.fm/api/account/create")
                        Divider().background(DS.Colors.inputBorder).padding(.horizontal)
                        linkRow(icon: "chevron.left.forwardslash.chevron.right", title: "Source Code", url: "https://github.com/VerbogSidhu/LastFMScrobblerMac")
                    }
                }
            }

            // Credits
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "Credits", icon: "heart")

                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Built with SwiftUI for macOS.")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("Uses the Last.fm API for scrobbling and stats. Artist images sourced from Deezer.")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }

            Spacer()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func linkRow(icon: String, title: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 20)
                Text(title)
                    .font(DS.Fonts.bodyMedium(12))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Colors.textMuted)
            }
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.lg)
        }
        .buttonStyle(.plain)
    }
}
```

2. Build: `swift build 2>&1`

3. Commit:
```bash
git add Sources/Settings/AboutSettingsView.swift
git commit -m "feat(settings): add about tab with app info, links, credits"
```

---

## Task 7: Wire Up and Clean Up

**Objective:** Replace old SettingsView references, delete the old file, final build and test.

**Files:**
- Delete: `Sources/SettingsView.swift` (replaced by Settings/)
- Modify: All files referencing `SettingsView` → `SettingsContainer`

**Steps:**

1. Search for all references to `SettingsView`:
```bash
cd /Users/verbog/LastFMSwift
grep -rn "SettingsView" Sources/ --include="*.swift"
```

2. Update each reference to `SettingsContainer`. Key locations:
   - `ContentView.swift` or wherever the settings sheet is presented
   - `SidebarView.swift` if it references SettingsView

3. Delete old `Sources/SettingsView.swift`.

4. Build: `swift build 2>&1`
   Expected: Clean build, 0 errors.

5. Deploy and test:
```bash
killall LastFM 2>/dev/null; sleep 0.5
cp .build/debug/LastFM /Applications/LastFM.app/Contents/MacOS/LastFM
open /Applications/LastFM.app
```

6. Verify: Open settings, click through all 5 tabs, change accent color, adjust scrobble threshold, check debug log.

7. Commit:
```bash
git add -A
git commit -m "feat(settings): complete settings redesign with tabbed layout"
```

---

## Task 8: Push and Document

**Objective:** Push to GitHub, update Obsidian notes.

**Files:**
- Modify: `~/Documents/Obsidian Vault/Tech_LastFMSwiftApp.md`

**Steps:**

1. Push:
```bash
cd /Users/verbog/LastFMSwift && git push
```

2. Update Obsidian note with new settings structure:
   - Add "Settings Redesign (June 2026)" section
   - Document the 5 tabs and what each contains
   - Note configurable scrobble rules and their defaults

3. Commit Obsidian changes.

---

## Summary of New Files

| File | Purpose | Lines (est.) |
|------|---------|-------------|
| `Sources/Settings/SettingsContainer.swift` | Tab container with sidebar navigation | ~90 |
| `Sources/Settings/AccountSettingsView.swift` | Username, API credentials, connection status | ~130 |
| `Sources/Settings/ScrobblerSettingsView.swift` | Scrobble rules, polling config | ~120 |
| `Sources/Settings/AppearanceSettingsView.swift` | Accent color picker, menu bar options | ~100 |
| `Sources/Settings/AdvancedSettingsView.swift` | Launch-at-login, export, clear stats, debug log | ~140 |
| `Sources/Settings/AboutSettingsView.swift` | App info, links, credits | ~90 |

## Files Modified

| File | Change |
|------|--------|
| `Sources/DSTokens.swift` | `accent` becomes computed property from UserDefaults |
| `Sources/ScrobbleMonitor.swift` | Read poll interval, min duration, refresh interval from UserDefaults |
| `Sources/SettingsView.swift` | Deleted (replaced by Settings/) |
