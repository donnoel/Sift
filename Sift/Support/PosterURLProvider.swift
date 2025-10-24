import SwiftUI

public struct PosterURLProvider {
    let build: (String?) -> URL?
    public func url(for posterPath: String?) -> URL? { build(posterPath) }
}

private struct PosterURLProviderKey: EnvironmentKey {
    static let defaultValue = PosterURLProvider { _ in nil }
}

public extension EnvironmentValues {
    var posterURLProvider: PosterURLProvider {
        get { self[PosterURLProviderKey.self] }
        set { self[PosterURLProviderKey.self] = newValue }
    }
}
