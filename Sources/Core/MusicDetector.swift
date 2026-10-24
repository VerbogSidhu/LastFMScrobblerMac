import Foundation
import AppKit
import CryptoKit

/// Detects what's currently playing in Apple Music via AppleScript.
struct MusicTrackInfo: Sendable {
    let name: String
    let artist: String
    let album: String
    let duration: Int      // seconds
    let playerPosition: Int // seconds
    let playerState: String // "playing", "paused", "stopped"
    let databaseID: Int
}

// The monitor confines every detector operation to its serial poll queue.
final class MusicDetector: @unchecked Sendable {
    private(set) var lastError: String?

    
    /// Zero-cost in-memory kernel check if Apple Music process is currently alive.
    /// Bypasses all Apple Events and AppleScript engine overhead.
    func isMusicRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }
    
    // NSAppleScript(source:) compiles the script — reuse the compiled instance
    // instead of recompiling on every poll (called every 5s while monitoring).
    // Note: We intentionally DO NOT query "System Events" here since isMusicRunning()
    // already verified the process exists, avoiding IPC to the System Events daemon.
    private let currentTrackScript = NSAppleScript(source: """
        tell application "Music"
            try
                set playerState to player state as string
                if playerState is "stopped" then
                    return "STOPPED"
                end if
                
                set t to current track
                set trackId to 0
                try
                    set trackId to database ID of t
                end try
                set trackName to name of t
                set artistName to artist of t
                set albumName to album of t
                set trackDuration to duration of t
                set pos to player position
                
                return {trackId, trackName, artistName, albumName, trackDuration, pos, playerState}
            on error errorMessage number errorNumber
                return {"ERROR", errorNumber, errorMessage}
            end try
        end tell
        """)
    
    /// Called only on the monitor's serial AppleScript queue.
    func getCurrentTrack() -> MusicTrackInfo? {
        lastError = nil
        guard isMusicRunning() else { return nil }
        guard let scriptObject = currentTrackScript else {
            lastError = "The Apple Music detection script could not be loaded."
            return nil
        }
        var error: NSDictionary?
        let result = scriptObject.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            lastError = code == -1743
                ? "Allow Last.fm to control Music in System Settings → Privacy & Security → Automation."
                : "Apple Music could not be read. Try reopening Music."
            return nil
        }
        if result.atIndex(1)?.stringValue == "ERROR" {
            let code = result.atIndex(2)?.int32Value ?? 0
            lastError = code == -1743
                ? "Allow Last.fm to control Music in System Settings → Privacy & Security → Automation."
                : "Apple Music could not provide track details."
            return nil
        }
        guard result.numberOfItems == 7 else { return nil }
        return MusicTrackInfo(
            name: result.atIndex(2)?.stringValue ?? "",
            artist: result.atIndex(3)?.stringValue ?? "",
            album: result.atIndex(4)?.stringValue ?? "",
            duration: Int(result.atIndex(5)?.doubleValue ?? 0),
            playerPosition: Int(result.atIndex(6)?.doubleValue ?? 0),
            playerState: result.atIndex(7)?.stringValue ?? "stopped",
            databaseID: Int(result.atIndex(1)?.int32Value ?? 0)
        )
    }

    /// The current track is verified in the same Apple Event that extracts its
    /// bytes. Cache identity includes metadata; old ID-only cache files are ignored.
    func getArtwork(for track: MusicTrackInfo) -> String? {
        guard isMusicRunning(), let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("LastFM/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let identity = [String(track.databaseID), track.name, track.artist, track.album]
        let data = (try? JSONEncoder().encode(identity)) ?? Data()
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let file = dir.appendingPathComponent("art-v2-\(hash).jpg")
        if FileManager.default.fileExists(atPath: file.path), NSImage(contentsOf: file) != nil { return file.absoluteString }
        let temporary = dir.appendingPathComponent("\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let scriptText = """
            tell application "Music"
                try
                    if player state is stopped then return "NONE"
                    set t to current track
                    if (name of t as string) is not "\(scriptEscape(track.name))" then return "NONE"
                    if (artist of t as string) is not "\(scriptEscape(track.artist))" then return "NONE"
                    if (album of t as string) is not "\(scriptEscape(track.album))" then return "NONE"
                    set arts to artworks of t
                    if (count of arts) is 0 then return "NONE"
                    set rawData to raw data of (item 1 of arts)
                on error
                    return "NONE"
                end try
            end tell
            set artFile to POSIX file "\(scriptEscape(temporary.path))"
            try
                set outFile to open for access artFile with write permission
                set eof outFile to 0
                write rawData to outFile
                close access outFile
                return "OK"
            on error
                try
                    close access artFile
                end try
                return "NONE"
            end try
            """
        var error: NSDictionary?
        guard NSAppleScript(source: scriptText)?.executeAndReturnError(&error).stringValue == "OK",
              error == nil, NSImage(contentsOf: temporary) != nil else { return nil }
        do {
            try? FileManager.default.removeItem(at: file)
            try FileManager.default.moveItem(at: temporary, to: file)
            return file.absoluteString
        } catch { return nil }
    }

    private func scriptEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    /// Check if Apple Music is installed on this Mac using native Cocoa URL lookup.
    func isAppleMusicInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") != nil
    }
    
    // MARK: - Playback Controls
    
    private let playPauseScript = NSAppleScript(source: """
        tell application "Music"
            playpause
        end tell
        """)
    
    private let nextTrackScript = NSAppleScript(source: """
        tell application "Music"
            next track
        end tell
        """)
    
    private let previousTrackScript = NSAppleScript(source: """
        tell application "Music"
            previous track
        end tell
        """)
        
    private let getVolumeScript = NSAppleScript(source: """
        tell application "Music"
            return sound volume
        end tell
        """)
    
    func playPause() {
        guard isMusicRunning() else { return }
        var error: NSDictionary?
        playPauseScript?.executeAndReturnError(&error)
        if let error = error {
            NSLog("[MusicDetector] playPause error: %@", "\(error)")
        }
    }
    
    func nextTrack() {
        guard isMusicRunning() else { return }
        var error: NSDictionary?
        nextTrackScript?.executeAndReturnError(&error)
        if let error = error {
            NSLog("[MusicDetector] nextTrack error: %@", "\(error)")
        }
    }
    
    func previousTrack() {
        guard isMusicRunning() else { return }
        var error: NSDictionary?
        previousTrackScript?.executeAndReturnError(&error)
        if let error = error {
            NSLog("[MusicDetector] previousTrack error: %@", "\(error)")
        }
    }
    
    func setPlayerPosition(_ seconds: Double) {
        guard isMusicRunning() else { return }
        let s = max(0, Int(seconds))
        let script = NSAppleScript(source: """
            tell application "Music"
                set player position to \(s)
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error = error {
            NSLog("[MusicDetector] setPlayerPosition error: %@", "\(error)")
        }
    }
    
    func getSoundVolume() -> Int {
        guard isMusicRunning() else { return 100 }
        var error: NSDictionary?
        let result = getVolumeScript?.executeAndReturnError(&error)
        if let val = result?.int32Value {
            return Int(val)
        }
        return 100
    }
    
    func setSoundVolume(_ volume: Int) {
        guard isMusicRunning() else { return }
        let clamped = max(0, min(100, volume))
        let script = NSAppleScript(source: """
            tell application "Music"
                set sound volume to \(clamped)
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error = error {
            NSLog("[MusicDetector] setSoundVolume error: %@", "\(error)")
        }
    }
}

