
import XCTest
@testable import Sift

@MainActor
final class ForYouViewModelTests: XCTestCase {
    func testRefreshSetsMainPickAndRails() {
        let lib = [
            Movie(id: 1, title: "A", year: 2010, rating: 8.0, overview: nil, posterPath: nil),
            Movie(id: 2, title: "B", year: 2011, rating: 7.0, overview: nil, posterPath: nil),
            Movie(id: 3, title: "C", year: 2012, rating: 6.5, overview: nil, posterPath: nil),
        ]
        let history = WatchHistoryStore.shared
        history.clearAll()
        let vm = ForYouViewModel(history: history, libraryProvider: { lib })
        vm.refresh()
        XCTAssertNotNil(vm.mainPick)
        XCTAssertFalse(vm.rails.isEmpty)
    }

    func testMarkWatchedFiltersOnNextRefresh() {
        let lib = [
            Movie(id: 11, title: "Hot", year: 2020, rating: 9.4, overview: nil, posterPath: nil),
            Movie(id: 12, title: "Other", year: 2021, rating: 7.1, overview: nil, posterPath: nil),
        ]
        let history = WatchHistoryStore.shared
        history.clearAll()
        let vm = ForYouViewModel(history: history, libraryProvider: { lib })
        vm.refresh()
        let first = vm.mainPick
        if let m = first { vm.markWatched(m) }
        vm.refresh()
        let second = vm.mainPick
        XCTAssertNotEqual(first?.id, second?.id)
    }
}
