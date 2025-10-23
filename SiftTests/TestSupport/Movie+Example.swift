import Foundation
@testable import Sift

extension Movie {
    static func example(id: Int = 42, title: String = "Example", overview: String? = "Overview") -> Movie {
        Movie(id: id, title: title, year: 2020, rating: 7.5, overview: overview, posterPath: nil)
    }
}
