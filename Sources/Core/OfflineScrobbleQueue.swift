import Foundation

struct QueuedScrobble: Codable, Identifiable {
    let id: UUID
    let track: String
    let artist: String
    let album: String
    let duration: Int
    let timestamp: Int
    
    init(track: String, artist: String, album: String, duration: Int, timestamp: Int) {
        self.id = UUID()
        self.track = track
        self.artist = artist
        self.album = album
        self.duration = duration
        self.timestamp = timestamp
    }
}

/// Manages disk persistence and synchronization for scrobbles accumulated while offline.
final class OfflineScrobbleQueue {
    private var queue: [QueuedScrobble] = []
    private let lock = NSLock()
    
    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("LastFM", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("offline_scrobbles.json")
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }
    
    var items: [QueuedScrobble] {
        lock.lock()
        defer { lock.unlock() }
        return queue
    }
    
    init() {
        load()
    }
    
    func enqueue(track: String, artist: String, album: String, duration: Int, timestamp: Int) {
        lock.lock()
        let item = QueuedScrobble(track: track, artist: artist, album: album, duration: duration, timestamp: timestamp)
        queue.append(item)
        save()
        lock.unlock()
    }
    
    func setRemaining(_ items: [QueuedScrobble]) {
        lock.lock()
        queue = items
        save()
        lock.unlock()
    }
    
    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([QueuedScrobble].self, from: data) {
            lock.lock()
            queue = list
            lock.unlock()
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: fileURL)
        }
    }
}
