
import XCTest
@testable import Sift

final class MovieTests: XCTestCase {
    func testPosterURL() {
        var m = Movie(id: 1, title: "Test", year: 2000, rating: 7.0, overview: nil, posterPath: nil)
        XCTAssertNil(m.posterURL)
        m.posterPath = "/poster.png"
        XCTAssertEqual(m.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w500/poster.png")
    }
}
