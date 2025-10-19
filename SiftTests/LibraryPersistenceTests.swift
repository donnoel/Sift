import XCTest
@testable import Sift

final class LibraryPersistenceTests: XCTestCase {
    func testRoundTrip() async throws {
        let p = LibraryPersistence()
        let movies = [
            Movie(id: 1, title: "A", year: 1999, rating: 7.1, overview: nil, posterPath: nil),
            Movie(id: 2, title: "B", year: 2001, rating: 8.4, overview: "x", posterPath: "/p.jpg")
        ]
        await p.save(movies: movies)
        let loaded = await p.load() ?? []
        XCTAssertEqual(loaded, movies)
    }

    func testLoadWhenMissingDoesNotCrash() async throws {
        let p = LibraryPersistence()
        let loaded = await p.load() ?? []
        XCTAssertNotNil(loaded)
    }
}
