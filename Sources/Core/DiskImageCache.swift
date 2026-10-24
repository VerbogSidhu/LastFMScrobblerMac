import Foundation
import CryptoKit
import ImageIO

/// Validated image data, with serialized filesystem and lookup access.
final class DiskImageCache {
    static let shared = DiskImageCache()
    private let cacheDir: URL
    private let session: URLSession
    private let lock = NSLock()
    private var generation = 0
    private let maxCacheBytes = 50 * 1024 * 1024

    init(directory: URL? = nil, session: URLSession = .shared) {
        self.session = session
        cacheDir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LastFM/ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    private func fileURL(for source: String) -> URL {
        let key = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent("\(key).img")
    }

    private func isImage(_ data: Data) -> Bool {
        guard let image = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(image) > 0 else { return false }
        return CGImageSourceCreateImageAtIndex(image, 0, nil) != nil
    }

    func cachedURL(for source: String) -> URL? {
        synchronized {
            let file = fileURL(for: source)
            guard let data = try? Data(contentsOf: file) else { return nil }
            guard isImage(data) else {
                try? FileManager.default.removeItem(at: file)
                return nil
            }
            return file
        }
    }

    func fetchAndCache(from source: String) async -> URL? {
        if let cached = cachedURL(for: source) { return cached }
        guard let url = URL(string: source), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        let requestGeneration = synchronized { generation }
        do {
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
                  data.count <= 15 * 1024 * 1024, isImage(data) else { return nil }
            return synchronized {
                guard generation == requestGeneration else { return nil }
                let file = fileURL(for: source)
                do {
                    try data.write(to: file, options: .atomic)
                    trimCache()
                    return FileManager.default.fileExists(atPath: file.path) ? file : nil
                } catch { return nil }
            }
        } catch { return nil }
    }

    func prefetch(_ sources: [String]) async -> [String: URL] {
        await withTaskGroup(of: (String, URL?).self) { group in
            var results: [String: URL] = [:]
            var iterator = Array(Set(sources)).makeIterator()
            for _ in 0..<5 {
                if let source = iterator.next() { group.addTask { (source, await self.fetchAndCache(from: source)) } }
            }
            while let (source, file) = await group.next() {
                if let file { results[source] = file }
                if let next = iterator.next() { group.addTask { (next, await self.fetchAndCache(from: next)) } }
            }
            return results
        }
    }

    func clearCache() {
        synchronized {
            generation += 1
            try? FileManager.default.removeItem(at: cacheDir)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }

    func cacheSize() -> Int { synchronized { files().reduce(0) { $0 + $1.size } } }

    private func files() -> [(url: URL, size: Int, created: Date)] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]) else { return nil }
            return (url, values.fileSize ?? 0, values.creationDate ?? .distantPast)
        }
    }

    private func trimCache() {
        let entries = files().sorted { $0.created < $1.created }
        var bytes = entries.reduce(0) { $0 + $1.size }
        guard bytes > maxCacheBytes else { return }
        for entry in entries where bytes > maxCacheBytes * 8 / 10 {
            if (try? FileManager.default.removeItem(at: entry.url)) != nil { bytes -= entry.size }
        }
    }
}
