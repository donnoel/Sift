// PATH: Sift/Views/Sections/ForYouView.swift
import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var vm: ForYouViewModel

    // Call site should pass: ForYouView(libraryProvider: { library.allMovies() })
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
                        // Force a full re-render whenever the hero movie changes.
                        MovieHeroCard(movie: m, onWatched: { vm.markWatched(m) })
                            .id(m.id)
                            .environmentObject(library)
                    }

                    ForEach(vm.rails, id: \.genre) { genre, movies in
                        SectionHeader(genre.rawValue)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Engine already delivers up to 10; clamp just in case.
                                ForEach(Array(movies.prefix(10))) { m in
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
            // Pull-to-refresh triggers a reseed (rotate results) and recompute.
            await MainActor.run { vm.refresh(shuffle: true) }
        }
        .task {
            // Initial compute on first appearance.
            if vm.mainPick == nil && vm.rails.isEmpty {
                vm.refresh()
            }
        }
        .onAppear {
            // Preheat posters for snappier scroll.
            preheatVisiblePosters()
        }
    }

    private func preheatVisiblePosters() {
        var urls: [URL] = []
        if let h = vm.mainPick, let u = library.posterURL(for: h.posterPath) {
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

            Text(movie.title)
                .font(.title.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let o = movie.overview, !o.isEmpty {
                Text(o)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(isCompactPhone ? 4 : 6)
            }

            HStack(spacing: 12) {
                if let y = movie.year {
                    Label("\(y)", systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let r = movie.rating {
                    Label(String(format: "%.1f", r), systemImage: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onWatched()
                } label: {
                    Label("Watched", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(movie.title)")
    }
}

private struct MoviePosterCard: View {
    let movie: Movie
    var onWatched: () -> Void

    @EnvironmentObject private var library: LibraryStore
    @Environment(\.horizontalSizeClass) private var hSize
    private var isCompactPhone: Bool { hSize == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: movie.posterPath)
                .frame(width: isCompactPhone ? 110 : 140, height: isCompactPhone ? 165 : 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            Button {
                onWatched()
            } label: {
                Image(systemName: "checkmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(width: isCompactPhone ? 120 : 150, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(movie.title)")
    }
}

private struct PosterImage: View {
    let path: String?
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        if let url = library.posterURL(for: path) {
            // KEY FIX: attach identity to the actual URL so SwiftUI can’t reuse a stale image view.
            CachedAsyncImage(url: url, contentMode: .fill) {
                AnyView(
                    ZStack {
                        Rectangle().fill(Color.secondary.opacity(0.15))
                        Image(systemName: "film").imageScale(.large).opacity(0.5)
                    }
                )
            }
            .id(url.absoluteString)
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
        VStack(spacing: 16) {
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
