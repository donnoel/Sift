// PATH: Sift/Views/Sections/LibraryView.swift
import SwiftUI
import UIKit

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// Dynamic-Type aware text height calculator so every card reserves identical space.
private struct CardTypography {
    let titleLines: CGFloat = 2
    let overviewLines: CGFloat = 2
    let vSpacingAboveMeta: CGFloat = 8    // spacing between poster and title
    let vSpacingBetweenBlocks: CGFloat = 8

    var titleHeight: CGFloat {
        let base = UIFont.preferredFont(forTextStyle: .headline)
        let scaled = UIFontMetrics(forTextStyle: .headline).scaledFont(for: base)
        return ceil(scaled.lineHeight) * titleLines
    }

    var metaHeight: CGFloat {
        // One caption line (year + rating row)
        let base = UIFont.preferredFont(forTextStyle: .caption1)
        let scaled = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: base)
        return ceil(scaled.lineHeight) * 1
    }

    var overviewHeight: CGFloat {
        let base = UIFont.preferredFont(forTextStyle: .footnote)
        let scaled = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: base)
        return ceil(scaled.lineHeight) * overviewLines
    }

    /// Total reserved text block height (title + spacing + meta + spacing + overview)
    var totalTextBlockHeight: CGFloat {
        vSpacingAboveMeta + titleHeight + vSpacingBetweenBlocks + metaHeight + vSpacingBetweenBlocks + overviewHeight
    }
}

