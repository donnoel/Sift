import XCTest
import Foundation
@testable import Sift

private final class URLProtocolStub: URLProtocol {
    static var responder: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = responder(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class TMDBClientTests: XCTestCase {
    @MainActor
    func makeClient(
        configResponder: @escaping (URLRequest) -> (Int, Data),
        searchResponder: @escaping (URLRequest) -> (Int, Data),
        detailsResponder: @escaping (URLRequest) -> (Int, Data)
    ) -> TMDBClient {
        URLProtocolStub.responder = { req in
            let url = req.url!.absoluteString
            if url.contains("/configuration") { return configResponder(req) }
            if url.contains("/search/movie") { return searchResponder(req) }
            return detailsResponder(req)
        }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: cfg)

        let suite = UserDefaults(suiteName: "SiftTests-TMDB-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: suite)
        settings.tmdbAPIKey = "TEST_KEY"
        return TMDBClient(settings: settings, session: session)
    }

    func testBestSearchMatchAndDetails() async throws {
        let imagesCfg = #"""
        {"images":{"base_url":"http://img/","secure_base_url":"https://img/","poster_sizes":["w92","w500","original"]}}
        """#.data(using: .utf8)!

        let search = #"""
        {"results":[
            {"id":157336,"title":"Interstellar","release_date":"2014-11-07","poster_path":"/x.png","overview":"x","vote_average":8.6},
            {"id":2,"title":"Interstellar 1999","release_date":"1999-01-01","poster_path":null,"overview":null,"vote_average":5.0}
        ]}
        """#.data(using: .utf8)!

        let details = #"""
        {"id":157336,"title":"Interstellar","release_date":"2014-11-07","poster_path":"/x.png","overview":"x","vote_average":8.6,"genres":[{"name":"Sci-Fi"}],"runtime":169}
        """#.data(using: .utf8)!

        let client = makeClient(
            configResponder: { _ in (200, imagesCfg) },
            searchResponder: { req in
                XCTAssertTrue(req.url!.absoluteString.contains("query=Interstellar"))
                return (200, search)
            },
            detailsResponder: { req in
                XCTAssertTrue(req.url!.absoluteString.contains("/movie/157336"))
                return (200, details)
            }
        )

        let best = try await client.bestSearchMatch(for: "Interstellar", year: 2014)
        XCTAssertEqual(best?.id, 157336)

        let det = try await client.details(for: 157336)
        XCTAssertEqual(det.id, 157336)
        XCTAssertEqual(det.runtime, 169)
    }

    func testBestSearchMatchNormalizesWhitespaceSequences() async throws {
        let imagesCfg = #"""
        {"images":{"base_url":"http://img/","secure_base_url":"https://img/","poster_sizes":["w92","w500","original"]}}
        """#.data(using: .utf8)!

        let search = #"""
        {"results":[
            {"id":101,"title":"Messy\tSpacing\nMovie","release_date":"2000-01-01","poster_path":null,"overview":null,"vote_average":1},
            {"id":202,"title":"Messy Spacing Movie 2","release_date":"2001-01-01","poster_path":null,"overview":null,"vote_average":1000}
        ]}
        """#.data(using: .utf8)!

        let client = makeClient(
            configResponder: { _ in (200, imagesCfg) },
            searchResponder: { _ in (200, search) },
            detailsResponder: { _ in (500, Data()) }
        )

        let best = try await client.bestSearchMatch(for: "Messy Spacing Movie", year: 2000)
        XCTAssertEqual(best?.id, 101)
    }
}
