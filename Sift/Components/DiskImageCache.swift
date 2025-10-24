import Foundation
import CryptoKit

actor DiskImageCache {
    nonisolated static let shared = DiskImageCache()

    private let fm = FileManager.default
    private let mem = NSCache<NSURL, NSData>()
    private let ttl: TimeInterval
    nonisolated private let cacheDir: URL
    private var inflight: [URL: Task<Data?, Never>] = [:]

    init(ttlDays: Int = 14) {
        self.ttl = TimeInterval(ttlDays) * 24 * 60 * 60
        mem.countLimit = 200
        mem.totalCostLimit = 64 * 1024 * 1024
        // Initialize a nonisolated, immutable cache directory path safely during init
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = base.appendingPathComponent("ImageCache", isDirectory: true)
        try? fm.createDirectory(at: self.cacheDir, withIntermediateDirectories: true, attributes: nil)
    }

    /// Memory → Disk → Network (coalesced) with background refresh of stale files.
    func data(for url: URL) async -> Data? {
        let nsURL = url as NSURL

        // 1) Memory
        if let cached = mem.object(forKey: nsURL) {
            return cached as Data
        }

        // 2) Disk
        let path = filePath(for: url)
        if let existing = try? Data(contentsOf: path) {
            mem.setObject(existing as NSData, forKey: nsURL, cost: existing.count)

            // If stale, refresh in background (doesn't block the caller)
            if isStale(path) {
                Task.detached { await DiskImageCache.shared.refresh(url, to: path) }
            }
            return existing
        }

        // 3) Network (coalesced so duplicate requests share one download)
        if let task = inflight[url] {
            if let data = await task.value {
                mem.setObject(data as NSData, forKey: nsURL, cost: data.count)
                write(data, to: path)
                return data
            }
            return nil
        } else {
            let task = Task<Data?, Never> { [weak self] in
                guard let self = self else { return nil }
                return await self.download(url)
            }
            inflight[url] = task
            let fresh = await task.value
            inflight[url] = nil

            if let data = fresh {
                mem.setObject(data as NSData, forKey: nsURL, cost: data.count)
                write(data, to: path)
            }
            return fresh
        }
    }

    /// Fire-and-forget warmup for a list of URLs (skips ones we already have).
    func preheat(_ urls: [URL]) async {
        for url in urls {
            let nsURL = url as NSURL

            // Skip if already in memory
            if mem.object(forKey: nsURL) != nil { continue }

            let path = filePath(for: url)
            // Skip if present on disk and not stale (background refresh will handle stale)
            if fm.fileExists(atPath: path.path), !isStale(path) { continue }

            // Avoid duplicate network work
            if inflight[url] != nil { continue }

            let task = Task<Data?, Never> { [weak self] in
                guard let self = self else { return nil }
                return await self.download(url)
            }
            inflight[url] = task

            let data = await task.value
            inflight[url] = nil

            if let d = data {
                mem.setObject(d as NSData, forKey: nsURL, cost: d.count)
                write(d, to: path)
            }
        }
    }

    // MARK: - Internals

    private func filePath(for url: URL) -> URL {
        let hash = sha256(url.absoluteString)
        return cacheDir.appendingPathComponent(hash + ".img", isDirectory: false)
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func isStale(_ fileURL: URL) -> Bool {
        guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
              let mod = attrs[.modificationDate] as? Date else { return true }
        return Date().timeIntervalSince(mod) > ttl
    }

    private func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
            // Update mtime so staleness checks are accurate
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } catch {
            // intentionally ignore write errors for cache
        }
    }

    private func download(_ url: URL) async -> Data? {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("image/*", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  !data.isEmpty else { return nil }
            // Extra safety: only cache when the server declares an image content type (when present).
            if let ctype = http.value(forHTTPHeaderField: "Content-Type"),
               !ctype.lowercased().hasPrefix("image/") {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func refresh(_ url: URL, to path: URL) async {
        // If another call is already in-flight, reuse it
        if let task = inflight[url] {
            if let data = await task.value {
                write(data, to: path)
                mem.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
            }
            return
        }
        let task = Task<Data?, Never> { [weak self] in
            guard let self = self else { return nil }
            return await self.download(url)
        }
        inflight[url] = task
        let fresh = await task.value
        inflight[url] = nil

        if let data = fresh {
            write(data, to: path)
            mem.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        }
    }
}
