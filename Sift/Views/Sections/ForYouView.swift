// PATH: Sift/Views/Sections/ForYouView.swift
import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var vm: ForYouViewModel

    // Call site should pass: ForYouView(libraryProvider: { library.movies })
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
                        MovieHeroCard(movie: m) { vm.markWatched(m) }
                            .environmentObject(library)
                    }
                    // Key rails by genre to ensure identity is stable across refreshes.
                    ForEach(vm.rails, id: \.genre) { rail in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(rail.genre.rawValue)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    // Key each poster by movie.id so refresh replaces cells correctly.
                                    ForEach(rail.movies, id: \.id) { m in
                                        MoviePosterCard(movie: m) { vm.markWatched(m) }
                                            .environmentObject(library)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .refreshable {
            // Rotate results and recompute on pull.
            await MainActor.run { vm.refresh(shuffle: true) }
            preheatVisiblePosters()
        }
        .task {
            // Initial compute on first appearance.
            if vm.mainPick == nil && vm.rails.isEmpty {
                vm.refresh()
                preheatVisiblePosters()
            }
        }
        .onAppear {
            preheatVisiblePosters()
        }
    }

    // MARK: - Preheating

    private func preheatVisiblePosters() {
        var urls: [URL] = []
        if let h = vm.mainPick, let u = library.posterURL(for: h.posterPath) {
            urls.append(u)
        }
        for (_, movies) in vm.rails.prefix(3) { // only preheat first few rails
            for m in movies.prefix(10) {
                if let u = library.posterURL(for: m.posterPath) {
                    urls.append(u)
                }
            }
        }
        // Let URLCache warm up naturally via AsyncImage fetches.
        // If you have a custom cache, hook it here.
        _ = urls
    }
}

// MARK: - Components

private struct SectionHeader: View {
    var title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct MovieHeroCard: View {
    @EnvironmentObject private var library: LibraryStore
    let movie: Movie
    var onWatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Poster(url: library.posterURL(for: movie.posterPath))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(movie.title)
                .font(.title.bold())
                .lineLimit(2)
            if let o = movie.overview, !o.isEmpty {
                Text(o)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            HStack(spacing: 12) {
                if let y = movie.year {
                    Label("\(y)", systemImage: "calendar")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let r = movie.rating {
                    Label(String(format: "%.1f", r), systemImage: "star.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onWatched()
                } label: {
                    Label("Watched", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MoviePosterCard: View {
    @EnvironmentObject private var library: LibraryStore
    let movie: Movie
    var onWatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Poster(url: library.posterURL(for: movie.posterPath))
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(movie.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
            Button {
                onWatched()
            } label: {
                Label("Watched", systemImage: "checkmark.circle")
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered)
        }
        .frame(width: 140, alignment: .leading)
    }
}

private struct Poster: View {
    let url: URL?
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.secondary.opacity(0.15)).overlay {
                        Image(systemName: "photo")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Rectangle().fill(.secondary.opacity(0.15)).overlay {
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .clipped()
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
