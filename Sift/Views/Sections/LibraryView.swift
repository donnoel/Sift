// PATH: Sift/Views/Sections/LibraryView.swift
import SwiftUI

@MainActor
struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var query: String = ""
    @State private var debouncedQuery: String = ""          // <- debounced for smooth filtering
    @State private var sort: Sort = .title
    @State private var debounceTask: Task<Void, Never>? = nil

    private let debounceDelayNS: UInt64 = 250_000_000       // ~250ms

    enum Sort: String, CaseIterable, Identifiable {
        case title, year, rating
        var id: String { rawValue }

        var label: String {
            switch self {
            case .title:  return "Title A–Z"
            case .year:   return "Year"
            case .rating: return "Rating"
            }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(Sort.allCases) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("Sort library")
                    }
                }
        }
        // Debounce changes to the query so the UI doesn't thrash on every keystroke
        .onChange(of: query) { newValue in
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: debounceDelayNS)
                if !Task.isCancelled {
                    debouncedQuery = newValue
                }
            }
        }
        .onAppear { debouncedQuery = query }
        .onDisappear { debounceTask?.cancel() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            SearchBar(text: $query)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120), spacing: 12, alignment: .top)
                ], spacing: 12) {
                    ForEach(filteredAndSortedMovies) { movie in
                        MovieCard(movie: movie)
                    }
                }
                .padding()
            }

            if library.movies.isEmpty {
                ContentUnavailableView(
                    "Your Library is Empty",
                    systemImage: "film.fill",
                    description: Text("Paste titles in Settings to import from TMDB.")
                )
                .padding()
            }
        }
    }

    private var filteredAndSortedMovies: [Movie] {
        // Take a snapshot with original indexes for stable tie-breaking
        let enumerated = Array(library.movies.enumerated())

        // Normalize once
        let q = normalize(debouncedQuery)

        // Filter: diacritic/case-insensitive title contains; allow year text match too
        let filtered = enumerated.filter { (_, m) in
            guard !q.isEmpty else { return true }
            if normalize(m.title).contains(q) { return true }
            if let y = m.year, String(y).contains(q) { return true }
            return false
        }

        let locale = Locale.autoupdatingCurrent

        // Sort with stability guarantees (original index as final tiebreaker)
        let sorted: [(offset: Int, element: Movie)]
        switch sort {
        case .title:
            sorted = filtered.sorted { lhs, rhs in
                let l = lhs.element.title
                let r = rhs.element.title
                let cmp = l.compare(r,
                                    options: [.caseInsensitive, .diacriticInsensitive],
                                    range: nil,
                                    locale: locale)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.offset < rhs.offset
            }

        case .year:
            sorted = filtered.sorted { lhs, rhs in
                let ly = lhs.element.year ?? Int.min
                let ry = rhs.element.year ?? Int.min
                if ly != ry { return ly > ry } // desc, newest first
                let cmp = lhs.element.title.compare(rhs.element.title,
                                                    options: [.caseInsensitive, .diacriticInsensitive],
                                                    range: nil,
                                                    locale: locale)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.offset < rhs.offset
            }

        case .rating:
            sorted = filtered.sorted { lhs, rhs in
                let lr = lhs.element.rating ?? -1.0
                let rr = rhs.element.rating ?? -1.0
                if lr != rr { return lr > rr } // desc, highest first
                let cmp = lhs.element.title.compare(rhs.element.title,
                                                    options: [.caseInsensitive, .diacriticInsensitive],
                                                    range: nil,
                                                    locale: locale)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.offset < rhs.offset
            }
        }

        return sorted.map { $0.element }
    }

    // MARK: - Normalization helper

    /// Lowercased + diacritic-insensitive, collapses whitespace.
    private func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                               locale: .autoupdatingCurrent)
        return folded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Movie Card

private struct MovieCard: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterView(url: movie.posterURL)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }

            Text(movie.title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            HStack(spacing: 8) {
                if let year = movie.year {
                    Label("\(year)", systemImage: "calendar")
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Year \(year)")
                    Text("\(year)")
                        .foregroundStyle(.secondary)
                }

                if let rating = movie.rating {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text(String(format: "%.1f", rating))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Rating \(rating, specifier: "%.1f")")
                }
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Poster (uses your existing cache async image if available)

private struct PosterView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                // If you already have a CachedAsyncImage, swap it here:
                // CachedAsyncImage(url: url) { image in ... }
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .contentShape(Rectangle())
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.secondary.opacity(0.15))
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Simple SearchBar

private struct SearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search library", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quinary, lineWidth: 0.5)
        }
    }
}