// MARK: - Detail Sheet
private struct LibraryMovieDetailView: View {
    let movie: Movie
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Poster
                    CachedAsyncImage(url: movie.posterURL, contentMode: .fill) {
                        ZStack {
                            Rectangle().fill(Color(.tertiarySystemFill))
                            Image(systemName: "photo")
                                .imageScale(.large)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    // Title + Meta
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.title)
                            .font(.largeTitle.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)

                        HStack(spacing: 12) {
                            if let year = movie.year {
                                HStack(spacing: 6) {
    Image(systemName: "calendar")
    Text(verbatim: String(year))
}
                            }
                            if let rating = movie.rating {
                                Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    // External link + identifiers
                    VStack(alignment: .leading, spacing: 6) {
                        if let url = URL(string: "https://www.themoviedb.org/movie/\(movie.id)") {
                            Link("View on TMDB", destination: url)
                                .font(.callout.weight(.semibold))
                        }
                        HStack(spacing: 12) {
                            Text("TMDB ID: \(movie.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let path = movie.posterPath, !path.isEmpty {
                                Text("Poster: \(path)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

                    // Overview
                    if let overview = movie.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
                .background(
                    Group {
                        if reduceTransparency {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        } else {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private enum SortOption: String, CaseIterable {
    case shuffle, titleAsc, titleDesc

    var label: String {
        switch self {
        case .shuffle:   return "Shuffle"
        case .titleAsc:  return "Title A → Z"
        case .titleDesc: return "Title Z → A"
        }
    }

    var systemImage: String {
        switch self {
        case .shuffle:   return "shuffle"
        case .titleAsc:  return "textformat.abc.dottedunderline"
        case .titleDesc: return "textformat.abc"
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let spacing: CGFloat = 16
    private let prefetchWindow: Int = 30
    private let fastThreshold: CGFloat = 1400
    private let slowResetDelay: UInt64 = 220_000_000

    @State private var isFastScrolling = false
    @State private var lastOffset: CGFloat = 0
    @State private var lastTime: TimeInterval = 0
    @State private var scrollEndTask: Task<Void, Never>?

    @State private var sort: SortOption = .titleAsc
    @State private var displayedMovies: [Movie] = []

    // NEW: selection for sheet presentation
    @State private var selectedMovie: Movie?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 200), spacing: spacing)]
    }

    private func applySort() {
        let base = library.movies
        switch sort {
        case .shuffle:
            displayedMovies = base.shuffled()
        case .titleAsc:
            displayedMovies = base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc:
            displayedMovies = base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let offset = -proxy.frame(in: .named("libraryScroll")).minY
                    Color.clear.preference(key: ScrollOffsetKey.self, value: offset)
                }
                .frame(height: 0)

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(displayedMovies.enumerated()), id: \.1.id) { index, movie in
                        // Wrap the card in a plain button; keep full-card hit area
                        Button {
                            selectedMovie = movie
                        } label: {
                            MovieCard(
                                movie: movie,
                                reduceTransparency: reduceTransparency,
                                isFastScrolling: isFastScrolling
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onAppear { preheatAround(index) }
                    }
                }
                .padding(20)
            }
        }
        .coordinateSpace(name: "libraryScroll")
        .transaction { $0.animation = nil }
        .onAppear {
            applySort()
            let urls = displayedMovies.prefix(24).compactMap { $0.posterURL }
            Task { await DiskImageCache.shared.preheat(urls) }
            lastTime = ProcessInfo.processInfo.systemUptime
        }
        .onPreferenceChange(ScrollOffsetKey.self) { newOffset in
            updateScrollVelocity(with: newOffset)
        }
        .onChange(of: sort) { oldValue, newValue in
              applySort()
          }
        .onChange(of: sort) { oldValue, newValue in
              applySort()
          }
        .onDisappear { scrollEndTask?.cancel() }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("Library")
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Menu {
                    Button { sort = .shuffle } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    Button { sort = .titleAsc } label: {
                        Label("Title A → Z", systemImage: "textformat.abc.dottedunderline")
                    }
                    Button { sort = .titleDesc } label: {
                        Label("Title Z → A", systemImage: "textformat.abc")
                    }
                } label: {
                    HStack(spacing: 0) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Filter")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if reduceTransparency {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .compositingGroup()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        // NEW: present detail
        .sheet(item: $selectedMovie) { movie in
            LibraryMovieDetailView(movie: movie)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Fast Scroll Detection
    private func updateScrollVelocity(with newOffset: CGFloat) {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = max(0.016, now - lastTime)
        let velocity = abs((newOffset - lastOffset) / CGFloat(dt))

        if velocity > fastThreshold, !isFastScrolling {
            isFastScrolling = true
        }

        scrollEndTask?.cancel()
        scrollEndTask = Task {
            try? await Task.sleep(nanoseconds: slowResetDelay)
            await MainActor.run { isFastScrolling = false }
        }

        lastOffset = newOffset
        lastTime = now
    }

    // MARK: - Viewport-aware prefetch
    private func preheatAround(_ index: Int) {
        guard !displayedMovies.isEmpty else { return }
        let start = index + 1
        let end = min(displayedMovies.count, start + prefetchWindow)
        guard start < end else { return }
        let urls = displayedMovies[start..<end].compactMap { $0.posterURL }
        Task { await DiskImageCache.shared.preheat(urls) }
    }
}

private struct MovieCard: View {
    let movie: Movie
    let reduceTransparency: Bool
    let isFastScrolling: Bool

    private let metrics = CardTypography()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster — stable 2:3 area (height derived from width)
            CachedAsyncImage(url: movie.posterURL, contentMode: .fill) {
                ZStack {
                    Rectangle().fill(Color(.tertiarySystemFill))
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Spacing between poster and text block
            Color.clear.frame(height: metrics.vSpacingAboveMeta)

            // Fixed-height text block (same height for every card)
            VStack(alignment: .leading, spacing: metrics.vSpacingBetweenBlocks) {
                // Title — reserve exactly 2 lines height
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(height: metrics.titleHeight, alignment: .topLeading)

                // Meta row — always 1 line tall
                HStack(spacing: 8) {
                    if let year = movie.year {
                        Text(verbatim: String(year))
                    }
                    if let rating = movie.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: metrics.metaHeight, alignment: .leading)

                // Overview — reserve exactly 2 lines even if missing
                if let overview = movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(height: metrics.overviewHeight, alignment: .topLeading)
                } else {
                    // Keep heights uniform when no overview is present
                    Color.clear
                        .frame(height: metrics.overviewHeight)
                }
            }
            .frame(height: metrics.titleHeight + metrics.vSpacingBetweenBlocks + metrics.metaHeight + metrics.vSpacingBetweenBlocks + metrics.overviewHeight, alignment: .topLeading)
        }
        .transaction { $0.animation = nil }
        .padding(12)
        .background(
            Group {
                if reduceTransparency || isFastScrolling {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(isFastScrolling ? 0.05 : 0.07),
            radius: isFastScrolling ? 6 : 8,
            x: 0, y: isFastScrolling ? 4 : 5
        )
    }
}
