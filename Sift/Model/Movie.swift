// PATH: Sift/Model/Movie.swift
import Foundation

struct Movie: Identifiable, Codable, Hashable {
    let id: Int
    var title: String
    var year: Int?
    var rating: Double?
    var overview: String?
    var posterPath: String?

    /// NEW: TMDB genre names captured during import (authoritative, optional for back-compat).
    var tmdbGenres: [String]? = nil

    var posterURL: URL? {
        guard let p = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500" + p)
    }
}
