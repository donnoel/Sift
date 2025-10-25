import Foundation

final class StubUbiquitousKeyValueStore: NSUbiquitousKeyValueStore {
    private var storage: [String: Any] = [:]

    override init() {
        super.init()
    }

    override func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    override func set(_ aValue: Any?, forKey defaultName: String) {
        if let value = aValue {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }

    override func synchronize() -> Bool {
        true
    }
}
