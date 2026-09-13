import SwiftUI
import Charts

/// Native Stats view with Apple Charts visualizations, period metrics,
/// interactive hover scrubbing, listening streak, and milestone countdown.
struct StatsView: View {
    @EnvironmentObject var appState: AppState

    @State private var userInfo: UserInfo?
    @State private var topArtistsWeek: [TopArtist] = []
    @State private var topAlbumsWeek: [TopAlbum] = []
    @State private var topTracksWeek: [TopTrack] = []
    @State private var dailyActivity: [DayActivity] = []
    @State private var timeOfDayDistribution: [TimeBucket] = []
    @State private var listeningStreak: Int = 0
    @State private var isLoading = true
    @State private var error: String?

    // Interactive chart scrub state
    @State private var hoveredDay: String? = nil
    @State private var hoveredCount: Int? = nil

    struct DayActivity: Identifiable {
        let id = UUID()
        let day: String
        let count: Int
    }

    struct TimeBucket: Identifiable {
        let id = UUID()
        let period: String
        let count: Int
        let icon: String
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: DS.Spacing.lg) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: DS.Spacing.lg) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: DS.Radius.xl)
                                    .fill(DS.Colors.inputBackground)
                                    .frame(height: 80)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xxxl)
                    .padding(.bottom, DS.Spacing.xxxl)
                }
                .accessibilityHidden(true)

            } else if let error {
                ErrorState(message: error) {
                    Task { await loadData() }
                }

            } else if let user = userInfo {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    // Big Numbers with Streak
                    HStack(spacing: DS.Spacing.lg) {
                        StatCard(value: formatCount("\(user.playcount)"), label: "Total Scrobbles", color: appState.accentColor)
                        StatCard(value: formatCount(user.artistCount), label: "Artists", color: DS.Colors.info)
                        StatCard(value: formatCount(user.albumCount), label: "Albums", color: DS.Colors.warning)
                        StatCard(value: "\(listeningStreak)d 🔥", label: "Listening Streak", color: .orange)
                    }

                    // Milestone Countdown Card
                    milestoneCard(totalPlaycount: user.playcount)

                    // Native Charts Section
                    HStack(alignment: .top, spacing: DS.Spacing.lg) {
                        // 7-Day Activity Area Chart with Hover Scrubbing
                        Card {
                            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(appState.accentColor)
                                    Text("7-Day Listening Trend")
                                        .font(DS.Fonts.subheading(13))
                                        .foregroundStyle(DS.Colors.textPrimary)

                                    Spacer()

                                    if let day = hoveredDay, let count = hoveredCount {
                                        HStack(spacing: 4) {
                                            Text(day)
                                                .font(DS.Fonts.caption(11).weight(.bold))
                                                .foregroundStyle(DS.Colors.textPrimary)
                                            Text("·")
                                                .foregroundStyle(DS.Colors.textMuted)
                                            Text("\(count) scrobbles")
                                                .font(DS.Fonts.mono(11))
                                                .foregroundStyle(appState.accentColor)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(appState.accentColor.opacity(0.15), in: Capsule())
                                    }
                                }

                                if dailyActivity.isEmpty {
                                    Text("No activity data")
                                        .font(DS.Fonts.caption())
                                        .foregroundStyle(DS.Colors.textMuted)
                                        .frame(height: 140)
                                } else {
                                    Chart {
                                        ForEach(dailyActivity) { item in
                                            AreaMark(
                                                x: .value("Day", item.day),
                                                y: .value("Scrobbles", item.count)
                                            )
                                            .interpolationMethod(.catmullRom)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [appState.accentColor.opacity(0.35), appState.accentColor.opacity(0.02)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )

                                            LineMark(
                                                x: .value("Day", item.day),
                                                y: .value("Scrobbles", item.count)
                                            )
                                            .interpolationMethod(.catmullRom)
                                            .foregroundStyle(appState.accentColor)
                                            .lineStyle(StrokeStyle(lineWidth: 2))

                                            PointMark(
                                                x: .value("Day", item.day),
                                                y: .value("Scrobbles", item.count)
                                            )
                                            .foregroundStyle(appState.accentColor)
                                        }

                                        // Hover Scrubbing RuleMark & Tooltip
                                        if let hDay = hoveredDay, let hCount = hoveredCount {
                                            RuleMark(x: .value("Day", hDay))
                                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                                .foregroundStyle(appState.accentColor)

                                            PointMark(
                                                x: .value("Day", hDay),
                                                y: .value("Scrobbles", hCount)
                                            )
                                            .symbolSize(80)
                                            .foregroundStyle(appState.accentColor)
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks { _ in
                                            AxisValueLabel()
                                                .foregroundStyle(DS.Colors.textSecondary)
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { _ in
                                            AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                                            AxisValueLabel()
                                                .foregroundStyle(DS.Colors.textMuted)
                                        }
                                    }
                                    .chartOverlay { proxy in
                                        GeometryReader { geo in
                                            Rectangle()
                                                .fill(Color.clear)
                                                .contentShape(Rectangle())
                                                .gesture(
                                                    DragGesture(minimumDistance: 0)
                                                        .onChanged { value in
                                                            let count = dailyActivity.count
                                                            guard count > 0 else { return }
                                                            let stepWidth = geo.size.width / CGFloat(count)
                                                            let idx = min(count - 1, max(0, Int(value.location.x / stepWidth)))
                                                            let item = dailyActivity[idx]
                                                            if hoveredDay != item.day {
                                                                hoveredDay = item.day
                                                                hoveredCount = item.count
                                                            }
                                                        }
                                                        .onEnded { _ in
                                                            hoveredDay = nil
                                                            hoveredCount = nil
                                                        }
                                                )
                                        }
                                    }
                                    .frame(height: 140)
                                }
                            }
                        }

                        // Time of Day Distribution Chart
                        Card {
                            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(appState.accentColor)
                                    Text("Listening by Time of Day")
                                        .font(DS.Fonts.subheading(13))
                                        .foregroundStyle(DS.Colors.textPrimary)
                                    Spacer()
                                }

                                if timeOfDayDistribution.isEmpty {
                                    Text("No distribution data")
                                        .font(DS.Fonts.caption())
                                        .foregroundStyle(DS.Colors.textMuted)
                                        .frame(height: 140)
                                } else {
                                    Chart {
                                        ForEach(timeOfDayDistribution) { bucket in
                                            BarMark(
                                                x: .value("Plays", bucket.count),
                                                y: .value("Period", bucket.period)
                                            )
                                            .foregroundStyle(appState.accentColor.gradient)
                                            .cornerRadius(3)
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks { _ in
                                            AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                                            AxisValueLabel()
                                                .foregroundStyle(DS.Colors.textMuted)
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { _ in
                                            AxisValueLabel()
                                                .foregroundStyle(DS.Colors.textSecondary)
                                        }
                                    }
                                    .frame(height: 140)
                                }
                            }
                        }
                    }

                    // Top Artists (this week)
                    if !topArtistsWeek.isEmpty {
                        RankedList(title: "Top Artists (7 Days)", icon: "person.fill", items: topArtistsWeek.prefix(5), id: \.name) { i, a in
                            Button {
                                appState.inspectorEntity = .artist(name: a.name)
                            } label: {
                                RankedListRow(
                                    rank: i,
                                    primary: a.name,
                                    secondary: "\(a.playcount) scrobbles",
                                    progress: { let pc = Double(a.playcount); return pc > 0 ? min(1.0, pc / Double(topArtistsWeek.first?.playcount ?? 1)) : nil }()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Top Albums (this week)
                    if !topAlbumsWeek.isEmpty {
                        RankedList(title: "Top Albums (7 Days)", icon: "square.stack.fill", items: topAlbumsWeek.prefix(5), id: \.name) { i, a in
                            Button {
                                appState.inspectorEntity = .album(artist: a.artist, album: a.name)
                            } label: {
                                RankedListRow(rank: i, primary: a.name, secondary: "\(a.artist) · \(a.playcount) plays")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Top Tracks (this week)
                    if !topTracksWeek.isEmpty {
                        RankedList(title: "Top Tracks (7 Days)", icon: "music.note", items: topTracksWeek.prefix(5), id: \.name) { i, t in
                            RankedListRow(rank: i, primary: t.name, secondary: "\(t.artist) · \(t.playcount) plays")
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.xxxl)

            } else {
                EmptyState(
                    icon: "chart.bar",
                    title: "No stats available",
                    subtitle: "Check your connection and try again."
                )
            }
        }
        .task { await loadData() }
    }

    // MARK: - Milestone Widget

    @ViewBuilder
    private func milestoneCard(totalPlaycount: Int) -> some View {
        let step = totalPlaycount < 5000 ? 500 : 1000
        let nextMilestone = ((totalPlaycount / step) + 1) * step
        let prevMilestone = nextMilestone - step
        let remaining = nextMilestone - totalPlaycount
        let progress = min(1.0, max(0.0, Double(totalPlaycount - prevMilestone) / Double(step)))

        let totalWeekScrobbles = dailyActivity.map(\.count).reduce(0, +)
        let dailyAverage = max(1, totalWeekScrobbles / max(1, dailyActivity.count))
        let daysEstimated = max(1, Int(ceil(Double(remaining) / Double(dailyAverage))))

        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(appState.accentColor)
                        Text("Next Milestone: \(formatCount("\(nextMilestone)")) Scrobbles")
                            .font(DS.Fonts.subheading(13))
                            .foregroundStyle(DS.Colors.textPrimary)
                    }

                    Spacer()

                    Text("\(remaining) to go")
                        .font(DS.Fonts.mono(11).weight(.bold))
                        .foregroundStyle(appState.accentColor)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)

                        Capsule()
                            .fill(appState.accentColor.gradient)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(progress * 100))% completed from \(formatCount("\(prevMilestone)"))")
                        .font(DS.Fonts.caption(10))
                        .foregroundStyle(DS.Colors.textSecondary)

                    Spacer()

                    Text("~Est. \(daysEstimated) days away (at ~\(dailyAverage)/day)")
                        .font(DS.Fonts.caption(10))
                        .foregroundStyle(DS.Colors.textMuted)
                }
            }
            .padding(4)
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        let username = Constants.lastFMUsername
        let service = appState.service

        do {
            async let user = service.getUserInfo(username: username)
            async let artists = service.getTopArtists(username: username, limit: 5, period: "7day")
            async let albums = service.getTopAlbums(username: username, limit: 5, period: "7day")
            async let tracks = service.getTopTracks(username: username, limit: 5, period: "7day")
            async let recent = service.getRecentTracks(username: username, limit: 50)

            let (u, ar, al, tr, rec) = try await (user, artists, albums, tracks, recent)

            // Compute 7-day activity
            let cal = Calendar.current
            let df = DateFormatter()
            df.dateFormat = "EEE"

            var dayCounts: [String: Int] = [:]
            let now = Date()
            var orderedDays: [String] = []
            for i in (0..<7).reversed() {
                if let date = cal.date(byAdding: .day, value: -i, to: now) {
                    let d = df.string(from: date)
                    orderedDays.append(d)
                    dayCounts[d] = 0
                }
            }

            // Time of day buckets
            var morning = 0
            var afternoon = 0
            var evening = 0
            var night = 0

            // Track days with scrobbles for streak
            var uniqueDatesWithScrobbles: Set<String> = []
            let dayDateFormatter = DateFormatter()
            dayDateFormatter.dateFormat = "yyyy-MM-dd"

            for t in rec.tracks {
                if let uts = t.date, let ts = TimeInterval(uts) {
                    let d = Date(timeIntervalSince1970: ts)
                    let dayStr = df.string(from: d)
                    if dayCounts[dayStr] != nil {
                        dayCounts[dayStr]! += 1
                    }
                    uniqueDatesWithScrobbles.insert(dayDateFormatter.string(from: d))

                    let hour = cal.component(.hour, from: d)
                    if hour >= 6 && hour < 12 { morning += 1 }
                    else if hour >= 12 && hour < 18 { afternoon += 1 }
                    else if hour >= 18 && hour < 24 { evening += 1 }
                    else { night += 1 }
                }
            }

            // Calculate streak (days in a row backwards from today)
            var streak = 0
            for i in 0..<30 {
                if let date = cal.date(byAdding: .day, value: -i, to: now) {
                    let dateStr = dayDateFormatter.string(from: date)
                    if uniqueDatesWithScrobbles.contains(dateStr) {
                        streak += 1
                    } else if i > 0 {
                        // Broke streak
                        break
                    }
                }
            }

            let activity = orderedDays.map { DayActivity(day: $0, count: dayCounts[$0] ?? 0) }
            let timeDist: [TimeBucket] = [
                TimeBucket(period: "Morning", count: morning, icon: "sun.max"),
                TimeBucket(period: "Afternoon", count: afternoon, icon: "sun.haze"),
                TimeBucket(period: "Evening", count: evening, icon: "moon.stars"),
                TimeBucket(period: "Night", count: night, icon: "moon.zzz")
            ]

            await MainActor.run {
                self.userInfo = u
                self.topArtistsWeek = ar
                self.topAlbumsWeek = al
                self.topTracksWeek = tr
                self.dailyActivity = activity
                self.timeOfDayDistribution = timeDist
                self.listeningStreak = max(1, streak)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func formatCount(_ s: String) -> String {
        guard let n = Int(s) else { return s }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
