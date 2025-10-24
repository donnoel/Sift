// PATH: SiftTests/SectionTests.swift
import XCTest
@testable import Sift

final class SectionTests: XCTestCase {
    func testTitleAndSymbolMapping() {
        XCTAssertEqual(Section.forYou.title, "For You")
        XCTAssertEqual(Section.forYou.systemImage, "sparkles")

        XCTAssertEqual(Section.discover.title, "Discover")
        XCTAssertEqual(Section.discover.systemImage, "safari")

        XCTAssertEqual(Section.library.title, "Library")
        XCTAssertEqual(Section.library.systemImage, "film")

        XCTAssertEqual(Section.settings.title, "Settings")
        XCTAssertEqual(Section.settings.systemImage, "gearshape")
    }

    func testAllCasesContainsFourSections() {
        XCTAssertEqual(Section.allCases.count, 4)
    }
}
