import SwiftUI

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @ObservedObject private var history = WatchHistoryStore.shared

    @State private var workingKey: String = ""
    @State private var importPreviewCount: Int = 0
    @State private var importSheetPresented: Bool = false
    @State private var pasteError: String?
    @State private var isPasteErrorPresented: Bool = false

    // App metadata
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
                .onAppear { workingKey = settings.tmdbAPIKey }
        }
        .sheet(isPresented: $importSheetPresented) {
            ImportPreviewSheet(
                count: importPreviewCount,
                confirm: { performPasteImport() }
            )
        }
        .alert("Paste Failed", isPresented: $isPasteErrorPresented) {
            Button("OK") { pasteError = nil }
        } message: {
            Text(pasteError ?? "")
        }
    }

    // Split out to keep the type-checker happy
    @ViewBuilder
    private var settingsForm: some View {
        Form {
            tmdbSection
            libraryToolsSection

            if !library.lastErrors.isEmpty {
                recentImportErrorsSection
            }

            if library.isImporting {
                importProgressSection
            }

            watchHistorySection
            aboutSection
        }
    }

    private var tmdbSection: some View {
        SwiftUI.Section {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.secondary)

                SecureField("TMDB API Key", text: $workingKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .accessibilityLabel("TMDB API Key")
            }

            HStack(spacing: 12) {
                Button {
                    settings.tmdbAPIKey = workingKey.trimmingCharacters(in: .whitespacesAndNewlines)
                } label: {
                    Label("Save Key", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(workingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    workingKey = settings.tmdbAPIKey
                } label: {
                    Label("Revert", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(workingKey == settings.tmdbAPIKey)
            }

            if settings.tmdbAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Add your TMDB API key to enable search and importing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .accessibilityLabel("TMDB key is missing")
            }
        } header: {
            Text("TMDB")
        }
    }

    private var libraryToolsSection: some View {
        SwiftUI.Section {
            Button {
                handlePasteAndPreview()
            } label: {
                Label("Paste & Preview Import", systemImage: "doc.on.clipboard.fill")
            }
            .buttonStyle(.bordered)
            .disabled(settings.tmdbAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(role: .destructive) {
                Task { @MainActor in
                    await library.clearAll()
                }
            } label: {
                Label("Clear Library", systemImage: "trash.fill")
            }
            .disabled(library.movies.isEmpty)
            .accessibilityLabel("Clear library")
            .accessibilityHint("Deletes all saved movies")
        } header: {
            Text("Library Tools")
        }
    }

    private var recentImportErrorsSection: some View {
        SwiftUI.Section {
            ForEach(library.lastErrors, id: \.self) { msg in
                Text(msg).font(.footnote)
            }
        } header: {
            Text("Recent Import Errors")
        }
    }

    private var importProgressSection: some View {
        SwiftUI.Section {
            ProgressView(value: library.progress)
                .accessibilityLabel("Import progress")
            Text("\(Int((library.progress * 100).rounded()))%")
                .foregroundStyle(.secondary)
        } header: {
            Text("Import Progress")
        }
    }

    private var watchHistorySection: some View {
        SwiftUI.Section {
            if history.watched.isEmpty {
                Text("No watched movies yet.")
                    .foregroundStyle(.secondary)
            } else {
                let entries = history.watched.sorted { lhs, rhs in lhs.value > rhs.value }
                ForEach(entries, id: \.key) { (id, date) in
                    HStack(alignment: .top, spacing: 12) {
                        // Poster
                        if let movie = library.movies.first(where: { $0.id == id }) {
                            CachedAsyncImage(url: movie.posterURL, contentMode: .fill) {
                                ZStack {
                                    Rectangle().fill(Color(.tertiarySystemFill))
                                    Image(systemName: "film").foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 44, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            ZStack {
                                Rectangle().fill(Color(.tertiarySystemFill))
                                Image(systemName: "film").foregroundStyle(.secondary)
                            }
                            .frame(width: 44, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Texts
                        VStack(alignment: .leading, spacing: 4) {
                            let title = library.movies.first(where: { $0.id == id })?.title ?? "Movie #\(id)"
                            Text(title)
                                .font(.headline)
                                .lineLimit(2)
                            Text(date, style: .date)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        // Unwatch
                        Button {
                            unwatch(id)
                        } label: {
                            Label("Put Back", systemImage: "arrow.uturn.left.circle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Put \(library.movies.first(where: { $0.id == id })?.title ?? "movie") back in rotation")
                    }
                    .padding(.vertical, 4)
                }

                // Optional: Clear all history
                Button(role: .destructive) {
                    let ids = Array(history.watched.keys)
                    ids.forEach { unwatch($0) }
                } label: {
                    Label("Clear Watch History", systemImage: "trash")
                }
                .padding(.top, 4)
            }
        } header: {
            Text("Watch History")
        }
    }

    private var aboutSection: some View {
        SwiftUI.Section {
            HStack {
                Text("Version")
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundStyle(.secondary)
                    .font(.body.monospaced())
                    .accessibilityLabel("App version \(appVersion) build \(buildNumber)")
            }
        } header: {
            Text("About")
        }
    }

    // Avoid property-wrapper/dynamicMember inference by capturing a strong reference first.
    @MainActor
    private func unwatch(_ id: Int) {
        let store = history
        store.markUnwatched(id)
    }

    private func handlePasteAndPreview() {
        guard let raw = Pasteboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            pasteError = "Clipboard is empty or not text."
            isPasteErrorPresented = true
            return
        }

        let titles = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !titles.isEmpty else {
            pasteError = "No titles found in clipboard text."
            isPasteErrorPresented = true
            return
        }

        importPreviewCount = titles.count
        importSheetPresented = true
    }

    private func performPasteImport() {
        // TODO: Wire this to the actual LibraryStore import method when available.
        importSheetPresented = false
        pasteError = nil
        isPasteErrorPresented = false
    }
}

// MARK: - Small helper sheet
private struct ImportPreviewSheet: View {
    let count: Int
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.largeTitle)
                .padding(.top, 12)

            Text("Import \(count) title\(count == 1 ? "" : "s") from Clipboard?")
                .font(.headline)

            Text("We’ll look them up on TMDB and add matches to your Library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Import") {
                    dismiss()
                    confirm()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 12)
        }
        .padding()
        .presentationDetents([.height(260)])
    }
}
