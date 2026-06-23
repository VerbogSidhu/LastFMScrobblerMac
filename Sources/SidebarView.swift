import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(DS.Colors.accent.gradient)
                Text("Last.fm")
                    .font(DS.Fonts.heading(24))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(.top, 24)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last.fm Scrobbler")

            // User info card
            if let user = appState.userInfo {
                Card(padding: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.md) {
                        MediaImage(url: user.imageURL, placeholder: "person.circle.fill", size: DS.Layout.avatarSize, cornerRadius: 40)
                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))

                        Text(user.realname ?? user.name)
                            .font(DS.Fonts.body(16).weight(.semibold))
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text("@\(user.name)")
                            .font(DS.Fonts.caption())
                            .foregroundStyle(DS.Colors.textTertiary)

                        HStack(spacing: DS.Spacing.xl) {
                            StatBadge(value: "\(user.playcount)", label: "Scrobbles")
                            StatBadge(value: user.artistCount, label: "Artists")
                            StatBadge(value: user.albumCount, label: "Albums")
                        }
                        .padding(.top, DS.Spacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
            }

            // Scrobbler status
            ScrobblerStatusCard()
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)

            // Navigation
            VStack(spacing: DS.Spacing.sm) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarButton(
                        title: tab.rawValue,
                        icon: iconForTab(tab),
                        isSelected: appState.selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()

            // Bottom buttons
            HStack(spacing: DS.Spacing.md) {
                IconButton(icon: "gearshape.fill", label: "Settings") {
                    showSettings = true
                }

                SecondaryButton(title: "Refresh", icon: appState.isLoading ? nil : "arrow.clockwise") {
                    appState.loadAll()
                }
            }
            .padding(.bottom, DS.Spacing.xl)
            .padding(.horizontal, DS.Spacing.xl)
        }
        .frame(width: DS.Layout.sidebarWidth)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private func iconForTab(_ tab: SidebarTab) -> String {
        switch tab {
        case .recent: return "clock.fill"
        case .artists: return "person.2.fill"
        case .albums: return "square.stack.fill"
        case .stats: return "chart.bar.fill"
        case .reports: return "doc.text.fill"
        }
    }
}
