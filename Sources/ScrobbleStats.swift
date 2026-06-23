import Foundation

/// Lightweight scrobble event record for stats tracking.
struct ScrobbleRecord: Codable, Identifiable {
    let id: UUID
    let track: String
    let artist: String
    let album: String
    let timestamp: Date
    
    init(track: String, artist: String, album: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.track = track
        self.artist = artist
        self.album = album
        self.timestamp = timestamp
    }
}

/// Manages scrobble statistics — records events, queries by time period,
/// and persists to a local JSON file. Designed to be lightweight:
/// loads on demand, writes incrementally, caps stored records at 10,000.
class ScrobbleStatsManager: ObservableObject {
    @Published var todayCount: Int = 0
    @Published var weekCount: Int = 0
    @Published var monthCount: Int = 0
    @Published var totalCount: Int = 0
    
    private var records: [ScrobbleRecord] = []
    private let maxRecords = 10_000
    private let persistenceURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LastFM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.persistenceURL = dir.appendingPathComponent("scrobble_stats.json")
        load()
    }
    
    // MARK: - Recording
    
    func recordScrobble(track: String, artist: String, album: String) {
        let record = ScrobbleRecord(track: track, artist: artist, album: album)
        records.append(record)
        
        // Trim if over cap (keep newest)
        if records.count > maxRecords {
            records = Array(records.suffix(maxRecords))
        }
        
        save()
        refreshCounts()
    }
    
    // MARK: - Querying
    
    func records(in period: TimePeriod) -> [ScrobbleRecord] {
        let cutoff = period.startDate
        return records.filter { $0.timestamp >= cutoff }
    }
    
    func topArtists(in period: TimePeriod, limit: Int = 10) -> [(name: String, count: Int)] {
        let periodRecords = records(in: period)
        var counts: [String: Int] = [:]
        for r in periodRecords {
            counts[r.artist, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map { (name: $0.key, count: $0.value) }
    }
    
    func topAlbums(in period: TimePeriod, limit: Int = 10) -> [(name: String, artist: String, count: Int)] {
        let periodRecords = records(in: period)
        var counts: [String: (artist: String, count: Int)] = [:]
        for r in periodRecords {
            let key = "\(r.album)|||\(r.artist)"
            if let existing = counts[key] {
                counts[key] = (existing.artist, existing.count + 1)
            } else {
                counts[key] = (r.artist, 1)
            }
        }
        return counts.sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { (name: String($0.key.split(separator: "|||").first!), artist: $0.value.artist, count: $0.value.count) }
    }
    
    func topTracks(in period: TimePeriod, limit: Int = 10) -> [(name: String, artist: String, count: Int)] {
        let periodRecords = records(in: period)
        var counts: [String: (artist: String, count: Int)] = [:]
        for r in periodRecords {
            let key = "\(r.track)|||\(r.artist)"
            if let existing = counts[key] {
                counts[key] = (existing.artist, existing.count + 1)
            } else {
                counts[key] = (r.artist, 1)
            }
        }
        return counts.sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { (name: String($0.key.split(separator: "|||").first!), artist: $0.value.artist, count: $0.value.count) }
    }
    
    func scrobblesPerDay(in period: TimePeriod) -> [(date: Date, count: Int)] {
        let periodRecords = records(in: period)
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var counts: [Date: Int] = [:]
        for r in periodRecords {
            let day = calendar.startOfDay(for: r.timestamp)
            counts[day, default: 0] += 1
        }
        return counts.sorted { $0.key < $1.key }.map { (date: $0.key, count: $0.value) }
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }
        records = (try? JSONDecoder().decode([ScrobbleRecord].self, from: data)) ?? []
        refreshCounts()
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }
    
    private func refreshCounts() {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        let startOfMonth = calendar.date(byAdding: .month, value: -1, to: startOfDay)!
        
        todayCount = records.filter { $0.timestamp >= startOfDay }.count
        weekCount = records.filter { $0.timestamp >= startOfWeek }.count
        monthCount = records.filter { $0.timestamp >= startOfMonth }.count
        totalCount = records.count
    }
}

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "3 Months"
    case year = "This Year"
    case allTime = "All Time"
    
    var id: String { rawValue }
    
    /// Maps to Last.fm API period parameter values.
    var lastfmPeriod: String {
        switch self {
        case .day: return "1day"
        case .week: return "7day"
        case .month: return "1month"
        case .threeMonths: return "3month"
        case .year: return "12month"
        case .allTime: return "overall"
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        switch self {
        case .day:
            return startOfDay
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: startOfDay)!
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: startOfDay)!
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: startOfDay)!
        case .allTime:
            return Date.distantPast
        }
    }
}
