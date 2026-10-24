import Testing
import Foundation
@testable import LastFM

struct PersistenceTests {
    @Test func clearingThenRecordingDoesNotResurrectOldHistoryAndExportReplaces() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = dir.appendingPathComponent("stats.json")
        let manager = ScrobbleStatsManager(persistenceURL: storage)
        manager.recordScrobble(track: "Old", artist: "Artist", album: "")
        try manager.clear()
        manager.recordScrobble(track: "New", artist: "Artist", album: "")
        let restored = ScrobbleStatsManager(persistenceURL: storage)
        #expect(restored.records(in: .allTime).map(\.track) == ["New"])
        let export = dir.appendingPathComponent("export.json")
        try Data("old backup".utf8).write(to: export)
        try manager.export(to: export)
        let exported = try JSONDecoder().decode([ScrobbleRecord].self, from: Data(contentsOf: export))
        #expect(exported.map(\.track) == ["New"])
    }
    @Test func queueRemovesAcceptedIDWithoutDroppingConcurrentEnqueue() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = dir.appendingPathComponent("pending.json")
        let queue = OfflineScrobbleQueue(fileURL: storage)
        let old = try queue.enqueue(track: "First", artist: "Artist", album: "", duration: 120, timestamp: 100, account: "A")
        let snapshot = queue.items
        _ = try queue.enqueue(track: "New", artist: "Artist", album: "", duration: 120, timestamp: 105, account: "B")
        #expect(snapshot.count == 1)
        try queue.remove(id: old.id)
        let restored = OfflineScrobbleQueue(fileURL: storage)
        #expect(restored.items.map(\.track) == ["New"])
        #expect(restored.items.first?.account == "B")
    }
}
