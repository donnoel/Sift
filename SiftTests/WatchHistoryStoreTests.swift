
import XCTest
@testable import Sift

@MainActor
final class WatchHistoryStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var cloudStore: StubUbiquitousKeyValueStore!
    private var history: WatchHistoryStore!

    override func setUp() {
        super.setUp()

        suiteName = "WatchHistoryStoreTests_\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults with suite \(suiteName!)")
        }
        defaults.removePersistentDomain(forName: suiteName)

        self.defaults = defaults
        cloudStore = StubUbiquitousKeyValueStore()
        history = WatchHistoryStore(defaults: defaults, store: cloudStore)
    }

    override func tearDown() {
        history = nil
        cloudStore = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil

        super.tearDown()
    }

    func testClearMarkUnwatch() {
        history.clearAll()
        XCTAssertTrue(history.watched.isEmpty)

        history.markWatched(101, on: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(history.watched[101], Date(timeIntervalSince1970: 10))

        history.unwatch(101)
        XCTAssertNil(history.watched[101])
    }

    func testCooldownLogic() {
        history.clearAll()
        history.markWatched(7, on: Date()) // now
        XCTAssertTrue(history.isCoolingDown(7))

        history.markWatched(8, on: Date(timeIntervalSince1970: 0)) // 1970
        XCTAssertFalse(history.isCoolingDown(8, cooldownDays: 1))
    }
}
