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
                            ForEach(accentColors, id: \..name) { item in
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
