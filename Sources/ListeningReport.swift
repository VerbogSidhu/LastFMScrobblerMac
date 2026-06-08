import Foundation

/// A generated listening report summarizing activity over a time period.
/// Fetches data from the Last.fm API rather than relying on local stats.
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
    let scrobblesPerDay: [(date: Date, count: Int)]
    let peakDay: (date: Date, count: Int)?
    let averagePerDay: Double
    
    /// Generate a report by fetching from the Last.fm API.
    @MainActor
    static func generate(username: String, service: LastFMService, period: TimePeriod) async -> ListeningReport {
        let calendar = Calendar.current
        let now = Date()
        
        // Fetch top artists, albums, tracks for this period
        async let artistsTask = service.getTopArtists(username: username, limit: 50, period: period.lastfmPeriod)
        async let albumsTask = service.getTopAlbums(username: username, limit: 50, period: period.lastfmPeriod)
        async let tracksTask = service.getTopTracks(username: username, limit: 50, period: period.lastfmPeriod)
        
        // Fetch recent tracks for daily breakdown (paginated)
        async let recentTask = service.getAllRecentTracks(username: username, maxPages: 10)
        
        // Fetch user info for total scrobble count
        async let userTask = service.getUserInfo(username: username)
        
        do {
            let (artists, albums, tracks, recentTracks, userInfo) = try await (
                artistsTask, albumsTask, tracksTask, recentTask, userTask
            )
            
            let totalArtists = Int(userInfo.artistCount) ?? artists.count
            let totalAlbums = Int(userInfo.albumCount) ?? albums.count
            let totalTracks = Int(userInfo.trackCount) ?? tracks.count
            
            // Build daily breakdown from recent tracks
            let periodStart = period.startDate
            let datedTracks = recentTracks.compactMap { track -> (date: Date, count: Int)? in
                guard let uts = track.date, let ts = TimeInterval(uts) else { return nil }
                let date = Date(timeIntervalSince1970: ts)
                guard date >= periodStart else { return nil }
                return (calendar.startOfDay(for: date), 1)
            }
            
            // Group by day
            var dayCounts: [Date: Int] = [:]
            for item in datedTracks {
                dayCounts[item.date, default: 0] += 1
            }
            let scrobblesPerDay = dayCounts.sorted { $0.key < $1.key }.map { (date: $0.key, count: $0.value) }
            let peakDay = scrobblesPerDay.max(by: { $0.count < $1.count })
            
            let daysSinceStart = max(calendar.dateComponents([.day], from: period.startDate, to: now).day ?? 1, 1)
            let totalScrobbles = Int(userInfo.playcount) ?? 0
            let averagePerDay = Double(datedTracks.count) / Double(daysSinceStart)
            
            return ListeningReport(
                period: period,
                generatedAt: Date(),
                totalScrobbles: totalScrobbles,
                uniqueArtists: totalArtists,
                uniqueAlbums: totalAlbums,
                uniqueTracks: totalTracks,
                topArtists: artists.prefix(10).map { (name: $0.name, count: Int($0.playcount) ?? 0) },
                topAlbums: albums.prefix(10).map { (name: $0.name, artist: $0.artist, count: Int($0.playcount) ?? 0) },
                topTracks: tracks.prefix(10).map { (name: $0.name, artist: $0.artist, count: Int($0.playcount) ?? 0) },
                scrobblesPerDay: scrobblesPerDay,
                peakDay: peakDay,
                averagePerDay: averagePerDay
            )
        } catch {
            // Return empty report on error
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
    
    /// Format the report as a shareable text string.
    func formattedText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var text = "📊 Listening Report — \(period.rawValue)\n"
        text += "Generated \(formatter.string(from: generatedAt))\n\n"
        text += "🔢 \(totalScrobbles) scrobbles · \(uniqueArtists) artists · \(uniqueAlbums) albums · \(uniqueTracks) tracks\n"
        text += "📈 Avg \(String(format: "%.1f", averagePerDay))/day"
        
        if let peak = peakDay {
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
