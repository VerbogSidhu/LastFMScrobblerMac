import Foundation
import Security

protocol CredentialBackend {
    func read(_ key: String) throws -> String?
    func write(_ value: String, for key: String) throws
    func delete(_ key: String) throws
}

struct KeychainCredentialBackend: CredentialBackend {
    private let service = "com.verbog.lastfm.credentials"

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    func read(_ key: String) throws -> String? {
        var request = query(key)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.storageFailure(status)
        }
        return value
    }

    func write(_ value: String, for key: String) throws {
        let attributes = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw CredentialStoreError.storageFailure(status) }
        var request = query(key)
        request[kSecValueData as String] = Data(value.utf8)
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(request as CFDictionary, nil)
        guard added == errSecSuccess else { throw CredentialStoreError.storageFailure(added) }
    }

    func delete(_ key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.storageFailure(status)
        }
    }
}

enum CredentialStoreError: LocalizedError {
    case storageFailure(OSStatus)
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .storageFailure: return "Your credentials could not be accessed in Keychain. Unlock your login keychain and try again."
        case .missingCredentials: return "Enter both your Last.fm API key and API secret."
        }
    }
}

/// Only the API key and account name remain in preferences. Secrets live in Keychain.
final class CredentialStore {
    static let shared = CredentialStore()
    private let defaults: UserDefaults
    private let backend: CredentialBackend
    private let lock = NSRecursiveLock()

    init(defaults: UserDefaults = .standard, backend: CredentialBackend = KeychainCredentialBackend()) {
        self.defaults = defaults
        self.backend = backend
    }

    var apiKey: String { locked { defaults.string(forKey: "lastfm_api_key") ?? "" } }
    var apiSecret: String { locked { (try? backend.read("apiSecret")) ?? defaults.string(forKey: "lastfm_api_secret") ?? "" } }
    var sessionKey: String? { locked { (try? backend.read("sessionKey")) ?? defaults.string(forKey: "lastfm_session_key") } }
    var username: String? {
        locked {
            guard sessionKey != nil else { return nil }
            return defaults.string(forKey: "lastfm_authenticated_username") ?? defaults.string(forKey: "lastfm_username")
        }
    }

    func credentialSnapshot() -> (key: String, secret: String) {
        locked { (apiKey, apiSecret) }
    }

    /// Keep both legacy values until every Keychain write has succeeded.
    func migrateLegacyDefaults() throws {
        try locked {
            let legacySecret = defaults.string(forKey: "lastfm_api_secret")
            let legacySession = defaults.string(forKey: "lastfm_session_key")
            if let secret = legacySecret, try backend.read("apiSecret") == nil {
                try backend.write(secret, for: "apiSecret")
            }
            if let session = legacySession, try backend.read("sessionKey") == nil {
                try backend.write(session, for: "sessionKey")
            }
            if let secret = legacySecret, try backend.read("apiSecret") != secret {
                throw CredentialStoreError.storageFailure(errSecInternalError)
            }
            if let session = legacySession, try backend.read("sessionKey") != session {
                throw CredentialStoreError.storageFailure(errSecInternalError)
            }
            defaults.removeObject(forKey: "lastfm_api_secret")
            defaults.removeObject(forKey: "lastfm_session_key")
        }
    }

    func saveCredentials(apiKey: String, apiSecret: String) throws {
        try locked {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let secret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !secret.isEmpty else { throw CredentialStoreError.missingCredentials }
            let previous = credentialSnapshot()
            let changed = (!previous.key.isEmpty && previous.key != key) || (!previous.secret.isEmpty && previous.secret != secret)
            try backend.write(secret, for: "apiSecret")
            if changed {
                do { try backend.delete("sessionKey") }
                catch {
                    if !previous.secret.isEmpty { try? backend.write(previous.secret, for: "apiSecret") }
                    throw error
                }
                defaults.removeObject(forKey: "lastfm_session_key")
                defaults.removeObject(forKey: "lastfm_authenticated_username")
            }
            defaults.set(key, forKey: "lastfm_api_key")
            defaults.removeObject(forKey: "lastfm_api_secret")
        }
    }

    func saveSession(key: String, username: String) throws {
        try locked {
            guard !key.isEmpty, !username.isEmpty else { throw CredentialStoreError.missingCredentials }
            try backend.write(key, for: "sessionKey")
            defaults.set(username, forKey: "lastfm_authenticated_username")
            defaults.set(username, forKey: "lastfm_username")
            defaults.removeObject(forKey: "lastfm_session_key")
        }
    }

    func clear() throws {
        try locked {
            try backend.delete("sessionKey")
            try backend.delete("apiSecret")
            for key in ["lastfm_api_key", "lastfm_api_secret", "lastfm_session_key", "lastfm_authenticated_username", "lastfm_username"] {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }
}
