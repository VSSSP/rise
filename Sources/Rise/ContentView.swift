import RiseCore
import SwiftUI

enum Tab: CaseIterable {
    case today, history, settings

    func title(_ s: Strings) -> String {
        switch self {
        case .today: return s.tabToday
        case .history: return s.tabHistory
        case .settings: return s.tabSettings
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: Store
    @State var tab: Tab = .today

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(store.s.section, selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.title(store.s)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case .today: TodayTab(store: store)
            case .history: HistoryTab(store: store)
            case .settings: SettingsForm(store: store, music: store.music)
            }
            if let problem = store.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

let sunrise = LinearGradient(
    colors: [
        Color(red: 0.16, green: 0.17, blue: 0.42), Color(red: 0.62, green: 0.25, blue: 0.52),
        Color(red: 0.95, green: 0.42, blue: 0.40), Color(red: 1.0, green: 0.64, blue: 0.33),
    ],
    startPoint: .topLeading, endPoint: .bottomTrailing)

struct TodayTab: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusCard(store: store)
            TotalsRow(totals: store.todayTotals, s: store.s)
            if !store.todaySlots.isEmpty {
                TodayGrid(store: store)
            }
            Actions(store: store)
            Label(store.s.menuBarHint, systemImage: "menubar.arrow.up.rectangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StatusCard: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .opacity(0.85)
            Text(time)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.callout)
                .opacity(0.92)
            Text(store.s.eachReminder(store.targets.pushups, store.targets.situps))
                .font(.footnote)
                .opacity(0.85)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(sunrise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var caption: String {
        guard store.hours.isValid else { return store.s.invalidHoursCaption }
        guard store.next != nil else { return store.s.noRemindersCaption }
        return store.isPausedToday ? store.s.pausedCaption : store.s.nextCaption
    }

    private var time: String {
        store.next.map { Format.clock.string(from: $0) } ?? "--:--"
    }

    private var detail: String {
        guard store.hours.isValid else { return store.s.intervalDoesNotFit }
        guard let next = store.next else { return store.s.pickADay }
        return Format.until(next, from: store.now, calendar: store.calendar, store.s)
    }
}

struct TotalsRow: View {
    let totals: DayTotals
    let s: Strings

    var body: some View {
        HStack(spacing: 10) {
            tile(s.standUpsTitle, totals.stood, "figure.stand", standColor)
            tile(s.pushupsTitle, totals.pushups, "figure.strengthtraining.functional", Series.pushups.color)
            tile(s.situpsTitle, totals.situps, "figure.core.training", Series.situps.color)
        }
    }

    private func tile(_ title: String, _ value: Int, _ symbol: String, _ mark: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(mark)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TodayGrid: View {
    @ObservedObject var store: Store
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.isPausedToday ? store.s.todayRemindersPaused : store.s.todayReminders)
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.todaySlots, id: \.self) { slot in
                    chip(slot)
                }
            }
            Text(store.s.slotLegend)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ slot: Date) -> some View {
        let past = slot <= store.now
        let skipped = store.skipped.contains(slot)
        let next = slot == store.next
        let quiet = past || skipped || store.isPausedToday
        let entry = store.history.alarmEntry(at: slot)
        return Button {
            store.toggleSkip(slot)
        } label: {
            HStack(spacing: 4) {
                Text(Format.clock.string(from: slot))
                    .monospacedDigit()
                    .strikethrough(skipped)
                if let entry {
                    Image(systemName: entry.answered ? "checkmark" : "xmark")
                        .font(.caption2.weight(.bold))
                }
            }
            .font(.system(.callout, design: .rounded).weight(next ? .bold : .regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(next ? Color.white : (quiet && entry == nil ? Color.secondary : Color.primary))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(next ? AnyShapeStyle(sunrise) : AnyShapeStyle(Color.primary.opacity(quiet ? 0.04 : 0.08)))
            )
        }
        .buttonStyle(.plain)
        .disabled(past)
        .help(help(entry, skipped))
    }

    private func help(_ entry: Entry?, _ skipped: Bool) -> String {
        let s = store.s
        guard let entry else { return skipped ? s.bringBack : s.skipThis }
        guard entry.answered else { return s.noAnswer }
        return "\(entry.stood ? s.stood : s.didNotStand) · \(s.pushups(entry.pushups)) · \(s.situps(entry.situps))"
    }
}

struct Actions: View {
    @ObservedObject var store: Store

    var body: some View {
        let s = store.s
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Button {
                    store.logNow()
                } label: {
                    Label(s.logNow, systemImage: "square.and.pencil").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                Button {
                    store.skipNext()
                } label: {
                    Label(s.skipNext, systemImage: "forward.end").frame(maxWidth: .infinity)
                }
                .disabled(store.next == nil)
            }
            GridRow {
                Button {
                    store.togglePauseToday()
                } label: {
                    Label(
                        store.isPausedToday ? s.resumeToday : s.pauseToday,
                        systemImage: store.isPausedToday ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                Button {
                    store.test()
                } label: {
                    Label(s.testReminder, systemImage: "bell").frame(maxWidth: .infinity)
                }
            }
        }
        .controlSize(.large)
    }
}

struct SettingsForm: View {
    @ObservedObject var store: Store
    @ObservedObject var music: MusicPlayer

    var body: some View {
        let s = store.s
        VStack(alignment: .leading, spacing: 12) {
            Text(s.workHours)
                .font(.headline)
            HStack {
                DatePicker(s.start, selection: minutes(\.start), displayedComponents: .hourAndMinute)
                Spacer()
                DatePicker(s.end, selection: minutes(\.end), displayedComponents: .hourAndMinute)
            }
            Stepper(value: $store.hours.interval, in: 15...120, step: 5) {
                Text(s.every(store.hours.interval))
            }
            HStack(spacing: 6) {
                ForEach(s.days, id: \.0) { day, name in
                    Toggle(name, isOn: weekday(day))
                        .toggleStyle(.button)
                }
            }
            Divider()
            Text(s.setTitle)
                .font(.headline)
            Stepper(value: $store.targets.pushups, in: 1...200) {
                Text(s.pushups(store.targets.pushups))
            }
            Stepper(value: $store.targets.situps, in: 1...200) {
                Text(s.situps(store.targets.situps))
            }
            Text(s.setHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Text(s.musicTitle)
                .font(.headline)
            Toggle(s.playMusic, isOn: $store.sound)
            HStack {
                Picker(s.music, selection: $store.tuneID) {
                    ForEach(store.tunes) { Text($0.title).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 210)
                Button(music.isPlaying ? s.stop : s.listen) { store.previewTune() }
                Button(s.useFile) { store.chooseTuneFile() }
            }
            .disabled(!store.sound)
            HStack {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $store.volume, in: 0.1...1)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            .disabled(!store.sound)
            .accessibilityLabel(s.volume)
            Divider()
            Picker(s.language, selection: $store.language) {
                Text(s.automatic).tag(LanguageChoice.system)
                Text("English").tag(LanguageChoice.en)
                Text("Português").tag(LanguageChoice.pt)
            }
            .frame(maxWidth: 260)
            Toggle(s.openAtLogin, isOn: loginBinding)
                .disabled(store.login == .unavailable)
            switch store.login {
            case .needsApproval:
                HStack {
                    Text(s.needsApproval)
                        .font(.caption)
                    Button(s.openSettings) { store.openLoginSettings() }
                        .controlSize(.small)
                }
            case .unavailable:
                Text(s.installFirst)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
            HStack {
                Button(s.showHistoryFile) { store.openHistoryFolder() }
                    .controlSize(.small)
                Spacer()
                Text("Rise \(store.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(get: { store.login == .on || store.login == .needsApproval }, set: { store.setLogin($0) })
    }

    private func minutes(_ key: WritableKeyPath<WorkHours, Int>) -> Binding<Date> {
        Binding(
            get: {
                let value = store.hours[keyPath: key]
                return store.calendar.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: store.now)
                    ?? store.now
            },
            set: { date in
                let parts = store.calendar.dateComponents([.hour, .minute], from: date)
                store.hours[keyPath: key] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }

    private func weekday(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { store.hours.weekdays.contains(day) },
            set: { on in
                if on { store.hours.weekdays.insert(day) } else { store.hours.weekdays.remove(day) }
            })
    }
}
