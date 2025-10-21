import SwiftUI

@MainActor
struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var query: String = ""
    @State private var sort: Sort = .title

    enum Sort: String, CaseIterable, Identifiable {
        case title, year, rating
        var id: String { rawValue }

        var label: String {
            switch self {
            case .title: return "Title A–Z"
            case .year:  return "Year"
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
        let base = library.movies
        let filtered: [Movie]
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = base
        } else {
            let q = query.lowercased()
            filtered = base.filter { m in
                m.title.lowercased().contains(q)
                || (m.year.map { "\($0)" }.map { $0.contains(q) } ?? false)
            }
        }

        switch sort {
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .year:
            return filtered.sorted { ( $0.year ?? 0 ) > ( $1.year ?? 0 ) }
        case .rating:
            return filtered.sorted { ( $0.rating ?? 0 ) > ( $1.rating ?? 0 ) }
        }
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
