---
name: domain-entity-inspector
description: Patterns for in-app metadata inspection, modal sheets, Last.fm API drill-downs, manual scrobbling, and deep-linking into Apple Music and web.
---

# Domain Entity Inspector & Drill-Down Skill

This skill explains how in-app entity drill-downs (artists and albums), manual scrobbling, and context menu workflows are implemented in LastFMSwift.

---

## 1. The `InspectorEntity` Pattern

Instead of opening a new window or pushing full navigation views that distract from the main dashboard, LastFMSwift uses an Identifiable enum bound to a sheet modal:

```swift
enum InspectorEntity: Identifiable, Equatable {
    case artist(name: String)
    case album(artist: String, album: String)

    var id: String {
        switch self {
        case .artist(let name): return "artist_\(name)"
        case .album(let artist, let album): return "album_\(artist)_\(album)"
        }
    }
}
```

In `ContentView.swift`:
```swift
.sheet(item: $appState.inspectorEntity) { entity in
    EntityInspectorSheet(entity: entity)
        .environmentObject(appState)
}
```

Any card or row can trigger this sheet instantly:
```swift
Button {
    appState.inspectorEntity = .artist(name: track.artist)
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
} label: {
    Text(track.artist)
}
```

---

## 2. Last.fm Metadata Fetching & In-Memory TTL Caching

Last.fm methods `artist.getInfo` and `album.getInfo` provide rich biographical summaries, tracklists, listener counts, and tags.

To prevent redundant API queries when switching views or re-inspecting:
- Responses are stored in an in-memory TTL dictionary (`cache[cacheKey] = CacheEntry(data, Date())`) with a 60-second expiration window.
- Raw HTML tags returned in Last.fm summaries (like `<a href="...">Read more on Last.fm</a>`) are automatically stripped:
  ```swift
  private func cleanSummary(_ html: String?) -> String {
      guard let html = html, !html.isEmpty else { return "" }
      return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
          .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  ```

---

## 3. Manual Scrobbler Workflow

Manual scrobbles are needed for vinyl records, offline listening sessions, or missed tracks.

### Validation Rules
1. `track` and `artist` must be non-empty after trimming whitespace.
2. `timestamp` cannot be in the future (`Date()...`).
3. Duration defaults to 180 seconds if unprovided.

### Execution Pipeline
```swift
func manualScrobble(track: String, artist: String, album: String, timestamp: Date) async throws {
    guard let service = scrobbleService, let sessionKey = sessionKey else {
        throw ScrobbleError.noSession
    }

    let ts = Int(timestamp.timeIntervalSince1970)
    try await service.scrobble(track: track, artist: artist, album: album, duration: 180, timestamp: ts, sessionKey: sessionKey)

    await MainActor.run {
        self.scrobbleLog.insert(ScrobbleLogEntry(track: track, artist: artist, timestamp: timestamp), at: 0)
        self.statsManager?.recordScrobble(track: track, artist: artist, album: album)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        NotificationCenter.default.post(name: .scrobbleDidComplete, object: nil)
    }
}
```

---

## 4. Unscrobble / Delete Policy

- Last.fm officially deprecated and removed the third-party `track.unscrobble` API method due to abuse prevention.
- The standard UX pattern adopted:
  1. Remove the play immediately from the local in-memory `appState.recentTracks` list so the user sees immediate feedback.
  2. Open the user's Last.fm Library web page (`https://www.last.fm/user/<username>/library`) so they can perform the official 1-click web deletion on Last.fm.
  3. Provide native haptic feedback confirming the action.
