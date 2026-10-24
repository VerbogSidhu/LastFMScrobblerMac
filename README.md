# LastFM Scrobbler for Mac

ai slop readme below
i used mimo v2.5 for like 99% of it and got gemini 3.8 flash to improve the ui a bunch

A native SwiftUI Last.fm dashboard and scrobbler for macOS. No Electron, no bloat — just a lightweight app that shows your Last.fm stats and scrobbles Apple Music tracks automatically.

## Features

- **Dashboard** — Recent tracks, top artists, top albums with artwork
- **Auto-scrobbler** — Detects Apple Music playback and scrobbles to Last.fm automatically
- **Now Playing** — Shows what's currently playing with a live progress indicator
- **Artist Images** — Fetches and caches artist photos from Last.fm
- **Minimal UI** — Clean, modern SwiftUI design that stays out of your way

## Requirements

- macOS 13+ (Ventura or later)
- Apple Music app
- A [Last.fm account](https://www.last.fm/join)

## Setup

### 1. Get a Last.fm API Key

Register an app at [last.fm/api/account/create](https://www.last.fm/api/account/create) to get your API key and secret. You need the secret for scrobbling.

### 2. Build

```bash
cd LastFMSwift
./scripts/build-app.sh
```

Or open in Xcode and hit Build.

### 3. Configure

1. Open the app
2. Click the gear icon in the sidebar
3. Enter your Last.fm API key and API secret (the authorized account supplies your username)
4. Click "Connect to Last.fm" and authorize in the browser window
5. The scrobbler starts automatically once connected

### 4. Install

Run `./scripts/build-app.sh`, then copy `.build/LastFM.app` to `/Applications/`. This creates the app bundle with its Automation permission description; `swift build` alone produces only an executable.

On first playback detection, allow Last.fm to control Apple Music. If permission was denied, open System Settings → Privacy & Security → Automation and enable Apple Music for Last.fm. Credentials are migrated to macOS Keychain on launch. Pending offline plays remain on disk and are retried only for their authenticated account.

## How Scrobbling Works

The app polls Apple Music every 5 seconds via AppleScript. When it detects a track has been playing for at least half its duration (or 4 minutes, whichever is less), it scrobbles to Last.fm. Tracks under 30 seconds are skipped.

## Project Structure

```
Sources/
├── LastFMApp.swift          — App entry point
├── ContentView.swift        — Main UI (sidebar + detail views)
├── LastFMService.swift      — Last.fm API client (read-only)
├── ScrobbleService.swift    — Last.fm scrobble/auth API
├── ScrobbleMonitor.swift    — Polling engine + scrobble logic
├── MusicDetector.swift      — AppleScript bridge to Apple Music
├── Models.swift             — Data models
└── ArtistImageService.swift — Image fetching + caching
```

## License

MIT

## Regression checks

Run `./scripts/test.sh` for the Swift Testing suite. It uses isolated fixtures and never submits real scrobbles or clears personal history. On Command Line Tools installations it supplies the bundled Testing framework path automatically.
