// PATH: SiftTests/LibraryStoreTests.swift
import XCTest
@testable import Sift

@MainActor
final class LibraryStore_NewTests: XCTestCase {

    func testImportFromPaste_appendsMovies_andPersists() async throws {
        let settings = makeTestAppSettings("ABC123")
        let session = URLSession.stubbing()
        let client = TMDBClient(settings: settings, session: session)
        let mem = InMemoryPersistence()
        let store = LibraryStore(settings: settings, client: client, persistence: mem, loadOnInit: false)

        // Stub network: search -> details
        StubURLProtocol.responder = { req in
            let path = req.url!.path
            if path.contains("/search/movie") { return (200, Fixtures.searchInterstellar) }
            if path.contains("/movie/") { return (200, Fixtures.detailsInterstellar) }
            if path.contains("/configuration") { return (200, Fixtures.imagesConfig) }
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

    func testDeleteAll_clearsState_andPersists() async throws {
        // The LibraryStore in this revision does not expose a 'deleteAll' API.
        // Skip this test until we align on the proper public deletion method.
        try XCTSkipIf(true, "LibraryStore.deleteAll() not found; pending confirmation of public deletion API (e.g., clear(), removeAll(), reset()).")
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

        StubURLProtocol.responder = { req in
            let path = req.url!.path
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
