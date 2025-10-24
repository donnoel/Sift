// PATH: Sift/Services/TMDBClient.swift
import Foundation

final class TMDBClient {
    // MARK: - Dependencies
    private weak var settings: AppSettings?
    private let session: URLSession

    // MARK: - Cached TMDB image configuration
    private var imageBaseURL: String?
    private var preferredPosterSize: String?   // e.g., "w500"

    // MARK: - Init
    init(settings: AppSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    // MARK: - Public API

    /// Best search match for a title (language=en-US, include_adult=false).
    /// Ranking favors: exact/near title match → year proximity (if available) → rating.
    func bestSearchMatch(for title: String) async throws -> TMDBSearchMovie? {
        try await bestSearchMatch(for: title, year: nil)
    }

    /// Overload that allows hinting a release year for tighter matching.
    func bestSearchMatch(for title: String, year: Int?) async throws -> TMDBSearchMovie? {
        guard let key = await apiKeyOrNil() else { return nil }
        let q = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        var queryItems: [URLQueryItem] = [
            .init(name: "query", value: q),
            .init(name: "include_adult", value: "false"),
            .init(name: "language", value: "en-US")
        ]
        if let year {
            queryItems.append(.init(name: "primary_release_year", value: String(year)))
        }

        let data = try await fetchData(
            path: "/search/movie",
            query: queryItems,
            apiKey: key
        )
        let resp: TMDBSearchResponse = try decode(data)
        guard !resp.results.isEmpty else { return nil }
        return rankSearchResults(queryTitle: q, queryYear: year, results: resp.results).first
    }

    /// Full movie details.
    func details(for movieID: Int) async throws -> TMDBMovieDetails {
        guard let key = await apiKeyOrNil() else {
            throw URLError(.userAuthenticationRequired)
        }
        let data = try await fetchData(
            path: "/movie/\(movieID)",
            query: [
                .init(name: "language", value: "en-US"),
                .init(name: "append_to_response", value: "credits,release_dates")
            ],
            apiKey: key
        )
        return try decode(data)
    }

    // MARK: - Image URLs

    /// Synchronous convenience: builds a poster URL from a TMDB poster path using any cached config.
    /// If the config isn't cached yet, it falls back to a standard `w500` URL.
    /// Use this in UI code when you don't want to `await`, and accept the safe fallback.
    func posterURL(for posterPath: String?) -> URL? {
        guard let posterPath else { return nil }
        if let base = imageBaseURL, let size = preferredPosterSize {
            return URL(string: base + size + posterPath)
        }
        // Fallback mirrors previous behavior (and keeps tests stable).
        return URL(string: "https://image.tmdb.org/t/p/w500" + posterPath)
    }

    /// Builds a full poster URL, lazily loading the TMDB image configuration if needed.
    /// If config fetch fails, returns a safe `w500` fallback.
    func imageURL(forPosterPath posterPath: String?) async throws -> URL? {
        guard let posterPath else { return nil }
        if imageBaseURL == nil || preferredPosterSize == nil {
            // Lazy-load once; failures are non-fatal (we'll fall back).
            try? await ensureImageConfigurationLoaded()
        }
        if let base = imageBaseURL, let size = preferredPosterSize {
            return URL(string: base + size + posterPath)
        } else {
            // Fallback mirrors Movie.posterURL behavior
            return URL(string: "https://image.tmdb.org/t/p/w500" + posterPath)
        }
    }

    // MARK: - Internal: Configuration

    private func ensureImageConfigurationLoaded() async throws {
        guard imageBaseURL == nil || preferredPosterSize == nil else { return }
        guard let key = await apiKeyOrNil() else { return }

        let data = try await fetchData(
            path: "/configuration",
            query: [],
            apiKey: key
        )
        let resp: TMDBImagesConfigResponse = try decode(data)

        // Choose a sensible poster size: prefer w500, else nearest ≥ w500, else the largest available.
        let sizes = resp.images.poster_sizes
        let chosen: String = {
            if sizes.contains("w500") { return "w500" }
            // pick the first size >= w500 if present, else the max size
            let numeric = sizes.compactMap { PosterSize(rawValue: $0) }.sorted()
            if let atLeast500 = numeric.first(where: { $0.pixelWidth >= 500 }) {
                return atLeast500.rawValue
            }
            return numeric.last?.rawValue ?? "w500"
        }()

        // Prefer secure base URL when available.
        let base = resp.images.secure_base_url.isEmpty ? resp.images.base_url : resp.images.secure_base_url

        self.imageBaseURL = base
        self.preferredPosterSize = chosen
    }

    // MARK: - Networking

    private func fetchData(path: String, query: [URLQueryItem], apiKey: String) async throws -> Data {
        // TMDB base
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "api.themoviedb.org"
        comps.path = "/3" + path
        comps.queryItems = (query + [URLQueryItem(name: "api_key", value: apiKey)])

        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: - Helpers

    private func apiKeyOrNil() async -> String? {
        await MainActor.run { [weak settings] in
            guard let s = settings else { return nil }
            let key = s.tmdbAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let dec = JSONDecoder()
        // Our schema uses snake_case properties already (release_date, poster_path), so no key strategy needed.
        return try dec.decode(T.self, from: data)
    }

    // MARK: - Search Ranking

    private func rankSearchResults(queryTitle: String, queryYear: Int?, results: [TMDBSearchMovie]) -> [TMDBSearchMovie] {
        let qNorm = normalizeTitle(queryTitle)
        let qTokens = tokenSet(qNorm)

        // Score each candidate; higher is better.
        struct Scored { let movie: TMDBSearchMovie; let score: Double }
        var scored: [Scored] = []

        for m in results {
            let titleNorm = normalizeTitle(m.title)
            let tokens = tokenSet(titleNorm)

            var score: Double = 0

            // 1) Exact title match
            if titleNorm == qNorm { score += 1000 }

            // 2) Token overlap (Jaccard-style)
            let interCount = tokens.intersection(qTokens).count
            let unionCount = tokens.union(qTokens).count
            if unionCount > 0 {
                score += Double(interCount) / Double(unionCount) * 100
            }

            // 3) Year proximity (if both sides have a year)
            if let qy = queryYear, let my = year(from: m.release_date) {
                let diff = abs(qy - my)
                // Perfect match gets a nice boost; ±1 still good; else diminishing
                if diff == 0 { score += 80 }
                else if diff == 1 { score += 40 }
                else if diff <= 3 { score += 10 }
            }

            // 4) Rating as a tiebreaker (scaled)
            if let r = m.vote_average {
                score += r // vote_average is 0-10
            }

            scored.append(.init(movie: m, score: score))
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                // Secondary stable sort: earlier release year first (older originals),
                // fall back to title lexicographic
                let ly = year(from: lhs.movie.release_date) ?? Int.max
                let ry = year(from: rhs.movie.release_date) ?? Int.max
                if ly != ry { return ly < ry }
                return lhs.movie.title.localizedCaseInsensitiveCompare(rhs.movie.title) == .orderedAscending
            }
            .map { $0.movie }
    }

    private func normalizeTitle(_ s: String) -> String {
        let lowered = s.lowercased()
        let folded = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .autoupdatingCurrent)
        // Strip punctuation and extra spaces
        let cleaned = folded.unicodeScalars.filter { CharacterSet.alphanumerics.union(.whitespacesAndNewlines).contains($0) }
        return String(String.UnicodeScalarView(cleaned)).replacingOccurrences(of: #"s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenSet(_ s: String) -> Set<String> {
        Set(s.split(whereSeparator: { $0.isWhitespace }).map(String.init))
    }

    private func year(from dateStr: String?) -> Int? {
        guard let s = dateStr, s.count >= 4, let y = Int(s.prefix(4)) else { return nil }
        return y
    }
}

// MARK: - Poster Size Utility
/// Helps order sizes like "w154", "w342", "w500", "original" by numeric width.
private struct PosterSize: RawRepresentable, Comparable {
    let rawValue: String
    let pixelWidth: Int

    init?(rawValue: String) {
        self.rawValue = rawValue
        if rawValue == "original" {
            self.pixelWidth = .max
        } else if rawValue.first == "w", let n = Int(rawValue.dropFirst()) {
            self.pixelWidth = n
        } else {
            return nil
        }
    }

    static func < (lhs: PosterSize, rhs: PosterSize) -> Bool {
        lhs.pixelWidth < rhs.pixelWidth
    }
}
