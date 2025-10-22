import Foundation
import Combine

/// Syncs the watched list locally (UserDefaults) and across devices using iCloud Key-Value Store.
/// - Stores JSON Data under a single key in both stores.
/// - Merges inbound iCloud changes by taking the *latest* date per movie ID.
/// - Provides a user-toggleable `cloudSyncEnabled` flag and a manual `syncNow()` action.
@MainActor
final class WatchHistoryStore: ObservableObject {
    static let shared = WatchHistoryStore()

    typealias MovieID = Int

    /// movieID : lastSeen
    @Published private(set) var watched: [MovieID: Date] = [:]

    /// Whether iCloud KVS sync is enabled (persisted in UserDefaults; default true).
    @Published var cloudSyncEnabled: Bool = true

    // Storage keys
    private let localKey = "watch_history_store_v1"
    private let cloudKey = "watch_history_store_v1"
    private let syncEnabledKey = "watch_history_icloud_sync_enabled"

    /// Single iCloud KVS store instance
    private let store = NSUbiquitousKeyValueStore.default

    private var ubiqObserver: NSObjectProtocol?

    private init() {
        // Load local first so UI is snappy
        if let local = Self.decodeLocal(UserDefaults.standard.data(forKey: localKey)) {
            watched = local
        }

        // Load sync toggle; default to true if unset
        if UserDefaults.standard.object(forKey: syncEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: syncEnabledKey)
        }
        cloudSyncEnabled = UserDefaults.standard.bool(forKey: syncEnabledKey)

        // Pull from iCloud (if enabled) and merge
        if cloudSyncEnabled {
            store.synchronize() // ask iCloud for latest immediately
            if let cloudData = store.data(forKey: cloudKey),
               let cloud = Self.decodeLocal(cloudData) {
                mergeInCloud(cloud)
            }
        }

        // Listen for remote changes and merge (only when enabled)
        ubiqObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard self.cloudSyncEnabled else { return }
            if let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
               changedKeys.contains(self.cloudKey),
               let data = self.store.data(forKey: self.cloudKey),
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

    /// Example convenience you already had — unchanged behavior.
    func isCoolingDown(_ id: MovieID, cooldownDays: Int = 365) -> Bool {
        guard let d = watched[id] else { return false }
        return Date().timeIntervalSince(d) < TimeInterval(cooldownDays) * 24 * 60 * 60
    }

    /// Toggle iCloud sync at runtime. When enabling, push local → iCloud and then pull/merge once.
    func setCloudSyncEnabled(_ enabled: Bool) {
        guard enabled != cloudSyncEnabled else { return }
        cloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: syncEnabledKey)

        if enabled {
            // Push current local state up
            if let data = Self.encodeLocal(watched) {
                store.set(data, forKey: cloudKey)
            }
            store.synchronize()

            // Pull and merge to converge across devices
            if let data = store.data(forKey: cloudKey),
               let incoming = Self.decodeLocal(data) {
                mergeInCloud(incoming)
            }
        }
        // If disabled: no-op; we’ll stop writing to iCloud and ignore incoming changes
    }

    /// Manually trigger a one-shot sync/merge from iCloud (no-op if disabled).
    func syncNow() {
        guard cloudSyncEnabled else { return }
        store.synchronize()
        if let data = store.data(forKey: cloudKey),
           let incoming = Self.decodeLocal(data) {
            mergeInCloud(incoming)
        }
    }

    // MARK: - Persistence & Merge

    /// Persist to local and (if enabled) iCloud; then push a sync.
    private func persistAll() {
        // Local
        if let data = Self.encodeLocal(watched) {
            UserDefaults.standard.set(data, forKey: localKey)
        }

        // iCloud KVS (if enabled)
        guard cloudSyncEnabled else { return }
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

        // Optional: cloud-authoritative deletions (off by default).
        // if incoming.count < merged.count {
        //     for key in merged.keys where incoming[key] == nil {
        //         merged.removeValue(forKey: key)
        //         changed = true
        //     }
        // }

        if changed {
            watched = merged
            // Write merged state back to local and (if enabled) iCloud
            persistAll()
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
