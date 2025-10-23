// PATH: SiftTests/TMDBClientTests.swift
import XCTest
@testable import Sift

@MainActor
final class TMDBClient_NewTests: XCTestCase {

    func makeClient(key: String = "KEY") -> TMDBClient {
        let settings = TestAppSettings(key)
        return TMDBClient(settings: settings, session: .stubbing())
    }

    func testBestSearchMatch_ranksExactTitleHigher_andPrefersYear() async throws {
        let client = makeClient()

        // Respond to search
        StubURLProtocol.responder = { req in
            if req.url!.path.contains("/search/movie") { return (200, Fixtures.searchInterstellar) }
            return (200, Data("{"" : ""}".utf8)) // not used
        }

        let best = try await client.bestSearchMatch(for: "Interstellar", year: 2014)
        XCTAssertEqual(best?.title, "Interstellar")
        XCTAssertEqual(best?.id, 157336)
    }

    func testImageURL_usesConfiguration_whenLoaded_elseFallback() async throws {
        let client = makeClient()
        // First call returns config then ignores
        var calls = 0
        StubURLProtocol.responder = { req in
            calls += 1
            if req.url!.path.contains("/configuration") { return (200, Fixtures.imagesConfig) }
            return (200, Data())
        }
        let url = try await client.imageURL(forPosterPath: "/abc.jpg")
        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.jpg")
        XCTAssertGreaterThan(calls, 0)
    }

    func testApiKey_nil_returnsNilForSearch() async throws {
        let settings = TestAppSettings("  ") // empty key
        let client = TMDBClient(settings: settings, session: .stubbing())
        let result = try await client.bestSearchMatch(for: "Something")
        XCTAssertNil(result)
    }
}