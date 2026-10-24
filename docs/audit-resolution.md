# Audit repair record — October 24, 2026

This repair builds on upstream revision `2d60b96`, preserving its newer dashboard, player, inspector, sharing, and manual-scrobble features. It addresses the 28 findings from the earlier audit plus the reported wrong current-track cover. Changes were pushed incrementally on `codex/audit-repairs`.

| Audit | Repair |
|---|---|
| F01 | Eligible events are persisted before submission; transient failures remain queued with bounded backoff. Queue changes remove IDs rather than overwrite concurrent additions. |
| F02 | Scrobbles require a positively accepted response; HTTP failures, malformed responses, and ignored plays remain distinct. |
| F03 | Signed clients resolve current saved credentials; Love/Unlove inspect API error bodies, and player actions expose failures. |
| F04 | Counts use timestamp-bounded recent-history metadata, not artist-list totals. |
| F05 | Today is derived from actual scrobbles since local midnight; no unsupported `1day` top-list request. |
| F06 | Report totals and unique counts include complete paginated history, independent of top-list previews. |
| F07 | Fixed history-page caps are removed; incomplete/failed requests throw rather than manufacture missing zero days. |
| F08 | All Time starts its chart at the earliest observed play and aggregates long ranges to at most 366 buckets. |
| F09 | Report failures show an error and retry action instead of a copyable zero report. |
| F10 | Initial position does not count as observed listening; the estimated start timestamp includes the detected offset. |
| F11 | Listening uses observed position advancement bounded by monotonic elapsed time, excluding long gaps. |
| F12 | Per-play submission state survives monitor pause/resume and timer reconfiguration. |
| F13 | Monitoring/track generations and task cancellation reject obsolete polls, artwork, and now-playing work. |
| F14 | Fresh/reset users reach the setup wizard; existing connections migrate without forced reauthorization. |
| F15 | Authorization retains the returned account identity. Existing sessions verify their actual owner; pending events are account scoped. |
| F16 | Child monitor changes are forwarded to dependent app views, coalesced to avoid redundant layout updates. |
| F17 | Unsupported Custom threshold is removed; supported policies persist and affect eligibility. Menu count preference is used by the actual menu label. |
| F18 | Poll settings reschedule the timer while preserving current-play state. |
| F19 | Clearing goes through the statistics manager and atomically clears its stored and in-memory records. |
| F20 | Export atomically replaces the destination and shows completion/errors. |
| F21 | Manual refresh signals independent Stats/Reports views to reload. |
| F22 | Manual and post-submission reads invalidate/bypass stale recent-track caches. |
| F23 | Calendar-labelled ranges use calendar boundaries, display actual dates, and calculate averages using the represented days; Today uses hourly buckets. |
| F24 | Ranked rows are enumerated independently of duplicate names, keeping distinct rows and consecutive ranks. |
| F25 | Paused playback sends no new now-playing updates and has a separate visible state. |
| F26 | Secrets/sessions use Keychain; migration retains legacy values until successful verified writes. |
| F27 | Dashboard uses a stable SwiftUI window identifier and the menu opens it through `openWindow`. |
| F28 | Weekly progress bars normalize against the largest displayed playcount. |

## Artwork and menu

- Local artwork files now use full metadata hashes instead of database ID alone. Extraction verifies current title, artist, and album within the Apple Event that reads the artwork.
- Fallback cover searches require matching artist and album; ambiguous song-only releases return no cover. Old speculative cache keys are not reused.
- Async image loads clear stale results and reject late/cancelled completions. Download caching validates HTTP status and actual image data; cache filesystem access is serialized.
- Missing artwork is retried at a bounded interval for the still-current identity.
- The popover now uses a rounded material surface, rounded player/count groups, circular playback controls, softer action rows, account identity, and visible pending/error states.
- Text contrast, chart accessibility, and reduced-motion behavior were improved. Playback controls remain native.

## Verification

- `./scripts/test.sh`: **37 tests passed across 7 suites**. The suite uses controlled API fixtures and disposable credential/statistics storage.
- `./scripts/build-app.sh`: application builds, produces a signed bundle and ZIP, and verifies the staged signature. The script selects the compatible SDK on this development Mac.
- Live checks: installed app launches, retained the authenticated account, displays the matching current album art, generates Today with hourly buckets and This Month with unique counts above 50, and exposes only supported scrobble settings.
- A normal ongoing playback was marked accepted by the updated monitor. No manual test scrobbles were submitted.
- Checked preference-key presence without printing secret values: plaintext API-secret and session entries are absent after migration.
- Native accessibility access to the system status-bar host timed out, so the popover styling was compiled but its opened system window was not visually inspected through that tool.
- Fresh authorization/revocation, destructive clearing of personal history, sleep/wake, and every supported macOS version were not deliberately exercised on the user's account. Their deterministic logic paths are covered by regression tests where available; this is not a claim of exhaustive hardware/runtime testing.

## Working with the repair

Run `./scripts/test.sh` and `./scripts/build-app.sh`. The default macOS 27 Command Line Tools SDK lacks the SwiftUI macro plugin on this machine; the scripts select macOS 26.5 when installed. Swift Testing's developer framework requires a newer test runtime than the application's macOS 13 deployment floor.

The original installed app was backed up before replacement. Existing listening history and unrelated untracked files were preserved.
