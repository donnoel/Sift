// PATH: SiftTests/TestSupport/Movie+Example.swift
import Foundation
@testable import Sift

extension Movie {
    static func example(id: Int = 42, title: String = "Example", overview: String? = "Overview") -> Movie {
        Movie(id: id, title: title, release_date: "2020-01-01", poster_path: nil, overview: overview, vote_average: 7.5)
    }
}