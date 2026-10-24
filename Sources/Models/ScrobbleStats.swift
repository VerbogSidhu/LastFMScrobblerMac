import Foundation
import Combine

struct ScrobbleRecord: Codable, Identifiable {
    let id: UUID
    let track: String
    let artist: String
    let album: String
    let timestamp: Date

    init(track: String, artist: String, album: String, timestamp: Date = Date()) {
        id = UUID()
        self.track = track
        self.artist = artist
        self.album = album
        self.timestamp = timestamp
    }
}

/// Serializes records and disk changes together so clearing cannot resurrect a stale snapshot.
final class ScrobbleStatsManager: ObservableObject {
    @Published private(set) var todayCount = 0
    @Published private(set) var weekCount = 0
    @Published private(set) var monthCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var persistenceError: String?

    private var storedRecords: [ScrobbleRecord] = []
    private var loadFailure: Error?
    private let storageQueue = DispatchQueue(label: "com.verbog.lastfm.statistics")
    private let persistenceURL: URL

    init(persistenceURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.persistenceURL = persistenceURL ?? support.appendingPathComponent("LastFM/scrobble_stats.json")
        storageQueue.sync {
            do {
                if FileManager.default.fileExists(atPath: self.persistenceURL.path) {
                    storedRecords = try JSONDecoder().decode([ScrobbleRecord].self, from: Data(contentsOf: self.persistenceURL))
                }
            } catch {
                loadFailure = error
                publishError(error)
            }
        }
        publishCounts()
    }

    func recordScrobble(track: String, artist: String, album: String, timestamp: Date = Date()) {
        storageQueue.sync {
            guard loadFailure == nil else { publishError(loadFailure); return }
            storedRecords.append(ScrobbleRecord(track: track, artist: artist, album: album, timestamp: timestamp))
            do { try persistLocked(); publishError(nil) }
            catch { publishError(error) }
        }
        publishCounts()
    }

    func clear() throws {
        try storageQueue.sync {
            // Write the empty state first: a failed clear leaves the existing history intact.
            try writeLocked([])
            storedRecords.removeAll()
            loadFailure = nil
            publishError(nil)
        }
        publishCounts()
    }

    func export(to destination: URL) throws {
        try storageQueue.sync {
            let data = try JSONEncoder().encode(storedRecords)
            try data.write(to: destination, options: .atomic)
        }
    }

    func records(in period: TimePeriod) -> [ScrobbleRecord] {
        let range = period.dateRange()
        return storageQueue.sync { storedRecords.filter { $0.timestamp >= range.start && $0.timestamp <= range.end } }
    }

    func topArtists(in period: TimePeriod, limit: Int = 10) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for record in records(in: period) { counts[record.artist, default: 0] += 1 }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit).map { (name: $0.key, count: $0.value) }
    }

    private struct MediaKey: Hashable { let name: String; let artist: String }

    private func topMedia(in period: TimePeriod, limit: Int, album: Bool) -> [(name: String, artist: String, count: Int)] {
        var counts: [MediaKey: Int] = [:]
        for record in records(in: period) {
            let name = album ? record.album : record.track
            if !name.isEmpty { counts[MediaKey(name: name, artist: record.artist), default: 0] += 1 }
        }
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return (lhs.key.name, lhs.key.artist) < (rhs.key.name, rhs.key.artist)
        }.prefix(limit).map { (name: $0.key.name, artist: $0.key.artist, count: $0.value) }
    }

    func topAlbums(in period: TimePeriod, limit: Int = 10) -> [(name: String, artist: String, count: Int)] {
        topMedia(in: period, limit: limit, album: true)
    }

    func topTracks(in period: TimePeriod, limit: Int = 10) -> [(name: String, artist: String, count: Int)] {
        topMedia(in: period, limit: limit, album: false)
    }

    func scrobblesPerDay(in period: TimePeriod) -> [(date: Date, count: Int)] {
        var counts: [Date: Int] = [:]
        for record in records(in: period) { counts[Calendar.current.startOfDay(for: record.timestamp), default: 0] += 1 }
        return counts.sorted { $0.key < $1.key }.map { (date: $0.key, count: $0.value) }
    }

    private func persistLocked() throws { try writeLocked(storedRecords) }

    private func writeLocked(_ records: [ScrobbleRecord]) throws {
        try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: persistenceURL, options: .atomic)
    }

    private func publishError(_ error: Error?) {
        DispatchQueue.main.async { self.persistenceError = error?.localizedDescription }
    }

    private func publishCounts() {
        // Re-read on the main queue, rather than publishing a stale pre-clear snapshot later.
        let update = {
            let records = self.storageQueue.sync { self.storedRecords }
            let now = Date()
            let today = TimePeriod.day.dateRange(endingAt: now)
            let week = TimePeriod.week.dateRange(endingAt: now)
            let month = TimePeriod.month.dateRange(endingAt: now)
            self.todayCount = records.filter { $0.timestamp >= today.start && $0.timestamp <= now }.count
            self.weekCount = records.filter { $0.timestamp >= week.start && $0.timestamp <= now }.count
            self.monthCount = records.filter { $0.timestamp >= month.start && $0.timestamp <= now }.count
            self.totalCount = records.count
        }
        if Thread.isMainThread { update() }
        else { DispatchQueue.main.async(execute: update) }
    }
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "3 Months"
    case year = "This Year"
    case allTime = "All Time"

    var id: String { rawValue }

    /// Calendar-labelled reports never use the top-list API's different rolling periods.
    func dateRange(endingAt now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let start: Date
        switch self {
        case .day: start = calendar.startOfDay(for: now)
        case .week: start = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        case .month: start = calendar.dateInterval(of: .month, for: now)!.start
        case .threeMonths: start = calendar.date(byAdding: .month, value: -3, to: calendar.startOfDay(for: now))!
        case .year: start = calendar.dateInterval(of: .year, for: now)!.start
        case .allTime: start = Date(timeIntervalSince1970: 0)
        }
        return DateInterval(start: min(start, now), end: now)
    }

    var startDate: Date { dateRange().start }
}
