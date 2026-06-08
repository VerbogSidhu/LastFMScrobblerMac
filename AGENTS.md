# AGENTS.md

## Project
Last.fm SwiftUI scrobbler for macOS — auto-scrobbles Apple Music tracks, displays profile data, tracks local stats.

## Build & Run
```bash
cd /Users/verbog/LastFMSwift
swift build                                          # debug build
cp .build/debug/LastFM /Applications/LastFM.app/Contents/MacOS/LastFM
pkill -f "LastFM.app/Contents/MacOS/LastFM"; sleep 1
open /Applications/LastFM.app
```

## Architecture
- **SwiftUI** (macOS 13+), dark mode, `MenuBarExtra` for menu bar popover
- **AppState** (`ObservableObject`) holds all state — scrobble monitor, stats manager, service clients
- **ScrobbleMonitor** — polls Apple Music via AppleScript on a background `DispatchQueue`, scrobbles when track reaches ≥half duration or 4 min
- **ScrobbleService** — authenticated Last.fm API (MD5-signed POST requests)
- **LastFMService** — read-only Last.fm API (public key, no auth)
- **ScrobbleStatsManager** — local JSON persistence of scrobble events, queried by `TimePeriod`
- **ListeningReport** — generates summaries from stats (top lists, daily chart, peak day)

## Key Files
| File | Purpose |
|------|---------|
| `Sources/LastFMApp.swift` | App entry, `AppState`, `SidebarTab` enum |
| `Sources/ContentView.swift` | Main UI — sidebar, track rows, artist/album grids, settings |
| `Sources/ScrobbleMonitor.swift` | Background polling, scrobble logic, state machine |
| `Sources/ScrobbleService.swift` | Auth flow, scrobble/love/unlove API calls |
| `Sources/ScrobbleStats.swift` | Local scrobble event persistence and queries |
| `Sources/MenuBarView.swift` | Menu bar popover (now-playing, love, counts) |
| `Sources/ReportsView.swift` | Listening report UI |
| `Sources/StatsView.swift` | Quick stats dashboard |

## API Keys
- **Read-only key** (`b5940532a8c9dfde75381c3060972a65`) — in `LastFMService.swift`, safe in source
- **Registered key** — stored in UserDefaults (`lastfm_api_key`), NOT in source
- **API secret** — stored in UserDefaults (`lastfm_api_secret`), NOT in source
- **Session key** — stored in UserDefaults (`lastfm_session_key`), obtained via OAuth

## Pitfalls
- `environmentObject` on `MenuBarExtra` requires macOS 14+ — use `@ObservedObject` with direct reference instead
- Last.fm read-only key is public and safe to commit; the scrobble key is user-specific
- AppleScript polling must run off main thread (`DispatchQueue` with `.utility` QoS)
- `@Published` properties should only update on actual state change to avoid SwiftUI layout storms
- Never use `.repeatForever` animation on frequently-updated views — it triggers 60fps redraws
- Timer stacking: always call `stopMonitoring()` before `startMonitoring()` to prevent duplicate timers

## Last.fm Scrobble Rules
- Track plays ≥ half its duration OR 4 minutes (whichever first)
- Tracks under 30 seconds are never scrobbled
- One scrobble per play
- Timestamp = when track started playing

## Username
`verbog` on Last.fm
