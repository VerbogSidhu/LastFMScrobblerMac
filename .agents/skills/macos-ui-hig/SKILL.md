---
name: macos-ui-hig
description: Design and implement native macOS 13+ SwiftUI views adhering to this repository's design system tokens (DS), materials, Apple Charts, and Apple HIG.
---

# macOS UI & HIG Design Skill

Use this skill when building or styling UI components, screens, or menus in **LastFMSwift**.

## Design Foundations
All UI styling must adhere to the Design System tokens in `Sources/UI/DesignSystem/DSTokens.swift` and Apple Human Interface Guidelines:

- **Materials & Vibrancy**: Use `.ultraThinMaterial` or `.regularMaterial` for backdrops and cards. Never use pure flat opaque colors for panels.
- **Color Palettes**:
  - Primary text: `DS.Colors.textPrimary`
  - Secondary text: `DS.Colors.textSecondary`
  - Subtle/muted text: `DS.Colors.textMuted` / `DS.Colors.textTertiary`
  - Borders: `Color.white.opacity(0.08)` or `DS.Colors.cardBorder`
  - Accent Color: Always reference `appState.accentColor` or `DS.Colors.accent` to respect user customization.
- **Media Controls**:
  - Keep buttons clean, neutral, and native. Avoid colored washes on playback buttons.
  - Standard circular buttons: `Color.white.opacity(0.12)` background with `DS.Colors.textPrimary` icon.
  - Hover states: Subtle background opacity increase (e.g. `0.06` -> `0.12`).

## Context Menus
All content cards and rows should provide a `.contextMenu` containing native macOS actions:
```swift
.contextMenu {
    Button {
        // Open on Last.fm
    } label: {
        Label("View on Last.fm", systemImage: "arrow.up.right.square")
    }
    
    Button {
        // Copy information to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    } label: {
        Label("Copy Info", systemImage: "doc.on.doc")
    }
}
```

## Apple Charts Standards
When creating charts in `StatsView` or `ReportsView`:
- Use `import Charts`
- Prefer `AreaMark` + `LineMark` for continuous listening trends over time.
- Prefer `BarMark` with `cornerRadius: 4` for discrete categorical or hourly distributions.
- Keep axis marks subtle using `DS.Colors.textMuted`.
