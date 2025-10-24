// PATH: SiftTests/TMDBSchemasTests.swift
import XCTest
@testable import Sift

final class TMDBSchemasTests: XCTestCase {
    func testDecodeSearchResponse_minimal() throws {
        let json = #"{"results":[{"id":1,"title":"Foo","release_date":"2020-01-01","poster_path":"/p.png","overview":"x","vote_average":7.5}]}"#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        XCTAssertEqual(decoded.results.first?.id, 1)
        XCTAssertEqual(decoded.results.first?.title, "Foo")
    }

    func testDecodeMovieDetails_minimal() throws {
        let json = #"{"id":10,"title":"Bar","release_date":null,"poster_path":null,"overview":null,"vote_average":null,"genres":[{"name":"Sci‑Fi"}],"runtime":123}"#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
        XCTAssertEqual(decoded.id, 10)
        XCTAssertEqual(decoded.genres?.first?.name, "Sci‑Fi")
        XCTAssertEqual(decoded.runtime, 123)
    }
}
