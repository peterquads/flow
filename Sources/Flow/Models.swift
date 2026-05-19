import Foundation

struct Interval: Codable, Identifiable, Hashable {
    let id: UUID
    let start: Date
    var end: Date?

    init(id: UUID = UUID(), start: Date, end: Date? = nil) {
        self.id = id
        self.start = start
        self.end = end
    }

    var seconds: TimeInterval {
        (end ?? Date()).timeIntervalSince(start)
    }

    var isOpen: Bool { end == nil }
}

struct Task: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var intervals: [Interval]
    var lastUsed: Date

    init(id: UUID = UUID(),
         name: String,
         intervals: [Interval] = [],
         lastUsed: Date = Date()) {
        self.id = id
        self.name = name
        self.intervals = intervals
        self.lastUsed = lastUsed
    }

    // Tolerantly ignore legacy fields (grayKey, sessionID) from older store.json files.
    private enum CodingKeys: String, CodingKey {
        case id, name, intervals, lastUsed
    }

    var totalSeconds: TimeInterval {
        intervals.reduce(0) { $0 + $1.seconds }
    }

    var isRunning: Bool {
        intervals.last?.isOpen == true
    }
}

struct Store: Codable {
    var schemaVersion: Int = 1
    var tasks: [Task] = []

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, tasks
    }
}
