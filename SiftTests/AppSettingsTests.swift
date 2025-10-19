import XCTest
@testable import Sift

@MainActor
final class AppSettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "tmdb_api_key")
    }

    func testDefaultAPIKeyEmpty() {
        let s = AppSettings()
        XCTAssertEqual(s.tmdbAPIKey, "")
    }

    func testAPIKeyPersists() {
        var s: AppSettings? = AppSettings()
        s?.tmdbAPIKey = "abc123"
        s = nil
        let s2 = AppSettings()
        XCTAssertEqual(s2.tmdbAPIKey, "abc123")
    }
}
