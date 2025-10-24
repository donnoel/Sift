// PATH: SiftTests/WatchHistoryStoreTests.swift
import XCTest
@testable import Sift

@MainActor
final class WatchHistoryStoreTests: XCTestCase {

    func testMarkUnwatchClear_roundtrip() {
        let store = WatchHistoryStore.shared
        store.clearAll()

        XCTAssertTrue(store.watched.isEmpty, "clearAll should empty the watched map")

        store.markWatched(42, on: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(store.watched[42], Date(timeIntervalSince1970: 1000))

        store.unwatch(42)
        XCTAssertNil(store.watched[42], "unwatch should remove the entry")
    }

    func testIsCoolingDown_respectsCooldownWindow() {
        let store = WatchHistoryStore.shared
        store.clearAll()

        // Watched just now => within cooldown by default
        store.markWatched(7, on: Date())
        XCTAssertTrue(store.isCoolingDown(7))

        // Watched far in the past => outside of small cooldown window
        store.markWatched(9, on: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(store.isCoolingDown(9, cooldownDays: 1))
    }
}
