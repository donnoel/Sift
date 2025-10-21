import Foundation

// Simple genre enum used by the recommendation engine.
// If you already define MovieGenre elsewhere, remove this declaration to avoid duplication.
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

    func compute(
        library: [Movie],
        rails wantedRails: [MovieGenre] = [.actionAdventure, .comedy, .drama, .horror, .thriller, .scienceFiction],
        picksPerRail: Int = 8
    ) -> RecommendationResult {
        guard !library.isEmpty else {
            return RecommendationResult(mainPick: nil, rails: [:])
        }

        // Choose a main pick: highest rating if available; otherwise first.
        let main = library.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }.first

        // Precompute genre buckets
        var buckets: [MovieGenre: [Movie]] = [:]
        var unclassified: [Movie] = []

        for m in library {
            let gs = classify(m)
            if gs.isEmpty {
                unclassified.append(m)
            } else {
                for g in gs {
                    buckets[g, default: []].append(m)
                }
            }
        }

        // Sort each bucket by rating desc, then title asc (stable & deterministic)
        for g in buckets.keys {
            buckets[g] = buckets[g, default: []].sorted {
                let l = ($0.rating ?? 0), r = ($1.rating ?? 0)
                if l != r { return l > r }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        unclassified.sort {
            let l = ($0.rating ?? 0), r = ($1.rating ?? 0)
            if l != r { return l > r }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        // Dedup against main + across rails
        var used = Set<Int>()
        if let main { used.insert(main.id) }

        func take(from array: inout [Movie], max k: Int) -> [Movie] {
            var picked: [Movie] = []
            picked.reserveCapacity(min(k, array.count))
            var i = 0
            while i < array.count && picked.count < k {
                let m = array[i]
                if !used.contains(m.id) {
                    picked.append(m)
                    used.insert(m.id)
                }
                i += 1
            }
            return picked
        }

        var railMap: [MovieGenre: [Movie]] = [:]

        // First pass: take from matching buckets
        for g in wantedRails {
            var bucket = buckets[g, default: []]
            let fromOwn = take(from: &bucket, max: picksPerRail)
            railMap[g] = fromOwn
            buckets[g] = bucket
        }

        // Second pass: backfill any short rails from remaining content (other buckets + unclassified)
        var leftovers: [Movie] = []
        for g in wantedRails {
            leftovers.append(contentsOf: buckets[g, default: []].filter { !used.contains($0.id) })
        }
        leftovers.append(contentsOf: unclassified.filter { !used.contains($0.id) })

        // Sort leftovers deterministically
        leftovers.sort {
            let l = ($0.rating ?? 0), r = ($1.rating ?? 0)
            if l != r { return l > r }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        var leftIndex = 0
        for g in wantedRails {
            var current = railMap[g] ?? []
            while current.count < picksPerRail, leftIndex < leftovers.count {
                let m = leftovers[leftIndex]; leftIndex += 1
                if !used.contains(m.id) {
                    current.append(m); used.insert(m.id)
                }
            }
            if !current.isEmpty {
                railMap[g] = current
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
