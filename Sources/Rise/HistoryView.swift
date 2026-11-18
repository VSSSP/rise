import AppKit
import Charts
import RiseCore
import SwiftUI

let standColor = dynamicColor(light: 0x6250D6, dark: 0x9085E9)

func dynamicColor(light: UInt32, dark: UInt32) -> Color {
    Color(
        nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
}

struct HistoryTab: View {
    @ObservedObject var store: Store
    @State private var span = 7

    var body: some View {
        let s = store.s
        let days = store.history.days(endingOn: store.now, count: span, calendar: store.calendar)
        let reps = store.plan.filter { $0.exercise?.unit == .reps }
        let timed = store.plan.filter { $0.exercise?.unit == .seconds }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(reps.isEmpty && !timed.isEmpty ? s.chartTimed : s.chartExercise)
                    .font(.headline)
                Spacer()
                Picker(s.period, selection: $span) {
                    Text(s.sevenDays).tag(7)
                    Text(s.thirtyDays).tag(30)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }
            if !reps.isEmpty {
                ExerciseChart(days: days, span: span, calendar: store.calendar, s: s, items: reps, plan: store.plan)
            }
            if !timed.isEmpty {
                if !reps.isEmpty {
                    Text(s.chartTimed).font(.headline)
                }
                ExerciseChart(days: days, span: span, calendar: store.calendar, s: s, items: timed, plan: store.plan)
            }
            Text(s.chartStandUps)
                .font(.headline)
            StandChart(days: days, span: span, calendar: store.calendar, s: s, plan: store.plan)
            Text(s.entries)
                .font(.headline)
            EntryList(store: store)
        }
    }
}

private func axisLabel(_ span: Int, _ lang: Lang) -> Date.FormatStyle {
    let style: Date.FormatStyle =
        span > 7 ? .dateTime.day().month(.defaultDigits) : .dateTime.weekday(.abbreviated).day()
    return style.locale(lang.locale)
}

private struct Hover: ChartContent {
    let day: DayTotals
    let s: Strings
    let plan: [PlanItem]

    var body: some ChartContent {
        RuleMark(x: .value(s.day, day.day, unit: .day))
            .foregroundStyle(Color.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(
                position: .top, spacing: 4,
                overflowResolution: AnnotationOverflowResolution(x: .fit(to: .chart), y: .disabled)
            ) {
                DayTip(day: day, s: s, plan: plan)
            }
    }
}

struct ExerciseChart: View {
    let days: [DayTotals]
    let span: Int
    let calendar: Calendar
    let s: Strings
    let items: [PlanItem]
    let plan: [PlanItem]
    @State private var picked: Date?

