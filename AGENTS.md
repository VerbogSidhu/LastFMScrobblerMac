# AGENTS.md

> Complete reference manual and instructions for AI agents and engineers working on **LastFMSwift**.

---

## 1. Project Overview

**LastFMSwift** is a native macOS 13+ (Ventura or later) application built in pure SwiftUI and AppKit. It performs lightweight, automatic scrobbling for tracks playing in Apple Music, displays user listening history and top charts, manages offline queues, and computes local analytics.

- **No Electron, no web wrappers**: 100% native SwiftUI, Apple `Charts`, and system materials.
- **Username**: `verbog` on Last.fm.
- **Bundle Identifier**: `com.verbog.lastfm`.

---

## 2. Build, Run & Deployment Instructions

### Critical Compiler Requirement
On this system, the default command-line tools SDK (`MacOSX27.0.sdk`) has known incompatibilities with SwiftUI macro plugins (`SwiftUIMacros` not found for `@State`). **Always specify the MacOSX26.5 SDK**:

```bash
# Build binary
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build

# Copy binary to workspace app bundle
cp .build/debug/LastFM LastFM.app/Contents/MacOS/LastFM

# Copy binary to system /Applications
cp .build/debug/LastFM /Applications/LastFM.app/Contents/MacOS/LastFM

# Gracefully reload the running instance
osascript -e 'quit app "LastFM"'; sleep 1; open /Applications/LastFM.app
```

---

## 3. Modular Codebase Architecture

All source code lives under `Sources/` and is strictly partitioned into domain-specific modules:

```
Sources/
├── App/                         # Application lifecycle & entry points
│   ├── LastFMApp.swift          # @main App entry point & MenuBarExtra definition
│   ├── AppState.swift           # @MainActor ObservableObject coordinating global state
│   ├── SidebarTab.swift         # Sidebar navigation enum
│   ├── Constants.swift          # API endpoints, default usernames, constants
│   └── Notifications.swift      # Centralized Notification.Name definitions
│
├── Core/                        # Hardware, OS integration & background logic
│   ├── MusicDetector.swift      # AppleScript bridge to Apple Music (detect, play/pause, next/prev)
│   ├── ScrobbleMonitor.swift    # Background state machine, polling loop, threshold calculation
│   ├── OfflineScrobbleQueue.swift # JSON disk persistence for offline scrobbles
│   └── DiskImageCache.swift     # Local filesystem caching for network artwork
│
├── Models/                      # Data structures & serialization
│   ├── DomainModels.swift       # Clean app models (RecentTrack, TopArtist, TopAlbum, StatsPeriod)
│   ├── LastFMResponses.swift    # Codable DTOs matching raw Last.fm JSON responses
│   ├── ScrobbleStats.swift      # Local scrobble event persistence & timeframe filtering
│   └── ListeningReport.swift    # Aggregate report generation logic & data models
│
├── Services/                    # Networking & API integrations
│   ├── LastFMService.swift      # Read-only public API client (profile, recent, top lists)
│   ├── ScrobbleService.swift    # Authenticated API client (MD5 signed: scrobble, love, session)
│   └── ArtistImageService.swift # Scrapes & caches high-res artist photos from Last.fm
│
└── UI/                          # User interface presentation layer
    ├── DesignSystem/            # Shared visual primitives & design tokens
    │   ├── DSTokens.swift       # DS.Colors (accent palettes), DS.Fonts, DS.Spacing, DS.Radius
    │   ├── DSComponents.swift   # Card, Buttons, SectionHeader, StatusDot, MediaImage, extensions
    │   ├── DSStateViews.swift   # EmptyState, ErrorBanner, SkeletonCard
    │   ├── SkeletonViews.swift  # Shimmer loading placeholders (rows, cards)
    │   ├── PlayingAnimation.swift # Animated equalizer wave bars
    │   └── CachedAsyncImage.swift # Async image loader with disk/memory cache
    │
    ├── Components/              # Reusable entity cards & rows
    │   ├── TrackRow.swift       # Track item with hover actions (Love, Last.fm, Copy) & context menu
    │   ├── ArtistCard.swift     # Artist grid card with hover elevation & context menu
    │   ├── AlbumCard.swift      # Album grid card with hover elevation & context menu
    │   └── ScrobblerStatusCard.swift # Live scrobble status card & debug log toggle
    │
    ├── Views/                   # Primary screen views
    │   ├── ContentView.swift    # Main window split view layout & title header
    │   ├── SidebarView.swift    # Sidebar navigation with icons & status
    │   ├── NowPlayingHeroView.swift # Floating hero card with scrubber, volume slider, ambient glow & playback controls
    │   ├── EntityInspectorSheet.swift # In-app artist/album deep metadata inspector (bio, tracklist, tags)
    │   ├── ManualScrobbleSheet.swift # Backdated manual scrobble submission modal
    │   ├── ShareCardView.swift  # High-res social share card generator (ImageRenderer)
    │   ├── RecentTracksView.swift # Recent listening history list
    │   ├── TopArtistsView.swift # Top artists grid with time period pills
    │   ├── TopAlbumsView.swift  # Top albums grid with time period pills
    │   ├── StatsView.swift      # Native Apple Charts: hover scrub, streak, milestones, time distribution
    │   ├── ReportsView.swift    # Listening reports & period breakdowns
    │   ├── MenuBarView.swift    # Menu bar extra popover view with live scrobble countdown
    │   └── SetupWizardView.swift # Initial Last.fm authentication & onboarding modal
    │
    └── Settings/                # Preference panes
        ├── SettingsContainer.swift
        ├── AccountSettingsView.swift
        ├── AppearanceSettingsView.swift # Accent color, Dock presentation mode & menubar toggles
        ├── ScrobblerSettingsView.swift
        ├── AdvancedSettingsView.swift
        └── AboutSettingsView.swift
```

