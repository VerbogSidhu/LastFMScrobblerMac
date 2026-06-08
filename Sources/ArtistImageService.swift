import Foundation

/// Fetches real artist images from Deezer API as a fallback when Last.fm
/// only has placeholder images (the generic grey silhouette).
/// URL mappings are persisted to disk so Deezer isn't hit on every launch.
class ArtistImageService {
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
    func isPlaceholder(_ url: String?) -> Bool {
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
            let (data, _) = try await session.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["data"] as? [[String: Any]],
                  let first = results.first,
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
    
    /// Batch-fetch artist images. Returns a dictionary of artist name -> image URL.
    func fetchArtistImages(for artistNames: [String]) async -> [String: String] {
        var results: [String: String] = [:]
        
        // Fetch in parallel (but capped to avoid rate limiting)
        await withTaskGroup(of: (String, String?).self) { group in
            for name in artistNames {
                group.addTask { [self] in
                    let image = await self.fetchArtistImage(for: name)
                    return (name, image)
                }
            }
            
            for await (name, image) in group {
                if let image = image {
                    results[name] = image
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
        try? data.write(to: cacheFile, options: .atomic)
    }
}
