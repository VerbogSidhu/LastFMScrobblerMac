---
name: macos-system-integration
description: Expert patterns for native macOS integration in SwiftUI apps, including MenuBarExtra progress rings, activation policy management, NSHapticFeedbackManager, ImageRenderer social share cards, and AppleScript media controls.
---

# macOS System Integration Skill

This skill provides best practices and copy-paste reference patterns for deeply integrating SwiftUI macOS applications into the macOS desktop ecosystem without third-party frameworks.

---

## 1. MenuBarExtra Mini Circular Progress Rings

In macOS 13+, `MenuBarExtra` labels can host reactive vector shapes:

```swift
MenuBarExtra {
    MenuBarPopoverContent(appState: appState)
} label: {
    HStack(spacing: 5) {
        if monitor.isScrobbling, let track = monitor.currentTrackName {
            // High-DPI circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(monitor.scrobbleProgress))
                    .stroke(appState.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 12, height: 12)

            Text(truncate(track, max: 20))
                .font(.system(size: 11))
        } else {
            Image(systemName: "waveform.circle")
                .font(.system(size: 14))
        }
    }
}
.menuBarExtraStyle(.window)
```

**Key Considerations**:
- Keep label height around 12–14pt to fit comfortably in the macOS system menubar.
- Animate `trim` smoothly using `@Published var scrobbleProgress: Double`.

---

## 2. Dock vs. Menu Bar Only Activation Policy

Allowing users to switch between standard Dock window application and menu-bar-only accessory:

```swift
// In App init() or @main:
let showInDock = UserDefaults.standard.object(forKey: "show_in_dock") as? Bool ?? true
NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

// When toggled in Settings:
Toggle("Show in macOS Dock", isOn: $showInDock)
    .onChange(of: showInDock) { newValue in
        UserDefaults.standard.set(newValue, forKey: "show_in_dock")
        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
```

**Activation Policies**:
- `.regular`: Standard macOS app with Dock icon, window menu, and Command-Tab presence.
- `.accessory`: Does not appear in Dock or Cmd-Tab switcher; perfect for passive scrobblers and menu bar utilities.

---

## 3. Native macOS Haptic Feedback

macOS Trackpads (Force Touch) support native haptic clicks via `NSHapticFeedbackManager`:

```swift
import AppKit

// Subtle standard click (e.g. Love track, Copy, Tab switch)
NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

// Precise snap/alignment click (e.g. Scrubber reaching threshold or drag release)
NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

// Destructive or boundary feedback
NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
```

---

## 4. ImageRenderer Social Share Card Generation

Render any SwiftUI view into high-resolution Retina image for clipboard or disk export:

```swift
import SwiftUI
import AppKit

@MainActor
func renderShareCard(content: some View) -> NSImage? {
    let renderer = ImageRenderer(content: content.frame(width: 600, height: 600))
    renderer.scale = 2.0 // Produces 1200x1200 high-DPI output
    return renderer.nsImage
}

// Write to Clipboard:
func copyToClipboard(image: NSImage) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([image])
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
}

// Save to PNG File:
func savePNG(image: NSImage, filename: String) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = filename
    panel.allowedContentTypes = [.png]
    if panel.runModal() == .OK, let url = panel.url {
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    }
}
```

---

## 5. Global Window Keyboard Shortcuts

Define keyboard accelerators that execute actions anywhere in the active window without cluttering the UI:

```swift
.background(
    Group {
        Button("") { appState.scrobbleMonitor.toggleLoveCurrentTrack() }
            .keyboardShortcut("l", modifiers: [.command])

        Button("") { appState.showManualScrobble = true }
            .keyboardShortcut("n", modifiers: [.command])

        Button("") { appState.refreshRecentTracks() }
            .keyboardShortcut("r", modifiers: [.command])

        Button("") { appState.selectedTab = .recent }
            .keyboardShortcut("1", modifiers: [.command])
    }
    .opacity(0)
    .allowsHitTesting(false)
)
```