---

## 4. Scrobbler Engine & Rules

### Last.fm Scrobble Rules
1. **Duration**: Tracks under 30 seconds are **never** scrobbled.
2. **Threshold**: A track is eligible for scrobbling after playing for **50% of its duration OR 4 minutes (240s)**, whichever is reached first.
3. **Uniqueness**: Exactly **one** scrobble per play.
4. **Timestamp**: Unix timestamp recorded at the moment track started playing.

### Real-Time Skip Detection
- In addition to standard polling (every 5 seconds via `pollTimer`), `ScrobbleMonitor` listens to the macOS distributed notification:
  `DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), ...)`
- When clicking `nextTrack()` / `previousTrack()`, `ScrobbleMonitor` schedules immediate polls at `+0.25s` and `+0.75s`.
- When `trackID != currentTrackID`:
  1. Publishes new track metadata to `@Published` properties immediately on `@MainActor`.
  2. Posts `.trackDidChange` which triggers an immediate background fetch of recent tracks.
  3. Sends `updateNowPlaying` to Last.fm.
  4. Upon success, posts `.nowPlayingDidUpdate` which triggers a secondary sync after 1.2s to ensure the new track appears as Now Playing.

### Offline Resilience
- If network requests fail during a scrobble, `OfflineScrobbleQueue` stores the scrobble locally in `~/Library/Application Support/LastFM/offline_scrobbles.json`.
- When connectivity resumes or during regular polling, `flushOfflineQueue()` re-attempts submissions chronologically.

---

## 5. Concurrency & Thread-Safety Rules

1. **AppleScript Execution**: AppleScript commands (`NSAppleScript` / `osascript`) block the calling thread. They **must always** be dispatched on `pollQueue` (`DispatchQueue(label: "com.lastfmscrobbler.poll", qos: .utility)`), **never on the main thread**.
2. **State Locking**: `ScrobbleMonitor` uses an `NSLock` (`withStateLock`) to synchronize reads and writes to variables accessed concurrently by `pollQueue` and background tasks.
3. **UI Updates**: All mutations to `@Published` properties and `NotificationCenter` posts intended for UI observation must occur on `DispatchQueue.main` or `@MainActor`.
4. **Swift 6 Compatibility**: Avoid capturing mutable variables across concurrent boundaries. Always capture local immutable copies (`let newName = info?.name`) before entering escaping closures.

