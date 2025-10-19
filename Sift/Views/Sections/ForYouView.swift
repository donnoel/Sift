import SwiftUI

struct ForYouView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .imageScale(.large)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("For You").font(.title2.weight(.semibold))
            Text("Personalized picks will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
