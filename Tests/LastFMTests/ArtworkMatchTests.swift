import Testing
import Foundation
@testable import LastFM

struct ArtworkMatchTests {
    private func row(artist: String, album: String, track: String = "Intro", cover: String) -> [String: Any] {
        ["artist": ["name": artist], "title": track, "album": ["title": album, "cover_xl": cover]]
    }
    @Test func sameTitleFromAnotherArtistCannotProvideCover() {
        let rows = [row(artist: "Wrong Artist", album: "Album", cover: "https://image.invalid/wrong.jpg")]
        #expect(ArtistImageService.matchingCover(in: rows, artist: "Right Artist", album: "Album", track: "Intro") == nil)
    }
    @Test func exactAlbumIsSelectedRatherThanFirstSearchResult() {
        let rows = [row(artist: "Artist", album: "Compilation", cover: "https://image.invalid/wrong.jpg"),
                    row(artist: "Artist", album: "Album", cover: "https://image.invalid/right.jpg")]
        #expect(ArtistImageService.matchingCover(in: rows, artist: "Artist", album: "Album", track: "Intro") == "https://image.invalid/right.jpg")
    }
    @Test func missingAlbumDoesNotGuessBetweenDifferentReleases() {
        let rows = [row(artist: "Artist", album: "Compilation", cover: "https://image.invalid/a.jpg"),
                    row(artist: "Artist", album: "Album", cover: "https://image.invalid/b.jpg")]
        #expect(ArtistImageService.matchingCover(in: rows, artist: "Artist", album: "", track: "Intro") == nil)
    }
}
