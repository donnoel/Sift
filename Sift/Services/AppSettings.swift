// AppSettings.swift
import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let defaults: UserDefaults
    private let apiKeyKey = "tmdb_api_key"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var tmdbAPIKey: String {
        get { defaults.string(forKey: apiKeyKey) ?? "" }
        set {
            if newValue != tmdbAPIKey {
                objectWillChange.send()
                defaults.set(newValue, forKey: apiKeyKey)
            }
        }
    }
}
