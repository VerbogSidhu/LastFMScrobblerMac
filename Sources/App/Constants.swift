import Foundation

enum Constants {
    static let lastFMBaseURL = "https://ws.audioscrobbler.com/2.0/"
    static let lastFMReadonlyAPIKey = "b5940532a8c9dfde75381c3060972a65"

    static var lastFMUsername: String {
        UserDefaults.standard.string(forKey: "lastfm_username") ?? ""
    }

    static func setUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: "lastfm_username")
    }
}
