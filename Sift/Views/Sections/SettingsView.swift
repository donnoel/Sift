import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var draftKey: String = ""
    @State private var isKeyHidden: Bool = false
    @FocusState private var keyIsFocused: Bool

    @State private var pastedTitles: String = ""

    // NEW: confirmation for clearing the library
    @State private var showClearConfirm: Bool = false
    @State private var isClearing: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                importCard
                maintenanceCard   // ← NEW
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .onAppear {
            draftKey = settings.tmdbAPIKey
            isKeyHidden = !settings.tmdbAPIKey.isEmpty
        }
        .onChange(of: settings.tmdbAPIKey) { _, newValue in
            isKeyHidden = !newValue.isEmpty
        }
        .navigationTitle("Settings")
        // Confirmation dialog for “Clear Library”
        .confirmationDialog("Clear Library?",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("Delete all movies", role: .destructive) {
                isClearing = true
                Task {
                    await library.clearAll()
                    isClearing = false
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all movies from your on-device library. This cannot be undone.")
        }
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill").imageScale(.large).foregroundStyle(.secondary)
                Text("TMDB API Key").font(.headline)
                Spacer()
                if !draftKey.isEmpty {
                    Button(isKeyHidden ? "Show" : "Hide") { isKeyHidden.toggle() }.buttonStyle(.bordered)
                }
                Button("Apply") {
                    settings.tmdbAPIKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    keyIsFocused = false
                    isKeyHidden = !settings.tmdbAPIKey.isEmpty
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Group {
                if isKeyHidden && !draftKey.isEmpty {
                    SecureField("TMDB API key", text: $draftKey).focused($keyIsFocused)
                } else {
                    TextField("Paste your TMDB API key", text: $draftKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textContentType(.password)
                        .focused($keyIsFocused)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))

            Divider().padding(.vertical, 4)

            HStack {
                Image(systemName: "list.clipboard").imageScale(.large).foregroundStyle(.secondary)
                Text("Paste movie titles (one per line)").font(.headline)
                Spacer()
                Button("Paste") { if let s = UIPasteboard.general.string { pastedTitles = s } }
                    .buttonStyle(.bordered)
                Button {
                    Task { await library.importFromPaste(pastedTitles) }
                } label: { Label("Import", systemImage: "arrow.down.doc") }
                .buttonStyle(.borderedProminent)
                .disabled(settings.tmdbAPIKey.isEmpty || pastedTitles.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextEditor(text: $pastedTitles)
                .frame(minHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            if library.isImporting {
                ProgressView(value: library.progress) { Text("Importing…") }
            }

            if !library.lastErrors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A few issues:").font(.subheadline).bold()
                    ForEach(Array(library.lastErrors.prefix(3).enumerated()), id: \.offset) { _, err in
                        Text("• " + err).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .background(
            Group {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.systemBackground))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
    }

    // MARK: - NEW: Library Maintenance
    private var maintenanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trash").imageScale(.large).foregroundStyle(.secondary)
                Text("Library Maintenance").font(.headline)
                Spacer()
            }

            Text("Remove all movies stored on this device. This action cannot be undone.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button {
                    showClearConfirm = true
                } label: {
                    Label(isClearing ? "Clearing…" : "Clear Library", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isClearing)
                Spacer()
            }
        }
        .padding(16)
        .background(
            Group {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.systemBackground))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}
