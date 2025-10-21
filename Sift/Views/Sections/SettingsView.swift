import SwiftUI
import UIKit

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @ObservedObject private var history = WatchHistoryStore.shared

    // Size-class awareness for adaptive layouts
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    private var isCompactPhone: Bool { hSize == .compact && vSize == .regular }

    @State private var workingKey: String = ""
    @State private var importPreviewCount: Int = 0
    @State private var importSheetPresented: Bool = false
    @State private var pasteError: String?
    @State private var isPasteErrorPresented: Bool = false
    @State private var importText: String = ""

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
                .navigationBarTitleDisplayMode(isCompactPhone ? .inline : .automatic)
                .formStyle(.grouped)
                .onAppear { workingKey = settings.tmdbAPIKey }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if library.isImporting {
                            HStack(spacing: 8) {
                                ProgressView(value: library.progress)
                                    .progressViewStyle(.circular)
                                    .frame(width: 18, height: 18)
                                Text("\(Int((library.progress * 100).rounded()))%")
                                    .font(isCompactPhone ? .caption2 : .footnote)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
        }
        .sheet(isPresented: $importSheetPresented) {
            ImportPasteSheet(
                text: $importText,
                onConfirm: { text in
                    importSheetPresented = false
                    pasteError = nil
                    isPasteErrorPresented = false
                    Task { @MainActor in
                        await library.importFromPaste(text)
                    }
                }
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
            if library.isImporting {
                importStatusTopSection
            }
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

    @ViewBuilder
    private var importStatusTopSection: some View {
        SwiftUI.Section {
            HStack(spacing: 12) {
                ProgressView(value: library.progress)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Importing…")
                        .font(.subheadline).bold()
                    Text("\(Int((library.progress * 100).rounded()))% complete")
                        .font(isCompactPhone ? .caption : .footnote)   // adaptive
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Importing")
            .accessibilityValue("\(Int((library.progress * 100).rounded())) percent")
        } header: {
            Text("Status")
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
                    .font(isCompactPhone ? .callout.monospaced() : .body.monospaced()) // adaptive
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
                // Capture a strong reference to avoid property-wrapper/dynamicMember inference issues.
                let store = history
                Task { @MainActor in
                    await library.clearAll()
                    // Unwatch everything in history (works even without a clearAll() API).
                    let ids = Array(store.watched.keys)
                    ids.forEach { store.unwatch($0) }
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
                // Adaptive metrics for compact phones vs iPad
                let poster = isCompactPhone ? CGSize(width: 32, height: 48) : CGSize(width: 44, height: 66)
                let titleFont: Font = isCompactPhone ? .subheadline.weight(.semibold) : .headline
                let dateFont: Font = isCompactPhone ? .caption : .footnote
                let rowVSpacing: CGFloat = isCompactPhone ? 6 : 8
                let rowHSpacing: CGFloat = isCompactPhone ? 10 : 12

                let entries = history.watched.sorted { lhs, rhs in lhs.value > rhs.value }
                ForEach(entries, id: \.key) { (id, date) in
                    HStack(alignment: .top, spacing: rowHSpacing) {
                        // Poster
                        if let movie = library.movies.first(where: { $0.id == id }) {
                            CachedAsyncImage(url: movie.posterURL, contentMode: .fill) {
                                ZStack {
                                    Rectangle().fill(Color(.tertiarySystemFill))
                                    Image(systemName: "film").foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: poster.width, height: poster.height)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            ZStack {
                                Rectangle().fill(Color(.tertiarySystemFill))
                                Image(systemName: "film").foregroundStyle(.secondary)
                            }
                            .frame(width: poster.width, height: poster.height)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Texts
                        VStack(alignment: .leading, spacing: rowVSpacing) {
                            let title = library.movies.first(where: { $0.id == id })?.title ?? "Movie #\(id)"
                            Text(title)
                                .font(titleFont)
                                .lineLimit(isCompactPhone ? 1 : 2)
                            Text(date, style: .date)
                                .font(dateFont)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        // Unwatch button (compact = icon-only)
                        if isCompactPhone {
                            Button { unwatch(id) } label: {
                                Image(systemName: "arrow.uturn.left.circle.fill")
                            }
                            .buttonStyle(.bordered)
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Put \(library.movies.first(where: { $0.id == id })?.title ?? "movie") back in rotation")
                        } else {
                            Button {
                                unwatch(id)
                            } label: {
                                Label("Put Back", systemImage: "arrow.uturn.left.circle.fill")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, isCompactPhone ? 3 : 4)
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
        store.unwatch(id)
    }

    private func handlePasteAndPreview() {
        // Read plain text from iOS pasteboard (user-initiated via button tap)
        guard let clipboard = UIPasteboard.general.string else {
            pasteError = "Clipboard is empty or not text."
            isPasteErrorPresented = true
            return
        }
        let raw = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            pasteError = "Clipboard is empty or not text."
            isPasteErrorPresented = true
            return
        }

        importText = raw
        importPreviewCount = titlesFromText(importText).count
        importSheetPresented = true
    }

    // Parse non-empty, trimmed lines as titles
    private func titlesFromText(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func performPasteImport() {
        guard let clipboard = UIPasteboard.general.string else {
            pasteError = "Clipboard is empty or not text."
            isPasteErrorPresented = true
            return
        }
        let raw = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            pasteError = "Clipboard is empty or not text."
            isPasteErrorPresented = true
            return
        }

        // Dismiss the preview sheet and kick off the import.
        importSheetPresented = false
        pasteError = nil
        isPasteErrorPresented = false

        Task { @MainActor in
            await library.importFromPaste(raw)
        }
    }
}

// MARK: - Paste + Edit sheet
private struct ImportPasteSheet: View {
    @Binding var text: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var detent: PresentationDetent = .large

    private var isCompactPhone: Bool { hSize == .compact }

    private var titles: [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Live stats
                HStack {
                    Label("\(titles.count) title\(titles.count == 1 ? "" : "s")", systemImage: "list.number")
                        .font(.subheadline.bold())
                    Spacer()
                    if titles.count > 0 {
                        Text("Preview shows first \(min(10, titles.count))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Editable text
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(2)
                    .frame(minHeight: isCompactPhone ? 260 : 200,
                           maxHeight: isCompactPhone ? 300 : 220) // adaptive height
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Preview list
                if !titles.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(titles.prefix(10).enumerated()), id: \.offset) { idx, t in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(idx + 1).")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, alignment: .trailing)
                                Text(t)
                                    .font(.body)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    }
                } else {
                    ContentUnavailableView("Nothing to import", systemImage: "doc.on.clipboard", description: Text("Paste or edit the text above. One title per line."))
                }

                // Actions
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Button {
                        onConfirm(text)
                        dismiss()
                    } label: {
                        Label("Import", systemImage: "arrow.down.doc.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(titles.isEmpty)
                }
                .padding(.top, 4)
            }
            .padding()
            .navigationTitle("Import from Clipboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let s = UIPasteboard.general.string {
                            text = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                }
            }
        }
        .onAppear { detent = .large } // open big by default
        .presentationDetents(isCompactPhone ? [.large] : [.medium, .large], selection: $detent)
        .scrollDismissesKeyboard(.interactively)
    }
}
