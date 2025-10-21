import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var library: LibraryStore
    @State private var selected: Section = .forYou

    var body: some View {
        ZStack {
            PremiumBackground(section: selected)
                .ignoresSafeArea()

            Group {
                switch selected {
                case .forYou:   ForYouView(libraryProvider: { [library] in library.movies })
                case .discover: DiscoverView()
                case .library:  LibraryView()
                case .settings: SettingsView()
                }
            }
            .transition(.opacity)

            VStack { Spacer() }
                .safeAreaInset(edge: .bottom) {
                    GlassTabBar(selected: $selected).padding(.top, 6)
                }
        }
    }
}

private struct PremiumBackground: View {
    let section: Section
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let base = LinearGradient(
            colors: [
                section.accent.opacity(0.20),
                section.accentSecondary.opacity(0.18),
                Color.clear
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        Group {
            if reduceTransparency {
                Rectangle().fill(Color(.systemBackground)).overlay(base.opacity(0.35))
            } else {
                Rectangle().fill(.ultraThinMaterial).overlay(base)
            }
        }
    }
}
