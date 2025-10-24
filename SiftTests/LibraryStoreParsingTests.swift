
import XCTest
@testable import Sift

@MainActor
final class LibraryStoreParsingTests: XCTestCase {
    func testYearFromDateStr() {
        XCTAssertEqual(LibraryStore.year(from: "2016-11-10"), 2016)
        XCTAssertNil(LibraryStore.year(from: nil))
        XCTAssertNil(LibraryStore.year(from: "xx"))
    }

    func testParseImportLine() {
        let cases: [(String, String, Int?)] = [
            ("Heat 1995", "Heat", 1995),
            ("The Thing (1982)", "The Thing", 1982),
            ("Arrival [2016]", "Arrival", 2016),
            ("Seven", "Seven", nil),
            ("  Mad Max: Fury Road (2015)  ", "Mad Max: Fury Road", 2015),
        ]
        for (input, expTitle, expYear) in cases {
            let out = LibraryStore.parseImportLine(input)
            XCTAssertEqual(out.title, expTitle, input)
            XCTAssertEqual(out.year, expYear, input)
        }
    }
}
