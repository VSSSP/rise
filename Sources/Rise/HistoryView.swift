import AppKit
import Charts
import RiseCore
import SwiftUI

// Chart colors validated for both modes; text never wears them.
enum Series: String, CaseIterable {
    case pushups = "Flexões"
    case situps = "Abdominais"

    var color: Color {
        switch self {
        case .pushups: return dynamicColor(light: 0x2A78D6, dark: 0x3987E5)
        case .situps: return dynamicColor(light: 0xEB6834, dark: 0xD95926)
        }
    }

    func value(_ day: DayTotals) -> Int {
        self == .pushups ? day.pushups : day.situps
    }
}

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

private let brazil = Locale(identifier: "pt_BR")

struct HistoryTab: View {
    @ObservedObject var store: Store
    @State private var span = 7

    var body: some View {
        let days = store.history.days(endingOn: store.now, count: span, calendar: store.calendar)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Flexões e abdominais por dia")
                    .font(.headline)
                Spacer()
                Picker("Período", selection: $span) {
                    Text("7 dias").tag(7)
                    Text("30 dias").tag(30)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }
            ExerciseChart(days: days, span: span, calendar: store.calendar)
            Text("Levantadas por dia")
                .font(.headline)
            StandChart(days: days, span: span)
            Text("Registros")
                .font(.headline)
            EntryList(store: store)
        }
    }
}

private func axisLabel(_ span: Int) -> Date.FormatStyle {
    let style: Date.FormatStyle =
        span > 7 ? .dateTime.day().month(.defaultDigits) : .dateTime.weekday(.abbreviated).day()
    return style.locale(brazil)
}

struct ExerciseChart: View {
    let days: [DayTotals]
    let span: Int
    let calendar: Calendar
    @State private var picked: Date?

    var body: some View {
        Chart {
            selection
            bars
        }
        .chartForegroundStyleScale([
            Series.pushups.rawValue: Series.pushups.color, Series.situps.rawValue: Series.situps.color,
        ])
        .chartLegend(position: .top, alignment: .leading, spacing: 8)
        .chartXSelection(value: $picked)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: span > 7 ? 5 : 1)) { _ in
                AxisValueLabel(format: axisLabel(span), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel()
            }
        }
        .environment(\.locale, brazil)
        .frame(height: 180)
        .accessibilityLabel("Flexões e abdominais por dia")
    }

    private struct Point: Identifiable {
        let day: Date
        let series: String
        let value: Int
        var id: String { "\(day.timeIntervalSince1970)-\(series)" }
    }

    private var points: [Point] {
        days.flatMap { day in Series.allCases.map { Point(day: day.day, series: $0.rawValue, value: $0.value(day)) } }
    }

    @ChartContentBuilder private var bars: some ChartContent {
        ForEach(points) { point in
            BarMark(x: .value("Dia", point.day, unit: .day), y: .value("Quantidade", point.value))
                .foregroundStyle(by: .value("Exercício", point.series))
                .position(by: .value("Exercício", point.series))
                .cornerRadius(3)
        }
    }

    @ChartContentBuilder private var selection: some ChartContent {
        if let day = selected {
            RuleMark(x: .value("Dia", day.day, unit: .day))
                .foregroundStyle(Color.secondary.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: span > 7 ? 8 : 34))
                .annotation(
                    position: .top, spacing: 4,
                    overflowResolution: AnnotationOverflowResolution(x: .fit(to: .chart), y: .disabled)
                ) {
                    DayTip(day: day)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Format.sentence(Format.dayTitle.string(from: day.day)))
                .font(.caption.weight(.bold))
            line(Series.pushups.color, "\(day.pushups) flexões")
            line(Series.situps.color, "\(day.situps) abdominais")
            line(standColor, Format.count(day.stood, "levantada", "levantadas"))
            if day.missed > 0 {
                Text(Format.count(day.missed, "aviso sem resposta", "avisos sem resposta"))
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

    var body: some View {
        Chart(days) { day in
            BarMark(x: .value("Dia", day.day, unit: .day), y: .value("Levantadas", day.stood))
                .foregroundStyle(standColor)
                .cornerRadius(3)
                .annotation(position: .top, spacing: 2) {
                    if span <= 7 && day.stood > 0 {
                        Text("\(day.stood)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: span > 7 ? 5 : 1)) { _ in
                AxisValueLabel(format: axisLabel(span), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel()
            }
        }
        .environment(\.locale, brazil)
        .frame(height: 90)
        .accessibilityLabel("Levantadas por dia")
    }
}

struct EntryList: View {
    @ObservedObject var store: Store
    @State private var doomed: Entry?

    var body: some View {
        let groups = grouped()
        Group {
            if groups.isEmpty {
                Text("Nada registrado ainda. Responda um aviso ou use Registrar agora.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Format.sentence(Format.dayTitle.string(from: group.day)))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                ForEach(group.entries) { entry in
                                    row(entry)
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
            "Apagar este registro?", isPresented: Binding(get: { doomed != nil }, set: { if !$0 { doomed = nil } })
        ) {
            Button("Apagar", role: .destructive) {
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

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: 10) {
            Text(Format.clock.string(from: entry.at))
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)
            Image(systemName: entry.source == .alarm ? "bell" : "square.and.pencil")
                .foregroundStyle(.secondary)
                .help(entry.source == .alarm ? "Aviso" : "Registrado à mão")
                .frame(width: 18)
            if entry.answered {
                mark(entry.stood, entry.stood ? "levantou" : "não levantou")
                mark(entry.pushups > 0, entry.pushups > 0 ? "\(entry.pushups) flexões" : "sem flexões")
                mark(entry.situps > 0, entry.situps > 0 ? "\(entry.situps) abdominais" : "sem abdominais")
            } else {
                Label("Sem resposta", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            Button("Apagar registro", role: .destructive) { doomed = entry }
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
