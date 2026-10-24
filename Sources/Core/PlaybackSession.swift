import Foundation

/// Metadata identity deliberately includes artist and album: database IDs can be
/// zero for streamed tracks, and two recordings can share a title.
struct PlaybackIdentity: Hashable {
    let databaseID: Int
    let name: String
    let artist: String
    let album: String

    init(_ track: MusicTrackInfo) {
        databaseID = track.databaseID
        name = track.name.precomposedStringWithCanonicalMapping
        artist = track.artist.precomposedStringWithCanonicalMapping
        album = track.album.precomposedStringWithCanonicalMapping
    }
}

/// State for one observed play. Monotonic time bounds position advancement;
/// attaching partway through never credits seconds the app did not observe.
struct PlaybackSession {
    private(set) var track: MusicTrackInfo?
    private(set) var startedAt: Date?
    private(set) var listened: TimeInterval = 0
    private(set) var submitted = false
    private var lastUptime: TimeInterval?
    private var lastPosition = 0
    private var wasPlaying = false
    private var explicitSeek = false

    var identity: PlaybackIdentity? { track.map(PlaybackIdentity.init) }

    @discardableResult
    mutating func observe(_ info: MusicTrackInfo, now: Date, uptime: TimeInterval, pollInterval: TimeInterval = 5) -> Bool {
        let elapsed = lastUptime.map { max(0, uptime - $0) } ?? 0
        let delta = info.playerPosition - lastPosition
        let playing = info.playerState == "playing"
        let reasonableGap = elapsed > 0 && elapsed <= max(20, pollInterval * 2.5)
        // Only a transition from the actual end to the beginning is evidence of
        // repeat. Accumulated wall time alone is never evidence of another play.
        let repeatTolerance = max(3, Int(pollInterval * 1.5))
        let repeated = !explicitSeek && reasonableGap && wasPlaying && playing &&
            info.duration > 30 && lastPosition >= info.duration - repeatTolerance &&
            info.playerPosition <= repeatTolerance && delta < 0
        let changed = identity != PlaybackIdentity(info) || repeated
        if changed {
            listened = 0
            startedAt = now.addingTimeInterval(-Double(max(0, info.playerPosition)))
            submitted = false
        } else if !explicitSeek && reasonableGap && playing && wasPlaying && delta > 0 && Double(delta) <= elapsed + 2 {
            listened += min(elapsed, Double(delta))
        }
        track = info
        lastUptime = uptime
        lastPosition = info.playerPosition
        wasPlaying = playing
        explicitSeek = false
        return changed
    }

    mutating func markSubmitted() { submitted = true }
    mutating func suspend() { lastUptime = nil; wasPlaying = false }
    mutating func seek() { lastUptime = nil; wasPlaying = false; explicitSeek = true }
    mutating func clear() { self = PlaybackSession() }
}
