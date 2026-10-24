import Testing
import Foundation
#if canImport(LastFM)
@testable import LastFM
#endif

struct PlaybackSessionTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private func sample(_ position: Int, title: String = "Track", artist: String = "Artist", album: String = "Album", id: Int = 1, state: String = "playing", duration: Int = 120) -> MusicTrackInfo {
        MusicTrackInfo(name: title, artist: artist, album: album, duration: duration, playerPosition: position, playerState: state, databaseID: id)
    }
    @Test func testInitialPositionDoesNotCountAsObservedListening() {
        var session = PlaybackSession()
        _ = session.observe(sample(80), now: start, uptime: 0)
        _ = session.observe(sample(85), now: start.addingTimeInterval(5), uptime: 5)
        #expect(abs(session.listened - 5) < 0.01)
        #expect(session.startedAt == start.addingTimeInterval(-80))
    }
    @Test func testSleepGapDoesNotCountAsListening() {
        var session = PlaybackSession()
        _ = session.observe(sample(0), now: start, uptime: 0)
        _ = session.observe(sample(5), now: start.addingTimeInterval(3600), uptime: 3600)
        #expect(session.listened == 0)
    }
    @Test func testForwardSeekDoesNotCountSkippedSeconds() {
        var session = PlaybackSession()
        _ = session.observe(sample(0), now: start, uptime: 0)
        _ = session.observe(sample(100), now: start.addingTimeInterval(5), uptime: 5)
        #expect(session.listened == 0)
    }
    @Test func testPausePreservesSubmissionAndDoesNotCreditUnobservedTime() {
        var session = PlaybackSession()
        _ = session.observe(sample(0), now: start, uptime: 0)
        _ = session.observe(sample(60), now: start.addingTimeInterval(60), uptime: 60, pollInterval: 15)
        session.markSubmitted()
        session.suspend()
        let changed1 = session.observe(sample(85), now: start.addingTimeInterval(80), uptime: 80)
        #expect(!changed1)
        #expect(session.submitted)
    }
    @Test func testEqualDatabaseIDsDoNotMergeDifferentAlbumsOrArtists() {
        var session = PlaybackSession()
        _ = session.observe(sample(50, id: 0), now: start, uptime: 0)
        let changed2 = session.observe(sample(0, artist: "Another artist", id: 0), now: start, uptime: 5)
        #expect(changed2)
        #expect(session.listened == 0)
    }
    @Test func testNaturalRepeatStartsAnotherPlayButManualSeekDoesNot() {
        var session = PlaybackSession()
        _ = session.observe(sample(116), now: start, uptime: 0)
        session.markSubmitted()
        let changed3 = session.observe(sample(1), now: start.addingTimeInterval(5), uptime: 5)
        #expect(changed3)
        #expect(!session.submitted)
        session.markSubmitted()
        session.seek()
        let changed4 = session.observe(sample(0), now: start.addingTimeInterval(6), uptime: 6)
        #expect(!changed4)
        #expect(session.submitted)
    }
    @Test func testBufferingAndPausedSamplesDoNotAccumulateTime() {
        var session = PlaybackSession()
        _ = session.observe(sample(0), now: start, uptime: 0)
        _ = session.observe(sample(0), now: start.addingTimeInterval(5), uptime: 5)
        _ = session.observe(sample(0, state: "paused"), now: start.addingTimeInterval(10), uptime: 10)
        #expect(session.listened == 0)
    }
}
