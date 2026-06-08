import SwiftUI

/// Listening reports view — generates and displays a report from the Last.fm API.
struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: TimePeriod = .month
    @State private var report: ListeningReport?
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Period Picker
            HStack(spacing: 8) {
                ForEach(TimePeriod.allCases) { period in
                    Button {
                        selectedPeriod = period
                        generateReport()
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 11, weight: selectedPeriod == period ? .semibold : .regular))
                            .foregroundStyle(selectedPeriod == period ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedPeriod == period
                                    ? .white.opacity(0.1)
                                    : .clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if let report {
                    Button {
                        let text = report.formattedText()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            if isGenerating {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("Generating report…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Summary Cards
                        ReportSummaryCards(report: report)
                        
                        // Daily Scrobble Chart
                        if !report.scrobblesPerDay.isEmpty {
                            ScrobbleChart(data: report.scrobblesPerDay, period: selectedPeriod)
                        }
                        
                        // Top Lists
                        HStack(alignment: .top, spacing: 16) {
                            if !report.topArtists.isEmpty {
                                ReportTopList(
                                    title: "Top Artists",
                                    icon: "person.fill",
                                    items: report.topArtists.prefix(5).enumerated().map { (i, a) in
                                        ReportListItem(rank: i + 1, primary: a.name, secondary: "\(a.count) scrobbles")
                                    }
                                )
                            }
                            
                            if !report.topAlbums.isEmpty {
                                ReportTopList(
                                    title: "Top Albums",
                                    icon: "square.stack.fill",
                                    items: report.topAlbums.prefix(5).enumerated().map { (i, a) in
                                        ReportListItem(rank: i + 1, primary: a.name, secondary: "\(a.artist) · \(a.count)")
                                    }
                                )
                            }
                            
                            if !report.topTracks.isEmpty {
                                ReportTopList(
                                    title: "Top Tracks",
                                    icon: "music.note",
                                    items: report.topTracks.prefix(5).enumerated().map { (i, t) in
                                        ReportListItem(rank: i + 1, primary: t.name, secondary: "\(t.artist) · \(t.count)")
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            } else {
                Spacer()
                Text("Select a period to generate a report")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .onAppear { generateReport() }
    }
    
    private func generateReport() {
        isGenerating = true
        report = nil
        Task {
            let newReport = await ListeningReport.generate(
                username: "verbog",
                service: appState.service,
                period: selectedPeriod
            )
            await MainActor.run {
                report = newReport
                isGenerating = false
            }
        }
    }
}

// MARK: - Summary Cards

struct ReportSummaryCards: View {
    let report: ListeningReport
    
    var body: some View {
        HStack(spacing: 12) {
            SummaryCard(icon: "waveform", value: "\(report.totalScrobbles)", label: "Scrobbles", color: .purple)
            SummaryCard(icon: "person.fill", value: "\(report.uniqueArtists)", label: "Artists", color: .blue)
            SummaryCard(icon: "square.stack.fill", value: "\(report.uniqueAlbums)", label: "Albums", color: .orange)
            SummaryCard(icon: "music.note", value: "\(report.uniqueTracks)", label: "Tracks", color: .green)
            
            if let peak = report.peakDay {
                SummaryCard(
                    icon: "flame.fill",
                    value: "\(peak.count)",
                    label: "Peak Day",
                    color: .red,
                    sub: peakDateFormatter.string(from: peak.date)
                )
            }
            
            SummaryCard(
                icon: "chart.line.uptrend.xyaxis",
                value: String(format: "%.1f", report.averagePerDay),
                label: "Avg/Day",
                color: .cyan
            )
        }
    }
    
    private var peakDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }
}

struct SummaryCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var sub: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
            if let sub {
                Text(sub)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}

// MARK: - Chart

struct ScrobbleChart: View {
    let data: [(date: Date, count: Int)]
    let period: TimePeriod
    
    private var maxCount: Int {
        data.map(\.count).max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scrobbles Over Time")
                .font(.system(size: 13, weight: .semibold))
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.purple.gradient)
                            .frame(
                                width: max(3, CGFloat(300) / CGFloat(max(data.count, 1))),
                                height: max(2, CGFloat(entry.count) / CGFloat(maxCount) * 100)
                            )
                        
                        if shouldShowLabel(entry) {
                            Text(dateLabel(entry.date))
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.04), lineWidth: 1))
    }
    
    private func shouldShowLabel(_ entry: (date: Date, count: Int)) -> Bool {
        let maxLabels = 8
        let step = max(1, data.count / maxLabels)
        guard let idx = data.firstIndex(where: { $0.date == entry.date }) else { return false }
        return idx % step == 0
    }
    
    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        switch period {
        case .day:
            f.dateFormat = "ha"
        case .week, .month:
            f.dateFormat = "MMM d"
        default:
            f.dateFormat = "MMM"
        }
        return f.string(from: date)
    }
}

// MARK: - Top List

struct ReportListItem: Identifiable {
    let id = UUID()
    let rank: Int
    let primary: String
    let secondary: String
}

struct ReportTopList: View {
    let title: String
    let icon: String
    let items: [ReportListItem]
    
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
                HStack(spacing: 8) {
                    Text("\(item.rank)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 16, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.primary)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(item.secondary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.04), lineWidth: 1))
    }
}
