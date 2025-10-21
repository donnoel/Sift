import UIKit

enum Pasteboard {
    static func readString() -> String? {
        UIPasteboard.general.string
    }

    static func writeString(_ value: String) {
        UIPasteboard.general.string = value
    }
}
