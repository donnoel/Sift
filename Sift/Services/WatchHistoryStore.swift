// PATH: Sift/Services/WatchHistoryStore.swift
import Foundation
import Combine
import os

/// Syncs the watched list locally (UserDefaults) and across devices using iCloud Key-Value Store.
/// - Stores JSON under one key in both stores.
/// - Merges inbound iCloud changes by keeping the *latest* date per movie ID.
/// - Toggle iCloud with `cloudSyncEnabled`; call `syncNow()` to force a round-trip.
@MainActor
final class WatchHistoryStore: ObservableObject {
    static let shared = WatchHistoryStore()

    typealias MovieID = Int

    // MARK: - Published state
    /// movieID : lastSeen
    @Published private(set) var watched: [MovieID: Date] = [:]

    // MARK: - Persistence keys
    private let localKey = "watched_local_v1"
    private let cloudKey = "watched_cloud_v1"
    private let syncEnabledKey = "watched_sync_enabled_v1"

    // MARK: - Dependencies
    private let defaults: UserDefaults
    private let store: NSUbiquitousKeyValueStore
    private let log = Logger(subsystem: "Sift", category: "WatchHistory")

    // MARK: - Settings
    private(set) var cloudSyncEnabled: Bool {
        didSet { defaults.set(cloudSyncEnabled, forKey: syncEnabledKey) }
    }

    // MARK: - Lifecycle
    init(defaults: UserDefaults = .standard,
         store: NSUbiquitousKeyValueStore = .default) {
        self.defaults = defaults
        self.store = store
        self.cloudSyncEnabled = defaults.bool(forKey: syncEnabledKey)

        // Load local snapshot
        if let data = defaults.data(forKey: localKey),
           let dict = Self.decodeLocal(data) {
            watched = dict
        }

        // If sync is enabled, pull once and merge
        if cloudSyncEnabled, let data = store.data(forKey: cloudKey),
           let inbound = Self.decodeLocal(data) {
            merge(cloud: inbound)
        }

        // Observe external iCloud changes
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard self.cloudSyncEnabled else { return }
            if let data = self.store.data(forKey: self.cloudKey),
               let inbound = Self.decodeLocal(data) {
                self.merge(cloud: inbound)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func clearAll() {
        watched.removeAll()
        persistAll()
    }

    /// NOTE: Label is **on** (matches tests and prior usage).
    func markWatched(_ id: MovieID, on date: Date = .now) {
        watched[id] = date
        persistAll()
    }

    func unwatch(_ id: MovieID) {
        watched.removeValue(forKey: id)
        persistAll()
    }

    /// Returns true when the movie has been watched within the last `cooldownDays`.
    func isCoolingDown(_ id: MovieID, cooldownDays: Int = 120) -> Bool {
        guard let last = watched[id] else { return false }
        let interval = Date().timeIntervalSince(last)
        return interval < TimeInterval(cooldownDays) * 24 * 60 * 60
    }

    /// Pushes local → iCloud and then pulls/merges back to converge.
    func syncNow() {
        guard cloudSyncEnabled else { return }
        if let data = Self.encodeLocal(watched) {
            store.set(data, forKey: cloudKey)
        }
        store.synchronize()
        if let data = store.data(forKey: cloudKey),
           let inbound = Self.decodeLocal(data) {
            merge(cloud: inbound)
        }
    }

    /// Toggle iCloud sync at runtime.
    func setCloudSyncEnabled(_ enabled: Bool) {
        guard enabled != cloudSyncEnabled else { return }
        cloudSyncEnabled = enabled
        if enabled {
            // Push current local state up, then pull/merge once.
            if let data = Self.encodeLocal(watched) {
                store.set(data, forKey: cloudKey)
            }
            store.synchronize()
            if let data = store.data(forKey: cloudKey),
               let inbound = Self.decodeLocal(data) {
                merge(cloud: inbound)
            }
        } else {
            // Leave cloud state as-is; we just stop reacting to it.
        }
    }

    // MARK: - Internals

    private func persistAll() {
        if let data = Self.encodeLocal(watched) {
            defaults.set(data, forKey: localKey)
            if cloudSyncEnabled {
                store.set(data, forKey: cloudKey)
                store.synchronize()
            }
        }
    }

    private func merge(cloud inbound: [MovieID: Date]) {
        var merged = watched
        for (k, v) in inbound {
            if let cur = merged[k] {
                merged[k] = max(cur, v) // keep latest date
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
            // JSONSerialization requires String keys; convert from Int -> String
            let payload: [String: Double] = dict.reduce(into: [:]) { result, pair in
                result[String(pair.key)] = pair.value.timeIntervalSince1970
            }
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
