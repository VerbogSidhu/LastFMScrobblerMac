import SwiftUI

/// Quick stats view — shows scrobble counts with a visual breakdown.
struct StatsView: View {
    @EnvironmentObject var appState: AppState
    
    private var stats: ScrobbleStatsManager { appState.statsManager }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Big Numbers
                HStack(spacing: 16) {
                    BigStat(value: "\(stats.todayCount)", label: "Today", color: .green)
                    BigStat(value: "\(stats.weekCount)", label: "This Week", color: .blue)
                    BigStat(value: "\(stats.monthCount)", label: "This Month", color: .purple)
                    BigStat(value: "\(stats.totalCount)", label: "All Time", color: .orange)
                }
                
                // Top Artists (all time)
                let topArtists = stats.topArtists(in: .allTime, limit: 5)
                if !topArtists.isEmpty {
                    QuickTopList(
                        title: "Top Artists (All Time)",
                        icon: "person.fill",
                        items: topArtists.enumerated().map { (i, a) in
                            QuickTopItem(rank: i + 1, name: a.name, detail: "\(a.count) scrobbles", progress: Double(a.count) / Double(max(stats.totalCount, 1)))
                        }
                    )
                }
                
                // Top Albums (this month)
                let topAlbums = stats.topAlbums(in: .month, limit: 5)
                if !topAlbums.isEmpty {
                    QuickTopList(
                        title: "Top Albums (This Month)",
                        icon: "square.stack.fill",
                        items: topAlbums.enumerated().map { (i, a) in
                            QuickTopItem(rank: i + 1, name: a.name, detail: "\(a.artist) · \(a.count)", progress: nil)
                        }
                    )
                }
                
                // Top Tracks (this week)
                let topTracks = stats.topTracks(in: .week, limit: 5)
                if !topTracks.isEmpty {
                    QuickTopList(
                        title: "Top Tracks (This Week)",
                        icon: "music.note",
                        items: topTracks.enumerated().map { (i, t) in
                            QuickTopItem(rank: i + 1, name: t.name, detail: "\(t.artist) · \(t.count)", progress: nil)
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct BigStat: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}

struct QuickTopItem: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let detail: String
    let progress: Double?
}

struct QuickTopList: View {
    let title: String
    let icon: String
    let items: [QuickTopItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Text("\(item.rank)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 16, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(item.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        if let p = item.progress {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.white.opacity(0.05))
                                        .frame(height: 3)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.purple.gradient)
                                        .frame(width: geo.size.width * p, height: 3)
                                }
                            }
                            .frame(height: 3)
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}
