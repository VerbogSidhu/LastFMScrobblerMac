# Last.fm API Reference & Protocol

This document describes the Last.fm Web Services 2.0 integration used by **LastFMSwift**.

---

## 1. Endpoints & Base Configuration

- **Base URL**: `https://ws.audioscrobbler.com/2.0/`
- **Format**: JSON (`format=json`)
- **Read-Only API Key**: `b5940532a8c9dfde75381c3060972a65` (publicly safe, stored in `Constants.swift`)
- **Registered API Key & Secret**: Configured by user in UserDefaults (`lastfm_api_key`, `lastfm_api_secret`).
- **Session Key**: Obtained through web authentication flow, stored in UserDefaults (`lastfm_session_key`).

---

## 2. Authentication Flow (`ScrobbleService.swift`)

1. **Request Token**:
   - `auth.getToken` (GET) -> returns 32-character token.
2. **User Authorization in Browser**:
   - URL: `http://www.last.fm/api/auth/?api_key=<API_KEY>&token=<TOKEN>`
3. **Session Key Exchange**:
   - `auth.getSession` (POST, signed with MD5) -> returns permanent `sessionKey`.

---

## 3. MD5 Signature Generation Algorithm

All authenticated POST requests (scrobble, love, unlove, updateNowPlaying, getSession) require an `api_sig` parameter generated as follows:

1. Collect all query/form parameters **excluding** `format` and `callback`.
2. Sort parameters alphabetically by key name (ASCII sort).
3. Concatenate each `key + value` without separators.
4. Append the application's `api_secret` to the end of the string.
5. Compute the MD5 hash (lowercase hex string).

### Swift Implementation
```swift
func generateSignature(params: [String: String], secret: String) -> String {
    let sorted = params
        .filter { $0.key != "format" && $0.key != "callback" }
        .sorted { $0.key < $1.key }
        .map { "\($0.key)\($0.value)" }
        .joined()
    
    let toHash = sorted + secret
    return Insecure.MD5.hash(data: Data(toHash.utf8))
        .map { String(format: "%02hhx", $0) }
        .joined()
}
```

---

## 4. Primary API Methods

| Method | HTTP | Auth Required | Purpose |
|---|---|---|---|
| `user.getRecentTracks` | GET | No | Fetches recent scrobbles and current Now Playing track |
| `user.getTopArtists` | GET | No | Fetches top artists for period (`7day`, `1month`, `3month`, etc.) |
| `user.getTopAlbums` | GET | No | Fetches top albums for period |
| `user.getTopTracks` | GET | No | Fetches top tracks for period |
| `user.getInfo` | GET | No | Fetches user profile, total playcounts, registration date |
| `track.updateNowPlaying` | POST | Yes (Signed) | Broadcasts current playing track to Last.fm profile |
| `track.scrobble` | POST | Yes (Signed) | Submits confirmed scrobble (track, artist, album, timestamp) |
| `track.love` | POST | Yes (Signed) | Adds track to user's Loved Tracks |
| `track.unlove` | POST | Yes (Signed) | Removes track from user's Loved Tracks |
| `track.getInfo` | GET | No | Checks loved state (`userloved == "1"`) |
| `artist.getInfo` | GET | No | Retrieves detailed artist bio, tags, listener/play counts, and image |
| `album.getInfo` | GET | No | Retrieves album tracklist, release date, wiki summary, and cover art |
| `artist.getTopTracks` | GET | No | Retrieves artist's top tracks ranked by popularity |

---

## 5. Rate Limiting & Error Handling

- Last.fm allows up to **5 requests per second**.
- Background refreshes of recent tracks are triggered only on scrobble or track change events, or every 30 seconds.
- Menu bar statistic counts (`7day`, `1month`, `3month`) are throttled to update at most once every 5 minutes.
