import Testing
import Foundation
@testable import LastFM

final class CredentialsMemoryBackend: CredentialBackend {
    var values: [String: String] = [:]
    var rejectedWriteKey: String?
    func read(_ key: String) throws -> String? { values[key] }
    func write(_ value: String, for key: String) throws {
        if key == rejectedWriteKey { throw CredentialStoreError.storageFailure(-1) }
        values[key] = value
    }
    func delete(_ key: String) throws { values.removeValue(forKey: key) }
}

@Suite(.serialized)
struct CredentialsTests {
    private func environment() -> (UserDefaults, String) {
        let domain = "LastFMCredentialsTest-\(UUID().uuidString)"
        return (UserDefaults(suiteName: domain)!, domain)
    }
    @Test func testMigrationRemovesPlaintextOnlyAfterBothSecretsPersist() throws {
        let (defaults, domain) = environment()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("secret-fixture", forKey: "lastfm_api_secret")
        defaults.set("session-fixture", forKey: "lastfm_session_key")
        defaults.set("UserA", forKey: "lastfm_username")
        let backend = CredentialsMemoryBackend()
        let store = CredentialStore(defaults: defaults, backend: backend)
        try store.migrateLegacyDefaults()
        #expect(defaults.object(forKey: "lastfm_api_secret") == nil)
        #expect(defaults.object(forKey: "lastfm_session_key") == nil)
        #expect(store.apiSecret == "secret-fixture")
        #expect(store.sessionKey == "session-fixture")
        #expect(store.username == "UserA")
    }
    @Test func testMigrationFailurePreservesBothLegacyValues() {
        let (defaults, domain) = environment()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("secret-fixture", forKey: "lastfm_api_secret")
        defaults.set("session-fixture", forKey: "lastfm_session_key")
        let backend = CredentialsMemoryBackend(); backend.rejectedWriteKey = "sessionKey"
        let store = CredentialStore(defaults: defaults, backend: backend)
        #expect(throws: (any Error).self) { try store.migrateLegacyDefaults() }
        #expect(defaults.string(forKey: "lastfm_api_secret") == "secret-fixture")
        #expect(defaults.string(forKey: "lastfm_session_key") == "session-fixture")
    }
    @Test func testSavingAuthenticatedIdentityBindsDisplayedUsername() throws {
        let (defaults, domain) = environment()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("UnrelatedName", forKey: "lastfm_username")
        let store = CredentialStore(defaults: defaults, backend: CredentialsMemoryBackend())
        try store.saveSession(key: "session-fixture", username: "ActualAccount")
        #expect(store.username == "ActualAccount")
        #expect(defaults.string(forKey: "lastfm_username") == "ActualAccount")
        #expect(store.sessionKey == "session-fixture")
        #expect(defaults.object(forKey: "lastfm_session_key") == nil)
    }
    @Test func testClearRemovesCredentialsAndAuthenticatedIdentity() throws {
        let (defaults, domain) = environment()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = CredentialStore(defaults: defaults, backend: CredentialsMemoryBackend())
        try store.saveCredentials(apiKey: "key-fixture", apiSecret: "secret-fixture")
        try store.saveSession(key: "session-fixture", username: "ActualAccount")
        try store.clear()
        #expect(store.apiKey == "")
        #expect(store.apiSecret == "")
        #expect(store.sessionKey == nil)
        #expect(store.username == nil)
    }
    @Test func testChangingAPIApplicationInvalidatesOldSession() throws {
        let (defaults, domain) = environment()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = CredentialStore(defaults: defaults, backend: CredentialsMemoryBackend())
        try store.saveCredentials(apiKey: "first-key", apiSecret: "first-secret")
        try store.saveSession(key: "old-session", username: "UserA")
        try store.saveCredentials(apiKey: "second-key", apiSecret: "second-secret")
        #expect(store.sessionKey == nil)
        #expect(store.username == nil)
        #expect(store.apiKey == "second-key")
    }
}
