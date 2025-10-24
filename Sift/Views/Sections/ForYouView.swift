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
                            .environmentObject(library)
                    }

                    ForEach(vm.rails, id: \.genre) { genre, movies in
                        SectionHeader(genre.rawValue)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(tenMovies(for: genre, current: movies)) { m in
                                    MoviePosterCard(movie: m) { vm.markWatched(m) }
                                        .environmentObject(library)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .refreshable {
            vm.refresh()
            preheatForYouPosters() // warm posters after refresh
        }
        .onAppear {
            vm.refresh()
            preheatForYouPosters()
        }
        .onChange(of: library.movies) { _, _ in
            vm.refresh()
            preheatForYouPosters()
        }
    }
    // Build exactly 10 real movies for a rail by backfilling from the library,
    // avoiding duplicates across rails and excluding the hero pick.
    private func tenMovies(for genre: MovieGenre, current: [Movie]) -> [Movie] {
        var result = current
        if result.count >= 10 { return Array(result.prefix(10)) }

        // Track used IDs to avoid duplicates across rows and the hero.
        var used = Set<Movie.ID>()
        if let hero = vm.mainPick { used.insert(hero.id) }
        for (_, ms) in vm.rails {
            for m in ms { used.insert(m.id) }
        }
        for m in result { used.insert(m.id) }

        // Backfill from the entire library (simple priority: library order).
        // If you want genre-strict backfill, we can refine here to filter by genre classification.
        for m in library.movies where !used.contains(m.id) {
            result.append(m)
            used.insert(m.id)
            if result.count == 10 { break }
        }
        return result
    }

    // Preheat poster images for main pick + rails (uses DiskImageCache)
    private func preheatForYouPosters() {
        var urls: [URL] = []
        if let m = vm.mainPick, let u = library.posterURL(for: m.posterPath) {
            urls.append(u)
        }
        for (_, movies) in vm.rails {
            for m in movies {
                if let u = library.posterURL(for: m.posterPath) {
                    urls.append(u)
                }
            }
        }
        guard !urls.isEmpty else { return }
        Task { await DiskImageCache.shared.preheat(urls) }
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

    @EnvironmentObject private var library: LibraryStore
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

    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: movie.posterPath)
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contextMenu {
                    Button {
                        onWatched()
                    } label: {
                        Label("Mark Watched", systemImage: "checkmark.circle.fill")
                    }
                    Button {
                        UIPasteboard.general.string = movie.title
                    } label: {
                        Label("Copy Title", systemImage: "doc.on.doc")
                    }
                }

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
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        if let url = library.posterURL(for: path) {
            // Uses your CachedAsyncImage with a simple placeholder
            CachedAsyncImage(url: url, contentMode: .fill) {
                ZStack {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                    Image(systemName: "film").imageScale(.large).opacity(0.5)
                }
            }
        } else {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.15))
                Image(systemName: "film").imageScale(.large).opacity(0.5)
            }
        }
    }
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
