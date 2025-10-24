// PATH: SiftTests/TMDBClientTests.swift
import XCTest
@testable import Sift

@MainActor
final class TMDBClient_NewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Register globally so even URLSession.shared gets intercepted
        URLProtocol.registerClass(StubURLProtocol.self)
        // Safe default to avoid nil responder crashes
        StubURLProtocol.responder = { _ in (200, Data()) }
    }

    override func tearDown() {
        // Clean up to avoid bleed-over between tests
        StubURLProtocol.responder = nil
        URLProtocol.unregisterClass(StubURLProtocol.self)
        super.tearDown()
    }

    func makeClient(key: String = "KEY") -> TMDBClient {
        let settings = makeTestAppSettings(key)
        return TMDBClient(settings: settings, session: .stubbing())
    }

    func testBestSearchMatch_ranksExactTitleHigher_andPrefersYear() async throws {
        let client = makeClient()

        // Respond to search
        var capturedQuery: URLComponents?

        StubURLProtocol.responder = { req in
            if req.url!.path.contains("/search/movie") {
                capturedQuery = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)
                return (200, Fixtures.searchInterstellar)
            }
            return (200, Data("{}".utf8)) // not used
        }

        let best = try await client.bestSearchMatch(for: "Interstellar", year: 2014)
        XCTAssertEqual(best?.title, "Interstellar")
        XCTAssertEqual(best?.id, 157336)
        let queryDict = Dictionary(uniqueKeysWithValues: (capturedQuery?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryDict["primary_release_year"], "2014")
    }

    func testImageURL_usesConfiguration_whenLoaded_elseFallback() async throws {
        let client = makeClient()
        // Respond to configuration endpoint
        StubURLProtocol.responder = { req in
            if req.url!.path.contains("/configuration") { return (200, Fixtures.imagesConfig) }
            return (200, Data())
        }
        let url = try await client.imageURL(forPosterPath: "/abc.jpg")
        let s = try XCTUnwrap(url?.absoluteString)
        XCTAssertTrue(s.hasSuffix("/abc.jpg"))
        XCTAssertTrue(s.contains("image.tmdb.org"))
    }

    func testApiKey_nil_returnsNilForSearch() async throws {
        let settings = makeTestAppSettings("  ") // empty key
        let client = TMDBClient(settings: settings, session: .stubbing())
        let result = try await client.bestSearchMatch(for: "Something")
        XCTAssertNil(result)
    }
}
