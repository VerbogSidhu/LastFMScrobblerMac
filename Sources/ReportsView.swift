import SwiftUI

/// Listening reports view — generates and displays a report from the Last.fm API.
struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: TimePeriod = .month
    @State private var report: ListeningReport?
    @State private var isGenerating = false
    @State private var currentTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Period Picker
            HStack(spacing: DS.Spacing.md) {
                ForEach(TimePeriod.allCases) { period in
                    Button {
                        selectedPeriod = period
                        generateReport()
                    } label: {
                        Text(period.rawValue)
                            .font(DS.Fonts.caption(11).weight(selectedPeriod == period ? .semibold : .regular))
                            .foregroundStyle(selectedPeriod == period ? DS.Colors.textPrimary : DS.Colors.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedPeriod == period ? Color.white.opacity(0.1) : .clear,
                                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(period.rawValue)
                    .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
                }

                Spacer()

                if let report {
                    SecondaryButton(title: "Copy", icon: "doc.on.doc") {
                        let text = report.formattedText()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .accessibilityLabel("Copy report to clipboard")
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.vertical, DS.Spacing.lg)

            if isGenerating {
                LoadingState(message: "Generating report…")
            } else if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                        // Summary Cards
                        ReportSummaryCards(report: report)

                        // Daily Scrobble Chart
                        if !report.scrobblesPerDay.isEmpty {
                            ScrobbleChart(data: report.scrobblesPerDay, period: selectedPeriod)
                        }

                        // Top Lists
                        HStack(alignment: .top, spacing: DS.Spacing.lg) {
                            if !report.topArtists.isEmpty {
                                RankedList(title: "Top Artists", icon: "person.fill", items: report.topArtists.prefix(5), id: \.name) { i, a in
                                    RankedListRow(rank: i, primary: a.name, secondary: "\(a.count) scrobbles")
                                }
                            }

                            if !report.topAlbums.isEmpty {
                                RankedList(title: "Top Albums", icon: "square.stack.fill", items: report.topAlbums.prefix(5), id: \.name) { i, a in
                                    RankedListRow(rank: i, primary: a.name, secondary: "\(a.artist) · \(a.count)")
                                }
                            }

                            if !report.topTracks.isEmpty {
                                RankedList(title: "Top Tracks", icon: "music.note", items: report.topTracks.prefix(5), id: \.name) { i, t in
                                    RankedListRow(rank: i, primary: t.name, secondary: "\(t.artist) · \(t.count)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xxxl)
                    .padding(.bottom, DS.Spacing.xxxl)
                }
            } else {
                EmptyState(
                    icon: "doc.text",
                    title: "Select a period to generate a report"
                )
            }
        }
        .onAppear { generateReport() }
        .onDisappear { currentTask?.cancel() }
    }

    private func generateReport() {
        currentTask?.cancel()
        isGenerating = true
        report = nil

        let period = selectedPeriod

        currentTask = Task {
            let newReport = await ListeningReport.generate(
                username: Constants.lastFMUsername,
                service: appState.service,
                period: period
            )

            guard !Task.isCancelled, selectedPeriod == period else { return }

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
        HStack(spacing: DS.Spacing.lg) {
            SummaryCard(icon: "waveform", value: "\(report.totalScrobbles)", label: "Scrobbles", color: DS.Colors.accent)
            SummaryCard(icon: "person.fill", value: "\(report.uniqueArtists)", label: "Artists", color: DS.Colors.info)
            SummaryCard(icon: "square.stack.fill", value: "\(report.uniqueAlbums)", label: "Albums", color: DS.Colors.warning)
            SummaryCard(icon: "music.note", value: "\(report.uniqueTracks)", label: "Tracks", color: DS.Colors.success)

            if let peak = report.peakDay, peak.count > 0 {
                SummaryCard(
                    icon: "flame.fill",
                    value: "\(peak.count)",
                    label: "Peak Day",
                    color: DS.Colors.error,
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
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Fonts.body(14))
                .foregroundStyle(color)
            Text(value)
                .font(DS.Fonts.statNumber(18))
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(DS.Fonts.caption(9))
                .foregroundStyle(DS.Colors.textMuted)
            if let sub {
                Text(sub)
                    .font(DS.Fonts.caption(8))
                    .foregroundStyle(DS.Colors.textMuted.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .cardStyle(cornerRadius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SectionHeader(title: "Scrobbles Over Time", icon: "chart.bar")

                if data.isEmpty {
                    Text("No data for this period")
                        .font(DS.Fonts.caption())
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(height: 120)
                } else {
                    GeometryReader { geo in
                        let barWidth = max(2, (geo.size.width - CGFloat(data.count) * 1) / CGFloat(data.count))
                        let showLabels = data.count <= 31

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: 1) {
                                ForEach(Array(data.enumerated()), id: \.offset) { idx, entry in
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(barColor(for: entry.count))
                                            .frame(
                                                width: barWidth,
                                                height: max(1, CGFloat(entry.count) / CGFloat(max(maxCount, 1)) * 100)
                                            )

                                        if showLabels && shouldShowLabel(idx: idx) {
                                            Text(dateLabel(entry.date))
                                                .font(DS.Fonts.caption(7))
                                                .foregroundStyle(DS.Colors.textMuted)
                                                .rotationEffect(.degrees(-45), anchor: .topTrailing)
                                        }
                                    }
                                }
                            }
                            .frame(height: 120)
                        }
                    }
                    .frame(height: 135)
                    .accessibilityLabel("Scrobble chart showing \(data.count) data points")
                }
            }
        }
    }

    private func barColor(for count: Int) -> LinearGradient {
        if count == 0 {
            return LinearGradient(colors: [DS.Colors.inputBackground], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }

    private func shouldShowLabel(idx: Int) -> Bool {
        let maxLabels = 10
        let step = max(1, data.count / maxLabels)
        return idx % step == 0 || idx == data.count - 1
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch period {
        case .day:
            f.dateFormat = "ha"
        case .week:
            f.dateFormat = "EEE"
        case .month:
            f.dateFormat = "d"
        case .threeMonths:
            f.dateFormat = "MMM d"
        case .year:
            f.dateFormat = "MMM"
        case .allTime:
            f.dateFormat = "MMM ''yy"
        }
        return f.string(from: date)
    }
}
