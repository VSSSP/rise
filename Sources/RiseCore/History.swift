import Foundation

public enum Source: String, Codable, Sendable {
    case alarm, manual
}

// One check-in: an alarm answered or left unanswered, or exercise logged by hand.
public struct Entry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var at: Date
    public var source: Source
    public var answered: Bool
    public var stood: Bool
    // Reps or seconds per exercise id; 0 means the exercise was asked and not done.
    public var counts: [String: Int]

    public init(
        id: UUID = UUID(), at: Date, source: Source, answered: Bool = true, stood: Bool, counts: [String: Int]
    ) {
        self.id = id
        self.at = at
        self.source = source
        self.answered = answered
        self.stood = stood
        self.counts = counts.mapValues { max(0, $0) }
    }

    public init(at: Date, source: Source, stood: Bool, pushups: Int, situps: Int) {
        self.init(at: at, source: source, stood: stood, counts: ["pushups": pushups, "situps": situps])
    }

    public static func missed(at: Date) -> Entry {
        Entry(at: at, source: .alarm, answered: false, stood: false, counts: [:])
    }

    public func count(_ exercise: String) -> Int {
        counts[exercise] ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, at, source, answered, stood, counts, pushups, situps
    }

    // Reads the first file format too, which kept push-ups and sit-ups in fields of their own.
    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        at = try box.decode(Date.self, forKey: .at)
        source = try box.decode(Source.self, forKey: .source)
        answered = try box.decode(Bool.self, forKey: .answered)
        stood = try box.decode(Bool.self, forKey: .stood)
        if let counts = try box.decodeIfPresent([String: Int].self, forKey: .counts) {
            self.counts = counts
        } else {
            var legacy: [String: Int] = [:]
            if let value = try box.decodeIfPresent(Int.self, forKey: .pushups), answered { legacy["pushups"] = value }
            if let value = try box.decodeIfPresent(Int.self, forKey: .situps), answered { legacy["situps"] = value }
            counts = legacy
        }
    }

    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(id, forKey: .id)
        try box.encode(at, forKey: .at)
        try box.encode(source, forKey: .source)
        try box.encode(answered, forKey: .answered)
        try box.encode(stood, forKey: .stood)
        try box.encode(counts, forKey: .counts)
    }
}

public struct DayTotals: Equatable, Identifiable, Sendable {
    public let day: Date
    public var stood = 0
    public var counts: [String: Int] = [:]
    public var answered = 0
    public var missed = 0

    public var id: Date { day }

    public init(day: Date) {
        self.day = day
    }

    public func count(_ exercise: String) -> Int {
        counts[exercise] ?? 0
    }
}

public struct History: Equatable, Sendable {
    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries.sorted { $0.at < $1.at }
    }

    public mutating func add(_ entry: Entry) {
        let index = entries.firstIndex { $0.at > entry.at } ?? entries.endIndex
        entries.insert(entry, at: index)
    }

    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public func entries(on day: Date, calendar: Calendar) -> [Entry] {
        entries.filter { calendar.isDate($0.at, inSameDayAs: day) }
    }

    public func alarmEntry(at slot: Date) -> Entry? {
        entries.last { $0.source == .alarm && $0.at == slot }
    }

    public func totals(on day: Date, calendar: Calendar) -> DayTotals {
        var totals = DayTotals(day: calendar.startOfDay(for: day))
        for entry in entries(on: day, calendar: calendar) {
            if entry.stood { totals.stood += 1 }
            for (exercise, value) in entry.counts { totals.counts[exercise, default: 0] += value }
            guard entry.source == .alarm else { continue }
            if entry.answered { totals.answered += 1 } else { totals.missed += 1 }
        }
        return totals
    }

    // The last `count` days up to and including `day`, oldest first, with the empty days kept.
    public func days(endingOn day: Date, count: Int, calendar: Calendar) -> [DayTotals] {
        let last = calendar.startOfDay(for: day)
        return (0..<max(count, 0)).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: last).map { totals(on: $0, calendar: calendar) }
        }
    }
}

public enum HistoryFileError: Error, Equatable {
    case unreadable(String)
}

// The history on disk as JSON; a file that cannot be read is moved aside, never overwritten.
public struct HistoryFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var standard: HistoryFile {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return HistoryFile(url: base.appendingPathComponent("Rise/history.json"))
    }

    private struct Payload: Codable {
        var version: Int
        var entries: [Entry]
    }

    public func load() throws -> History {
        guard FileManager.default.fileExists(atPath: url.path) else { return History() }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(Payload.self, from: Data(contentsOf: url))
            return History(entries: payload.entries)
        } catch {
            throw HistoryFileError.unreadable(error.localizedDescription)
        }
    }

    public func save(_ history: History) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Payload(version: 2, entries: history.entries)).write(to: url, options: .atomic)
    }

    // Moves an unreadable file aside so a fresh history never writes over it; returns the new path.
    public func setAside(now: Date = Date()) throws -> URL {
        let stamp = Int(now.timeIntervalSince1970)
        let aside = url.deletingLastPathComponent().appendingPathComponent("history-unreadable-\(stamp).json")
        try FileManager.default.moveItem(at: url, to: aside)
        return aside
    }
}
