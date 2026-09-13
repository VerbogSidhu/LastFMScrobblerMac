import Foundation
import AppKit

/// Detects what's currently playing in Apple Music via AppleScript.
struct MusicTrackInfo {
    let name: String
    let artist: String
    let album: String
    let duration: Int      // seconds
    let playerPosition: Int // seconds
    let playerState: String // "playing", "paused", "stopped"
    let databaseID: Int
}

class MusicDetector {
    
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
                set trackId to database ID of t
                set trackName to name of t
                set artistName to artist of t
                set albumName to album of t
                set trackDuration to duration of t
                set pos to player position
                
                return (trackId as string) & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & (trackDuration as string) & "|||" & (pos as string) & "|||" & playerState
            on error
                return "ERROR"
            end try
        end tell
        """)
    
    /// Check if Apple Music is running and get current track info.
    func getCurrentTrack() -> MusicTrackInfo? {
        // Fast-path: If Apple Music isn't open, exit immediately with 0% CPU
        guard isMusicRunning() else { return nil }
        guard let scriptObject = currentTrackScript else { return nil }
        
        var error: NSDictionary?
        let result = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            NSLog("[MusicDetector] AppleScript error: %@", "\(error)")
            return nil
        }
        
        guard let stringValue = result.stringValue else { return nil }
        
        if stringValue == "STOPPED" || stringValue == "ERROR" {
            return nil
        }
        
        let components = stringValue.components(separatedBy: "|||")
        guard components.count >= 7 else { return nil }
        
        // Duration from AppleScript is a float (e.g. "151.593994140625")
        // Int("151.593...") fails — must parse as Double first
        return MusicTrackInfo(
            name: components[1],
            artist: components[2],
            album: components[3],
            duration: Int(Double(components[4]) ?? 0),
            playerPosition: Int(Double(components[5]) ?? 0),
            playerState: components[6],
            databaseID: Int(components[0]) ?? 0
        )
    }

    /// Extract album artwork from Apple Music for the current track and write to disk.
    func getArtwork(databaseID: Int) -> String? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("LastFM/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = dir.appendingPathComponent("art_\(databaseID).jpg").path

        if FileManager.default.fileExists(atPath: filePath) {
            return "file://" + filePath
        }

        let scriptText = """
            set artFile to POSIX file "\(filePath)"
            tell application "Music"
                try
                    if player state is not stopped then
                        set t to current track
                        set arts to artworks of t
                        if (count of arts) > 0 then
                            set rawData to raw data of (item 1 of arts)
                        else
                            return "NONE"
                        end if
                    else
                        return "NONE"
                    end if
                on error
                    return "NONE"
                end try
            end tell

            try
                set outFile to open for access artFile with write permission
                set eof outFile to 0
                write rawData to outFile
                close access outFile
                return "\(filePath)"
            on error
                try
                    close access artFile
                end try
                return "NONE"
            end try
            """

        var error: NSDictionary?
        let script = NSAppleScript(source: scriptText)
        let result = script?.executeAndReturnError(&error)
        if let res = result?.stringValue, res != "NONE" && !res.isEmpty {
            return "file://" + res
        }
        return nil
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

