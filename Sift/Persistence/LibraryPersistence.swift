import Foundation

actor LibraryPersistence {
    private var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("library.json")
    }

    func load() -> [Movie]? {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return try? JSONDecoder().decode([Movie].self, from: data)
    }

    func save(movies: [Movie]) {
        do {
            let data = try JSONEncoder().encode(movies)
            try data.write(to: url, options: .atomic)
        } catch { }
    }
}
