import SwiftUI
import Combine
import Foundation

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var mainPick: Movie?
    @Published private(set) var rails: [(genre: MovieGenre, movies: [Movie])] = []

    private let engine = RecommendationEngine()
    private let history: WatchHistoryStore
    private let provider: () -> [Movie]

    init(history: WatchHistoryStore = .shared,
         libraryProvider: @escaping () -> [Movie]) {
        self.history = history
        self.provider = libraryProvider
    }

    func refresh() {
        let library = provider().filter { !history.isCoolingDown($0.id) }
        let result = engine.compute(library: library)
        self.mainPick = result.mainPick
        self.rails = result.rails
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value) }
    }

    func markWatched(_ movie: Movie) {
        history.markWatched(movie.id)
        refresh()
    }
}
