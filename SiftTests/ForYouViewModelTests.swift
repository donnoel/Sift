// PATH: SiftTests/ForYouViewModelTests.swift
import XCTest
@testable import Sift

@MainActor
final class ForYouViewModelTests: XCTestCase {

    func testRefresh_setsMainPick_andRails_fromEngine() async {
        // Library of distinct genres so we can see rails groupings
        let lib: [Movie] = [
            Movie(id: 1, title: "Sci‑Fi One", year: 2014, rating: 8.0, overview: nil, posterPath: nil),
            Movie(id: 2, title: "Action Two", year: 2016, rating: 7.4, overview: nil, posterPath: nil),
            Movie(id: 3, title: "Comedy Three", year: 2019, rating: 7.1, overview: nil, posterPath: nil),
        ]

        let history = WatchHistoryStore.shared
        history.clearAll()
        let vm = ForYouViewModel(history: history, libraryProvider: { lib })

        vm.refresh()

        XCTAssertNotNil(vm.mainPick, "refresh() should choose a main pick")
        XCTAssertFalse(vm.rails.isEmpty, "refresh() should produce at least one rail from the library")
    }

    func testMarkWatched_filtersCoolingDownTitles_onNextRefresh() async {
        let lib: [Movie] = [
            Movie(id: 1, title: "Hot Pick", year: 2020, rating: 9.1, overview: nil, posterPath: nil),
            Movie(id: 2, title: "Other Pick", year: 2021, rating: 7.2, overview: nil, posterPath: nil),
        ]

        let history = WatchHistoryStore.shared
        history.clearAll()
        let vm = ForYouViewModel(history: history, libraryProvider: { lib })

        vm.refresh()
        let firstMain = vm.mainPick

        // Mark the main pick as watched; default cooldown should hide it on the next refresh
        if let m = firstMain {
            vm.markWatched(m)
        }

        vm.refresh()
        let secondMain = vm.mainPick

        XCTAssertNotEqual(firstMain?.id, secondMain?.id, "After marking watched, the main pick should change due to cooldown filtering.")
    }
}
