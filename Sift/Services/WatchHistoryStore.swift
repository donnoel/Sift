import Foundation
import Combine

/// Syncs the watched list locally (UserDefaults) and across devices using iCloud Key-Value Store.
/// - Uses JSON-encoded Data under a single key in both stores.
/// - Merges inbound iCloud changes by taking the *latest* date per movie ID.
/// - Calls `NSUbiquitousKeyValueStore.default.synchronize()` on init and after writes.
@MainActor
final class WatchHistoryStore: ObservableObject {
    static let shared = WatchHistoryStore()

    typealias MovieID = Int

    /// movieID : lastSeen
    @Published private(set) var watched: [MovieID: Date] = [:]

    // Storage keys
    private let localKey = "watch_history_store_v1"  // existing local key
    private let cloudKey = "watch_history_store_v1"  // use the same for iCloud KVS

    private var ubiqObserver: NSObjectProtocol?

    private init() {
        // 1) Load local first so UI is snappy
        if let local = Self.decodeLocal(UserDefaults.standard.data(forKey: localKey)) {
            watched = local
        }

        // 2) Pull from iCloud and merge
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize() // ask iCloud for the latest immediately

        if let cloudData = store.data(forKey: cloudKey),
           let cloud = Self.decodeLocal(cloudData) {
            mergeInCloud(cloud)
        }

        // 3) Listen for remote changes and merge
        ubiqObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            // Only care about our key
            if let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
               changedKeys.contains(self.cloudKey),
               let data = store.data(forKey: self.cloudKey),
               let incoming = Self.decodeLocal(data) {
                self.mergeInCloud(incoming)
            }
        }
    }

    deinit {
        if let o = ubiqObserver {
            NotificationCenter.default.removeObserver(o)
        }
    }

    // MARK: - Public API

    func markWatched(_ id: MovieID, on date: Date = .now) {
        watched[id] = date
        persistAll()
    }

    func unwatch(_ id: MovieID) {
        watched.removeValue(forKey: id)
        persistAll()
    }

    func clearAll() {
        watched.removeAll()
        persistAll()
    }

    /// A convenience you already had — unchanged behavior.
    func isCoolingDown(_ id: MovieID, cooldownDays: Int = 365) -> Bool {
        guard let d = watched[id] else { return false }
        return Date().timeIntervalSince(d) < TimeInterval(cooldownDays) * 24 * 60 * 60
    }

    // MARK: - Persistence & Merge

    /// Persist to local and iCloud, then push a sync.
    private func persistAll() {
        // Local
        if let data = Self.encodeLocal(watched) {
            UserDefaults.standard.set(data, forKey: localKey)
        }

        // iCloud KVS
        let store = NSUbiquitousKeyValueStore.default
        if let data = Self.encodeLocal(watched) {
            store.set(data, forKey: cloudKey)
        }
        store.synchronize()
    }

    /// Merge incoming cloud dictionary into memory, preferring the *latest* date per movieID.
    private func mergeInCloud(_ incoming: [MovieID: Date]) {
        var changed = false
        var merged = watched

        for (id, date) in incoming {
            if let existing = merged[id] {
                if date > existing {
                    merged[id] = date
                    changed = true
                }
            } else {
                merged[id] = date
                changed = true
            }
        }

        // Also handle deletions propagated from another device:
        // If the cloud has *fewer* keys and some of ours are older than the cloud’s max,
        // that usually indicates a deliberate removal. If you want hard deletions to sync,
        // uncomment the block below to mirror cloud exactly (authoritative cloud).
        //
        // if incoming.count < merged.count {
        //     for key in merged.keys where incoming[key] == nil {
        //         merged.removeValue(forKey: key)
        //         changed = true
        //     }
        // }

        if changed {
            watched = merged
            persistAll() // write the merged state back locally and to iCloud
        }
    }

    // MARK: - Encoding helpers

    /// Encode as Data for both UserDefaults and KVS. We store as `[String: Double]` (epoch seconds) for robustness.
    private static func encodeLocal(_ dict: [MovieID: Date]) -> Data? {
        let wire: [String: Double] = dict.reduce(into: [:]) { acc, pair in
            acc[String(pair.key)] = pair.value.timeIntervalSince1970
        }
        return try? JSONSerialization.data(withJSONObject: wire, options: [])
    }

    /// Decode from Data produced by `encodeLocal`.
    private static func decodeLocal(_ data: Data?) -> [MovieID: Date]? {
        guard let data else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Double] else { return nil }
        var out: [MovieID: Date] = [:]
        out.reserveCapacity(obj.count)
        for (k, ts) in obj {
            if let id = Int(k) {
                out[id] = Date(timeIntervalSince1970: ts)
            }
        }
        return out
    }
}
