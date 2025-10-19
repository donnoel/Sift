import SwiftUI

public enum Section: String, Hashable, CaseIterable {
    case forYou, discover, library, settings

    var title: String {
        switch self {
        case .forYou:   "For You"
        case .discover: "Discover"
        case .library:  "Library"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .forYou:   return "sparkles"
        case .discover: return "safari"
        case .library:  return "film"
        case .settings: return "gearshape"
        }
    }

    var accentPrimary: Color {
        switch self {
        case .forYou:   Color(hue: 0.92, saturation: 0.70, brightness: 0.98)
        case .discover: Color(hue: 0.57, saturation: 0.65, brightness: 0.98)
        case .library:  Color(hue: 0.08, saturation: 0.85, brightness: 0.98)
        case .settings: Color(hue: 0.43, saturation: 0.60, brightness: 0.95)
        }
    }

    var accentSecondary: Color {
        switch self {
        case .forYou:   Color(hue: 0.86, saturation: 0.52, brightness: 0.98)
        case .discover: Color(hue: 0.72, saturation: 0.55, brightness: 0.95)
        case .library:  Color(hue: 0.03, saturation: 0.70, brightness: 0.98)
        case .settings: Color(hue: 0.50, saturation: 0.40, brightness: 0.95)
        }
    }

    var accent: Color { accentPrimary }
}
