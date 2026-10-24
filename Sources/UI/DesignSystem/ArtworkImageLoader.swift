import Foundation
import Combine
import AppKit

/// Results belong to one source request, even when a cancelled fetch finishes late.
@MainActor
final class ArtworkImageLoader: ObservableObject {
    @Published private(set) var fileURL: URL?
    @Published private(set) var source: String?
    @Published private(set) var image: NSImage?
    private var generation = UUID()

    func load(_ source: String?, fetch: (String) async -> URL? = { await DiskImageCache.shared.fetchAndCache(from: $0) }) async {
        let request = UUID()
        generation = request
        self.source = source
        fileURL = nil
        image = nil
        guard let source, !source.isEmpty else { return }
        let resolved: URL?
        if source.hasPrefix("/") { resolved = URL(fileURLWithPath: source) }
        else if let url = URL(string: source), url.isFileURL { resolved = url }
        else { resolved = await fetch(source) }
        guard !Task.isCancelled, generation == request else { return }
        fileURL = resolved
        image = resolved.flatMap { NSImage(contentsOf: $0) }
    }
}
