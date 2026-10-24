import SwiftUI
import Charts

/// Listening reports view — generates and displays a report from the Last.fm API.
struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: TimePeriod = .month
    @State private var report: ListeningReport?
    @State private var isGenerating = false
    @State private var currentTask: Task<Void, Never>?
    @State private var errorMessage: String?

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
            } else if let errorMessage {
                ErrorState(message: errorMessage) { generateReport() }
            } else if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                        Text("\(report.range.start.formatted(date: .abbreviated, time: .omitted)) – \(report.range.end.formatted(date: .abbreviated, time: .omitted)) · Average includes today")
                            .font(DS.Fonts.caption(11))
                            .foregroundStyle(DS.Colors.textSecondary)
                        ReportSummaryCards(report: report)

                        // Daily Scrobble Chart
                        if !report.scrobblesPerDay.isEmpty {
                            ScrobbleChart(data: report.scrobblesPerDay, period: selectedPeriod, unit: report.chartUnit)
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
        .onReceive(NotificationCenter.default.publisher(for: .dashboardDidRefresh)) { _ in generateReport() }
    }

    private func generateReport() {
        currentTask?.cancel()
        isGenerating = true
        report = nil
        errorMessage = nil

        let period = selectedPeriod

        currentTask = Task {
            do {
                let newReport = try await ListeningReport.generate(username: Constants.lastFMUsername, service: appState.service, period: period)
                guard !Task.isCancelled, selectedPeriod == period else { return }
                report = newReport
                isGenerating = false
            } catch is CancellationError {
                // The replacement task owns the loading state.
            } catch {
                guard !Task.isCancelled, selectedPeriod == period else { return }
                errorMessage = error.localizedDescription
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

struct ReportChartPoint: Identifiable {
    let id: Int
    let date: Date
    let count: Int
}

struct ScrobbleChart: View {
    @EnvironmentObject var appState: AppState
    let data: [(date: Date, count: Int)]
    let period: TimePeriod
    let unit: Calendar.Component

    private var chartPoints: [ReportChartPoint] {
        data.enumerated().map { ReportChartPoint(id: $0.offset, date: $0.element.date, count: $0.element.count) }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(appState.accentColor)
                    Text(unit == .month ? "Monthly Scrobbles" : unit == .year ? "Yearly Scrobbles" : unit == .hour ? "Scrobbles by Hour" : "Daily Scrobbles")
                        .font(DS.Fonts.subheading(13))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                }

                if data.isEmpty {
                    Text("No data for this period")
                        .font(DS.Fonts.caption())
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(height: 140)
                } else {
                    Chart {
                        ForEach(chartPoints) { point in
                            BarMark(
                                x: .value("Date", point.date, unit: unit),
                                y: .value("Scrobbles", point.count)
                            )
                            .foregroundStyle(appState.accentColor.gradient)
                            .cornerRadius(2.5)
                            .accessibilityLabel(point.date.formatted(date: .abbreviated, time: unit == .hour ? .shortened : .omitted))
                            .accessibilityValue("\(point.count) scrobbles")
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                            AxisValueLabel()
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                            AxisValueLabel()
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                    }
                    .frame(height: 140)
                    .accessibilityLabel("Scrobble chart showing \(data.count) data points")
                }
            }
        }
    }

}
