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

    // MARK: - Public

    /// Stable recommendations with deterministic rotation.
    /// - Parameters:
    ///   - library: Pool of candidates (already filtered for cooldowns by caller).
    ///   - wantedRails: Order determines rail order in the result.
    ///   - picksPerRail: Target per row (default 10).
    ///   - seed: Rotation seed; changing it rotates hero and rails predictably.
    func compute(
        library: [Movie],
        rails wantedRails: [MovieGenre] = [.actionAdventure, .comedy, .drama, .horror, .thriller, .scienceFiction],
        picksPerRail: Int = 10,
        seed: UInt64 = 0
    ) -> RecommendationResult {
        guard !library.isEmpty else { return .init(mainPick: nil, rails: [:]) }

        // Base sort for quality: rating desc → year desc → title asc
        let base = library.sorted {
            let l = ($0.rating ?? 0, $0.year ?? 0, $0.title)
            let r = ($1.rating ?? 0, $1.year ?? 0, $1.title)
            return l > r
        }

        // Rotate the whole list so hero changes with seed.
        let rotated = rotate(base, by: Int(seed % UInt64(max(1, min(base.count, 512)))))

        // Hero = top of rotated list
        let main = rotated.first

        // Bucket by genre in rotated order so seed affects rails too.
        var buckets: [MovieGenre: [Movie]] = [:]
        var unclassified: [Movie] = []
        for m in rotated {
            let gs = classify(m)
            if gs.isEmpty {
                unclassified.append(m)
            } else {
                for g in gs { buckets[g, default: []].append(m) }
            }
        }

        // Dedup across hero + all rails using model ID type
        var used = Set<Movie.ID>()
        if let main { used.insert(main.id) }

        // Per-genre deterministic shuffle (seed mixed with the genre label)
        func shuffled(_ movies: [Movie], for genre: MovieGenre) -> [Movie] {
            let genreSeed = seed &+ hash64(genre.rawValue) &+ 0x9E3779B97F4A7C15
            return fisherYates(movies, seed: genreSeed)
        }

        // First pass: pick from each genre's own (shuffled) bucket
        var railMap: [MovieGenre: [Movie]] = [:]
        for g in wantedRails {
            let own = buckets[g, default: []].filter { !used.contains($0.id) }
            let shuffledOwn = shuffled(own, for: g)
            let picked = take(shuffledOwn, upTo: picksPerRail, used: &used)
            railMap[g] = picked
        }

        // Second pass: backfill short rails from global leftovers (shuffled)
        var leftovers: [Movie] = []
        for g in wantedRails {
            leftovers += buckets[g, default: []]
        }
        leftovers += unclassified
        leftovers.removeAll { used.contains($0.id) }
        leftovers = fisherYates(leftovers, seed: seed &+ 0xD00DF00DCAFEBABE)

        var li = 0
        for g in wantedRails {
            var current = railMap[g] ?? []
            while current.count < picksPerRail, li < leftovers.count {
                let m = leftovers[li]; li += 1
                if used.insert(m.id).inserted { current.append(m) }
            }
            railMap[g] = current
        }

        return .init(mainPick: main, rails: railMap)
    }

    // MARK: - Genre classification (simple heuristic)

    private func classify(_ movie: Movie) -> Set<MovieGenre> {
        let t = movie.title.lowercased()
        let o = (movie.overview ?? "").lowercased()
        let text = t + " " + o
        var g: Set<MovieGenre> = []

        if text.containsAny(of: ["space","alien","future","robot","cyber","sci-fi","sci fi"]) { g.insert(.scienceFiction) }
        if text.containsAny(of: ["murder","chase","detective","suspense","conspiracy","crime","heist"]) { g.insert(.thriller) }
        if text.containsAny(of: ["ghost","haunted","demon","slash","zombie","possession","creature","horror"]) { g.insert(.horror) }
        if text.containsAny(of: ["war","battle","spy","mission","explosion","car chase","ninja","sword","fight","adventure","action"]) { g.insert(.actionAdventure) }
        if text.containsAny(of: ["love","family","life","tragedy","biopic","drama","relationship"]) { g.insert(.drama) }
        if text.containsAny(of: ["funny","hilarious","comedy","sitcom","joke","laugh"]) { g.insert(.comedy) }

        return g
    }

    // MARK: - Helpers

    private func take(_ src: [Movie], upTo k: Int, used: inout Set<Movie.ID>) -> [Movie] {
        var out: [Movie] = []
        out.reserveCapacity(min(k, src.count))
        for m in src where out.count < k {
            if used.insert(m.id).inserted { out.append(m) }
        }
        return out
    }

    private func rotate<T>(_ a: [T], by offset: Int) -> [T] {
        guard !a.isEmpty else { return a }
        let o = ((offset % a.count) + a.count) % a.count
        if o == 0 { return a }
        return Array(a[o...] + a[..<o])
    }

    private func hash64(_ s: String) -> UInt64 {
        // FNV-1a 64-bit
        var h: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for b in s.utf8 {
            h ^= UInt64(b)
            h &*= prime
        }
        return h
    }

    private func fisherYates<T>(_ array: [T], seed: UInt64) -> [T] {
        var arr = array
        var rng = SplitMix64(state: seed | 1) // avoid zero state
        if arr.count > 1 {
            for i in stride(from: arr.count - 1, through: 1, by: -1) {
                let j = Int(rng.next() % UInt64(i + 1))
                if i != j { arr.swapAt(i, j) }
            }
        }
        return arr
    }
}

// MARK: - SplitMix64 PRNG (deterministic, fast)
private struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private extension String {
    func containsAny(of needles: [String]) -> Bool {
        for n in needles where self.contains(n) { return true }
        return false
    }
}
