import Foundation
import Testing
@testable import LastFM

private class AnalyticsFixtureService: LastFMService {
    var offline = false
    let now = Date(timeIntervalSince1970: 1_792_843_200)
    override func getRecentTracks(username: String, limit: Int, page: Int = 1, from: Date? = nil, to: Date? = nil, forceRefresh: Bool = false) async throws -> (tracks: [RecentTrack], totalPages: Int, total: Int) {
        if offline { throw URLError(.notConnectedToInternet) }
        let total = 600
        let start = (page - 1) * limit
        let indices = start..<min(start + limit, total)
        return (indices.map { index in RecentTrack(name: "Track \(index % 60)", artist: "Artist \(index % 60)", album: "Album \(index % 60)", imageURL: nil, date: String(Int(now.timeIntervalSince1970) - 10 - index), nowPlaying: false) }, Int(ceil(Double(total)/Double(limit))), total)
    }
}

struct AnalyticsTests {
    @Test @MainActor func testReportCountsAllPlaysAndUniqueItemsBeyondTopFifty() async throws {
        let service = AnalyticsFixtureService()
        let report = try await ListeningReport.generate(username: "audit-fixture", service: service, period: .week, now: service.now)
        #expect(report.totalScrobbles == 600)
        #expect(report.uniqueArtists == 60)
        #expect(report.uniqueAlbums == 60)
        #expect(report.uniqueTracks == 60)
        #expect(report.scrobblesPerDay.reduce(0) { $0 + $1.count } == 600)
    }

    @Test @MainActor func testTodayDoesNotTruncateHistoryAfterFivePages() async throws {
        let service = AnalyticsFixtureService()
        let report = try await ListeningReport.generate(username: "audit-fixture", service: service, period: .day, now: service.now)
        #expect(report.scrobblesPerDay.reduce(0) { $0 + $1.count } == 600)
    }

    @Test func testThisMonthStartsAtCurrentCalendarMonth() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: TimePeriod.month.startDate)
        let today = Calendar.current.dateComponents([.year, .month], from: Date())
        #expect(components.year == today.year)
        #expect(components.month == today.month)
        #expect(components.day == 1)
    }

    @Test func testThisYearStartsAtJanuaryFirst() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: TimePeriod.year.startDate)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }
    @Test func failedHistoryLoadThrowsInsteadOfManufacturingZeroReport() async {
        let service = AnalyticsFixtureService(); service.offline = true
        do {
            _ = try await ListeningReport.generate(username: "fixture", service: service, period: .day, now: service.now)
            Issue.record("Offline history must not produce a report")
        } catch { #expect((error as? URLError)?.code == .notConnectedToInternet) }
    }
    @Test func scrobbleCountsUseHistoryTotalNotNumberOfArtists() async throws {
        let service = AnalyticsFixtureService()
        let value = try await service.getScrobbleCount(username: "fixture", from: service.now.addingTimeInterval(-3600), to: service.now)
        #expect(value == 600)
    }
    @Test func allTimeChartHasBoundedBucketsAndUsesEarliestActualPlay() throws {
        let start = Date(timeIntervalSince1970: 946_728_000)
        let now = Date(timeIntervalSince1970: 1_792_843_200)
        let track = RecentTrack(name: "Track", artist: "Artist", album: "Album", imageURL: nil, date: String(Int(start.timeIntervalSince1970)), nowPlaying: false)
        let report = try ListeningReport.build(tracks: [track], period: .allTime, range: DateInterval(start: Date(timeIntervalSince1970: 0), end: now))
        #expect(report.scrobblesPerDay.count <= 366)
        #expect(report.totalScrobbles == 1)
        #expect(report.scrobblesPerDay.reduce(0) { $0 + $1.count } == 1)
        #expect(Calendar.current.component(.year, from: report.range.start) == 2000)
    }

}
