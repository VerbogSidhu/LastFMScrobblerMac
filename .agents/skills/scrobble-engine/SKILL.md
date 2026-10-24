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
1. Track duration must exceed 30 seconds. Threshold defaults to `min(duration / 2, 240)`; saved `half` and `fourMinutes` policies may wait longer.
2. `PlaybackSession` credits only observed position advancement bounded by monotonic elapsed time. Never initialize listened time from player position or accumulate sleep/pause gaps.
3. Persist the eligible event before submission. Preserve its per-play submitted flag across monitoring pauses and timer reconfiguration. Only actual end-to-start playback transitions establish a repeat; elapsed duration alone is not evidence.
4. `ScrobbleMonitor` is main-actor isolated. Every AppleScript action goes through `pollQueue`; generation checks reject stale polls, artwork, now-playing and love results.
5. Use full metadata identity (database ID, title, artist, album), never database ID or title alone. Artwork extraction verifies metadata atomically; remote fallback rejects unmatched/ambiguous releases.
6. Accepted, ignored, pending, and failed outcomes remain distinct. Queue removals are by event ID, account-scoped, and atomic. Keychain migration must preserve legacy values on write failure.

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
- Keep monitor state on `@MainActor`; cross to `pollQueue` only for detector operations and return immutable samples.
- Always push UI updates (`currentPosition`, `isPlaying`, `scrobbleThresholdSeconds`) onto `DispatchQueue.main` or `@MainActor`.
