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
    #expect(day.count("pushups") == 30)
    #expect(day.count("situps") == 30)
    #expect(day.answered == 2)
    #expect(day.missed == 1)
}

@Test func theWeekKeepsEmptyDaysOldestFirst() {
    let week = sample().days(endingOn: at(18, 12, 0), count: 7, calendar: saoPaulo)
    #expect(week.count == 7)
    #expect(week.first?.day == saoPaulo.startOfDay(for: at(12, 0, 0)))
    #expect(week.last?.count("pushups") == 30)
    #expect(week[5].count("situps") == 20)
    #expect(week[0...4].allSatisfy { $0.stood == 0 && $0.counts.isEmpty })
}

@Test func anAlarmIsFoundByItsSlotAndAManualLogNever() {
    let history = sample()
    #expect(history.alarmEntry(at: at(18, 9, 45))?.count("pushups") == 10)
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
    #expect(entry.count("pushups") == 0 && entry.count("situps") == 0)
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

@Test func anyExerciseIsSummedByItsId() {
    var history = History()
    history.add(Entry(at: at(18, 9, 45), source: .alarm, stood: true, counts: ["squats": 15, "plank": 30]))
    history.add(Entry(at: at(18, 10, 30), source: .alarm, stood: true, counts: ["squats": 0, "plank": 45]))
    let day = history.totals(on: at(18, 12, 0), calendar: saoPaulo)
    #expect(day.count("squats") == 15)
    #expect(day.count("plank") == 75)
    #expect(day.count("pushups") == 0)
}

@Test func theFirstFileFormatStillLoads() throws {
    let url = try scratch()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let old = """
        {"version":1,"entries":[
        {"answered":true,"at":"2026-11-18T14:45:00Z","id":"575816CE-4338-4215-9DD4-44B9E868A419",
         "pushups":10,"situps":15,"source":"manual","stood":true},
        {"answered":false,"at":"2026-11-18T15:15:00Z","id":"675816CE-4338-4215-9DD4-44B9E868A419",
         "pushups":0,"situps":0,"source":"alarm","stood":false}]}
        """
    try Data(old.utf8).write(to: url)
    let file = HistoryFile(url: url)
    let loaded = try file.load()
    #expect(loaded.entries.first?.counts == ["pushups": 10, "situps": 15])
    #expect(loaded.entries.last?.counts == [:])
    try file.save(loaded)
    #expect(try file.load() == loaded)
    #expect(try String(contentsOf: url, encoding: .utf8).contains("\"counts\""))
}
