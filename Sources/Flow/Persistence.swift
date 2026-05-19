import Foundation

enum Persistence {
    static let currentSchema = 1

    static var storeURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Flow", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("store.json")
    }

    static func load() -> Store {
        let url = storeURL
        guard let data = try? Data(contentsOf: url) else { return Store() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(Store.self, from: data) else {
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("store.broken.\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return Store()
        }
        if decoded.schemaVersion != currentSchema {
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("store.v\(decoded.schemaVersion).json")
            try? FileManager.default.copyItem(at: url, to: backup)
            return Store()
        }
        return decoded
    }

    static func deleteStore() {
        try? FileManager.default.removeItem(at: storeURL)
    }

    static func save(_ store: Store) {
        let url = storeURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store) else { return }
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } catch {
            try? data.write(to: url)
        }
    }
}
