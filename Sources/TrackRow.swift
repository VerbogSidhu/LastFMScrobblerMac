import SwiftUI

struct TrackRow: View {
    let track: RecentTrack

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Album art
            MediaImage(url: track.imageURL, placeholder: "music.note", size: DS.Layout.trackRowHeight, cornerRadius: DS.Radius.sm)

            // Track info
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(track.name)
                    .font(DS.Fonts.body(14).weight(.semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(DS.Fonts.caption(12))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)

                if !track.album.isEmpty {
                    Text(track.album)
                        .font(DS.Fonts.caption(11))
                        .foregroundStyle(DS.Colors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Now playing indicator or timestamp
            if track.nowPlaying {
                HStack(spacing: DS.Spacing.sm) {
                    PlayingAnimation()
                    Text("NOW PLAYING")
                        .font(DS.Fonts.caption(10).weight(.bold))
                }
                .foregroundStyle(DS.Colors.success)
                .accessibilityLabel("Currently playing")
            } else if let uts = track.date, let timestamp = TimeInterval(uts) {
                Text(timeAgo(from: timestamp))
                    .font(DS.Fonts.caption(11))
                    .foregroundStyle(DS.Colors.textMuted)
                    .accessibilityLabel("Played \(timeAgo(from: timestamp))")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .cardStyle()
    }

    private func timeAgo(from timestamp: TimeInterval) -> String {
        let now = Date().timeIntervalSince1970
        let diff = now - timestamp

        if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}
