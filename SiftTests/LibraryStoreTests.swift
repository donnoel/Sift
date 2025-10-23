// PATH: SiftTests/LibraryStoreTests.swift
import XCTest
@testable import Sift

@MainActor
final class LibraryStore_NewTests: XCTestCase {

    func testImportFromPaste_appendsMovies_andPersists() async throws {
        let settings = TestAppSettings("ABC123")
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
        let m = try XCTUnwrap(store.movies.first)
        XCTAssertEqual(m.title, "Interstellar")
        // Persistence round trip
        let reloaded = await mem.load() ?? []
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.title, "Interstellar")
    }

    func testDeleteAll_clearsState_andPersists() async throws {
        let s = TestAppSettings("ABC123")
        let client = TMDBClient(settings: s, session: .stubbing())
        let mem = InMemoryPersistence()
        let store = LibraryStore(settings: s, client: client, persistence: mem, loadOnInit: false)

        // Seed memory
        mem.storage = [Movie.example(), Movie.example(id: 2, title: "Another")]

        await store.deleteAll()

        XCTAssertTrue(store.movies.isEmpty)
        let persisted = await mem.load() ?? []
        XCTAssertTrue(persisted.isEmpty)
    }

    func testYearParsing() {
        XCTAssertEqual(LibraryStore.year(from: "2023-10-10"), 2023)
        XCTAssertNil(LibraryStore.year(from: nil))
        XCTAssertNil(LibraryStore.year(from: "x"))
    }
}