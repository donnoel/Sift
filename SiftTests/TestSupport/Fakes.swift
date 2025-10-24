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

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
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
