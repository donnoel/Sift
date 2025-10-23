# Sift – Unit Test Coverage Plan

## Project Summary

- Swift files: 29
- Total lines of Swift: 2896
- Functions detected: 91
- TODO/FIXME markers: 0
- Xcode project present: True (Sift.xcodeproj)
- Swift Package Manager: False (—)


## High-Priority Files (by size/complexity/todos)

| path                                      |   loc |   func_count |   todo_count |   priority_weight |
|:------------------------------------------|------:|-------------:|-------------:|------------------:|
| Sift/Views/Sections/SettingsView.swift    |   633 |            4 |            0 |               641 |
| Sift/Views/Sections/LibraryView.swift     |   282 |            1 |            0 |               284 |
| Sift/Services/TMDBClient.swift            |   242 |           11 |            0 |               264 |
| Sift/Components/CachedAsyncImage.swift    |   206 |           15 |            0 |               236 |
| Sift/Services/WatchHistoryStore.swift     |   201 |           10 |            0 |               221 |
| Sift/Services/DiskImageCache.swift        |   164 |            8 |            0 |               180 |
| Sift/Views/Sections/ForYouView.swift      |   168 |            1 |            0 |               170 |
| Sift/Services/RecommendationEngine.swift  |   156 |            4 |            0 |               164 |
| Sift/Components/GlassTabBar.swift         |   138 |            2 |            0 |               142 |
| Sift/Stores/LibraryStore.swift            |   116 |            7 |            0 |               130 |
| SiftTests/LibraryStoreTests.swift         |    89 |            9 |            0 |               107 |
| Sift/Views/Details/MovieDetailView.swift  |    89 |            0 |            0 |                89 |
| Sift/Views/RootView.swift                 |    52 |            0 |            0 |                52 |
| SiftTests/TMDBClientTests.swift           |    39 |            5 |            0 |                49 |
| Sift/Model/Section.swift                  |    43 |            0 |            0 |                43 |
| Sift/ViewModels/ForYouViewModel.swift     |    33 |            2 |            0 |                37 |
| Sift/Services/TMDBSchemas.swift           |    33 |            0 |            0 |                33 |
| SiftTests/AppSettingsTests.swift          |    23 |            3 |            0 |                29 |
| SiftTests/LibraryPersistenceTests.swift   |    21 |            2 |            0 |                25 |
| Sift/Persistence/LibraryPersistence.swift |    20 |            2 |            0 |                24 |
| Sift/SiftApp.swift                        |    23 |            0 |            0 |                23 |
| Sift/App/TopSheetsApp.swift               |    22 |            0 |            0 |                22 |
| Sift/Services/AppSettings.swift           |    19 |            0 |            0 |                19 |
| SiftTests/MovieTests.swift                |    14 |            2 |            0 |                18 |
| Sift/Item.swift                           |    18 |            0 |            0 |                18 |
| Sift/Views/Sections/DiscoverView.swift    |    17 |            0 |            0 |                17 |
| Sift/Support/Pasteboard.swift             |    11 |            2 |            0 |                15 |
| Sift/Model/Movie.swift                    |    15 |            0 |            0 |                15 |
| SiftUITests/SiftUISmokeTests.swift        |     9 |            1 |            0 |                11 |

## Coverage Matrix (excerpt)

