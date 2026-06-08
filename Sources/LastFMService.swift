import Foundation

class LastFMService {
    private let apiKey = "YOUR_API_KEY"
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let session = URLSession.shared
    private let imageService = ArtistImageService.shared
    
    func getRecentTracks(username: String, limit: Int) async throws -> [RecentTrack] {
        let url = URL(string: "\(baseURL)?method=user.getrecenttracks&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(RecentTracksResponse.self, from: data)
        
        return response.recenttracks.track.map { track in
            RecentTrack(
                name: track.name,
                artist: track.artist.text,
                album: track.album.text,
                imageURL: track.image.last?.text,
                date: track.date?.uts,
                nowPlaying: track.attr?.nowplaying != nil
            )
        }
    }
    
    func getTopArtists(username: String, limit: Int) async throws -> [TopArtist] {
        let url = URL(string: "\(baseURL)?method=user.gettopartists&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)")!
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
    
    func getTopAlbums(username: String, limit: Int) async throws -> [TopAlbum] {
        let url = URL(string: "\(baseURL)?method=user.gettopalbums&user=\(username)&api_key=\(apiKey)&format=json&limit=\(limit)")!
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
}
