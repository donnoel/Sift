import SwiftUI
import Foundation
import Combine

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var mainPick: Movie?
    @Published private(set) var rails: [(genre: MovieGenre, movies: [Movie])] = []

    private let engine = RecommendationEngine()
    private let history: WatchHistoryStore
    private let provider: () -> [Movie]

    // Incremented to rotate results on each refresh.
    private var shuffleSeed: UInt64 = 0

    init(history: WatchHistoryStore = .shared,
         libraryProvider: @escaping () -> [Movie]) {
        self.history = history
        self.provider = libraryProvider
    }

    /// Refresh recommendations. Pass `shuffle: true` to rotate results.
    func refresh(shuffle: Bool = false) {
        if shuffle { shuffleSeed &+= 1 }

        // Exclude cooldown titles from WatchHistoryStore.
        let library = provider().filter { !history.isCoolingDown($0.id) }

        let result = engine.compute(
            library: library,
            rails: [.actionAdventure, .comedy, .drama, .horror, .thriller, .scienceFiction],
            picksPerRail: 10,
            seed: shuffleSeed
        )

        self.mainPick = result.mainPick
        self.rails = result.rails
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value) }
    }

    func markWatched(_ movie: Movie) {
        history.markWatched(movie.id)
        refresh() // recompute without shuffling
    }
}
