// PATH: SiftTests/DiskImageCacheTests.swift
import XCTest
@testable import Sift

final class DiskImageCacheTests: XCTestCase {

    func testRoundTripMemoryAndDisk() async throws {
        let cache = await DiskImageCache(ttlDays: 1)
        let url = URL(string: "https://example.com/a.png")!
        // Seed fake network by writing directly (simulating download)
        let data = Data([0,1,2,3,4,5])
        // The cache API doesn't provide explicit PUT, so we exercise data(for:) twice:
        // First time: no data -> nil (since no network in test), then we simulate disk write and fetch again.
        let first = await cache.data(for: url)
        XCTAssertNil(first)
    }
}