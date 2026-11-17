import Foundation

// Work hours in minutes after midnight; weekdays as Calendar counts them, where 1 is Sunday.
public struct WorkHours: Codable, Equatable, Sendable {
    public var start: Int
    public var end: Int
    public var interval: Int
    public var weekdays: Set<Int>

    public static let standard = WorkHours(start: 9 * 60, end: 18 * 60, interval: 45, weekdays: [2, 3, 4, 5, 6])

    public init(start: Int, end: Int, interval: Int, weekdays: Set<Int>) {
        self.start = start
        self.end = end
        self.interval = interval
        self.weekdays = weekdays
    }

    public var isValid: Bool {
        interval >= 5 && start >= 0 && end < 24 * 60 && start + interval <= end && !weekdays.isEmpty
    }
}

public struct DayKey: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

public struct Planner: Sendable {
    public let hours: WorkHours
    public let calendar: Calendar

    public init(hours: WorkHours, calendar: Calendar) {
        self.hours = hours
        self.calendar = calendar
    }

    // The alarms of the day that holds `day`: one interval after the start, then every interval.
    public func slots(on day: Date) -> [Date] {
        guard hours.isValid, hours.weekdays.contains(calendar.component(.weekday, from: day)) else { return [] }
        let midnight = calendar.startOfDay(for: day)
        return stride(from: hours.start + hours.interval, through: hours.end, by: hours.interval).compactMap {
            calendar.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: midnight)
        }
    }

    // The next alarms after `now`, leaving out a paused day and the skipped alarms.
    public func upcoming(
        after now: Date, pausedDay: DayKey?, skipped: Set<Date>, limit: Int, horizonDays: Int = 14
    ) -> [Date] {
        var found: [Date] = []
        var day = calendar.startOfDay(for: now)
        for _ in 0..<horizonDays {
            if DayKey(day, calendar: calendar) != pausedDay {
                for slot in slots(on: day) where slot > now && !skipped.contains(slot) {
                    found.append(slot)
                    if found.count == limit { return found }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return found
    }

    // The alarm to ring at `now`: one not rung yet and at most `grace` old, so a slept one stays quiet.
    public func due(
        at now: Date, after last: Date?, pausedDay: DayKey?, skipped: Set<Date>, grace: TimeInterval = 120
    ) -> Date? {
        guard pausedDay != DayKey(now, calendar: calendar) else { return nil }
        return slots(on: now).last { slot in
            slot <= now && now.timeIntervalSince(slot) <= grace && !skipped.contains(slot)
                && (last.map { slot > $0 } ?? true)
        }
    }
}
