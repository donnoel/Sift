// PATH: Sift/Services/RecommendationEngine.swift
import Foundation

// If you already declare MovieGenre elsewhere, keep this enum here (as-is) or remove it there.
// Keeping it here ensures this file compiles on its own.
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

    /// Compute hero + rails deterministically from a seed.
    /// - Parameters:
    ///   - library: pre-filtered library (ForYouViewModel already removes cooldown)
    ///   - rails: which rails to build (order respected)
    ///   - picksPerRail: target count per rail
    ///   - seed: deterministically affects selection/rotation
    func compute(
        library: [Movie],
        rails: [MovieGenre],
        picksPerRail: Int,
        seed: UInt64
    ) -> RecommendationResult {

        guard !library.isEmpty else {
            return .init(mainPick: nil, rails: [:])
        }

        // 1) Classify each movie → set of genres.
        var byGenre: [MovieGenre: [Movie]] = [:]
        var allClassified: [Movie] = []
        allClassified.reserveCapacity(library.count)

        for m in library {
            let g = classify(m)
            if g.isEmpty { continue }
            allClassified.append(m)
            for gg in g { byGenre[gg, default: []].append(m) }
        }

        // 2) Score function favors higher ratings and year proximity to median.
        let medianYear = median(library.compactMap { $0.year })
        func score(_ m: Movie) -> Double {
            let r = (m.rating ?? 0) / 10.0                // 0…1
            let y = m.year ?? medianYear ?? 2000
            let yDelta = abs(Double(y - (medianYear ?? y)))
            let yBoost = max(0.0, 1.0 - min(yDelta, 25.0)/25.0) // within ~25y zone
            return r * 0.7 + yBoost * 0.3
        }

        // 3) Choose a main pick from the top bucket; deterministic rotation by seed.
        let rankedAll = library.sorted { score($0) > score($1) }
        let heroPool = Array(rankedAll.prefix(max(12, picksPerRail)))
        let mainPick = rotate(heroPool, by: Int(seed % UInt64(max(heroPool.count, 1)))).first

        // 4) Build rails: per-genre ranked lists, dedupe across rails & hero, then backfill.
        var used: Set<Int> = []
        if let h = mainPick { used.insert(h.id) }

        // Pre-rank each rail
        var railMap: [MovieGenre: [Movie]] = [:]
        for g in rails {
            let candidates = (byGenre[g] ?? [])
                .sorted { score($0) > score($1) }
            railMap[g] = candidates
        }

        // Dedupe and take top N per rail, rotating by seed to give variety.
        for g in rails {
            let base = rotate(railMap[g] ?? [], by: Int(seed % 17))
            var out: [Movie] = []
            for m in base where out.count < picksPerRail {
                if used.insert(m.id).inserted { out.append(m) }
            }
            railMap[g] = out
        }

        // Backfill skinnier rails using leftover high-quality titles.
        let leftoverPool = rankedAll.filter { !used.contains($0.id) }
        var li = 0
        for g in rails {
            var curr = railMap[g] ?? []
            while curr.count < picksPerRail, li < leftoverPool.count {
                let m = leftoverPool[li]; li += 1
                if used.insert(m.id).inserted { curr.append(m) }
            }
            railMap[g] = curr
        }

        return .init(mainPick: mainPick, rails: railMap)
    }

    // MARK: - Genre classification (prefer TMDB, fallback to keywords)
    private func classify(_ movie: Movie) -> Set<MovieGenre> {
        // 1) Use authoritative TMDB tags if present.
        if let names = movie.tmdbGenres, !names.isEmpty {
            var out: Set<MovieGenre> = []
            let g = names.map { $0.lowercased() }

            if g.contains(where: { $0.contains("action") || $0.contains("adventure") }) {
                out.insert(.actionAdventure)
            }
            if g.contains(where: { $0.contains("science fiction") || $0 == "sci-fi" || $0 == "sci fi" }) {
                out.insert(.scienceFiction)
            }
            if g.contains(where: { $0.contains("comedy") }) {
                out.insert(.comedy)
            }
            if g.contains(where: { $0.contains("drama") }) {
                out.insert(.drama)
            }
            if g.contains(where: { $0.contains("horror") }) {
                out.insert(.horror)
            }
            if g.contains(where: { $0.contains("thriller") || $0.contains("crime") || $0.contains("mystery") }) {
                out.insert(.thriller)
            }

            if !out.isEmpty { return out }
            // otherwise, fall through to heuristics
        }

        // 2) Fallback heuristics (title + overview keywords).
        let t = movie.title.lowercased()
        let o = (movie.overview ?? "").lowercased()
        let text = t + " " + o
        var g: Set<MovieGenre> = []

        if text.containsAny(of: ["space","alien","future","robot","cyber","sci-fi","sci fi"]) { g.insert(.scienceFiction) }
        if text.containsAny(of: ["murder","chase","detective","suspense","conspiracy","crime","heist"]) { g.insert(.thriller) }
        if text.containsAny(of: ["ghost","haunted","demon","slash","zombie","possession","exorcism"]) { g.insert(.horror) }
        if text.containsAny(of: ["love","family","heart","relationship","life","tragedy"]) { g.insert(.drama) }
        if text.containsAny(of: ["laugh","funny","hilarious","comedy","joke","satire"]) { g.insert(.comedy) }
        if text.containsAny(of: ["battle","war","hero","spy","adventure","quest","action"]) { g.insert(.actionAdventure) }

        return g
    }

    // MARK: - Helpers

    private func rotate<T>(_ a: [T], by offset: Int) -> [T] {
        guard !a.isEmpty else { return a }
        let o = ((offset % a.count) + a.count) % a.count
        if o == 0 { return a }
        return Array(a[o...] + a[..<o])
    }

    private func median(_ arr: [Int]) -> Int? {
        guard !arr.isEmpty else { return nil }
        let s = arr.sorted()
        let mid = s.count / 2
        if s.count % 2 == 0 { return (s[mid-1] + s[mid]) / 2 }
        return s[mid]
    }
}

private extension String {
    func containsAny(of needles: [String]) -> Bool {
        for n in needles where self.contains(n) { return true }
        return false
    }
}
