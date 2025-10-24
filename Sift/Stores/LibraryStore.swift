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

        var imported: [Movie] = []
        let total = Double(lines.count)
        var step = 0.0

        let maxConcurrent = 4
        let client = self.client  // capture for task closures

        await withTaskGroup(of: (Movie?, String?).self) { group in
            var iterator = lines.makeIterator()

            func enqueueNext() {
                guard let line = iterator.next() else { return }
                group.addTask {
                    do {
                        let parsed = Self.parseImportLine(line)
                        let query = parsed.title.isEmpty ? line : parsed.title
                        guard let match = try await client.bestSearchMatch(for: query, year: parsed.year) else {
                            return (nil, "No match for: \(line)")
                        }
                        let details = try await client.details(for: match.id)
                        let movie = Movie(
                            id: details.id,
                            title: details.title,
                            year: Self.year(from: details.release_date),
                            rating: details.vote_average,
                            overview: details.overview,
                            posterPath: details.poster_path
                        )
                        return (movie, nil)
                    } catch {
                        return (nil, "Error \"\(line)\": \(error.localizedDescription)")
                    }
                }
            }

            // Prime the group
            for _ in 0..<min(maxConcurrent, lines.count) {
                enqueueNext()
            }

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
        var byID: [Int: Movie] = movies.reduce(into: [:]) { $0[$1.id] = $1 }
        for m in imported { byID[m.id] = m }
        movies = Array(byID.values).sorted { ($0.title, $0.year ?? 0) < ($1.title, $1.year ?? 0) }

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

    // Internal so tests can call it directly.
    nonisolated static func year(from dateStr: String?) -> Int? {
        guard let s = dateStr, s.count >= 4, let y = Int(s.prefix(4)) else { return nil }
        return y
    }

    /// Parses a pasted line into a cleaned search title and optional release year hint.
    /// Accepts inputs like "Heat 1995", "The Thing (1982)" or "Arrival [2016]" and
    /// trims any trailing punctuation after removing the detected year.
    nonisolated static func parseImportLine(_ line: String) -> (title: String, year: Int?) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", nil) }

        let pattern = "(?<!\\d)(\\d{4})(?!\\d)[^\\d]*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (trimmed, nil)
        }

        let nsString = trimmed as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: fullRange) else {
            return (trimmed, nil)
        }

        let yearRange = match.range(at: 1)
        guard let yearStringRange = Range(yearRange, in: trimmed),
              let year = Int(trimmed[yearStringRange]),
              (1888...2100).contains(year) else {
            return (trimmed, nil)
        }

        var title = trimmed
        if let removalRange = Range(match.range, in: trimmed) {
            title.removeSubrange(removalRange)
        }

        title = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        return (title, year)
    }
}
