# Scrobbler State Machine Reference

This document describes the lifecycle, state variables, and decision logic implemented in `Sources/Core/ScrobbleMonitor.swift`.

---

## State Lifecycle Diagram

```
                        [ Idle / No Track ]
                                │
                                │ Apple Music starts playing track
                                ▼
                       [ Track Detected ]
                (trackID, name, artist, duration)
                                │
                                ├──────────────────────────────┐
                                │ duration < 30s               │ duration >= 30s
                                ▼                              ▼
                    [ Ignore Scrobble ]             [ Playing & Accumulating ]
                  (status: "<30s (No Scrobble)")    - Send updateNowPlaying
                                                    - Track accumulatedPlayTime
                                                               │
                               ┌───────────────────────────────┤
                               │ Paused                        │ Continues Playing
                               ▼                               ▼
                      [ Pause State ]               [ Accumulated >= Threshold ]
                  (Freeze accumulation)             (50% duration OR 4 minutes)
                               │                               │
                               │ Resumed                       ▼
                               └────────────────────────► [ Dispatch Scrobble ]
                                                               │
                                               ┌───────────────┴───────────────┐
                                               │ Success                       │ Network Failure
                                               ▼                               ▼
                                      [ Mark Scrobbled ]            [ OfflineScrobbleQueue ]
                                      - hasScrobbled = true         - Persist to JSON
                                      - Notify UI                   - Auto-flush on reconnect
                                               │
                                               │ Track finishes or skips
                                               ▼
                                      [ Track Transition ]
                                      - Reset state
                                      - Start new track lifecycle
```

---

## State Variables (`ScrobbleMonitor.swift`)

| Variable | Type | Purpose |
|---|---|---|
| `currentTrackID` | `Int?` | Unique Apple Music persistent database ID. Used to identify when track changes. |
| `trackStartTime` | `Date?` | Wall-clock timestamp when the current track began playing. Used for the scrobble timestamp. |
| `accumulatedPlayTime` | `Double` | Total active playback duration (in seconds) accrued while playing. Excludes paused time. |
| `scrobbleThresholdSeconds` | `Double` | Threshold target: `min(Double(duration) / 2.0, 240.0)`. |
| `hasScrobbled` | `Bool` | Set to `true` once the scrobble has been dispatched. Prevents duplicate scrobbles for the same play. |
| `wasPlaying` | `Bool` | Records whether the player was playing on the previous poll. Ensures pause time is never erroneously added to `accumulatedPlayTime`. |
| `lastPlayerPosition` | `Int` | Previous reported playback position. Used for position-reset loop detection. |
| `nowPlayingRetryCount` | `Int` | Backoff counter for `updateNowPlaying` failures (up to 3 retries: 5s, 10s, 15s). |

---

## Edge Case Handling

### 1. Track Looping / Repeat 1
- **Position Reset Detection**: If `lastPlayerPosition / duration > 0.6` and `currentPlayerPosition / duration < 0.3`, a repeat has occurred. `ScrobbleMonitor` resets `hasScrobbled = false`, zeroes `accumulatedPlayTime`, and sends a fresh `updateNowPlaying`.
- **Duration Fallback**: If `hasScrobbled == true` and `accumulatedPlayTime >= Double(duration)`, the state is reset for the next loop.

### 2. Track Pausing
- While paused, `lastPollTime` is updated on every poll, but `accumulatedPlayTime` is **not** incremented because `wasPlaying == false`.
- Resuming playback sets `wasPlaying = true` and only accumulates elapsed time from that point forward.

### 3. Track Skips
- If skipped before reaching threshold: `hasScrobbled` remains `false`, no scrobble is submitted, and state immediately transitions to the new track.
- If skipped after reaching threshold: The scrobble was already dispatched at the threshold mark. The new track is detected and begins its own independent lifecycle.
