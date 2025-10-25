// PATH: SiftTests/LibraryStoreTests.swift
import XCTest
@testable import Sift

@MainActor
final class LibraryStore_NewTests: XCTestCase {

    // Intercept ALL URLSession traffic (including URLSession.shared) for this test class
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(SiftStubURLProtocol.self)
        // Safe default so a missing stub never hangs a test
        SiftStubURLProtocol.responder = { _ in (200, Data()) }
    }

    override func tearDown() {
        // Clean up between tests
        SiftStubURLProtocol.responder = nil
        URLProtocol.unregisterClass(SiftStubURLProtocol.self)
        super.tearDown()
    }

    func testImportFromPaste_appendsMovies_andPersists() async throws {
        let settings = makeTestAppSettings("ABC123")
        let session = URLSession.stubbing() // uses SiftStubURLProtocol
        let client = TMDBClient(settings: settings, session: session)
        let mem = InMemoryPersistence()
        let store = LibraryStore(settings: settings, client: client, persistence: mem, loadOnInit: false)

        // Stub network: search -> details -> configuration
        SiftStubURLProtocol.responder = { req in
            let path = req.url?.path ?? ""
            if path.contains("/search/movie")   { return (200, Fixtures.searchInterstellar) }
            if path.contains("/movie/")         { return (200, Fixtures.detailsInterstellar) }
            if path.contains("/configuration")  { return (200, Fixtures.imagesConfig) }
            return (404, Data())
        }

        await store.importFromPaste("""
        Interstellar
        """)

        // Assert state
        XCTAssertEqual(store.movies.count, 1)
        let m: Movie = try XCTUnwrap(store.movies.first)
        XCTAssertEqual(m.title, "Interstellar")

        // Persistence round trip
        let reloaded = await mem.load() ?? []
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.title, "Interstellar")
    }

    func testClearAll_clearsState_andPersists() async throws {
        // Library deletion flows should call clearAll(), which resets state and persists the empty collection.
        let settings = makeTestAppSettings("ABC123")
        let session = URLSession.stubbing()
        let client = TMDBClient(settings: settings, session: session)
        let mem = InMemoryPersistence()
        let store = LibraryStore(settings: settings, client: client, persistence: mem, loadOnInit: false)

        SiftStubURLProtocol.responder = { req in
            let path = req.url?.path ?? ""
            if path.contains("/search/movie")   { return (200, Fixtures.searchInterstellar) }
            if path.contains("/movie/")         { return (200, Fixtures.detailsInterstellar) }
            if path.contains("/configuration")  { return (200, Fixtures.imagesConfig) }
            return (404, Data())
        }

        await store.importFromPaste("Interstellar")

        XCTAssertEqual(store.movies.count, 1)
        XCTAssertEqual(mem.storage.count, 1)

        await store.clearAll()

        XCTAssertTrue(store.movies.isEmpty)
        XCTAssertTrue(mem.storage.isEmpty)
    }

    func testYearParsing() {
        XCTAssertEqual(LibraryStore.year(from: "2023-10-10"), 2023)
        XCTAssertNil(LibraryStore.year(from: nil))
        XCTAssertNil(LibraryStore.year(from: "x"))
    }

    func testImportFromPaste_passesYearHintToSearch() async throws {
        let settings = makeTestAppSettings("ABC123")
        let session = URLSession.stubbing()
        let client = TMDBClient(settings: settings, session: session)
        let mem = InMemoryPersistence()
        let store = LibraryStore(settings: settings, client: client, persistence: mem, loadOnInit: false)

        var capturedSearchURL: URL?

        SiftStubURLProtocol.responder = { req in
            let path = req.url?.path ?? ""
            if path.contains("/search/movie") {
                capturedSearchURL = req.url
                return (200, Fixtures.searchInterstellar)
            }
            if path.contains("/movie/") { return (200, Fixtures.detailsInterstellar) }
            if path.contains("/configuration") { return (200, Fixtures.imagesConfig) }
            return (404, Data())
        }

        await store.importFromPaste("Interstellar (2014)")

        let url = try XCTUnwrap(capturedSearchURL)
        let comps = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryDict = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryDict["query"], "Interstellar")
        XCTAssertEqual(queryDict["primary_release_year"], "2014")
        XCTAssertEqual(store.movies.count, 1)
    }

    func testParseImportLine_extractsYearAndCleansTitle() {
        XCTAssertEqual(LibraryStore.parseImportLine("Heat 1995").title, "Heat")
        XCTAssertEqual(LibraryStore.parseImportLine("Heat 1995").year, 1995)

        let thing = LibraryStore.parseImportLine("The Thing (1982)")
        XCTAssertEqual(thing.title, "The Thing")
        XCTAssertEqual(thing.year, 1982)

        let arrival = LibraryStore.parseImportLine("Arrival [2016]")
        XCTAssertEqual(arrival.title, "Arrival")
        XCTAssertEqual(arrival.year, 2016)

        let noYear = LibraryStore.parseImportLine("The Matrix")
        XCTAssertEqual(noYear.title, "The Matrix")
        XCTAssertNil(noYear.year)
    }
}
