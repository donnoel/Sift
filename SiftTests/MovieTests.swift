import XCTest
@testable import Sift

final class MovieTests: XCTestCase {
    func testPosterURLWhenNil() {
        let m = Movie(id: 1, title: "Test", year: nil, rating: nil, overview: nil, posterPath: nil)
        XCTAssertNil(m.posterURL)
    }

    func testPosterURLWhenPathSet() {
        let m = Movie(id: 1, title: "Test", year: nil, rating: nil, overview: nil, posterPath: "/abc.jpg")
        XCTAssertEqual(m.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.jpg")
    }
}
