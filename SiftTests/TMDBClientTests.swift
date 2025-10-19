import XCTest
@testable import Sift

@MainActor
final class TMDBClientTests: XCTestCase {

    // A URLProtocol stub to intercept requests and return canned responses
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
        override func stopLoading() { }
    }

    /// Creates a TMDBClient that uses a stubbed URLSession (no real network).
    private func makeClient(apiKey: String = "KEY", payload: Data, status: Int = 200) -> TMDBClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.responder = { _ in (status, payload) }
        let session = URLSession(configuration: config)

        // This is now legal because the whole class runs on the main actor:
        let settings = AppSettings()
        settings.tmdbAPIKey = apiKey

        return TMDBClient(settings: settings, session: session)
    }

    // … your tests …
}