    var body: some View {
        Chart {
            lines
            if let day = selected { Hover(day: day, s: s, plan: plan) }
        }
        .chartForegroundStyleScale(domain: items.map { s.name($0.id) }, range: items.map { Palette.color($0.slot) })
        .chartSymbolScale(domain: items.map { s.name($0.id) }, range: items.map { Palette.shapes[$0.slot % Palette.shapes.count] })
        .chartLegend(position: .top, alignment: .leading, spacing: 8)
        .chartYScale(domain: .automatic(includesZero: true))
        .chartXSelection(value: $picked)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: span > 7 ? 5 : 1)) { _ in
                AxisValueLabel(format: axisLabel(span, s.lang), centered: false)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel()
            }
        }
        .frame(height: 190)
        .accessibilityLabel(s.chartExercise)
    }

    private struct Point: Identifiable {
        let day: Date
        let series: String
        let value: Int
        let label: Bool
        let higher: Bool
        var id: String { "\(day.timeIntervalSince1970)-\(series)" }
    }

    // Direct labels on the last day only while two series or fewer share the chart.
    private var points: [Point] {
        let lastDay = days.last?.day
        return days.flatMap { day in
            items.map { item in
                let value = day.count(item.id)
                let others = items.filter { $0.id != item.id }.map { day.count($0.id) }
                return Point(
                    day: day.day, series: s.name(item.id), value: value,
                    label: items.count <= 2 && day.day == lastDay, higher: value >= (others.max() ?? 0))
            }
        }
    }

    @ChartContentBuilder private var lines: some ChartContent {
        ForEach(points) { point in
            LineMark(x: .value(s.day, point.day, unit: .day), y: .value(s.amount, point.value))
                .foregroundStyle(by: .value(s.exercise, point.series))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
        }
        ForEach(points) { point in
            PointMark(x: .value(s.day, point.day, unit: .day), y: .value(s.amount, point.value))
                .foregroundStyle(by: .value(s.exercise, point.series))
                .symbol(by: .value(s.exercise, point.series))
                .symbolSize(span > 7 ? 40 : 64)
                .annotation(position: point.higher ? .top : .bottom, spacing: 4) {
                    if point.label {
                        Text("\(point.value)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
        }
    }

    private var selected: DayTotals? {
        guard let picked else { return nil }
        return days.first { calendar.isDate($0.day, inSameDayAs: picked) }
    }
}

private struct DayTip: View {
    let day: DayTotals
    let s: Strings
    let plan: [PlanItem]

    var body: some View {
        let chosen = Set(plan.map(\.id))
        let others = day.counts.filter { !chosen.contains($0.key) && $0.value > 0 }.keys
            .sorted { Exercise.order($0) < Exercise.order($1) }
        VStack(alignment: .leading, spacing: 3) {
            Text(Format.dayTitle(day.day, s.lang))
                .font(.caption.weight(.bold))
            line(standColor, s.standUps(day.stood))
            ForEach(plan) { item in
                line(Palette.color(item.slot), s.amount(item.id, day.count(item.id)))
            }
            ForEach(others, id: \.self) { id in
                line(.secondary, s.amount(id, day.count(id)))
            }
            if day.missed > 0 {
                Text(s.missed(day.missed))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
    }

    private func line(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption).monospacedDigit()
        }
    }
}

struct StandChart: View {
    let days: [DayTotals]
    let span: Int
    let calendar: Calendar
    let s: Strings
    let plan: [PlanItem]
    @State private var picked: Date?

    var body: some View {
        Chart {
            ForEach(days) { day in
                LineMark(x: .value(s.day, day.day, unit: .day), y: .value(s.standUpsTitle, day.stood))
                    .foregroundStyle(standColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value(s.day, day.day, unit: .day), y: .value(s.standUpsTitle, day.stood))
                    .foregroundStyle(standColor)
                    .symbolSize(span > 7 ? 40 : 64)
                    .annotation(position: .top, spacing: 3) {
                        if span <= 7 && day.stood > 0 {
                            Text("\(day.stood)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
            }
            if let day = selected { Hover(day: day, s: s, plan: plan) }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartXSelection(value: $picked)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: span > 7 ? 5 : 1)) { _ in
                AxisValueLabel(format: axisLabel(span, s.lang), centered: false)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel()
            }
        }
        .frame(height: 110)
        .accessibilityLabel(s.chartStandUps)
    }

    private var selected: DayTotals? {
        guard let picked else { return nil }
        return days.first { calendar.isDate($0.day, inSameDayAs: picked) }
    }
}

struct EntryList: View {
    @ObservedObject var store: Store
    @State private var doomed: Entry?

    var body: some View {
        let s = store.s
        let groups = grouped()
        Group {
            if groups.isEmpty {
                Text(s.nothingYet)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Format.dayTitle(group.day, s.lang))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                ForEach(group.entries) { entry in
                                    row(entry, s)
                                }
                            }
                        }
                    }
                    .padding(.trailing, 6)
                }
                .frame(height: 200)
            }
        }
        .confirmationDialog(
            s.deleteQuestion, isPresented: Binding(get: { doomed != nil }, set: { if !$0 { doomed = nil } })
        ) {
            Button(s.delete, role: .destructive) {
                if let doomed { store.remove(doomed) }
                doomed = nil
            }
        }
    }

    private func grouped() -> [(day: Date, entries: [Entry])] {
        var groups: [(day: Date, entries: [Entry])] = []
        for entry in store.history.entries.reversed().prefix(120) {
            let day = store.calendar.startOfDay(for: entry.at)
            if groups.last?.day == day {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((day, [entry]))
            }
        }
        return groups
    }

    private func row(_ entry: Entry, _ s: Strings) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(Format.clock.string(from: entry.at))
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)
            Image(systemName: entry.source == .alarm ? "bell" : "square.and.pencil")
                .foregroundStyle(.secondary)
                .help(entry.source == .alarm ? s.fromReminder : s.byHand)
                .frame(width: 18)
            if entry.answered {
                Flow(spacing: 10, lineSpacing: 4) {
                    mark(entry.stood, entry.stood ? s.stood : s.didNotStand)
                    ForEach(entry.ordered, id: \.0) { id, value in
                        mark(value > 0, value > 0 ? s.amount(id, value) : s.none(id))
                    }
                }
            } else {
                Label(s.noAnswer, systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            Button(s.deleteEntry, role: .destructive) { doomed = entry }
        }
    }

    private func mark(_ done: Bool, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: done ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(done ? Color.primary : Color.secondary)
            Text(text)
                .foregroundStyle(done ? Color.primary : Color.secondary)
        }
        .lineLimit(1)
        .fixedSize()
    }
}
