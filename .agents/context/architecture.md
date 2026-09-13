# Architecture Reference

This document maps the architectural layers, data flows, and component responsibilities in **LastFMSwift**.

---

## High-Level Architecture Diagram

```
+-------------------------------------------------------------+
|                         Apple Music                         |
|                 (Native macOS Media Player)                 |
+-------------------------------------------------------------+
        │                                             ▲
        │ Player State & Track Info                   │ Play/Pause, Next, Prev
        ▼                                             │ (AppleScript)
+─────────────────────────────────────────────────────────────+
|                    Sources/Core/MusicDetector               |
|            (AppleScript runner via NSAppleScript)           |
+─────────────────────────────────────────────────────────────+
                                ▲
                                │ Async polling & state queries
                                ▼
+─────────────────────────────────────────────────────────────+
|                   Sources/Core/ScrobbleMonitor              |
|        - Background poll queue (com.lastfmscrobbler.poll)   |
|        - Scrobble state machine (threshold, loop, pause)    |
|        - Real-time skip detection (distributed notifications)|
+─────────────────────────────────────────────────────────────+
         │                              │               ▲
         │ Offline scrobbles            │ Telemetry     │ Flush
         ▼                              ▼               │
+──────────────────────+       +──────────────────+     │
| OfflineScrobbleQueue |       | AppState         |     │
| (JSON Disk Store)    |       | (@MainActor)     |     │
+──────────────────────+       +──────────────────+     │
         │                              │               │
         │ Re-attempt submissions       │ State updates │
         ▼                              ▼               │
+─────────────────────────────────────────────────────────────+
|                  Sources/Services/ScrobbleService           |
|                (Authenticated API, MD5 signatures)          |
+─────────────────────────────────────────────────────────────+
                                │
                                ▼
+─────────────────────────────────────────────────────────────+
|                      Last.fm Web API                        |
|            (ws.audioscrobbler.com: scrobble, love)          |
+─────────────────────────────────────────────────────────────+
```

---

## Data Flow & Responsibilities

### 1. Audio Playback Detection & Telemetry
1. `ScrobbleMonitor` maintains a 5-second recurring timer on `RunLoop.main` (common modes).
2. It registers with `DistributedNotificationCenter` for `com.apple.Music.playerInfo` so track switches trigger an instantaneous poll.
3. Every poll executes off the main thread on `pollQueue`.
4. `MusicDetector` runs AppleScript queries asking Apple Music for the current track name, artist, album, duration, player position, database ID, and state.
5. If the track changed:
   - Publishes new metadata immediately to `@Published` properties on `MainActor`.
   - Posts `Notification.Name.trackDidChange` to trigger a UI refresh of recent tracks.
   - Dispatches `updateNowPlaying` to Last.fm.

### 2. Scrobbling & Persistence
1. As the track plays, `ScrobbleMonitor` tracks `accumulatedPlayTime`.
2. When `accumulatedPlayTime >= scrobbleThreshold` (`min(duration / 2, 240s)`):
   - Invokes `ScrobbleService.scrobble(...)`.
   - Records the scrobble event in `ScrobbleStatsManager` for local analytics.
   - If network fails, queues the scrobble in `OfflineScrobbleQueue`.
   - Sets `hasScrobbled = true` to prevent duplicate scrobbles for the same playback session.
3. When network connectivity resumes, `flushOfflineQueue()` submits pending scrobbles in chronological order.

### 3. UI Presentation Layer
- `AppState` acts as the single source of truth for all SwiftUI views.
- Views are partitioned into:
  - `UI/DesignSystem/`: Reusable styling primitives, tokens, and animations (`DSTokens`, `DSComponents`).
  - `UI/Components/`: Entity cards (`ArtistCard`, `AlbumCard`, `TrackRow`, `ScrobblerStatusCard`).
  - `UI/Views/`: Top-level tab views (`RecentTracksView`, `TopArtistsView`, `TopAlbumsView`, `StatsView`, `ReportsView`), hero player (`NowPlayingHeroView`), menu bar popover (`MenuBarView`), and modal sheets (`EntityInspectorSheet`, `ManualScrobbleSheet`, `ShareCardView`).
  - `UI/Settings/`: User configuration panes (`AppearanceSettingsView` with Dock toggle, `AccountSettingsView`, etc.).
