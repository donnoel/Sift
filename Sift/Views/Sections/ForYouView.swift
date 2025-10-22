import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var vm: ForYouViewModel

    // Call site will pass: ForYouView(libraryProvider: { library.allMovies() })
    init(libraryProvider: @escaping () -> [Movie]) {
        _vm = StateObject(wrappedValue: ForYouViewModel(libraryProvider: libraryProvider))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if vm.mainPick == nil && vm.rails.isEmpty {
                    EmptyForYouState()
                } else {
                    if let m = vm.mainPick {
                        SectionHeader("Tonight’s Pick")
                        MovieHeroCard(movie: m, onWatched: { vm.markWatched(m) })
                    }

                    ForEach(vm.rails, id: \.genre) { genre, movies in
                        SectionHeader(genre.rawValue)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(movies) { m in
                                    MoviePosterCard(movie: m) { vm.markWatched(m) }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .refreshable { vm.refresh() }
        .onAppear { vm.refresh() }
        .onChange(of: library.movies) { _, _ in vm.refresh() }
    }
}

// MARK: - UI bits

private struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct MovieHeroCard: View {
    let movie: Movie
    var onWatched: () -> Void

    @Environment(\.horizontalSizeClass) private var hSize
    private var isCompactPhone: Bool { hSize == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PosterImage(path: movie.posterPath)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(movie.title).font(.title.bold())
            if let o = movie.overview, !o.isEmpty {
                Text(o).font(.callout).lineLimit(4)
            }
            HStack {
                if isCompactPhone {
                    Button {
                        onWatched()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .accessibilityLabel("Mark \(movie.title) watched")
                } else {
                    Button {
                        onWatched()
                    } label: {
                        Label("Watched", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Spacer()
            }
        }
    }
}

private struct MoviePosterCard: View {
    let movie: Movie
    var onWatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: movie.posterPath)
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(movie.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                onWatched()
            } label: {
                Image(systemName: "checkmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .font(.caption)
            .accessibilityLabel("Mark \(movie.title) watched")
        }
        .frame(width: 140)
    }
}

private struct PosterImage: View {
    let path: String?
    var body: some View {
        if let url = posterURL(from: path) {
            // Uses your CachedAsyncImage; it shows a placeholder internally.
            CachedAsyncImage(url: url, contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.15))
                Image(systemName: "film").imageScale(.large).opacity(0.5)
            }
        }
    }
}

// Absolute URLs only; if you store TMDB relative paths, we’ll wire the base later.
fileprivate func posterURL(from path: String?) -> URL? {
    guard let p = path, !p.isEmpty else { return nil }
    if p.hasPrefix("http://") || p.hasPrefix("https://") {
        return URL(string: p)
    }
    // Compose a TMDB image URL when given a relative path like "/abc.jpg"
    let base = "https://image.tmdb.org/t/p/w500"
    let full = p.hasPrefix("/") ? base + p : base + "/" + p
    return URL(string: full)
}

private struct EmptyForYouState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .imageScale(.large)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("For You is empty")
                .font(.title3.weight(.semibold))
            Text("Import some movies to see recommendations here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
