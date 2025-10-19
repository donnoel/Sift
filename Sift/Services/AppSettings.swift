// PATH: Sift/Services/AppSettings.swift
import Foundation
import Combine

/// Global app configuration and user-editable settings.
/// Keeps the TMDB API key that `TMDBClient` reads from the main actor and persists it.
@MainActor
final class AppSettings: ObservableObject {
    
    @Published var tmdbAPIKey: String {
        didSet { UserDefaults.standard.set(self.tmdbAPIKey, forKey: Self.key) }
    }

    private static let key = "tmdb_api_key"

    init() {
        self.tmdbAPIKey = UserDefaults.standard.string(forKey: Self.key) ?? ""
    }
}
