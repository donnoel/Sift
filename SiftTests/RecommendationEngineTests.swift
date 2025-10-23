// PATH: SiftTests/RecommendationEngineTests.swift
import XCTest
@testable import Sift

final class RecommendationEngineTests: XCTestCase {

    func testClassifyAndRails_basic() {
        let engine = RecommendationEngine()
        let sci = Movie.example(id: 1, title: "Star Voyager", overview: "A sci-fi space epic.")
        let horror = Movie.example(id: 2, title: "Night Fear", overview: "Horror in the woods.")
        let drama = Movie.example(id: 3, title: "Tears of the Sun", overview: "A moving drama.")

        // We can't reach into classify (it's private), but we can use public APIs that depend on it
        let res = engine.buildRails(from: [sci, horror, drama])
        XCTAssertNotNil(res.mainPick)
        XCTAssertFalse(res.rails.isEmpty)
    }
}