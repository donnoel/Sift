// PATH: SiftTests/TestSupport/Fakes.swift
import Foundation
import XCTest
@testable import Sift

// MARK: - InMemoryPersistence
final class InMemoryPersistence: LibraryPersisting {
    var storage: [Movie] = []
    func load() async -> [Movie]? { storage }
    func save(movies: [Movie]) async { storage = movies }
}

// MARK: - Test AppSettings factory
@MainActor
func makeTestAppSettings(_ key: String) -> AppSettings {
    let settings = AppSettings()
    settings.tmdbAPIKey = key
    return settings
}

// MARK: - StubURLProtocol
final class SiftStubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Ensure we have a URL to report back with
        let resolvedURL = request.url ?? URL(string: "about:blank")!

        // If there's no responder, deliver a deterministic empty 501 response and finish.
        guard let responder = Self.responder else {
            let resp = HTTPURLResponse(url: resolvedURL, statusCode: 501, httpVersion: nil, headerFields: [:])!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Use the responder and always finish.
        let (status, data) = responder(request)
        let resp = HTTPURLResponse(url: resolvedURL, statusCode: status, httpVersion: nil, headerFields: [:])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - URLSession factory with StubURLProtocol
extension URLSession {
    static func stubbing() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [SiftStubURLProtocol.self]
        return URLSession(configuration: cfg)
    }
}

// MARK: - JSON Fixtures
enum Fixtures {
    static func data(_ json: String) -> Data { Data(json.utf8) }

    static let searchInterstellar = data("""
    { "results": [
        { "id": 157336, "title": "Interstellar", "release_date": "2014-11-05", "poster_path": "/nBNZadXqJSdt05SHLqgT0HuC5Gm.jpg", "overview": "A team travels through a wormhole.", "vote_average": 8.3 },
        { "id": 123, "title": "Interstaller", "release_date": "2015-01-01", "poster_path": null, "overview": "Typos happen.", "vote_average": 5.0 }
    ]}
    """)

    static let detailsInterstellar = data("""
    {
      "id": 157336,
      "title": "Interstellar",
      "release_date": "2014-11-05",
      "poster_path": "/nBNZadXqJSdt05SHLqgT0HuC5Gm.jpg",
      "overview": "Explorers undertake a mission.",
      "vote_average": 8.6,
      "genres": [{"name":"Science Fiction"}],
      "runtime": 169
    }
    """)

    static let imagesConfig = data("""
    {
      "images": {
        "base_url": "http://image.tmdb.org/t/p/",
        "secure_base_url": "https://image.tmdb.org/t/p/",
        "poster_sizes": ["w92","w154","w342","w500","w780","original"]
      }
    }
    """)

    static let searchAlienVariants = data("""
    { "results": [
        { "id": 1, "title": "Alien", "release_date": "1979-05-25", "poster_path": "/poster1.jpg", "overview": "Classic sci-fi horror.", "vote_average": 8.4 },
        { "id": 2, "title": "Alien", "release_date": "2014-01-01", "poster_path": "/poster2.jpg", "overview": "A modern reboot.", "vote_average": 9.0 }
    ]}
    """)

    static let detailsAlien1979 = data("""
    {
      "id": 1,
      "title": "Alien",
      "release_date": "1979-05-25",
      "poster_path": "/poster1.jpg",
      "overview": "The crew of the Nostromo encounters a deadly alien lifeform.",
      "vote_average": 8.4,
      "genres": [{"name":"Science Fiction"}]
    }
    """)
}
