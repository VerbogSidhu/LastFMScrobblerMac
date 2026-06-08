import Foundation

// MARK: - Models

struct RecentTrack: Identifiable, Codable {
    let id = UUID()
    let name: String
    let artist: String
    let album: String
    let imageURL: String?
    let date: String?
    let nowPlaying: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case artist
        case album
        case imageURL = "image"
        case date
        case nowPlaying = "@attr"
    }
}

struct TopArtist: Identifiable, Codable {
    let id = UUID()
    let name: String
    let playcount: String
    let imageURL: String?
    let rank: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case playcount
        case imageURL = "image"
        case rank
    }
}

struct TopAlbum: Identifiable, Codable {
    let id = UUID()
    let name: String
    let artist: String
    let playcount: String
    let imageURL: String?
    let rank: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case artist
        case playcount
        case imageURL = "image"
        case rank
    }
}

struct UserInfo: Codable {
    let name: String
    let realname: String?
    let imageURL: String?
    let playcount: String
    let artistCount: String
    let albumCount: String
    let trackCount: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case realname
        case imageURL = "image"
        case playcount
        case artistCount = "artist_count"
        case albumCount = "album_count"
        case trackCount = "track_count"
    }
}

// MARK: - API Response Wrappers

struct RecentTracksResponse: Codable {
    let recenttracks: RecentTracksContainer
}

struct RecentTracksContainer: Codable {
    let track: [LastFMTrack]
}

struct LastFMTrack: Codable {
    let name: String
    let artist: LastFMNameValue
    let album: LastFMNameValue
    let image: [LastFMImage]
    let date: LastFMDate?
    let attr: TrackAttr?
    
    enum CodingKeys: String, CodingKey {
        case name, artist, album, image, date
        case attr = "@attr"
    }
    
    struct LastFMNameValue: Codable {
        let text: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
        }
    }
    
    struct LastFMImage: Codable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
    
    struct LastFMDate: Codable {
        let uts: String
    }
    
    struct TrackAttr: Codable {
        let nowplaying: String?
    }
}

struct TopArtistsResponse: Codable {
    let topartists: TopArtistsContainer
}

struct TopArtistsContainer: Codable {
    let artist: [LastFMArtist]
}

struct LastFMArtist: Codable {
    let name: String
    let playcount: String
    let image: [LastFMImage]
    let attr: ArtistAttr?
    
    enum CodingKeys: String, CodingKey {
        case name, playcount, image
        case attr = "@attr"
    }
    
    struct ArtistAttr: Codable {
        let rank: String
    }
    
    struct LastFMImage: Codable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
}

struct TopAlbumsResponse: Codable {
    let topalbums: TopAlbumsContainer
}

struct TopAlbumsContainer: Codable {
    let album: [LastFMAlbum]
}

struct LastFMAlbum: Codable {
    let name: String
    let artist: AlbumArtist
    let playcount: String
    let image: [LastFMImage]
    let attr: AlbumAttr?
    
    enum CodingKeys: String, CodingKey {
        case name, artist, playcount, image
        case attr = "@attr"
    }
    
    struct AlbumArtist: Codable {
        let name: String
    }
    
    struct AlbumAttr: Codable {
        let rank: String
    }
    
    struct LastFMImage: Codable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
}

struct UserInfoResponse: Codable {
    let user: LastFMUser
}

struct LastFMUser: Codable {
    let name: String
    let realname: String?
    let image: [LastFMImage]
    let playcount: String
    let artistCount: String
    let albumCount: String
    let trackCount: String
    
    enum CodingKeys: String, CodingKey {
        case name, realname, image, playcount
        case artistCount = "artist_count"
        case albumCount = "album_count"
        case trackCount = "track_count"
    }
    
    struct LastFMImage: Codable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
}
