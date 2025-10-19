// PATH: Sift/Stores/LibraryStore.swift
import SwiftUI
import Combine

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

    // MARK: - Import
    /// Parses pasted lines, searches TMDB, fetches details, and appends to library.
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

        for line in lines {
            do {
                guard let match = try await client.bestSearchMatch(for: line) else {
                    lastErrors.append("No match for: \(line)")
                    continue
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
                imported.append(movie)
            } catch {
                lastErrors.append("Error \"\(line)\": \(error.localizedDescription)")
            }
            step += 1
            progress = min(1.0, step / total)
        }

        // Merge: avoid duplicates by id (prefer new details)
        var byID: [Int: Movie] = movies.reduce(into: [:]) { $0[$1.id] = $1 }
        for m in imported { byID[m.id] = m }
        movies = Array(byID.values).sorted { ($0.title, $0.year ?? 0) < ($1.title, $1.year ?? 0) }

        await saveToDisk()
        isImporting = false
    }

    // MARK: - Utilities

    // Internal so tests can call it directly.
    static func year(from dateStr: String?) -> Int? {
        guard let s = dateStr, s.count >= 4, let y = Int(s.prefix(4)) else { return nil }
        return y
    }
}
