import SwiftUI

struct DiscoverView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .imageScale(.large)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Discover").font(.title2.weight(.semibold))
            Text("Explore trending and new releases.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
