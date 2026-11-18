import Foundation
import Testing

@testable import RiseCore

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

private func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
    saoPaulo.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

private func sample() -> History {
    History(entries: [
        Entry(at: at(18, 11, 15), source: .alarm, stood: true, pushups: 10, situps: 0),
        Entry(at: at(18, 9, 45), source: .alarm, stood: true, pushups: 10, situps: 15),
        Entry.missed(at: at(18, 10, 30)),
        Entry(at: at(18, 11, 40), source: .manual, stood: true, pushups: 10, situps: 15),
        Entry(at: at(17, 16, 30), source: .alarm, stood: false, pushups: 0, situps: 20),
    ])
}

@Test func entriesStayInTimeOrderWhateverOrderTheyCameIn() {
    var history = sample()
    history.add(Entry(at: at(18, 10, 0), source: .manual, stood: false, pushups: 5, situps: 0))
    let times = history.entries.map(\.at)
    #expect(times == times.sorted())
    #expect(history.entries.count == 6)
}

@Test func aDaySumsItsStandUpsAndExerciseAndCountsMissedAlarms() {
    let day = sample().totals(on: at(18, 20, 0), calendar: saoPaulo)
    #expect(day.day == saoPaulo.startOfDay(for: at(18, 0, 0)))
    #expect(day.stood == 3)
    #expect(day.pushups == 30)
    #expect(day.situps == 30)
    #expect(day.answered == 2)
    #expect(day.missed == 1)
}

@Test func theWeekKeepsEmptyDaysOldestFirst() {
    let week = sample().days(endingOn: at(18, 12, 0), count: 7, calendar: saoPaulo)
    #expect(week.count == 7)
    #expect(week.first?.day == saoPaulo.startOfDay(for: at(12, 0, 0)))
    #expect(week.last?.pushups == 30)
    #expect(week[5].situps == 20)
    #expect(week[0...4].allSatisfy { $0.stood == 0 && $0.pushups == 0 && $0.situps == 0 })
}

@Test func anAlarmIsFoundByItsSlotAndAManualLogNever() {
    let history = sample()
    #expect(history.alarmEntry(at: at(18, 9, 45))?.pushups == 10)
    #expect(history.alarmEntry(at: at(18, 10, 30))?.answered == false)
    #expect(history.alarmEntry(at: at(18, 11, 40)) == nil)
}

@Test func removingAnEntryTakesOnlyThatOne() {
    var history = sample()
    let target = history.entries[1]
    history.remove(id: target.id)
    #expect(history.entries.count == 4)
    #expect(!history.entries.contains(target))
}

@Test func negativeCountsBecomeZero() {
    let entry = Entry(at: at(18, 9, 45), source: .manual, stood: true, pushups: -3, situps: -1)
    #expect(entry.pushups == 0 && entry.situps == 0)
}

private func scratch() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rise-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("Rise/history.json")
}

@Test func theFileRoundTripsEveryEntry() throws {
    let file = HistoryFile(url: try scratch())
    #expect(try file.load() == History())
    let history = sample()
    try file.save(history)
    let loaded = try file.load()
    #expect(loaded == history)
    #expect(loaded.totals(on: at(18, 0, 0), calendar: saoPaulo) == history.totals(on: at(18, 0, 0), calendar: saoPaulo))
}

@Test func anUnreadableFileIsReportedAndSetAsideNotLost() throws {
    let url = try scratch()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: url)
    let file = HistoryFile(url: url)
    #expect(throws: HistoryFileError.self) { try file.load() }
    let aside = try file.setAside(now: at(18, 12, 0))
    #expect(try String(contentsOf: aside, encoding: .utf8) == "not json")
    #expect(try file.load() == History())
}
