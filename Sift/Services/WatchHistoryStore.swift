// PATH: Sift/Services/WatchHistoryStore.swift
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

    // User-facing iCloud toggle
    @Published var cloudSyncEnabled: Bool = true

    // MARK: - Keys & Stores
    private let localKey = "watch_history_local_v1"
    private let cloudKey = "watch_history_cloud_v1"
    private let syncEnabledKey = "watch_history_cloud_enabled"
    private let store = NSUbiquitousKeyValueStore.default

    private var observers: [NSObjectProtocol] = []

    // MARK: - Init
    init() {
        cloudSyncEnabled = UserDefaults.standard.bool(forKey: syncEnabledKey)

        // Load local
        if let data = UserDefaults.standard.data(forKey: localKey),
           let dict = Self.decodeLocal(data) {
            watched = dict
        }

        // Merge from cloud on launch if enabled
        if cloudSyncEnabled {
            if let data = store.data(forKey: cloudKey),
               let cloud = Self.decodeLocal(data) {
                merge(cloud: cloud)
            }
        }

        // Listen to iCloud KVS changes
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, self.cloudSyncEnabled else { return }
                if let data = self.store.data(forKey: self.cloudKey),
                   let inbound = Self.decodeLocal(data) {
                    self.merge(cloud: inbound)
                }
            }
        )
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers.removeAll()
    }

    // MARK: - Public API

    func markWatched(_ id: MovieID, at date: Date = .now) {
        watched[id] = date
        persistAll()
        if cloudSyncEnabled { pushToCloud() }
    }

    func unwatch(_ id: MovieID) {
        watched.removeValue(forKey: id)
        persistAll()
        if cloudSyncEnabled { pushToCloud() }
    }

    /// Default cooldown reduced to 120 days so libraries don’t feel “empty” for a year.
    func isCoolingDown(_ id: MovieID, cooldownDays: Int = 120) -> Bool {
        guard let d = watched[id] else { return false }
        return Date().timeIntervalSince(d) < TimeInterval(cooldownDays) * 24 * 60 * 60
    }

    func syncNow() {
        guard cloudSyncEnabled else { return }
        pushToCloud()
        store.synchronize()
        if let data = store.data(forKey: cloudKey),
           let inbound = Self.decodeLocal(data) {
            merge(cloud: inbound)
        }
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
               let inbound = Self.decodeLocal(data) {
                merge(cloud: inbound)
            }
        } else {
            // When disabling, do nothing destructive; user can re-enable later.
        }
    }

    // MARK: - Persistence

    private func persistAll() {
        if let data = Self.encodeLocal(watched) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    private func pushToCloud() {
        guard cloudSyncEnabled else { return }
        if let data = Self.encodeLocal(watched) {
            store.set(data, forKey: cloudKey)
        }
    }

    private func merge(cloud: [MovieID: Date]) {
        var merged = watched
        for (k, v) in cloud {
            if let cur = merged[k] {
                merged[k] = max(cur, v) // keep latest
            } else {
                merged[k] = v
            }
        }
        watched = merged
        persistAll()
    }

    // MARK: - Coding helpers

    private static func encodeLocal(_ dict: [MovieID: Date]) -> Data? {
        do {
            let payload = dict.mapValues { $0.timeIntervalSince1970 }
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            return nil
        }
    }

    private static func decodeLocal(_ data: Data) -> [MovieID: Date]? {
        do {
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Double] else {
                return nil
            }
            var out: [MovieID: Date] = [:]
            for (k, ts) in obj {
                if let id = Int(k) {
                    out[id] = Date(timeIntervalSince1970: ts)
                }
            }
            return out
        } catch {
            return nil
        }
    }
}
