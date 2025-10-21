import SwiftUI

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore

    @State private var workingKey: String = ""
    @State private var importPreviewCount: Int = 0
    @State private var importSheetPresented: Bool = false
    @State private var pasteError: String?

    var body: some View {
        NavigationStack {
            Form(content: {
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

                if !library.lastErrors.isEmpty {
                    SwiftUI.Section {
                        ForEach(library.lastErrors, id: \.self) { msg in
                            Text(msg).font(.footnote)
                        }
                    } header: {
                        Text("Recent Import Errors")
                    }
                }

                if library.isImporting {
                    SwiftUI.Section {
                        ProgressView(value: library.progress)
                            .accessibilityLabel("Import progress")
                        Text("\(Int((library.progress * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Import Progress")
                    }
                }
            })
            .navigationTitle("Settings")
            .onAppear {
                workingKey = settings.tmdbAPIKey
            }
            .sheet(isPresented: $importSheetPresented) {
                ImportPreviewSheet(
                    count: importPreviewCount,
                    confirm: { performPasteImport() }
                )
            }
            .alert("Paste Failed", isPresented: .constant(pasteError != nil), actions: {
                Button("OK") { pasteError = nil }
            }, message: {
                Text(pasteError ?? "")
            })
        }
    }

    private func handlePasteAndPreview() {
        guard let raw = Pasteboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            pasteError = "Clipboard is empty or not text."
            return
        }

        // Count non-empty lines – what we’ll attempt to import.
        let titles = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !titles.isEmpty else {
            pasteError = "No titles found in clipboard text."
            return
        }

        importPreviewCount = titles.count
        importSheetPresented = true
    }

    private func performPasteImport() {
        // TODO: Wire this to the actual LibraryStore import method when available.
        // Temporarily dismiss the sheet so the app compiles and runs without errors.
        importSheetPresented = false
        pasteError = nil
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