| source_path                               | area        | types_found                                                                                                  |   functions |   todos | suggested_tests                                                                                                                       |
|:------------------------------------------|:------------|:-------------------------------------------------------------------------------------------------------------|------------:|--------:|:--------------------------------------------------------------------------------------------------------------------------------------|
| Sift/App/TopSheetsApp.swift               | Sift        | AppContainer, TopSheetsRoot                                                                                  |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Components/CachedAsyncImage.swift    | Sift        | _ImageDecodeCache, CachedAsyncImage                                                                          |          15 |       0 | Cache eviction & TTL tests • Thread-safety tests                                                                                      |
| Sift/Components/GlassTabBar.swift         | Sift        | TabItemBoundsKey, GlassTabBar                                                                                |           2 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Item.swift                           | Sift        | Item                                                                                                         |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Model/Movie.swift                    | Sift        | Movie                                                                                                        |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Model/Section.swift                  | Sift        | Section                                                                                                      |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Persistence/LibraryPersistence.swift | Sift        | LibraryPersistence                                                                                           |           2 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Services/AppSettings.swift           | Sift        | and, AppSettings                                                                                             |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Services/DiskImageCache.swift        | Sift        | DiskImageCache                                                                                               |           8 |       0 | Cache eviction & TTL tests • Thread-safety tests                                                                                      |
| Sift/Services/RecommendationEngine.swift  | Sift        | used, MovieGenre, RecommendationResult, RecommendationEngine                                                 |           4 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Services/TMDBClient.swift            | Sift        | TMDBClient, Scored, PosterSize                                                                               |          11 |       0 | HTTP stubbing tests (happy/sad paths) • Decoding/encoding fixtures tests                                                              |
| Sift/Services/TMDBSchemas.swift           | Sift        | TMDBSearchResponse, TMDBSearchMovie, TMDBMovieDetails, TMDBGenre, TMDBImagesConfigResponse, TMDBImagesConfig |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Services/WatchHistoryStore.swift     | Sift        | WatchHistoryStore                                                                                            |          10 |       0 | Reducer/state mutation tests • Import/de-duplication tests • Progress reporting & cancellation tests                                  |
| Sift/SiftApp.swift                        | Sift        | SiftApp                                                                                                      |           0 |       0 | Core logic unit tests                                                                                                                 |
| Sift/Stores/LibraryStore.swift            | Sift        | LibraryStore                                                                                                 |           7 |       0 | Reducer/state mutation tests • Import/de-duplication tests • Progress reporting & cancellation tests                                  |
| Sift/Support/Pasteboard.swift             | Sift        | Pasteboard                                                                                                   |           2 |       0 | Core logic unit tests                                                                                                                 |
| Sift/ViewModels/ForYouViewModel.swift     | Sift        | ForYouViewModel                                                                                              |           2 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| Sift/Views/Details/MovieDetailView.swift  | Sift        | MovieDetailView                                                                                              |           0 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| Sift/Views/RootView.swift                 | Sift        | RootView, PremiumBackground                                                                                  |           0 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| Sift/Views/Sections/DiscoverView.swift    | Sift        | DiscoverView                                                                                                 |           0 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| Sift/Views/Sections/ForYouView.swift      | Sift        | ForYouView, SectionHeader, MovieHeroCard, MoviePosterCard, PosterImage, EmptyForYouState                     |           1 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| Sift/Views/Sections/LibraryView.swift     | Sift        | LibraryView, Sort, MovieCard, PosterView, SearchBar                                                          |           1 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| Sift/Views/Sections/SettingsView.swift    | Sift        | SettingsView, awareness, WatchedHistoryView, ImportPasteSheet                                                |           4 |       0 | Snapshot tests for layout states • ViewModel-driven state rendering tests (inject fakes) • Accessibility labels & dynamic type checks |
| SiftTests/AppSettingsTests.swift          | SiftTests   | AppSettingsTests                                                                                             |           3 |       0 | Core logic unit tests                                                                                                                 |
| SiftTests/LibraryPersistenceTests.swift   | SiftTests   | LibraryPersistenceTests                                                                                      |           2 |       0 | Core logic unit tests                                                                                                                 |
| SiftTests/LibraryStoreTests.swift         | SiftTests   | LibraryStoreTests, InMemoryPersistence, StubURLProtocol, func, func                                          |           9 |       0 | Reducer/state mutation tests • Import/de-duplication tests • Progress reporting & cancellation tests                                  |
| SiftTests/MovieTests.swift                | SiftTests   | MovieTests                                                                                                   |           2 |       0 | Core logic unit tests                                                                                                                 |
| SiftTests/TMDBClientTests.swift           | SiftTests   | TMDBClientTests, StubURLProtocol, func, func, runs                                                           |           5 |       0 | HTTP stubbing tests (happy/sad paths) • Decoding/encoding fixtures tests                                                              |
| SiftUITests/SiftUISmokeTests.swift        | SiftUITests | SiftUISmokeTests                                                                                             |           1 |       0 | Core logic unit tests                                                                                                                 |

## Next Steps


1. Create an XCTest target (SiftTests) if missing.
2. Add test support utilities: FakeTMDBClient, InMemoryPersistence, TemporaryDirectory helper.
3. For Services/Stores: write deterministic unit tests around inputs/outputs; avoid async flakiness with expectations.
4. For Views: adopt snapshot tests (point-in-time) and verify accessibility labels; gate animations with `XCTSkipIf(ProcessInfo.processInfo.isiOSAppOnMac)` as needed.
5. Add a CI workflow to run `xcodebuild test` on macOS-15, and capture derived data + code coverage.
6. Track coverage deltas per PR; enforce a minimum threshold (e.g., 70%) with gradual ratchet.
