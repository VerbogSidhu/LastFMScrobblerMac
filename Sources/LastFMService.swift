import Foundation

class LastFMService {
    private let apiKey = "b5940532a8c9dfde75381c3060972a65"
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let imageService = ArtistImageService.shared
    
    /// URLSession with in-memory + disk caching (5 min memory, 30 min disk).
    /// Avoids re-fetching the same data when switching tabs.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 1 * 1024 * 1024,   // 1 MB memory
            diskCapacity: 5 * 1024 * 1024,      // 5 MB disk
            diskPath: "LastFMAPICache"
        )
        config.requestCachePolicy = .reloadRevalidatingCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    // MARK: - Recent Tracks
    
    func getRecentTracks(username: String, limit: Int, page: Int = 1) async throws -> (tracks: [RecentTrack], totalPages: Int, total: Int) {
        let url = URL(string: "\(baseURL)?method=user.getrecenttracks&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)&page=\(page)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(RecentTracksResponse.self, from: data)
        
        let totalPages = Int(response.recenttracks.attr?.totalPages ?? "1") ?? 1
        let total = Int(response.recenttracks.attr?.total ?? "0") ?? 0
        
        let tracks = response.recenttracks.track.map { track in
            RecentTrack(
                name: track.name,
                artist: track.artist.text,
                album: track.album.text,
                imageURL: track.image.last?.text,
                date: track.date?.uts,
                nowPlaying: track.attr?.nowplaying != nil
            )
        }
        
        return (tracks, totalPages, total)
    }
    
    /// Fetch all recent tracks across multiple pages (up to maxPages).
    func getAllRecentTracks(username: String, maxPages: Int = 20) async throws -> [RecentTrack] {
        var allTracks: [RecentTrack] = []
        var page = 1
        var totalPages = 1
        
        while page <= maxPages && page <= totalPages {
            let result = try await getRecentTracks(username: username, limit: 50, page: page)
            allTracks.append(contentsOf: result.tracks)
            totalPages = result.totalPages
            page += 1
        }
        
        return allTracks
    }
    
    // MARK: - Top Artists
    
    func getTopArtists(username: String, limit: Int, period: String = "overall") async throws -> [TopArtist] {
        let url = URL(string: "\(baseURL)?method=user.gettopartists&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)&period=\(period)")!
        let (data, _) = try await session.data(from: url)
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
        
        return artists
    }
    
    // MARK: - Top Albums
    
    func getTopAlbums(username: String, limit: Int, period: String = "overall") async throws -> [TopAlbum] {
        let url = URL(string: "\(baseURL)?method=user.gettopalbums&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)&period=\(period)")!
        let (data, _) = try await session.data(from: url)
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
        let url = URL(string: "\(baseURL)?method=user.gettoptracks&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)&period=\(period)")!
        let (data, _) = try await session.data(from: url)
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
        let url = URL(string: "\(baseURL)?method=user.getinfo&user=\(username)&api_key=\(apiKey)&format=json")!
        let (data, _) = try await session.data(from: url)
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
    
    /// Get scrobble count for a specific period by summing top artists' playcounts.
    func getScrobbleCount(username: String, period: String) async throws -> Int {
        let url = URL(string: "\(baseURL)?method=user.gettopartists&user=\(username)&api_key=\(apiKey)&format=json&limit=50&period=\(period)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TopArtistsResponse.self, from: data)
        return response.topartists.artist.reduce(0) { $0 + (Int($1.playcount) ?? 0) }
    }
}
