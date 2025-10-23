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
final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let responder = Self.responder else { return }
        let (status, data) = responder(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: [:])!
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
        cfg.protocolClasses = [StubURLProtocol.self]
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
}
