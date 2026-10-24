import Foundation

struct QueuedScrobble: Codable, Identifiable {
    let id: UUID
    let track: String
    let artist: String
    let album: String
    let duration: Int
    let timestamp: Int
    /// Older queue files lack this field. They are bound once during migration,
    /// before the user can switch accounts; never silently sent to a new account.
    var account: String?

    init(track: String, artist: String, album: String, duration: Int, timestamp: Int, account: String? = nil) {
        id = UUID()
        self.track = track; self.artist = artist; self.album = album
        self.duration = duration; self.timestamp = timestamp; self.account = account
    }
}

/// Lock-protected, atomic persistence. Flushers remove individual IDs, so an
/// event appended during an outstanding request cannot be overwritten by a snapshot.
final class OfflineScrobbleQueue {
    private var queue: [QueuedScrobble] = []
    private let lock = NSLock()
    private let fileURL: URL
    private(set) var loadError: Error?

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = fileURL ?? support.appendingPathComponent("LastFM/offline_scrobbles.json")
        load()
    }

    var count: Int { lock.withLock { queue.count } }
    var items: [QueuedScrobble] { lock.withLock { queue.sorted { $0.timestamp < $1.timestamp } } }

    @discardableResult
    func enqueue(track: String, artist: String, album: String, duration: Int, timestamp: Int, account: String? = nil) throws -> QueuedScrobble {
        try lock.withLock {
            if let loadError { throw loadError }
            let item = QueuedScrobble(track: track, artist: artist, album: album, duration: duration, timestamp: timestamp, account: account)
            var updated = queue
            updated.append(item)
            try persist(updated)
            queue = updated
            return item
        }
    }

    func remove(id: UUID) throws {
        try lock.withLock {
            if let loadError { throw loadError }
            let updated = queue.filter { $0.id != id }
            try persist(updated)
            queue = updated
        }
    }

    func bindLegacyItems(to account: String) throws {
        guard !account.isEmpty else { return }
        try lock.withLock {
            if let loadError { throw loadError }
            let updated = queue.map { item -> QueuedScrobble in
                var bound = item
                if bound.account == nil { bound.account = account }
                return bound
            }
            try persist(updated)
            queue = updated
        }
    }

    func rebind(from previous: String, to account: String) throws {
        try lock.withLock {
            if let loadError { throw loadError }
            let updated = queue.map { item -> QueuedScrobble in
                var result = item
                if result.account == previous { result.account = account }
                return result
            }
            try persist(updated)
            queue = updated
        }
    }

    func load() {
        lock.withLock {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            do {
                queue = try JSONDecoder().decode([QueuedScrobble].self, from: Data(contentsOf: fileURL))
                loadError = nil
            } catch { loadError = error }
        }
    }

    private func persist(_ items: [QueuedScrobble]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
    }
}
