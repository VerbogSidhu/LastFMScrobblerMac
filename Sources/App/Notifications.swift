import Foundation

extension Notification.Name {
    /// Posted when a track is successfully scrobbled to Last.fm.
    static let scrobbleDidComplete = Notification.Name("scrobbleDidComplete")
    /// Posted when Apple Music detects a track change or skip.
    static let trackDidChange = Notification.Name("trackDidChange")
    /// Posted when Last.fm successfully acknowledges a now-playing update.
    static let nowPlayingDidUpdate = Notification.Name("nowPlayingDidUpdate")
}
