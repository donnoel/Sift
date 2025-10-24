import XCTest
@testable import Sift

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaultAPIKeyEmpty() {
        let suiteName = "SiftTests-AppSettings-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: suite)
        XCTAssertEqual(settings.tmdbAPIKey, "")
    }

    func testAPIKeyPersistsRoundTrip() {
        let suiteName = "SiftTests-AppSettings-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: suite)
        settings.tmdbAPIKey = "abc123"
        XCTAssertEqual(settings.tmdbAPIKey, "abc123")
    }
}
