# LastFM Audit Repairs Implementation Plan

> For agentic workers: implement task by task with failing regression tests, bounded file ownership, and integration review before each push.

**Goal:** Resolve all 28 audit findings and follow-up risks still present on upstream main, fix mismatched current-track artwork, and modernize the menu popover.

**Architecture:** Keep the existing native app and modular structure. Centralize accepted API outcomes and credentials; make playback and asynchronous work generation-aware; derive complete bounded-date analytics independently of preview limits. Use rounded material containers and native controls in the menu.

**Tech Stack:** Swift 5 language mode, SwiftUI/AppKit, Foundation, Security, XCTest; macOS 13 minimum. Build with SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk.

**Spec:** User-approved fixes in the audit at /Users/verbog/Documents/Codex/2026-10-24/sea/outputs/LastFMSwift-Bug-and-UX-Audit.md, plus latest request for artwork correctness, rounded menu styling, and frequent GitHub pushes.

## Global constraints

- Preserve untracked files, existing dashboard/playback/inspector/share features, account identity, and listening history.
- No live authenticated API requests in automated tests. No secret values in logs or commits.
- Correct existing behavior instead of replacing the app with the older audited version.
- Each behavioral repair gets a regression test first. Test unavailable external/OS paths with boundary fakes and report runtime limits explicitly.
- Push independently verified groups to codex/audit-repairs; never force-push or stage unrelated files.

## Task 1: API outcomes and credential identity

Files: Services/ScrobbleService.swift; new Core/CredentialStore.swift; UI/Settings/AccountSettingsView.swift; corresponding XCTest tests.

- [ ] Add failing response tests for ignored, malformed, HTTP-error, and Love API-error responses.
- [ ] Make only accepted submissions succeed; expose ignored and authentication errors distinctly; retain original API error codes.
- [ ] Add Keychain storage with one-way defaults migration and identity from auth.getSession; preserve a compatibility getSession wrapper if needed.
- [ ] Fix account form validation, explicit account save, error feedback, and credential loading.
- [ ] Run targeted tests and compile; provide integration contracts to playback and app-state owners.

## Task 2: Playback accounting, durable queue, and artwork identity

Files: Core/ScrobbleMonitor.swift, MusicDetector.swift, OfflineScrobbleQueue.swift; focused helpers and XCTest tests.

- [ ] Reproduce initial-seek credit, long gaps, resume duplication, stale work, queued-event removal, and equal-title artwork races with deterministic inputs.
- [ ] Preserve per-play identity across pauses; credit observed advancement only; reject stalled/sleep gaps; bound repeat detection to real transitions.
- [ ] Persist events before sending, remove accepted items by ID without discarding concurrent additions, scope pending events to the signed-in account, retry transient failures, and expose pending/error/auth states.
- [ ] Guard polls, delayed updates, and artwork results by track identity plus generation. Cancel obsolete work and suppress paused now-playing updates.
- [ ] Use exact local/remote artist+album artwork matching and invalidate mismatched cache results.
- [ ] Apply polling settings without resetting current-play state; run focused regression tests.

## Task 3: Accurate analytics and local persistence

Files: Services/LastFMService.swift; Models/ListeningReport.swift, ScrobbleStats.swift; Views/ReportsView.swift, StatsView.swift; tests.

- [ ] Add failing tests for artist-vs-play totals, top-50 limits, incomplete history, Today, all-time date bounds, zero-on-error, date semantics, clearing history, and export replacement.
- [ ] Use explicit calendar date ranges and complete paginated recent history; separate bounded chart rendering from data coverage; propagate load errors.
- [ ] Implement cancellation-aware report loads and bounded chart aggregation; use consistent unique identities and averages.
- [ ] Isolate mutable response caches and local records; clear/export through the statistics manager using atomic writes.
- [ ] Ensure Stats/Reports refresh on the app refresh signal; run focused tests.

## Task 4: App integration, modern menu, and cache safety

Files: App/AppState.swift, LastFMApp.swift, Notifications.swift; UI/Views/MenuBarView.swift, ContentView.swift, NowPlayingHeroView.swift, SetupWizardView.swift; UI/Settings/AdvancedSettingsView.swift, AppearanceSettingsView.swift, ScrobblerSettingsView.swift; UI/DesignSystem/CachedAsyncImage.swift, DSComponents.swift, DSTokens.swift, PlayingAnimation.swift; Core/DiskImageCache.swift; Info.plist; README; tests and packaging script.

- [ ] Add regression coverage for image replacement/cancellation, fresh refresh policy, and ranked duplicate names.
- [ ] Forward nested monitor changes, route onboarding/reset correctly, reuse authenticated clients, and reopen dashboard by stable window ID.
- [ ] Make menu counts/toggles effective, remove unsupported Custom threshold promises, expose playback pause/errors, and normalize progress visuals.
- [ ] Replace blocky menu sections with a rounded material surface, album-art header, circular playback controls, rounded count group, and compact rounded action rows. Keep minimum macOS 13 APIs.
- [ ] Bind all cover displays to the monitor's exact current identity; clear stale images before new requests and reject late completions. Validate downloaded image bodies and synchronize image-cache state.
- [ ] Package a reproducible bundle with Automation usage text; run full tests/build, review all audit IDs, and push tested milestones.
- [ ] Back up installed bundle, deploy only a passing build, restart via supported UI, visually inspect artwork/menu/settings/report behavior, and report any untested external interactions.
