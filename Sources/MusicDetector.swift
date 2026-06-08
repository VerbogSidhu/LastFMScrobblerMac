import Foundation

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
    
    /// Check if Apple Music is running and get current track info.
    func getCurrentTrack() -> MusicTrackInfo? {
        let script = """
        tell application "System Events"
            if not (exists process "Music") then
                return "NOT_RUNNING"
            end if
        end tell
        
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
        """
        
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else { return nil }
        let result = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            NSLog("[MusicDetector] AppleScript error: %@", "\(error)")
            return nil
        }
        
        guard let stringValue = result.stringValue else { return nil }
        
        if stringValue == "NOT_RUNNING" || stringValue == "STOPPED" || stringValue == "ERROR" {
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
    
    /// Check if Apple Music is installed on this Mac.
    func isAppleMusicInstalled() -> Bool {
        let script = """
        tell application "System Events"
            return (exists process "Music")
        end tell
        """
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else { return false }
        let result = scriptObject.executeAndReturnError(&error)
        return result.booleanValue
    }
}
