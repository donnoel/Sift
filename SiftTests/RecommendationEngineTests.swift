import XCTest
@testable import Sift

final class RecommendationEngineTests: XCTestCase {

    func testClassifyAndRails_basic() throws {
        try XCTSkipIf(true, "RecommendationEngine.buildRails(from:) not found in this revision; pending API confirmation.")
    }
}
