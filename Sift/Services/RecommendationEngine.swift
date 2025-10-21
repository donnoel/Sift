import Foundation

enum MovieGenre: String, CaseIterable, Hashable {
    case actionAdventure = "Action/Adventure"
    case comedy = "Comedy"
    case drama = "Drama"
    case horror = "Horror"
    case thriller = "Thriller"
    case scienceFiction = "Science Fiction"
}

struct RecommendationResult {
    let mainPick: Movie?
    let rails: [MovieGenre: [Movie]]
}

struct RecommendationEngine {
    /// Heuristic genre classification based on title/overview keywords.
    private func classify(_ movie: Movie) -> Set<MovieGenre> {
        let t = movie.title.lowercased()
        let o = (movie.overview ?? "").lowercased()
        let text = t + " " + o

        var g: Set<MovieGenre> = []

        if text.containsAny(of: ["space","alien","future","robot","cyber","sci-fi","sci fi"]) {
            g.insert(.scienceFiction)
        }
        if text.containsAny(of: ["murder","chase","detective","suspense","conspiracy","crime","heist"]) {
            g.insert(.thriller)
        }
        if text.containsAny(of: ["ghost","haunted","demon","slash","zombie","possession","creature","horror"]) {
            g.insert(.horror)
        }
        if text.containsAny(of: ["war","battle","spy","mission","explosion","car chase","ninja","sword","fight","adventure","action"]) {
            g.insert(.actionAdventure)
        }
        if text.containsAny(of: ["love","family","life","tragedy","biopic","drama","relationship"]) {
            g.insert(.drama)
        }
        if text.containsAny(of: ["funny","hilarious","comedy","sitcom","joke","laugh"]) {
            g.insert(.comedy)
        }
        return g
    }

    func compute(library: [Movie],
                 rails: [MovieGenre] = [.actionAdventure, .comedy, .drama, .horror, .thriller, .scienceFiction],
                 picksPerRail: Int = 8) -> RecommendationResult {

        // Choose a main pick: highest rating if available; otherwise first.
        let main = library
            .sorted(by: { ($0.rating ?? 0) > ($1.rating ?? 0) })
            .first

        var used = Set<Int>()
        if let main { used.insert(main.id) }

        // Build rails with dedupe across rails and vs main
        var railMap: [MovieGenre: [Movie]] = [:]

        for genre in rails {
            var bucket: [Movie] = []
            for m in library {
                guard !used.contains(m.id) else { continue }
                if classify(m).contains(genre) {
                    bucket.append(m)
                    used.insert(m.id)
                    if bucket.count == picksPerRail { break }
                }
            }
            if !bucket.isEmpty {
                railMap[genre] = bucket
            }
        }

        return RecommendationResult(mainPick: main, rails: railMap)
    }
}

private extension String {
    func containsAny(of needles: [String]) -> Bool {
        for n in needles where self.contains(n) { return true }
        return false
    }
}
