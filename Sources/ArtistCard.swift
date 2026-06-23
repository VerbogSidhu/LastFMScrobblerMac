import SwiftUI

struct ArtistCard: View {
    let artist: TopArtist

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            MediaImage(url: artist.imageURL, placeholder: "person.fill", size: DS.Layout.cardImageSize, cornerRadius: DS.Radius.lg)

            Text(artist.name)
                .font(DS.Fonts.body(12).weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)

            Text("\(artist.playcount) plays")
                .font(DS.Fonts.caption(10))
                .foregroundStyle(DS.Colors.textMuted)
        }
        .padding(DS.Spacing.lg)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artist.name), \(artist.playcount) plays")
    }
}
