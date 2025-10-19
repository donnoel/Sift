// PATH: Sift/Services/TMDBClient.swift  (use your actual path for TMDBClient)
import Foundation

actor TMDBClient {
    private weak var settings: AppSettings?
    private var imageBaseURL: String?
    private let session: URLSession   // ← injected

    init(settings: AppSettings, session: URLSession = .shared) { // ← default .shared
        self.settings = settings
        self.session = session
    }

    func bestSearchMatch(for title: String) async throws -> TMDBSearchMovie? {
        guard let key = await apiKeyOrNil() else { return nil }
        let encoded = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !encoded.isEmpty else { return nil }
        let resp: TMDBSearchResponse = try await fetch(
            path: "/search/movie",
            query: [URLQueryItem(name: "query", value: encoded)],
            apiKey: key
        )
        return resp.results.first
    }

    func details(for movieID: Int) async throws -> TMDBMovieDetails {
        guard let key = await apiKeyOrNil() else { throw URLError(.userAuthenticationRequired) }
        return try await fetch(path: "/movie/\(movieID)", query: [], apiKey: key)
    }

    func refreshImagesConfigIfNeeded() async {
        guard imageBaseURL == nil, let key = await apiKeyOrNil() else { return }
        if let cfg: TMDBImagesConfigResponse = try? await fetch(path: "/configuration", query: [], apiKey: key) {
            self.imageBaseURL = cfg.images.secure_base_url
        }
    }

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem], apiKey: String) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = "/3" + path
        var items = query
        items.append(URLQueryItem(name: "api_key", value: apiKey))
        items.append(URLQueryItem(name: "language", value: "en-US"))
        components.queryItems = items

        guard let url = components.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData

        // USE INJECTED SESSION (this is the key)
        let (data, resp) = try await session.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func apiKeyOrNil() async -> String? {
        let settingsRef = self.settings
        return await MainActor.run { [settingsRef] in
            guard let s = settingsRef else { return nil }
            let key = s.tmdbAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        }
    }
}
