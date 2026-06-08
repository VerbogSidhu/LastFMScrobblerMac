import SwiftUI

/// A drop-in replacement for AsyncImage that checks the on-disk cache first.
/// Falls back to network fetch + cache on miss.
struct CachedAsyncImage<Placeholder: View, Content: View>: View {
    private let urlString: String?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var imageURL: URL?
    @State private var isLoading = true
    
    init(
        url urlString: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let fileURL = imageURL {
                AsyncImage(url: fileURL) { phase in
                    switch phase {
                    case .success(let image):
                        content(image)
                    case .failure:
                        placeholder()
                    default:
                        placeholder()
                    }
                }
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let urlString, !urlString.isEmpty else {
            isLoading = false
            return
        }
        
        let cache = DiskImageCache.shared
        
        // Check cache first (instant)
        if let cached = cache.cachedURL(for: urlString) {
            imageURL = cached
            isLoading = false
            return
        }
        
        // Fetch from network + cache
        if let fileURL = await cache.fetchAndCache(from: urlString) {
            imageURL = fileURL
        }
        isLoading = false
    }
}
