import Foundation

/// A generated listening report summarizing activity over a time period.
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
    
    /// Generate a report from the stats manager for a given period.
    static func generate(from stats: ScrobbleStatsManager, period: TimePeriod) -> ListeningReport {
        let records = stats.records(in: period)
        let uniqueArtists = Set(records.map(\.artist)).count
        let uniqueAlbums = Set(records.map(\.album)).count
        let uniqueTracks = Set(records.map(\.track)).count
        
        let perDay = stats.scrobblesPerDay(in: period)
        let peakDay = perDay.max(by: { $0.count < $1.count })
        
        let calendar = Calendar.current
        let daysSinceStart = max(calendar.dateComponents([.day], from: period.startDate, to: Date()).day ?? 1, 1)
        let averagePerDay = Double(records.count) / Double(daysSinceStart)
        
        return ListeningReport(
            period: period,
            generatedAt: Date(),
            totalScrobbles: records.count,
            uniqueArtists: uniqueArtists,
            uniqueAlbums: uniqueAlbums,
            uniqueTracks: uniqueTracks,
            topArtists: stats.topArtists(in: period, limit: 10),
            topAlbums: stats.topAlbums(in: period, limit: 10),
            topTracks: stats.topTracks(in: period, limit: 10),
            scrobblesPerDay: perDay,
            peakDay: peakDay,
            averagePerDay: averagePerDay
        )
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
