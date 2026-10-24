import Foundation

class LastFMService {
    private let apiKey = "b5940532a8c9dfde75381c3060972a65"
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let imageService = ArtistImageService.shared
    
    // MARK: - In-Memory Cache
    
    /// Simple TTL-based cache for API responses to avoid redundant fetches.
    private struct CacheEntry {
        let data: Any
        let timestamp: Date
    }
    
    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 60
    private let cacheLock = NSLock()
    
    /// Returns cached value if still valid, nil otherwise.
    private func cached<T>(_ key: String) -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let entry = cache[key],
              Date().timeIntervalSince(entry.timestamp) < cacheTTL else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data as? T
    }
    
    /// Stores value in cache with current timestamp.
    private func setCache(_ key: String, value: Any) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < cacheTTL }
        if cache.count >= 128, let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
            cache.removeValue(forKey: oldest)
        }
        cache[key] = CacheEntry(data: value, timestamp: now)
    }
    
    func invalidateCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    // MARK: - Safe URL Builder
    
    /// Builds a URL safely using URLComponents. Throws if the URL cannot be constructed.
    private func buildURL(method: String, parameters: [String: String]) throws -> URL {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ] + parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
    
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.urlCache = URLCache(memoryCapacity: 1 * 1024 * 1024, diskCapacity: 5 * 1024 * 1024, diskPath: "LastFMAPICache")
            config.requestCachePolicy = .reloadRevalidatingCacheData
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    private func data(from url: URL, forceRefresh: Bool = false) async throws -> Data {
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        if forceRefresh { request.cachePolicy = .reloadIgnoringLocalCacheData }
        let (data, response) = try await session.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = (json["error"] as? NSNumber)?.intValue {
            throw LastFMReadError.api(code: code, message: json["message"] as? String ?? "Last.fm request failed.")
        }
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        try Task.checkCancellation()
        return data
    }

    // MARK: - Recent Tracks

    func getRecentTracks(username: String, limit: Int, page: Int = 1, from: Date? = nil, to: Date? = nil, forceRefresh: Bool = false) async throws -> (tracks: [RecentTrack], totalPages: Int, total: Int) {
        let cacheKey = "recent_\(username)_\(limit)_\(page)_\(from?.timeIntervalSince1970 ?? -1)_\(to?.timeIntervalSince1970 ?? -1)"
        if !forceRefresh, let result: (tracks: [RecentTrack], totalPages: Int, total: Int) = cached(cacheKey) { return result }
        var parameters = ["user": username, "limit": "\(limit)", "page": "\(page)"]
        // Keep count metadata and local filtering on the same UTC interval.
        if let from { parameters["from"] = String(max(0, Int(from.timeIntervalSince1970))) }
        if let to { parameters["to"] = String(Int(to.timeIntervalSince1970)) }
        let url = try buildURL(method: "user.getrecenttracks", parameters: parameters)
        let response = try JSONDecoder().decode(RecentTracksResponse.self, from: try await data(from: url, forceRefresh: forceRefresh))
        let totalPages = Int(response.recenttracks.attr?.totalPages ?? "1") ?? 1
        let total = Int(response.recenttracks.attr?.total ?? "0") ?? 0
        let tracks = response.recenttracks.track.map { track in
            RecentTrack(name: track.name, artist: track.artist.text, album: track.album.text,
                        imageURL: track.image.last?.text, date: track.date?.uts,
                        nowPlaying: track.attr?.nowplaying == "true")
        }
        let result = (tracks, totalPages, total)
        setCache(cacheKey, value: result)
        return result
    }

    /// A fixed upper bound keeps pagination stable when new music is scrobbled during a load.
    /// Every page is fetched; a failed/incomplete load throws rather than inventing zero days.
    func getTracks(username: String, from: Date, to: Date, forceRefresh: Bool = false) async throws -> [RecentTrack] {
        var allTracks: [RecentTrack] = []
        var page = 1
        var totalPages = 1
        repeat {
            try Task.checkCancellation()
            let result = try await getRecentTracks(username: username, limit: 200, page: page, from: from, to: to, forceRefresh: forceRefresh)
            totalPages = result.totalPages
            let completed = result.tracks.filter { track in
                guard !track.nowPlaying, let uts = track.date, let seconds = TimeInterval(uts) else { return false }
                let date = Date(timeIntervalSince1970: seconds)
                return date >= from && date <= to
            }
            allTracks.append(contentsOf: completed)
            if result.tracks.isEmpty && page < totalPages { throw LastFMReadError.incompleteHistory }
            page += 1
        } while page <= totalPages
        return allTracks
    }

    /// Compatibility for older callers. Exact bounded analytics use getTracks instead.
    func getAllRecentTracks(username: String, maxPages: Int = 20) async throws -> [RecentTrack] {
        try await getTracks(username: username, from: Date(timeIntervalSince1970: 0), to: Date())
    }

    // MARK: - Top Artists
    
    func getTopArtists(username: String, limit: Int, period: String = "overall") async throws -> [TopArtist] {
        let cacheKey = "artists_\(username)_\(limit)_\(period)"
        if let cached: [TopArtist] = cached(cacheKey) {
            return cached
        }
        
        let url = try buildURL(method: "user.gettopartists", parameters: ["user": username, "limit": "\(limit)", "period": period])
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(TopArtistsResponse.self, from: data)
        
        var artists = response.topartists.artist.map { artist in
            TopArtist(
                name: artist.name,
                playcount: artist.playcount,
                imageURL: artist.image.last?.text,
                rank: Int(artist.attr?.rank ?? "0")
            )
        }
        
        // Replace placeholder images with real artist photos from Deezer
        let placeholderArtists = artists.filter { imageService.isPlaceholder($0.imageURL) }
        if !placeholderArtists.isEmpty {
            let names = placeholderArtists.map { $0.name }
            let images = await imageService.fetchArtistImages(for: names)
            
            for i in artists.indices {
                if let realImage = images[artists[i].name] {
                    artists[i] = TopArtist(
                        name: artists[i].name,
                        playcount: artists[i].playcount,
                        imageURL: realImage,
                        rank: artists[i].rank
                    )
                }
            }
        }
        
        setCache(cacheKey, value: artists)
        return artists
    }
    
    // MARK: - Top Albums
    
    func getTopAlbums(username: String, limit: Int, period: String = "overall") async throws -> [TopAlbum] {
        let url = try buildURL(method: "user.gettopalbums", parameters: ["user": username, "limit": "\(limit)", "period": period])
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(TopAlbumsResponse.self, from: data)
        
        return response.topalbums.album.map { album in
            TopAlbum(
                name: album.name,
                artist: album.artist.name,
                playcount: album.playcount,
                imageURL: album.image.last?.text,
                rank: Int(album.attr?.rank ?? "0")
            )
        }
    }
    
    // MARK: - Top Tracks
    
    func getTopTracks(username: String, limit: Int, period: String = "overall") async throws -> [TopTrack] {
        let url = try buildURL(method: "user.gettoptracks", parameters: ["user": username, "limit": "\(limit)", "period": period])
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(TopTracksResponse.self, from: data)
        
        return response.toptracks.track.map { track in
            TopTrack(
                name: track.name,
                artist: track.artist.name,
                playcount: track.playcount,
                imageURL: track.image.last?.text,
                rank: Int(track.attr?.rank ?? "0")
            )
        }
    }
    
    // MARK: - User Info
    
    func getUserInfo(username: String) async throws -> UserInfo {
        let url = try buildURL(method: "user.getinfo", parameters: ["user": username])
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        
        return UserInfo(
            name: response.user.name,
            realname: response.user.realname,
            imageURL: response.user.image.last?.text,
            playcount: response.user.playcount,
            artistCount: response.user.artistCount,
            albumCount: response.user.albumCount,
            trackCount: response.user.trackCount
        )
    }
    
    // MARK: - Scrobble Counts (for menu bar stats)
    
    /// Read the number of plays, not the number of unique artists.
    func getScrobbleCount(username: String, from: Date, to: Date) async throws -> Int {
        // Last.fm's recent-track metadata counts completed scrobbles in this range.
        let result = try await getRecentTracks(username: username, limit: 1, from: from, to: to, forceRefresh: true)
        return result.total
    }

    func getScrobbleCount(username: String, period: String) async throws -> Int {
        let now = Date()
        let calendar = Calendar.current
        let start: Date
        switch period {
        case "1day": start = calendar.startOfDay(for: now)
        case "7day": start = calendar.date(byAdding: .day, value: -7, to: now)!
        case "1month": start = calendar.date(byAdding: .month, value: -1, to: now)!
        case "3month": start = calendar.date(byAdding: .month, value: -3, to: now)!
        case "6month": start = calendar.date(byAdding: .month, value: -6, to: now)!
        case "12month": start = calendar.date(byAdding: .year, value: -1, to: now)!
        case "overall": start = Date(timeIntervalSince1970: 0)
        default: throw LastFMReadError.unsupportedPeriod
        }
        return try await getScrobbleCount(username: username, from: start, to: now)
    }

    // MARK: - Artist & Album Details (Inspector)

    func getArtistInfo(artist: String, username: String? = nil) async throws -> ArtistDetailInfo {
        let cacheKey = "artist_info_\(artist)_\(username ?? "")"
        if let cached: ArtistDetailInfo = cached(cacheKey) {
            return cached
        }

        var params = ["artist": artist]
        if let username = username, !username.isEmpty {
            params["username"] = username
        }

        let url = try buildURL(method: "artist.getinfo", parameters: params)
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(ArtistInfoResponse.self, from: data)
        let d = response.artist

        // Fetch top tracks for this artist concurrently
        var topTracks: [TopTrack] = []
        if let topTracksURL = try? buildURL(method: "artist.gettoptracks", parameters: ["artist": artist, "limit": "5"]) {
            if let (ttData, _) = try? await session.data(from: topTracksURL),
               let ttResponse = try? JSONDecoder().decode(TopTracksResponse.self, from: ttData) {
                topTracks = ttResponse.toptracks.track.map { t in
                    TopTrack(name: t.name, artist: t.artist.name, playcount: t.playcount, imageURL: t.image.last?.text, rank: Int(t.attr?.rank ?? "0"))
                }
            }
        }

        var image = d.image?.last?.text
        if imageService.isPlaceholder(image) {
            let fetched = await imageService.fetchArtistImages(for: [artist])
            if let realImg = fetched[artist] {
                image = realImg
            }
        }

        let cleanBio = cleanSummary(d.bio?.summary)
        let tags = d.tags?.tag?.map { $0.name } ?? []
        let webURL = d.url != nil ? URL(string: d.url!) : nil

        let result = ArtistDetailInfo(
            name: d.name,
            playcount: Int(d.stats?.playcount ?? "0") ?? 0,
            listeners: Int(d.stats?.listeners ?? "0") ?? 0,
            userPlaycount: Int(d.stats?.userplaycount ?? ""),
            bioSummary: cleanBio,
            tags: tags,
            topTracks: topTracks,
            imageURL: image,
            webURL: webURL
        )
        setCache(cacheKey, value: result)
        return result
    }

    func getAlbumInfo(artist: String, album: String, username: String? = nil) async throws -> AlbumDetailInfo {
        let cacheKey = "album_info_\(artist)_\(album)_\(username ?? "")"
        if let cached: AlbumDetailInfo = cached(cacheKey) {
            return cached
        }

        var params = ["artist": artist, "album": album]
        if let username = username, !username.isEmpty {
            params["username"] = username
        }

        let url = try buildURL(method: "album.getinfo", parameters: params)
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(AlbumInfoResponse.self, from: data)
        let d = response.album

        let parsedTracks = d.tracks?.track?.enumerated().map { (idx, t) in
            AlbumTrackInfo(
                name: t.name,
                duration: Int(t.duration ?? "0") ?? 0,
                rank: Int(t.attr?.rank ?? "\(idx + 1)") ?? (idx + 1)
            )
        } ?? []

        let cleanWiki = cleanSummary(d.wiki?.summary)
        let webURL = d.url != nil ? URL(string: d.url!) : nil

        let result = AlbumDetailInfo(
            name: d.name,
            artist: d.artist,
            playcount: Int(d.playcount ?? "0") ?? 0,
            listeners: Int(d.listeners ?? "0") ?? 0,
            userPlaycount: Int(d.userplaycount ?? ""),
            wikiSummary: cleanWiki.isEmpty ? nil : cleanWiki,
            releaseDate: d.wiki?.published,
            tracks: parsedTracks,
            imageURL: d.image?.last?.text,
            webURL: webURL
        )
        setCache(cacheKey, value: result)
        return result
    }

    private func cleanSummary(_ html: String?) -> String {
        guard let html = html, !html.isEmpty else { return "" }
        let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


enum LastFMReadError: LocalizedError {
    case api(code: Int, message: String)
    case incompleteHistory
    case unsupportedPeriod

    var errorDescription: String? {
        switch self {
        case .api(_, let message): return message
        case .incompleteHistory: return "Last.fm returned incomplete listening history. Please retry."
        case .unsupportedPeriod: return "This listening period is not supported."
        }
    }
}
