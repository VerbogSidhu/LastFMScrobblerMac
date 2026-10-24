import Foundation

/// A complete report from one fixed UTC query interval. Preview limits never affect totals.
struct ListeningReport: Identifiable {
    let id = UUID()
    let period: TimePeriod
    let generatedAt: Date
    let totalScrobbles: Int
    let uniqueArtists: Int
    let uniqueAlbums: Int
    let uniqueTracks: Int
    let topArtists: [(name: String, count: Int)]
    let topAlbums: [(name: String, artist: String, count: Int)]
    let topTracks: [(name: String, artist: String, count: Int)]
    /// Chart buckets are hourly today, daily in short periods, monthly/yearly in long periods.
    let scrobblesPerDay: [(date: Date, count: Int)]
    let chartUnit: Calendar.Component
    let range: DateInterval
    let peakDay: (date: Date, count: Int)?
    let averagePerDay: Double

    static func generate(username: String, service: LastFMService, period: TimePeriod,
                         now: Date = Date(), calendar: Calendar = .current) async throws -> ListeningReport {
        let range = period.dateRange(endingAt: now, calendar: calendar)
        let tracks = try await service.getTracks(username: username, from: range.start, to: range.end)
        try Task.checkCancellation()
        return try build(tracks: tracks, period: period, range: range, calendar: calendar)
    }

    private struct MediaKey: Hashable { let name: String; let artist: String }

    static func build(tracks: [RecentTrack], period: TimePeriod, range: DateInterval,
                      calendar: Calendar = .current) throws -> ListeningReport {
        var artists: [String: Int] = [:]
        var albums: [MediaKey: Int] = [:]
        var titles: [MediaKey: Int] = [:]
        var daily: [Date: Int] = [:]
        var timestamps: [Date] = []
        for (index, track) in tracks.enumerated() {
            if index.isMultiple(of: 200) { try Task.checkCancellation() }
            guard !track.nowPlaying, let uts = track.date, let value = TimeInterval(uts) else { continue }
            let date = Date(timeIntervalSince1970: value)
            guard date >= range.start && date <= range.end else { continue }
            timestamps.append(date)
            artists[track.artist, default: 0] += 1
            if !track.album.isEmpty { albums[MediaKey(name: track.album, artist: track.artist), default: 0] += 1 }
            titles[MediaKey(name: track.name, artist: track.artist), default: 0] += 1
            daily[calendar.startOfDay(for: date), default: 0] += 1
        }
        let start = period == .allTime ? calendar.startOfDay(for: timestamps.min() ?? range.end) : range.start
        let chartRange = DateInterval(start: start, end: range.end)
        let dayCount = max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: range.end)).day ?? 0) + 1)
        let unit: Calendar.Component
        if period == .day { unit = .hour }
        else if dayCount <= 366 { unit = .day }
        else {
            let months = (calendar.dateComponents([.month], from: calendar.dateInterval(of: .month, for: start)!.start, to: calendar.dateInterval(of: .month, for: range.end)!.start).month ?? 0) + 1
            unit = months <= 366 ? .month : .year
        }
        var buckets: [Date: Int] = [:]
        for date in timestamps {
            let bucket = calendar.dateInterval(of: unit, for: date)!.start
            buckets[bucket, default: 0] += 1
        }
        var filled: [(date: Date, count: Int)] = []
        var date = calendar.dateInterval(of: unit, for: start)!.start
        let end = calendar.dateInterval(of: unit, for: range.end)!.start
        while date <= end {
            try Task.checkCancellation()
            filled.append((date: date, count: buckets[date] ?? 0))
            guard let next = calendar.date(byAdding: unit, value: 1, to: date), next > date else { break }
            date = next
        }
        let rankedArtists = artists.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        func ranked(_ counts: [MediaKey: Int]) -> [(name: String, artist: String, count: Int)] {
            counts.sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return (lhs.key.name, lhs.key.artist) < (rhs.key.name, rhs.key.artist)
            }.prefix(10).map { (name: $0.key.name, artist: $0.key.artist, count: $0.value) }
        }
        let peak = daily.sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }.first
        return ListeningReport(period: period, generatedAt: range.end, totalScrobbles: timestamps.count,
            uniqueArtists: artists.count, uniqueAlbums: albums.count, uniqueTracks: titles.count,
            topArtists: rankedArtists.prefix(10).map { (name: $0.key, count: $0.value) },
            topAlbums: ranked(albums), topTracks: ranked(titles), scrobblesPerDay: filled,
            chartUnit: unit, range: chartRange, peakDay: peak.map { (date: $0.key, count: $0.value) },
            averagePerDay: Double(timestamps.count) / Double(dayCount))
    }

    /// Format the report as a shareable text string.
    func formattedText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var text = "📊 Listening Report — \(period.rawValue)\n"
        text += "\(formatter.string(from: range.start)) – \(formatter.string(from: range.end))\n"
        text += "Generated \(formatter.string(from: generatedAt)) · Average includes today.\n\n"
        text += "🔢 \(totalScrobbles) scrobbles · \(uniqueArtists) artists · \(uniqueAlbums) albums · \(uniqueTracks) tracks\n"
        text += "📈 Avg \(String(format: "%.1f", averagePerDay))/day"
        
        if let peak = peakDay, peak.count > 0 {
            let dayStr = formatter.string(from: peak.date)
            text += " · Peak: \(peak.count) on \(dayStr)"
        }
        
        text += "\n\n"
        
        if !topArtists.isEmpty {
            text += "🎵 Top Artists\n"
            for (i, artist) in topArtists.prefix(5).enumerated() {
                text += "  \(i + 1). \(artist.name) (\(artist.count))\n"
            }
            text += "\n"
        }
        
        if !topAlbums.isEmpty {
            text += "💿 Top Albums\n"
            for (i, album) in topAlbums.prefix(5).enumerated() {
                text += "  \(i + 1). \(album.name) — \(album.artist) (\(album.count))\n"
            }
            text += "\n"
        }
        
        if !topTracks.isEmpty {
            text += "🎶 Top Tracks\n"
            for (i, track) in topTracks.prefix(5).enumerated() {
                text += "  \(i + 1). \(track.name) — \(track.artist) (\(track.count))\n"
            }
        }
        
        return text
    }
}
