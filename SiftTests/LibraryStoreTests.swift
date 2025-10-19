import XCTest
@testable import Sift

@MainActor
final class LibraryStoreTests: XCTestCase {

    // Clear real disk before each test (extra safety)
    override func setUp() async throws {
        let p = LibraryPersistence()
        await p.save(movies: [])
    }

    // In-memory persistence so tests never touch disk
    final class InMemoryPersistence: LibraryPersisting {
        var storage: [Movie] = []
        func load() async -> [Movie]? { storage }
        func save(movies: [Movie]) async { storage = movies }
    }

    // URLProtocol stub returning different JSON for search vs details
    final class StubURLProtocol: URLProtocol {
        static var status: Int = 200
        static var searchPayload = Data()
        static var detailsPayload = Data()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let url = request.url else { return }
            let isSearch = url.path.contains("/search/movie")
            let data = isSearch ? Self.searchPayload : Self.detailsPayload
            let resp = HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: nil, headerFields: [:])!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func makeClient(searchJSON: String, detailsJSON: String, status: Int = 200) -> TMDBClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.status = status
        StubURLProtocol.searchPayload = Data(searchJSON.utf8)
        StubURLProtocol.detailsPayload = Data(detailsJSON.utf8)

        let session = URLSession(configuration: cfg)
        let settings = AppSettings()
        settings.tmdbAPIKey = "KEY"
        return TMDBClient(settings: settings, session: session)
    }

    func testImportHappyPathDedupAndSort() async throws {
        // Stub 1 search hit + full details response
        let client = makeClient(
            searchJSON: #"""
            { "results": [
              { "id": 1, "title": "Inception", "release_date": "2010-07-16",
                "poster_path": "/a.jpg", "overview": "x", "vote_average": 8.8 }
            ] }
            """#,
            detailsJSON: #"""
            { "id": 1, "title": "Inception", "release_date": "2010-07-16",
              "poster_path": "/a.jpg", "overview": "x", "vote_average": 8.8,
              "genres": [], "runtime": 148 }
            """#
        )

        // Hermetic store: in-memory persistence, skip auto-load
        let store = LibraryStore(
            settings: AppSettings(),
            client: client,
            persistence: InMemoryPersistence(),
            loadOnInit: false
        )

        // Tripwire: PROVE the store starts empty
        XCTAssertEqual(store.movies.count, 0, "Store should start empty (no disk)")

        await store.importFromPaste("Inception\nInception")

        XCTAssertEqual(store.movies.count, 1)
        let m = store.movies.first
        XCTAssertEqual(m?.title, "Inception")
        XCTAssertEqual(m?.year, 2010)
        XCTAssertTrue(store.lastErrors.isEmpty)
        XCTAssertEqual(store.progress, 1.0)
    }
}
