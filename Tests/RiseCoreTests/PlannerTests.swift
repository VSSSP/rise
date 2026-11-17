import Foundation
import Testing

@testable import RiseCore

private let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    return calendar
}()

private let planner = Planner(hours: .standard, calendar: saoPaulo)

private func at(_ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
    saoPaulo.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
}

private func clock(_ dates: [Date]) -> [String] {
    dates.map { String(format: "%02d:%02d", saoPaulo.component(.hour, from: $0), saoPaulo.component(.minute, from: $0)) }
}

@Test func aWorkdayRingsTwelveTimesFromNineFortyFiveToSix() {
    #expect(
        clock(planner.slots(on: at(17, 8, 0))) == [
            "09:45", "10:30", "11:15", "12:00", "12:45", "13:30",
            "14:15", "15:00", "15:45", "16:30", "17:15", "18:00",
        ])
}

@Test func theWeekendNeverRings() {
    #expect(planner.slots(on: at(21, 10, 0)).isEmpty)
    #expect(planner.slots(on: at(22, 10, 0)).isEmpty)
}

@Test func theNextAlarmsFollowTheClock() {
    let next = planner.upcoming(after: at(17, 10, 0), pausedDay: nil, skipped: [], limit: 2)
    #expect(clock(next) == ["10:30", "11:15"])
}

@Test func afterFridayEveningTheNextAlarmIsMondayMorning() {
    let next = planner.upcoming(after: at(20, 18, 5), pausedDay: nil, skipped: [], limit: 1)
    #expect(next == [at(23, 9, 45)])
}

@Test func aPausedDayRingsNoMoreAndTomorrowRingsAgain() {
    let today = DayKey(at(17, 10, 0), calendar: saoPaulo)
    let next = planner.upcoming(after: at(17, 10, 0), pausedDay: today, skipped: [], limit: 1)
    #expect(next == [at(18, 9, 45)])
    #expect(planner.due(at: at(17, 10, 30), after: nil, pausedDay: today, skipped: []) == nil)
}

@Test func aSkippedAlarmIsLeftOut() {
    let skipped: Set = [at(17, 10, 30)]
    #expect(planner.upcoming(after: at(17, 10, 0), pausedDay: nil, skipped: skipped, limit: 1) == [at(17, 11, 15)])
    #expect(planner.due(at: at(17, 10, 30, second: 20), after: nil, pausedDay: nil, skipped: skipped) == nil)
}

@Test func anAlarmRingsOnceInsideItsGrace() {
    let slot = at(17, 10, 30)
    #expect(planner.due(at: at(17, 10, 30, second: 5), after: nil, pausedDay: nil, skipped: []) == slot)
    #expect(planner.due(at: at(17, 10, 31), after: slot, pausedDay: nil, skipped: []) == nil)
    #expect(planner.due(at: at(17, 10, 29), after: nil, pausedDay: nil, skipped: []) == nil)
}

@Test func anAlarmMissedWhileTheMacSleptStaysQuiet() {
    #expect(planner.due(at: at(17, 13, 40), after: at(17, 12, 0), pausedDay: nil, skipped: []) == nil)
}

@Test func anIntervalThatDoesNotDivideStopsBeforeTheEnd() {
    let hours = WorkHours(start: 9 * 60, end: 18 * 60, interval: 50, weekdays: [3])
    let slots = clock(Planner(hours: hours, calendar: saoPaulo).slots(on: at(17, 8, 0)))
    #expect(slots.count == 10)
    #expect(slots.first == "09:50")
    #expect(slots.last == "17:20")
}

@Test func hoursThatCannotHoldOneIntervalNeverRing() {
    let hours = WorkHours(start: 17 * 60 + 30, end: 18 * 60, interval: 45, weekdays: [3])
    #expect(!hours.isValid)
    #expect(Planner(hours: hours, calendar: saoPaulo).slots(on: at(17, 8, 0)).isEmpty)
}

@Test func noChosenDayMeansNoAlarmInTheHorizon() {
    let hours = WorkHours(start: 9 * 60, end: 18 * 60, interval: 45, weekdays: [])
    #expect(Planner(hours: hours, calendar: saoPaulo).upcoming(after: at(17, 8, 0), pausedDay: nil, skipped: [], limit: 1).isEmpty)
}
