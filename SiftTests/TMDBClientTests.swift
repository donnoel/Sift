// PATH: SiftTests/TMDBClientTests.swift
import XCTest
@testable import Sift

@MainActor
final class TMDBClient_NewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Register globally so even URLSession.shared gets intercepted
        URLProtocol.registerClass(SiftStubURLProtocol.self)
        // Safe default to avoid nil responder crashes
        SiftStubURLProtocol.responder = { _ in (200, Data()) }
    }

    override func tearDown() {
        // Clean up to avoid bleed-over between tests
        SiftStubURLProtocol.responder = nil
        URLProtocol.unregisterClass(SiftStubURLProtocol.self)
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

        SiftStubURLProtocol.responder = { req in
            let url = req.url ?? URL(string: "about:blank")!
            let path = url.path
            if path.contains("/search/movie") {
                capturedQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)
                return (200, Fixtures.searchInterstellar)
            }
            if path.contains("/movie/") {
                return (200, Fixtures.detailsInterstellar)
            }
            if path.contains("/configuration") {
                return (200, Fixtures.imagesConfig)
            }
            return (404, Data())
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
        SiftStubURLProtocol.responder = { req in
            let path = req.url?.path ?? ""
            if path.contains("/configuration") { return (200, Fixtures.imagesConfig) }
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
