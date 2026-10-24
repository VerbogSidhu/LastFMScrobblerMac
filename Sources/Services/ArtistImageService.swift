import Foundation

/// Fetches real artist images from Deezer API as a fallback when Last.fm
/// only has placeholder images (the generic grey silhouette).
/// URL mappings are persisted to disk so Deezer isn't hit on every launch.
/// Uses an actor to prevent concurrent dictionary write crashes.
actor ArtistImageService {
    static let shared = ArtistImageService()
    
    private let session = URLSession.shared
    private var cache: [String: String] = [:]  // artist name -> Deezer image URL
    private let cacheFile: URL
    
    // Last.fm's default placeholder image hash
    private let placeholderHash = "2a96cbd8b46e442fc41c2b86b821562f"
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheFile = appSupport.appendingPathComponent("LastFM/artist_images.json")
        
        // Load persisted mappings
        if let data = try? Data(contentsOf: cacheFile),
           let mapped = try? JSONDecoder().decode([String: String].self, from: data) {
            cache = mapped
        }
    }
    
    /// Check if a URL is the Last.fm placeholder image.
    nonisolated func isPlaceholder(_ url: String?) -> Bool {
        guard let url = url else { return true }
        return url.contains(placeholderHash) || url.isEmpty
    }
    
    /// Fetch a real artist image from Deezer. Returns the XL image URL.
    /// Results are cached in memory and persisted to disk.
    func fetchArtistImage(for artistName: String) async -> String? {
        // Check cache first
        if let cached = cache[artistName] {
            return cached
        }
        
        guard let encoded = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search/artist?q=\(encoded)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["data"] as? [[String: Any]],
                  let first = results.first(where: { ($0["name"] as? String)?.caseInsensitiveCompare(artistName) == .orderedSame }),
                  let pictureXL = first["picture_xl"] as? String,
                  !pictureXL.isEmpty else {
                return nil
            }
            
            cache[artistName] = pictureXL
            persistCache()
            return pictureXL
        } catch {
            print("[ArtistImageService] Failed to fetch image for \(artistName): \(error)")
            return nil
        }
    }

    /// Album and artist must both match. An ambiguous song-only lookup is not artwork evidence.
    func fetchAlbumCover(artist: String, album: String, track: String) async -> String? {
        let parts = [artist, album, track]
        let cacheKey = "cover-v3:" + ((try? JSONEncoder().encode(parts)).flatMap { String(data: $0, encoding: .utf8) } ?? "")
        if let cached = cache[cacheKey] { return cached }
        var components = URLComponents(string: "https://api.deezer.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "\(artist) \(album.isEmpty ? track : album)")]
        guard let url = components.url else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rows = json["data"] as? [[String: Any]],
                  let cover = Self.matchingCover(in: rows, artist: artist, album: album, track: track) else { return nil }
            try Task.checkCancellation()
            cache[cacheKey] = cover
            persistCache()
            return cover
        } catch { return nil }
    }

    nonisolated static func matchingCover(in rows: [[String: Any]], artist: String, album: String, track: String) -> String? {
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        guard !artist.isEmpty else { return nil }
        let matches = rows.compactMap { row -> String? in
            guard let candidateArtist = (row["artist"] as? [String: Any])?["name"] as? String,
                  normalized(candidateArtist) == normalized(artist),
                  let candidate = row["album"] as? [String: Any] else { return nil }
            if !album.isEmpty {
                guard let title = candidate["title"] as? String, normalized(title) == normalized(album) else { return nil }
            } else {
                guard let title = row["title"] as? String, normalized(title) == normalized(track) else { return nil }
            }
            let cover = (candidate["cover_xl"] as? String) ?? (candidate["cover_big"] as? String)
            guard let cover, !cover.isEmpty, URL(string: cover)?.scheme == "https" else { return nil }
            return cover
        }
        let distinct = Set(matches)
        return distinct.count == 1 ? distinct.first : nil
    }

    /// Batch-fetch artist images. Returns a dictionary of artist name -> image URL.
    /// Fetches in parallel for speed, with a concurrency limit to avoid overwhelming Deezer.
    func fetchArtistImages(for artistNames: [String]) async -> [String: String] {
        // Filter out already-cached names
        let uncached = artistNames.filter { cache[$0] == nil }
        
        // Fetch uncached images in parallel (max 5 concurrent)
        var results: [String: String] = [:]
        
        // First, add cached results
        for name in artistNames {
            if let cached = cache[name] {
                results[name] = cached
            }
        }
        
        // Then fetch uncached in parallel with bounded concurrency
        await withTaskGroup(of: (String, String?).self) { group in
            var activeTasks = 0
            var index = 0
            
            for name in uncached {
                // Limit concurrent requests to 5
                if activeTasks >= 5 {
                    if let (fetchedName, fetchedURL) = await group.next() {
                        if let url = fetchedURL {
                            results[fetchedName] = url
                        }
                        activeTasks -= 1
                    }
                }
                
                group.addTask { [self] in
                    let image = await self.fetchArtistImage(for: name)
                    return (name, image)
                }
                activeTasks += 1
                index += 1
            }
            
            // Wait for remaining tasks
            for await (fetchedName, fetchedURL) in group {
                if let url = fetchedURL {
                    results[fetchedName] = url
                }
            }
        }
        
        return results
    }
    
    /// Clear persisted cache.
    func clearCache() {
        cache.removeAll()
        try? FileManager.default.removeItem(at: cacheFile)
    }
    
    // MARK: - Private
    
    private func persistCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheFile, options: .atomic)
    }
}
