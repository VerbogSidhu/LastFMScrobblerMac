import Foundation
import CryptoKit
import AppKit

/// Handles Last.fm API authentication and scrobble submission.
class ScrobbleService {
    // Default API key (same as read-only). Users should register their own app
    // at https://www.last.fm/api/account/create to get a secret for scrobbling.
    static let defaultAPIKey = ""
    
    private let apiKey: String
    private let apiSecret: String
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let session = URLSession.shared
    
    init(apiKey: String = ScrobbleService.defaultAPIKey, apiSecret: String = "") {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }
    
    var isConfigured: Bool {
        !apiSecret.isEmpty
    }
    
    // MARK: - API Signature
    
    private func apiSignature(params: [String: String]) -> String {
        let sorted = params.sorted { $0.key < $1.key }
        var combined = ""
        for (key, value) in sorted {
            combined += key + value
        }
        combined += apiSecret
        
        let digest = Insecure.MD5.hash(data: Data(combined.utf8))
        let sig = digest.map { String(format: "%02x", $0) }.joined()
        
        #if DEBUG
        NSLog("[Scrobble] computed_sig: %@", sig)
        #endif
        
        return sig
    }
    
    // MARK: - URL Helper
    
    /// Safely constructs the base Last.fm API URL, throwing if the URL is invalid.
    private func lastFMURL() throws -> URL {
        guard let url = URL(string: baseURL) else {
            throw ScrobbleError.invalidURL
        }
        return url
    }
    
    // MARK: - Authentication
    
    /// Step 1: Get a request token (no signature needed).
    func getRequestToken() async throws -> String {
        guard let url = URL(string: "\(baseURL)?method=auth.getToken&api_key=\(apiKey)&format=json") else {
            throw ScrobbleError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let token = json?["token"] as? String else {
            throw ScrobbleError.noToken
        }
        return token
    }
    
    /// Step 2: Open browser for user authorization.
    func openAuthorization(token: String) {
        let urlString = "https://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Step 3: Get session key after user authorizes (signed call).
    func getSession(token: String) async throws -> String {
        var params = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token
        ]
        params["api_sig"] = apiSignature(params: params)
        params["format"] = "json"
        
        let queryString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        guard let url = URL(string: "\(baseURL)?\(queryString)") else {
            throw ScrobbleError.invalidURL
        }
        let (data, _) = try await session.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let session = json?["session"] as? [String: Any],
              let sessionKey = session["key"] as? String else {
            throw ScrobbleError.noSession
        }
        return sessionKey
    }
    
    // MARK: - Scrobble
    
    /// Submit a scrobble to Last.fm.
    func scrobble(track: String, artist: String, album: String, duration: Int, timestamp: Int, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.scrobble",
            "api_key": apiKey,
            "sk": sessionKey,
            "track": track,
            "artist": artist,
            "timestamp": String(timestamp),
            "duration": String(duration),
            "album": album
        ]
        
        NSLog("[Scrobble] Params: track=%@ artist=%@ album=%@ dur=%d ts=%d", track, artist, album, duration, timestamp)
        
        params["api_sig"] = apiSignature(params: params)
        params["format"] = "json"
        
        let queryString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        var request = URLRequest(url: try lastFMURL())
        request.httpMethod = "POST"
        request.httpBody = queryString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        let jsonString = String(data: data, encoding: .utf8) ?? "NO BODY"
        NSLog("[Scrobble] HTTP %d — %@", statusCode, jsonString)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let scrobbles = json?["scrobbles"] as? [String: Any],
           let attr = scrobbles["@attr"] as? [String: Any],
           let accepted = attr["accepted"] as? Int, accepted > 0 {
            NSLog("[Scrobble] Accepted: %d track(s)", accepted)
        } else if let error = json?["error"] as? Int {
            let message = json?["message"] as? String ?? "unknown"
            NSLog("[Scrobble] API error %d: %@", error, message)
            throw ScrobbleError.apiError(error)
        } else {
            NSLog("[Scrobble] Unexpected response: %@", "\(json ?? [:])")
        }
    }
    
    // MARK: - Love / Unlove
    
    /// Love a track on Last.fm.
    func loveTrack(track: String, artist: String, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.love",
            "api_key": apiKey,
            "sk": sessionKey,
            "track": track,
            "artist": artist
        ]
        params["api_sig"] = apiSignature(params: params)
        params["format"] = "json"
        
        let queryString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        var request = URLRequest(url: try lastFMURL())
        request.httpMethod = "POST"
        request.httpBody = queryString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw ScrobbleError.apiError(statusCode)
        }
    }
    
    /// Unlove a track on Last.fm.
    func unloveTrack(track: String, artist: String, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.unlove",
            "api_key": apiKey,
            "sk": sessionKey,
            "track": track,
            "artist": artist
        ]
        params["api_sig"] = apiSignature(params: params)
        params["format"] = "json"
        
        let queryString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        var request = URLRequest(url: try lastFMURL())
        request.httpMethod = "POST"
        request.httpBody = queryString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw ScrobbleError.apiError(statusCode)
        }
    }
    
    /// Update now-playing status.
    func updateNowPlaying(track: String, artist: String, album: String, duration: Int, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "api_key": apiKey,
            "sk": sessionKey,
            "track": track,
            "artist": artist,
            "duration": String(duration),
            "album": album
        ]
        params["api_sig"] = apiSignature(params: params)
        params["format"] = "json"
        
        let queryString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        var request = URLRequest(url: try lastFMURL())
        request.httpMethod = "POST"
        request.httpBody = queryString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        let jsonString = String(data: data, encoding: .utf8) ?? "NO BODY"
        NSLog("[NowPlaying] HTTP %d — %@", statusCode, jsonString)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let error = json?["error"] as? Int {
            let message = json?["message"] as? String ?? "unknown"
            NSLog("[NowPlaying] API error %d: %@", error, message)
        }
    }
}

enum ScrobbleError: LocalizedError {
    case noToken
    case noSession
    case apiError(Int)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .noToken: return "Failed to get request token from Last.fm"
        case .noSession: return "Failed to get session — did you authorize?"
        case .apiError(let code): return "Last.fm API error: \(code)"
        case .invalidURL: return "Invalid URL configuration"
        }
    }
}
