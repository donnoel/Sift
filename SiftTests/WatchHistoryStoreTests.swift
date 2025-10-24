
import XCTest
@testable import Sift

@MainActor
final class WatchHistoryStoreTests: XCTestCase {
    func testClearMarkUnwatch() {
        let store = WatchHistoryStore.shared
        store.clearAll()
        XCTAssertTrue(store.watched.isEmpty)

        store.markWatched(101, on: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(store.watched[101], Date(timeIntervalSince1970: 10))

        store.unwatch(101)
        XCTAssertNil(store.watched[101])
    }

    func testCooldownLogic() {
        let store = WatchHistoryStore.shared
        store.clearAll()
        store.markWatched(7, on: Date()) // now
        XCTAssertTrue(store.isCoolingDown(7))

        store.markWatched(8, on: Date(timeIntervalSince1970: 0)) // 1970
        XCTAssertFalse(store.isCoolingDown(8, cooldownDays: 1))
    }
}
