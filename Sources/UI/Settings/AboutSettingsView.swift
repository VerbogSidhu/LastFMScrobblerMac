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
