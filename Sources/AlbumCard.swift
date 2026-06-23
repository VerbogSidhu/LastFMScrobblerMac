import SwiftUI

struct AlbumCard: View {
    let album: TopAlbum

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            MediaImage(url: album.imageURL, placeholder: "square.stack.fill", size: DS.Layout.cardImageSize, cornerRadius: DS.Radius.lg)

            Text(album.name)
                .font(DS.Fonts.body(12).weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Text(album.artist)
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted)
                .lineLimit(1)

            Text("\(album.playcount) plays")
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted.opacity(0.7))
        }
        .padding(DS.Spacing.lg)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.name) by \(album.artist), \(album.playcount) plays")
    }
}
