import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showMenuBarCount: Bool = UserDefaults.standard.object(forKey: "menu_bar_show_count") as? Bool ?? true
    @State private var showInDock: Bool = UserDefaults.standard.object(forKey: "show_in_dock") as? Bool ?? true

    private let accentColors: [String] = [
        "red",
        "purple",
        "blue",
        "green",
        "orange",
        "pink",
        "cyan",
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
                            ForEach(accentColors, id: \.self) { name in
                                let color = DS.Colors.color(for: name)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.setAccentColor(name)
                                    }
                                } label: {
                                    VStack(spacing: DS.Spacing.sm) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(appState.accentColorName == name ? DS.Colors.textPrimary : Color.clear, lineWidth: 2)
                                            )
                                            .shadow(color: color.opacity(appState.accentColorName == name ? 0.4 : 0), radius: 6)
                                        Text(name.capitalized)
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

            // Dock & Presentation Mode
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                SectionHeader(title: "App Presentation", icon: "macwindow.badge.plus")

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Show in macOS Dock")
                                .font(DS.Fonts.bodyMedium(12))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("When disabled, the app runs discreetly in the Menu Bar only")
                                .font(DS.Fonts.caption(10))
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $showInDock)
                            .toggleStyle(.switch)
                            .onChange(of: showInDock) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "show_in_dock")
                                NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            }
                    }
                }
            }

            Spacer()
        }
    }
}
