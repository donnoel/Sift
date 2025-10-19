import SwiftUI
import Combine

// A simple container so we can build and share both Settings and Library
// without tricky @StateObject initialization ordering.
@MainActor
final class AppContainer: ObservableObject {
    let settings = AppSettings()
    lazy var library: LibraryStore = LibraryStore(settings: settings)
}

public struct TopSheetsRoot: View {
    @StateObject private var container = AppContainer()

    public init() {}

    public var body: some View {
        RootView()
            .environmentObject(container.settings)
            .environmentObject(container.library)
    }
}