---

## 6. UI & Design System Guidelines

- **Design System Tokens**: Access all design tokens through `DS` (`DS.Colors`, `DS.Fonts`, `DS.Spacing`, `DS.Radius`, `DS.Layout`).
- **Dynamic Accent Color**: Always use `appState.accentColor` for user-customizable accent highlights.
- **macOS HIG Adherence**:
  - Use system materials (`.ultraThinMaterial`, `.regularMaterial`) instead of heavy opaque color fills.
  - Media controls (Play/Pause, Prev, Next) use clean, neutral circular backgrounds (`Color.white.opacity(0.12)`) without strong color washes.
  - Hover states should use subtle opacity changes and soft border highlights (`Color.white.opacity(0.08)`).
  - Context menus should be native macOS `.contextMenu` blocks attached to rows and cards.

---

## 7. Useful Diagnostic Commands

```bash
# Check if LastFM process is running
pgrep -fl LastFM

# Check what Apple Music is currently playing
osascript -e 'tell application "Music" to get {name, artist, album, player state} of current track'

# Inspect offline queued scrobbles
cat "$HOME/Library/Application Support/LastFM/offline_scrobbles.json"

# Read app diagnostic crash logs (if any)
ls -lt ~/Library/Logs/DiagnosticReports | grep -i LastFM
```

---

## 8. Advanced UI/UX Features

### 1. macOS System Polish
- **MenuBarExtra Circular Progress Ring**: Custom vector circle with animated `trim(from: 0, to: scrobbleProgress)` in the menubar label.
- **Dock vs. Menu Bar Only**: Preference setting toggling `NSApp.setActivationPolicy(.regular)` vs `.accessory` on the fly.
- **Global Keyboard Accelerators**:
  - `⌘L`: Love / unlove track
  - `⌘N`: Open Manual Scrobbler sheet
  - `⌘R`: Refresh scrobbles and active tab
  - `⌘1`–`⌘5`: Instant tab navigation

### 2. Hero Player Polish
- **Interactive Scrubber Seeking**: Draggable & tappable playback scrubber triggering AppleScript player position seek (`monitor.seekTo(position:)`).
- **Volume Popover**: Native slider bound to Apple Music sound volume (`monitor.setVolume(val)`).
- **Ambient Artwork Backdrop Glow**: Blurred dynamic artwork layer (`.blur(radius: 50).opacity(0.32)`) expanding behind the hero card.

### 3. Interactive Charts & Milestones
- **Apple Charts Hover Scrubbing**: `DragGesture` scrub overlay updating a vertical `RuleMark` and pill badge with exact day and scrobble count.
- **Listening Streak**: Tracks consecutive active listening days backwards from today.
- **Milestone Countdown**: Visual progress bar to next 500/1,000 scrobbles with estimated arrival based on current weekly pace.

### 4. Drill-Downs & In-App Sheets
- **In-App Entity Inspector**: Slide-over sheet for artists and albums with biographical text, tracklists, tags, playcounts, and Apple Music deep-links.
- **Manual Scrobbler**: Modal sheet with live validation and backdated timestamp selection.
- **Unscrobble Support**: Context menu option to remove play locally and open Last.fm library edit page.

### 5. Social Sharing & Haptics
- **ImageRenderer Share Cards**: Renders 1200x1200 Retina artwork cards with one-click copy to clipboard or PNG file export.
- **Native Haptics**: `NSHapticFeedbackManager` triggers on love/unlove, seeking, manual scrobbling, and card copying.

---

## 9. Agent Skills Catalog (`.agents/skills/`)

- `macos-system-integration`: Guide to MenuBarExtra progress rings, activation policies, haptic performer, ImageRenderer, and keyboard shortcuts.
- `domain-entity-inspector`: Guide to `InspectorEntity` sheet pattern, Last.fm metadata caching, manual scrobbler workflow, and delete policy.
- `scrobble-engine`: Background state machine, polling thresholds, and offline resilience.
- `macos-ui-hig`: Design tokens, materials, and typography guidelines.
- `lastfm-workflow`: Build, test, and release procedures.
