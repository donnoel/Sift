import Foundation
import Combine

@MainActor
final class WatchHistoryStore: ObservableObject {
    static let shared = WatchHistoryStore()

    @Published private(set) var watched: [Int: Date] = [:]  // movieID : lastSeen

    private let key = "watch_history_store_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Int: Date].self, from: data) {
            watched = decoded
        }
    }

    func markWatched(_ id: Int, on date: Date = Date()) {
        watched[id] = date
        persist()
    }

    /// Remove a movie from history so it returns to recommendation rotation.
    func markUnwatched(_ id: Int) {
        watched.removeValue(forKey: id)
        persist()
    }

    func isCoolingDown(_ id: Int, cooldownDays: Int = 365) -> Bool {
        guard let d = watched[id] else { return false }
        return Date().timeIntervalSince(d) < TimeInterval(cooldownDays) * 24 * 60 * 60
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(watched) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
