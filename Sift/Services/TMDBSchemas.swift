import Foundation

struct TMDBSearchResponse: Codable { let results: [TMDBSearchMovie] }

struct TMDBSearchMovie: Codable {
    let id: Int
    let title: String
    let release_date: String?
    let poster_path: String?
    let overview: String?
    let vote_average: Double?
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let release_date: String?
    let poster_path: String?
    let overview: String?
    let vote_average: Double?
    let genres: [TMDBGenre]?
    let runtime: Int?
}

struct TMDBGenre: Codable { let name: String }

struct TMDBImagesConfigResponse: Codable { let images: TMDBImagesConfig }

struct TMDBImagesConfig: Codable {
    let base_url: String
    let secure_base_url: String
    let poster_sizes: [String]
}
