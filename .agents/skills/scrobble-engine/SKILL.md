---
name: scrobble-engine
description: Modify, troubleshoot, or extend the Apple Music scrobbler engine, state machine, thresholds, polling loops, and offline queue.
---

# Scrobbler Engine Skill

Use this skill when modifying or debugging the audio detection, state transitions, threshold calculations, or offline syncing logic in `Sources/Core/`.

## Key Files
- `Sources/Core/ScrobbleMonitor.swift`: Central orchestrator, polling timer, state variables, telemetry publisher.
- `Sources/Core/MusicDetector.swift`: AppleScript bridge queries (`getCurrentTrack()`, `playPause()`, `nextTrack()`, `previousTrack()`).
- `Sources/Core/OfflineScrobbleQueue.swift`: Thread-safe persistence of pending scrobbles to `~/Library/Application Support/LastFM/offline_scrobbles.json`.
- `Sources/Services/ScrobbleService.swift`: API caller generating MD5 request signatures and submitting to Last.fm.

## Scrobbler State Rules
1. **Minimum Duration**: `track.duration > 30` seconds. Tracks shorter than 30s are ignored.
2. **Scrobble Threshold**: `min(Double(duration) / 2.0, 240.0)`. Scrobbles at 50% or 4 minutes, whichever comes first.
3. **One Scrobble Per Play**: `hasScrobbled` flag set to `true` upon dispatch; reset on loop or track change.
4. **Playback Loop Detection**:
   - Primary: If `lastPlayerPosition / duration > 0.6` and current `playerPosition / duration < 0.3`.
   - Fallback: If `accumulatedPlayTime >= duration` and `hasScrobbled == true`.
5. **Pause Deductions**:
   - `accumulatedPlayTime` only accumulates when `wasPlaying == true`. It never accumulates while paused.

## Skip Detection Pattern
- Always register distributed notifications:
  ```swift
  DistributedNotificationCenter.default().addObserver(
      forName: NSNotification.Name("com.apple.Music.playerInfo"),
      object: nil,
      queue: .main
  ) { [weak self] _ in
      self?.poll()
  }
  ```
- In UI track skip methods (`nextTrack()`, `previousTrack()`), schedule rapid multi-stage polls (+0.25s, +0.75s) to detect Apple Music's state transition instantly.
- When `trackID != currentTrackID`:
  1. Immediately update `@Published` UI properties on `DispatchQueue.main`.
  2. Post `NotificationCenter.default.post(name: .trackDidChange, object: nil)` to trigger an immediate background refresh of recent tracks.
  3. Call `sendNowPlaying(...)`.
  4. On successful response, post `.nowPlayingDidUpdate` to trigger a follow-up sync once Last.fm indexes the new song.

## Threading Rules
- **Never run AppleScript on the main thread.** Always dispatch on `pollQueue`.
- Guard all shared mutable variables in `ScrobbleMonitor` with `withStateLock { ... }`.
- Always push UI updates (`currentPosition`, `isPlaying`, `scrobbleThresholdSeconds`) onto `DispatchQueue.main` or `@MainActor`.
