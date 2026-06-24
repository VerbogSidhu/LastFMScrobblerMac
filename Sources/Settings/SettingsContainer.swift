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
