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
    @State private var isSyncingNow: Bool = false

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
            statsTopSection
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

    @ViewBuilder
    private var statsTopSection: some View {
        SwiftUI.Section {
            let libraryCount = library.movies.count
            let libraryIDs = Set(library.movies.map(\.id))
            let watchedTotal = history.watched.count
            let watchedInLibrary = history.watched.keys.filter { libraryIDs.contains($0) }.count
            let unwatched = max(0, libraryCount - watchedInLibrary)

            // Recent window
            let recentDays = 30
            let cutoff = Calendar.current.date(byAdding: .day, value: -recentDays, to: Date()) ?? Date.distantPast
            let recentWatched = history.watched.values.filter { $0 >= cutoff }.count
            let mostRecent = history.watched.values.max()
            let daysSuffix = String(localized: "days", comment: "Suffix describing a day count")

            // Row: Library size
            HStack {
                Label("Library", systemImage: "square.stack.3d.up")
                Spacer()
                Text("\(libraryCount)")
                    .font(isCompactPhone ? .body.weight(.semibold) : .title3.weight(.semibold))
                    .monospacedDigit()
            }

            // Row: Watched
            HStack {
                Label("Watched", systemImage: "eye.fill")
                Spacer()
                Text("\(watchedInLibrary)")
                    .font(isCompactPhone ? .body.weight(.semibold) : .title3.weight(.semibold))
                    .monospacedDigit()
            }

            // Row: Unwatched
            HStack {
                Label("Unwatched", systemImage: "eye.slash")
                Spacer()
                Text("\(unwatched)")
                    .font(isCompactPhone ? .body.weight(.semibold) : .title3.weight(.semibold))
                    .monospacedDigit()
            }

            // Row: Watched recently
            HStack {
                Label("Watched (last \(recentDays) \(daysSuffix))", systemImage: "clock")
                Spacer()
                Text("\(recentWatched)")
                    .font(isCompactPhone ? .body.weight(.semibold) : .title3.weight(.semibold))
                    .monospacedDigit()
            }

            // Row: Most recent watch date (optional)
            if let mostRecent {
                HStack {
                    Label("Most Recent Watch", systemImage: "calendar")
                    Spacer()
                    Text(mostRecent, style: .date)
                        .font(isCompactPhone ? .footnote : .body)
                        .foregroundStyle(.secondary)
                }
            }

            // Row: iCloud sync status
            HStack {
                Label("iCloud Sync", systemImage: "icloud")
                Spacer()
                Text(history.cloudSyncEnabled ? "On" : "Off")
                    .font(isCompactPhone ? .footnote.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(history.cloudSyncEnabled ? .primary : .secondary)
                    .accessibilityLabel("iCloud sync \(history.cloudSyncEnabled ? "on" : "off")")
            }
        } header: {
            Text("Stats")
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

            if isCompactPhone {
                VStack(spacing: 8) {
                    Button {
                        settings.tmdbAPIKey = workingKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    } label: {
                        Label("Save Key", systemImage: "tray.and.arrow.down.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(workingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        workingKey = settings.tmdbAPIKey
                    } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(workingKey == settings.tmdbAPIKey)
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        settings.tmdbAPIKey = workingKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    } label: {
                        Label("Save Key", systemImage: "tray.and.arrow.down.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(workingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        workingKey = settings.tmdbAPIKey
                    } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(workingKey == settings.tmdbAPIKey)

                    Spacer()
                }
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
                Label("Import", systemImage: "doc.on.clipboard.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(isCompactPhone ? .regular : .large)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(isCompactPhone ? .regular : .large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(library.movies.isEmpty)
            .accessibilityLabel("Clear library")
            .accessibilityHint("Deletes all saved movies")

            Toggle(isOn: Binding(get: {
                history.cloudSyncEnabled
            }, set: { newValue in
                history.setCloudSyncEnabled(newValue)
            })) {
                Label("iCloud sync for Watched", systemImage: "icloud")
            }

            Button {
                isSyncingNow = true
                history.syncNow()
                isSyncingNow = false
            } label: {
                Label(isSyncingNow ? "Syncing…" : "Sync Now", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!history.cloudSyncEnabled)
            .accessibilityLabel("Sync watched list with iCloud now")
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
                NavigationLink {
                    WatchedHistoryView()
                } label: {
                    Label("Watched History", systemImage: "clock.arrow.circlepath")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("Open full watched history")
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

// MARK: - Full Watched List
private struct WatchedHistoryView: View {
    @EnvironmentObject private var library: LibraryStore
    @ObservedObject private var history = WatchHistoryStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    private var isCompactPhone: Bool { hSize == .compact }

    var body: some View {
        // Use List for performance with larger histories
        List {
            let poster = isCompactPhone ? CGSize(width: 36, height: 54) : CGSize(width: 44, height: 66)
            let titleFont: Font = isCompactPhone ? .subheadline.weight(.semibold) : .headline
            let dateFont: Font = isCompactPhone ? .caption : .footnote
            let rowVSpacing: CGFloat = isCompactPhone ? 6 : 8
            let rowHSpacing: CGFloat = isCompactPhone ? 10 : 12

            let sorted = history.watched.sorted { $0.value > $1.value }

            ForEach(sorted, id: \.key) { (id, date) in
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

                    // Unwatch
                    if isCompactPhone {
                        Button {
                            history.unwatch(id)
                        } label: {
                            Image(systemName: "arrow.uturn.left.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Put \(library.movies.first(where: { $0.id == id })?.title ?? "movie") back in rotation")
                    } else {
                        Button {
                            history.unwatch(id)
                        } label: {
                            Label("Put Back", systemImage: "arrow.uturn.left.circle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, isCompactPhone ? 3 : 4)
            }
        }
        .navigationTitle("Watched History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !history.watched.isEmpty {
                    Button(role: .destructive) {
                        let ids = Array(history.watched.keys)
                        ids.forEach { history.unwatch($0) }
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                    .accessibilityLabel("Clear all watched history")
                }
            }
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
