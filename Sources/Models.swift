import Foundation

// MARK: - Shared Models

struct LastFMImage: Codable {
    let text: String
    let size: String
    
    enum CodingKeys: String, CodingKey {
        case text = "#text"
        case size
    }
}

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
    let playcount: Int
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
    let playcount: Int
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

struct TopTrack: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
    let playcount: Int
    let imageURL: String?
    let rank: Int?
}

struct TopTracksResponse: Codable {
    let toptracks: TopTracksContainer
}

struct TopTracksContainer: Codable {
    let track: [LastFMTopTrack]
    let attr: TopTracksAttr?
    
    enum CodingKeys: String, CodingKey {
        case track
        case attr = "@attr"
    }
}

struct LastFMTopTrack: Codable {
    let name: String
    let artist: LastFMTopTrackArtist
    let playcount: Int
    let image: [LastFMTopTrackImage]
    let attr: TrackRankAttr?
    
    enum CodingKeys: String, CodingKey {
        case name, artist, playcount, image
        case attr = "@attr"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        artist = try container.decode(LastFMTopTrackArtist.self, forKey: .artist)
        let playcountStr = try container.decode(String.self, forKey: .playcount)
        playcount = Int(playcountStr) ?? 0
        image = try container.decode([LastFMTopTrackImage].self, forKey: .image)
        attr = try container.decodeIfPresent(TrackRankAttr.self, forKey: .attr)
    }
    
    struct LastFMTopTrackArtist: Codable {
        let name: String
    }
    
    struct TrackRankAttr: Codable {
        let rank: String
    }
    
    struct LastFMTopTrackImage: Codable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
}

struct TopTracksAttr: Codable {
    let totalPages: String?
    let page: String?
    let perPage: String?
    let total: String?
    
    enum CodingKeys: String, CodingKey {
        case totalPages = "totalPages"
        case page, perPage, total
    }
}

struct UserInfo: Codable {
    let name: String
    let realname: String?
    let imageURL: String?
    let playcount: Int
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
    let attr: RecentTracksAttr?
    
    enum CodingKeys: String, CodingKey {
        case track
        case attr = "@attr"
    }
}

struct RecentTracksAttr: Codable {
    let user: String?
    let totalPages: String?
    let page: String?
    let perPage: String?
    let total: String?
    
    enum CodingKeys: String, CodingKey {
        case user
        case totalPages = "totalPages"
        case page, perPage, total
    }
}

struct TopListAttr: Codable {
    let user: String?
    let totalPages: String?
    let page: String?
    let perPage: String?
    let total: String?
    
    enum CodingKeys: String, CodingKey {
        case user
        case totalPages = "totalPages"
        case page, perPage, total
    }
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
    let attr: TopListAttr?
    
    enum CodingKeys: String, CodingKey {
        case artist
        case attr = "@attr"
    }
}

struct LastFMArtist: Codable {
    let name: String
    let playcount: Int
    let image: [LastFMImage]
    let attr: ArtistAttr?
    
    enum CodingKeys: String, CodingKey {
        case name, playcount, image
        case attr = "@attr"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let playcountStr = try container.decode(String.self, forKey: .playcount)
        playcount = Int(playcountStr) ?? 0
        image = try container.decode([LastFMImage].self, forKey: .image)
        attr = try container.decodeIfPresent(ArtistAttr.self, forKey: .attr)
    }

    struct ArtistAttr: Codable {
        let rank: String
    }
}

struct TopAlbumsResponse: Codable {
    let topalbums: TopAlbumsContainer
}

struct TopAlbumsContainer: Codable {
    let album: [LastFMAlbum]
    let attr: TopListAttr?
    
    enum CodingKeys: String, CodingKey {
        case album
        case attr = "@attr"
    }
}

struct LastFMAlbum: Codable {
    let name: String
    let artist: AlbumArtist
    let playcount: Int
    let image: [LastFMImage]
    let attr: AlbumAttr?
    
    enum CodingKeys: String, CodingKey {
        case name, artist, playcount, image
        case attr = "@attr"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        artist = try container.decode(AlbumArtist.self, forKey: .artist)
        let playcountStr = try container.decode(String.self, forKey: .playcount)
        playcount = Int(playcountStr) ?? 0
        image = try container.decode([LastFMImage].self, forKey: .image)
        attr = try container.decodeIfPresent(AlbumAttr.self, forKey: .attr)
    }

    struct AlbumArtist: Codable {
        let name: String
    }

    struct AlbumAttr: Codable {
        let rank: String
    }
}

struct UserInfoResponse: Codable {
    let user: LastFMUser
}

struct LastFMUser: Codable {
    let name: String
    let realname: String?
    let image: [LastFMImage]
    let playcount: Int
    let artistCount: String
    let albumCount: String
    let trackCount: String
    
    enum CodingKeys: String, CodingKey {
        case name, realname, image, playcount
        case artistCount = "artist_count"
        case albumCount = "album_count"
        case trackCount = "track_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        realname = try container.decodeIfPresent(String.self, forKey: .realname)
        image = try container.decode([LastFMImage].self, forKey: .image)
        let playcountStr = try container.decode(String.self, forKey: .playcount)
        playcount = Int(playcountStr) ?? 0
        artistCount = try container.decode(String.self, forKey: .artistCount)
        albumCount = try container.decode(String.self, forKey: .albumCount)
        trackCount = try container.decode(String.self, forKey: .trackCount)
    }
}
