import XCTest
@testable import Sift

@MainActor
final class AppSettingsTests: XCTestCase {
    var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: "AppSettingsTests.suite")
        precondition(suite != nil, "Failed to create isolated UserDefaults suite")
        suite.removePersistentDomain(forName: "AppSettingsTests.suite")
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: "AppSettingsTests.suite")
        suite = nil
        super.tearDown()
    }

    func testDefaultAPIKeyEmpty() {
        let s = AppSettings(defaults: suite)
        XCTAssertEqual(s.tmdbAPIKey, "")
    }

    func testAPIKeyPersists() {
        var s: AppSettings? = AppSettings(defaults: suite)
        s?.tmdbAPIKey = "abc123"
        s = nil
        let s2 = AppSettings(defaults: suite)
        XCTAssertEqual(s2.tmdbAPIKey, "abc123")
    }
}
