---
name: lastfm-workflow
description: Build, run, test, deploy, and debug the LastFMSwift macOS application with the correct SDK and bundle installation.
---

# LastFMSwift Workflow Skill

Use this skill whenever you need to build, test, package, install, or debug **LastFMSwift**.

## 1. Mandatory Build Command

On this development machine, the default `MacOSX27.0.sdk` lacks Swift macro plugins needed for SwiftUI `@State` declarations. You **MUST** build using the `MacOSX26.5.sdk`:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build
```

Do not run plain `swift build` without `SDKROOT`.

## 2. Deploying & Relaunching Locally

To test changes in the live running app on the user's Mac:

```bash
# 1. Compile
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build

# 2. Update workspace and system application bundles
cp .build/debug/LastFM LastFM.app/Contents/MacOS/LastFM
cp .build/debug/LastFM /Applications/LastFM.app/Contents/MacOS/LastFM

# 3. Quit current process and restart
osascript -e 'quit app "LastFM"'
sleep 1
open /Applications/LastFM.app

# 4. Bring window to front
osascript -e 'tell application "LastFM" to activate'
```

## 3. Verifying Process Health

```bash
# Check if running
pgrep -fl LastFM

# Check memory / CPU usage
ps aux | grep LastFM | grep -v grep
```

## 4. Troubleshooting Apple Music Integration

To test if Apple Music is reachable via AppleScript from the terminal:

```bash
osascript -e 'tell application "Music" to get player state'
osascript -e 'tell application "Music" to get {name, artist, album} of current track'
```

If AppleScript returns an error:
- Check if Apple Music is running: `pgrep -fl Music`
- Launch Apple Music if closed: `open -a Music`
