// PATH: Sift/Stores/LibraryStore.swift
import SwiftUI
import Combine
import Foundation

// MARK: - Testable persistence abstraction
protocol LibraryPersisting {
    func load() async -> [Movie]?
    func save(movies: [Movie]) async
}

// The real persistence already exists; make it conform for free.
extension LibraryPersistence: LibraryPersisting {}

@MainActor
final class LibraryStore: ObservableObject {
    // MARK: - Published State
    @Published private(set) var movies: [Movie] = []
    @Published var isImporting = false
    @Published var progress: Double = 0
    @Published var lastErrors: [String] = []

    // MARK: - Dependencies
    private let client: TMDBClient
    private let persistence: LibraryPersisting

    // MARK: - Init (inject client & persistence for tests)
    init(
        settings: AppSettings,
        client: TMDBClient? = nil,
        persistence: LibraryPersisting = LibraryPersistence(),
        loadOnInit: Bool = true
    ) {
        self.client = client ?? TMDBClient(settings: settings)
        self.persistence = persistence
        if loadOnInit {
            Task { await loadFromDisk() }
        }
    }

    // MARK: - Persistence
    private func loadFromDisk() async {
        let loaded = await persistence.load() ?? []
        self.movies = loaded
    }

    private func saveToDisk() async {
        await persistence.save(movies: movies)
    }

    // MARK: - Image URLs
    /// Build a poster URL using the TMDB config cached in TMDBClient (falls back to w500).
    func posterURL(for posterPath: String?) -> URL? {
        client.posterURL(for: posterPath)
    }

    // MARK: - Import (bounded concurrency)
    /// Parses pasted lines, searches TMDB, fetches details, and appends to library.
    /// Uses a small concurrency window to keep the UI responsive and imports fast.
    func importFromPaste(_ text: String) async {
        lastErrors.removeAll()
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }

        isImporting = true
        progress = 0

        // Concurrency window
        let maxInFlight = 6
        let total = Double(lines.count)
        var step = 0.0
        var imported: [Movie] = []

        await withTaskGroup(of: (Movie?, String?).self) { group in
            var iterator = lines.makeIterator()

            func enqueueNext() {
                guard let line = iterator.next() else { return }
                group.addTask {
                    do {
                        let parsed = Self.parseImportLine(line)
                        let query = parsed.title.isEmpty ? line : parsed.title

                        guard let match = try await self.client.bestSearchMatch(for: query, year: parsed.year) else {
                            return (nil, "No match for: \(line)")
                        }
                        let details = try await self.client.details(for: match.id)

                        // Persist TMDB genres so the engine can use them authoritatively.
                        let movie = Movie(
                            id: details.id,
                            title: details.title,
                            year: Self.year(from: details.release_date),
                            rating: details.vote_average,
                            overview: details.overview,
                            posterPath: details.poster_path,
                            tmdbGenres: details.genres?.map { $0.name }
                        )
                        return (movie, nil)
                    } catch let e as URLError {
                        return (nil, "Network error for: \(line) (\(e.code.rawValue))")
                    } catch {
                        return (nil, "Error for: \(line) (\(error.localizedDescription))")
                    }
                }
            }

            // Fill the pipeline
            for _ in 0..<maxInFlight { enqueueNext() }

            // Drain results and keep the pipeline full
            while let result = await group.next() {
                let (movie, err) = result
                if let m = movie { imported.append(m) }
                if let e = err { lastErrors.append(e) }
                step += 1
                progress = min(1.0, step / total)
                enqueueNext()
            }
        }

        // Merge: avoid duplicates by id (prefer new details)
        var byID: [Int: Movie] = [:]
        for m in movies { byID[m.id] = m }
        for m in imported { byID[m.id] = m }
        movies = Array(byID.values).sorted {
            ($0.title, $0.year ?? 0, $0.id) < ($1.title, $1.year ?? 0, $1.id)
        }

        await saveToDisk()
        isImporting = false
    }

    // MARK: - Maintenance
    /// Clear the entire on-device library database.
    func clearAll() async {
        lastErrors.removeAll()
        isImporting = false
        progress = 0
        movies.removeAll()
        await saveToDisk()
    }

    // MARK: - Utilities

    /// Extract a 4-digit year from the start of a date string like "2014-11-07".
    nonisolated static func year(from dateStr: String?) -> Int? {
        guard let s = dateStr, s.count >= 4, let y = Int(s.prefix(4)) else { return nil }
        return y
    }

    /// Parses a pasted line into a cleaned search title and optional release year hint.
    /// Accepts inputs like:
    ///   "Interstellar (2014)", "Interstellar - 2014", "Interstellar 2014", "Interstellar"
    nonisolated static func parseImportLine(_ raw: String) -> (title: String, year: Int?) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find a trailing 4-digit year in common patterns.
        let patterns = [
            #"\((\d{4})\)\s*$"#,
            #"\-\s*(\d{4})\s*$"#,
            #"(\d{4})\s*$"#
        ]

        for p in patterns {
            if let r = s.range(of: p, options: .regularExpression) {
                let yearStr = String(s[r]).filter("0123456789".contains)
                let title = s.replacingCharacters(in: r, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let y = Int(yearStr) { return (title, y) }
            }
        }
        return (s, nil)
    }
}
