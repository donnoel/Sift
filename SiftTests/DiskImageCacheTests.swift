import Foundation
import XCTest

final class StubURLProtocol: URLProtocol {

    static var responder: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

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

// MARK: - XCTestCase helpers
extension XCTestCase {
    /// Waits for a short period so async work can complete, preventing infinite spinners.
    /// Use only in tests that do not already use explicit expectations.
    func waitBriefly(seconds: TimeInterval = 0.2, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "waitBriefly")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
}
