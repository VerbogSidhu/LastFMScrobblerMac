import Foundation

// MARK: - Domain Models

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

// MARK: - Stats Period

enum StatsPeriod: String, CaseIterable, Identifiable {
    case sevenDays = "7day"
    case oneMonth = "1month"
    case threeMonths = "3month"
    case sixMonths = "6month"
    case oneYear = "12month"
    case overall = "overall"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .overall: return "All Time"
        }
    }
}

// MARK: - Inspector & Drill-Down Models

enum InspectorEntity: Identifiable, Equatable {
    case artist(name: String)
    case album(artist: String, album: String)
    
    var id: String {
        switch self {
        case .artist(let name): return "artist_\(name)"
        case .album(let artist, let album): return "album_\(artist)_\(album)"
        }
    }
}

struct ArtistDetailInfo {
    let name: String
    let playcount: Int
    let listeners: Int
    let userPlaycount: Int?
    let bioSummary: String
    let tags: [String]
    let topTracks: [TopTrack]
    let imageURL: String?
    let webURL: URL?
}

struct AlbumDetailInfo {
    let name: String
    let artist: String
    let playcount: Int
    let listeners: Int
    let userPlaycount: Int?
    let wikiSummary: String?
    let releaseDate: String?
    let tracks: [AlbumTrackInfo]
    let imageURL: String?
    let webURL: URL?
}

struct AlbumTrackInfo: Identifiable {
    let id = UUID()
    let name: String
    let duration: Int
    let rank: Int
}
