import Foundation
import CryptoKit
import AppKit

struct AuthenticatedSession {
    let key: String
    let name: String
}

/// Signed Last.fm writes. A normal return always means the server accepted the operation.
final class ScrobbleService {
    static let defaultAPIKey = ""
    private let explicitCredentials: (key: String, secret: String)?
    private let credentialStore: CredentialStore
    private let session: URLSession
    private let baseURL = URL(string: "https://ws.audioscrobbler.com/2.0/")!

    init(apiKey: String? = nil, apiSecret: String? = nil, session: URLSession = .shared, credentialStore: CredentialStore = .shared) {
        self.explicitCredentials = apiKey != nil || apiSecret != nil ? (apiKey ?? "", apiSecret ?? "") : nil
        self.credentialStore = credentialStore
        self.session = session
    }

    private var credentials: (key: String, secret: String) {
        explicitCredentials ?? credentialStore.credentialSnapshot()
    }

    var isConfigured: Bool {
        let value = credentials
        return !value.key.isEmpty && !value.secret.isEmpty
    }

    private func signature(_ parameters: [String: String], secret: String) -> String {
        let payload = parameters.sorted { $0.key < $1.key }.map { $0.key + $0.value }.joined() + secret
        return Insecure.MD5.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func post(_ method: String, parameters: [String: String]) async throws -> (json: [String: Any], data: Data, status: Int) {
        let value = credentials
        guard !value.key.isEmpty, !value.secret.isEmpty else { throw ScrobbleError.notConfigured }
        var params = parameters
        params["method"] = method
        params["api_key"] = value.key
        params["api_sig"] = signature(params, secret: value.secret)
        params["format"] = "json"
        var components = URLComponents()
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        return try await response(for: request)
    }

    private func response(for request: URLRequest) async throws -> (json: [String: Any], data: Data, status: Int) {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        // API codes explain permanent/auth failures even when HTTP status is not 200.
        if let json, let code = integer(json["error"]) {
            throw ScrobbleError.apiError(code, json["message"] as? String ?? "The request was rejected")
        }
        guard (200...299).contains(status) else { throw ScrobbleError.httpError(status) }
        guard let json else { throw ScrobbleError.malformedResponse }
        return (json, data, status)
    }

    func getRequestToken() async throws -> String {
        let value = credentials
        guard !value.key.isEmpty else { throw ScrobbleError.notConfigured }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "method", value: "auth.getToken"), URLQueryItem(name: "api_key", value: value.key), URLQueryItem(name: "format", value: "json")]
        guard let url = components.url else { throw ScrobbleError.invalidURL }
        let result = try await response(for: URLRequest(url: url))
        guard let token = result.json["token"] as? String, !token.isEmpty else { throw ScrobbleError.noToken }
        return token
    }

    func openAuthorization(token: String) {
        var components = URLComponents(string: "https://www.last.fm/api/auth/")!
        components.queryItems = [URLQueryItem(name: "api_key", value: credentials.key), URLQueryItem(name: "token", value: token)]
        if let url = components.url {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
    }

    func getAuthenticatedSession(token: String) async throws -> AuthenticatedSession {
        let result = try await post("auth.getSession", parameters: ["token": token])
        guard let session = result.json["session"] as? [String: Any],
              let key = session["key"] as? String, !key.isEmpty,
              let name = session["name"] as? String, !name.isEmpty else { throw ScrobbleError.noSession }
        return AuthenticatedSession(key: key, name: name)
    }

    func getAuthenticatedUsername(sessionKey: String) async throws -> String {
        let result = try await post("user.getInfo", parameters: ["sk": sessionKey])
        guard let user = result.json["user"] as? [String: Any],
              let name = user["name"] as? String, !name.isEmpty else { throw ScrobbleError.malformedResponse }
        return name
    }

    func getSession(token: String) async throws -> String {
        try await getAuthenticatedSession(token: token).key
    }

    func scrobble(track: String, artist: String, album: String, duration: Int, timestamp: Int, sessionKey: String) async throws {
        let result = try await post("track.scrobble", parameters: ["sk": sessionKey, "track": track, "artist": artist, "timestamp": String(timestamp), "duration": String(duration), "album": album])
        guard let scrobbles = result.json["scrobbles"] as? [String: Any],
              let attr = scrobbles["@attr"] as? [String: Any],
              let accepted = integer(attr["accepted"]), let ignored = integer(attr["ignored"]) else {
            throw ScrobbleError.malformedResponse
        }
        guard accepted == 1 && ignored == 0 else {
            if ignored > 0 {
                let entry = (scrobbles["scrobble"] as? [String: Any]) ?? (scrobbles["scrobble"] as? [[String: Any]])?.first
                let message = entry?["ignoredMessage"] as? [String: Any]
                throw ScrobbleError.ignored(integer(message?["code"]) ?? 0, message?["#text"] as? String ?? "Last.fm did not accept this play")
            }
            throw ScrobbleError.malformedResponse
        }
    }

    func loveTrack(track: String, artist: String, sessionKey: String) async throws {
        _ = try await post("track.love", parameters: ["sk": sessionKey, "track": track, "artist": artist])
    }

    func unloveTrack(track: String, artist: String, sessionKey: String) async throws {
        _ = try await post("track.unlove", parameters: ["sk": sessionKey, "track": track, "artist": artist])
    }

    func updateNowPlaying(track: String, artist: String, album: String, duration: Int, sessionKey: String) async throws -> (Int, String) {
        let result = try await post("track.updateNowPlaying", parameters: ["sk": sessionKey, "track": track, "artist": artist, "album": album, "duration": String(duration)])
        guard let nowPlaying = result.json["nowplaying"] as? [String: Any],
              let message = nowPlaying["ignoredMessage"] as? [String: Any],
              let code = integer(message["code"]) else { throw ScrobbleError.malformedResponse }
        guard code == 0 else { throw ScrobbleError.ignored(code, message["#text"] as? String ?? "Now playing was ignored") }
        return (result.status, String(data: result.data, encoding: .utf8) ?? "")
    }

    private func integer(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        return nil
    }
}

enum ScrobbleError: LocalizedError {
    case noToken
    case noSession
    case apiError(Int, String)
    case invalidURL
    case notConfigured
    case malformedResponse
    case httpError(Int)
    case ignored(Int, String)

    var isAuthenticationError: Bool {
        switch self {
        case .noSession, .notConfigured: return true
        case .apiError(let code, _): return [4, 9, 10, 13, 26].contains(code)
        default: return false
        }
    }

    var isRetryable: Bool {
        switch self {
        case .apiError(let code, _): return [11, 16, 29].contains(code)
        case .httpError(let code): return code == 408 || code == 429 || code >= 500
        case .malformedResponse: return true
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .noToken: return "Last.fm did not provide an authorization token. Please try again."
        case .noSession: return "Last.fm has not authorized this session yet."
        case .apiError(let code, let message): return "Last.fm error \(code): \(message)"
        case .invalidURL: return "The Last.fm address is invalid."
        case .notConfigured: return "Enter an API key and secret in Account settings, then connect to Last.fm."
        case .malformedResponse: return "Last.fm returned an incomplete response. This play has not been marked accepted."
        case .httpError(let code): return "Last.fm could not complete the request (HTTP \(code))."
        case .ignored(_, let message): return "Last.fm ignored this play: \(message)"
        }
    }
}
