import Foundation
import CryptoKit

/// On-disk image cache. Stores downloaded image data in
/// ~/Library/Application Support/LastFM/ImageCache/ keyed by SHA-256 of the URL.
/// Provides file:// URLs for use with AsyncImage.
class DiskImageCache {
    static let shared = DiskImageCache()
    
    private let cacheDir: URL
    private let fileManager = FileManager.default
    private var inMemoryLookup: [String: URL] = [:]  // url string -> file URL
    
    /// Max cache size in bytes (50 MB). Evicts oldest files when exceeded.
    private let maxCacheBytes: Int = 50 * 1024 * 1024
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("LastFM/ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // Build in-memory lookup from existing files
        if let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey]) {
            for file in files where file.pathExtension == "img" {
                let key = file.deletingPathExtension().lastPathComponent
                inMemoryLookup[key] = file
            }
        }
    }
    
    // MARK: - Public API
    
    /// Returns a file:// URL if the image is already cached, nil otherwise.
    func cachedURL(for urlString: String) -> URL? {
        let key = hashKey(urlString)
        if let existing = inMemoryLookup[key], fileManager.fileExists(atPath: existing.path) {
            return existing
        }
        return nil
    }
    
    /// Returns cached URL if available, otherwise downloads, caches, and returns the file URL.
    func fetchAndCache(from urlString: String) async -> URL? {
        // Check cache first
        if let cached = cachedURL(for: urlString) {
            return cached
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !data.isEmpty else { return nil }
            
            let key = hashKey(urlString)
            let fileURL = cacheDir.appendingPathComponent("\(key).img")
            try data.write(to: fileURL)
            
            await MainActor.run {
                inMemoryLookup[key] = fileURL
            }
            
            // Evict old files if cache is too large
            trimCacheIfNeeded()
            
            return fileURL
        } catch {
            return nil
        }
    }
    
    /// Prefetch a batch of image URLs in parallel. Returns a dict of url -> file URL for successful fetches.
    func prefetch(_ urlStrings: [String]) async -> [String: URL] {
        var results: [String: URL] = [:]
        
        // Only fetch URLs that aren't already cached
        let toFetch = urlStrings.filter { cachedURL(for: $0) == nil }
        
        await withTaskGroup(of: (String, URL?).self) { group in
            for urlString in toFetch {
                group.addTask { [self] in
                    let fileURL = await self.fetchAndCache(from: urlString)
                    return (urlString, fileURL)
                }
            }
            
            for await (urlString, fileURL) in group {
                if let fileURL {
                    results[urlString] = fileURL
                }
            }
        }
        
        // Include already-cached URLs
        for urlString in urlStrings {
            if let cached = cachedURL(for: urlString) {
                results[urlString] = cached
            }
        }
        
        return results
    }
    
    /// Remove all cached images.
    func clearCache() {
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        inMemoryLookup.removeAll()
    }
    
    /// Current cache size in bytes.
    func cacheSize() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { sum, file in
            sum + ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
    
    // MARK: - Private
    
    private func hashKey(_ urlString: String) -> String {
        let digest = SHA256.hash(data: Data(urlString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func trimCacheIfNeeded() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return }
        
        let totalSize = files.reduce(0) { sum, file in
            sum + ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        
        guard totalSize > maxCacheBytes else { return }
        
        // Sort by creation date (oldest first) and remove until under limit
        let sorted = files.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return aDate < bDate
        }
        
        var runningSize = totalSize
        for file in sorted {
            guard runningSize > maxCacheBytes * 8 / 10 else { break }  // trim to 80%
            let fileSize = ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try? fileManager.removeItem(at: file)
            runningSize -= fileSize
            
            let key = file.deletingPathExtension().lastPathComponent
            inMemoryLookup.removeValue(forKey: key)
        }
    }
}
