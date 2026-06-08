import Foundation

/// A generated listening report summarizing activity over a time period.
/// Fetches data from the Last.fm API — all tracks within the period are
/// fetched page by page until we pass the period start date.
struct ListeningReport: Identifiable {
    let id = UUID()
    let period: TimePeriod
    let generatedAt: Date
    let totalScrobbles: Int       // scrobbles within this period only
    let uniqueArtists: Int
    let uniqueAlbums: Int
    let uniqueTracks: Int
    let topArtists: [(name: String, count: Int)]
    let topAlbums: [(name: String, artist: String, count: Int)]
    let topTracks: [(name: String, artist: String, count: Int)]
    let scrobblesPerDay: [(date: Date, count: Int)]   // every day in period, 0-filled
    let peakDay: (date: Date, count: Int)?
    let averagePerDay: Double
    
    /// Generate a report by fetching from the Last.fm API.
    @MainActor
    static func generate(username: String, service: LastFMService, period: TimePeriod) async -> ListeningReport {
        let calendar = Calendar.current
        let now = Date()
        let periodStart = period.startDate
        
        // Max pages to fetch per period — stop early once we pass periodStart
        let maxPages: Int
        switch period {
        case .day:        maxPages = 5    // 250 tracks
        case .week:       maxPages = 10   // 500 tracks
        case .month:      maxPages = 15   // 750 tracks
        case .threeMonths: maxPages = 40  // 2000 tracks
        case .year:       maxPages = 80   // 4000 tracks
        case .allTime:    maxPages = 120  // 6000 tracks
        }
        
        // Fetch top artists, albums, tracks for this period
        async let artistsTask = service.getTopArtists(username: username, limit: 50, period: period.lastfmPeriod)
        async let albumsTask = service.getTopAlbums(username: username, limit: 50, period: period.lastfmPeriod)
        async let tracksTask = service.getTopTracks(username: username, limit: 50, period: period.lastfmPeriod)
        
        // Fetch recent tracks page by page until we pass the period start
        async let recentTask = fetchTracksInPeriod(
            username: username, service: service,
            periodStart: periodStart, maxPages: maxPages
        )
        
        do {
            let (artists, albums, tracks, recentTracks) = try await (
                artistsTask, albumsTask, tracksTask, recentTask
            )
            
            // Count unique artists/albums/tracks from fetched data
            let artistSet = Set(recentTracks.map(\.artist))
            let albumSet = Set(recentTracks.map { "\($0.album)|||\($0.artist)" })
            let trackSet = Set(recentTracks.map { "\($0.name)|||\($0.artist)" })
            
            // Build daily breakdown — fill ALL days in the period
            var dayCounts: [Date: Int] = [:]
            for track in recentTracks {
                guard let uts = track.date, let ts = TimeInterval(uts) else { continue }
                let date = Date(timeIntervalSince1970: ts)
                guard date >= periodStart else { continue }
                let day = calendar.startOfDay(for: date)
                dayCounts[day, default: 0] += 1
            }
            
            // Fill missing days with 0
            let filledDays = fillDays(from: periodStart, to: now, counts: dayCounts)
            let peakDay = filledDays.max(by: { $0.count < $1.count })
            
            let daysSinceStart = max(calendar.dateComponents([.day], from: periodStart, to: now).day ?? 1, 1)
            let totalScrobbles = recentTracks.filter { track in
                guard let uts = track.date, let ts = TimeInterval(uts) else { return false }
                return Date(timeIntervalSince1970: ts) >= periodStart
            }.count
            let averagePerDay = Double(totalScrobbles) / Double(daysSinceStart)
            
            return ListeningReport(
                period: period,
                generatedAt: Date(),
                totalScrobbles: totalScrobbles,
                uniqueArtists: artistSet.count,
                uniqueAlbums: albumSet.count,
                uniqueTracks: trackSet.count,
                topArtists: artists.prefix(10).map { (name: $0.name, count: Int($0.playcount) ?? 0) },
                topAlbums: albums.prefix(10).map { (name: $0.name, artist: $0.artist, count: Int($0.playcount) ?? 0) },
                topTracks: tracks.prefix(10).map { (name: $0.name, artist: $0.artist, count: Int($0.playcount) ?? 0) },
                scrobblesPerDay: filledDays,
                peakDay: peakDay,
                averagePerDay: averagePerDay
            )
        } catch {
            return ListeningReport(
                period: period,
                generatedAt: Date(),
                totalScrobbles: 0,
                uniqueArtists: 0,
                uniqueAlbums: 0,
                uniqueTracks: 0,
                topArtists: [],
                topAlbums: [],
                topTracks: [],
                scrobblesPerDay: [],
                peakDay: nil,
                averagePerDay: 0
            )
        }
    }
    
    /// Fetch recent tracks page by page, stopping once we pass the period start.
    private static func fetchTracksInPeriod(
        username: String, service: LastFMService,
        periodStart: Date, maxPages: Int
    ) async throws -> [RecentTrack] {
        var allTracks: [RecentTrack] = []
        var page = 1
        
        while page <= maxPages {
            let result = try await service.getRecentTracks(username: username, limit: 50, page: page)
            let tracks = result.tracks
            
            // Check if we've gone past the period start
            var hitOldTrack = false
            for track in tracks {
                if let uts = track.date, let ts = TimeInterval(uts) {
                    let date = Date(timeIntervalSince1970: ts)
                    if date < periodStart {
                        hitOldTrack = true
                        break
                    }
                }
                allTracks.append(track)
            }
            
            // If last track on this page is older than period start, stop
            if hitOldTrack || tracks.count < 50 || page >= result.totalPages {
                break
            }
            
            page += 1
        }
        
        return allTracks
    }
    
    /// Fill in missing days between start and end with 0 counts.
    private static func fillDays(from start: Date, to end: Date, counts: [Date: Int]) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        var result: [(date: Date, count: Int)] = []
        
        var day = calendar.startOfDay(for: start)
        let endDate = calendar.startOfDay(for: end)
        
        while day <= endDate {
            let count = counts[day] ?? 0
            result.append((date: day, count: count))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        
        return result
    }
    
    /// Format the report as a shareable text string.
    func formattedText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var text = "📊 Listening Report — \(period.rawValue)\n"
        text += "Generated \(formatter.string(from: generatedAt))\n\n"
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
