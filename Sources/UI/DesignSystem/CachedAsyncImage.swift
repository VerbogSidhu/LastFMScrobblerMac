import SwiftUI
import AppKit

struct CachedAsyncImage<Placeholder: View, Content: View>: View {
    private let urlString: String?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    @StateObject private var loader = ArtworkImageLoader()

    init(url: String?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        urlString = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if loader.source == urlString, let file = loader.fileURL,
               let image = NSImage(contentsOf: file) {
                content(Image(nsImage: image))
            } else { placeholder() }
        }
        .task(id: urlString) { await loader.load(urlString) }
    }
}
