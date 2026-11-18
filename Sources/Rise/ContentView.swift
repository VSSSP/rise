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
        if store.setupDone {
            tabs
        } else {
            SetupView(store: store)
        }
    }

    private var tabs: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(store.s.section, selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.title(store.s)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case .today: TodayTab(store: store)
            case .history: HistoryTab(store: store)
            case .settings:
                ScrollView {
                    SettingsForm(store: store, music: store.music).padding(.trailing, 12)
                }
                .frame(height: 600)
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

struct TodayTab: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusCard(store: store)
            TotalsRow(store: store)
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
            Text(store.eachReminder)
                .font(.footnote)
                .opacity(0.85)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(store.theme.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
    @ObservedObject var store: Store
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        let s = store.s
        let totals = store.todayTotals
        LazyVGrid(columns: columns, spacing: 10) {
            tile(s.standUpsTitle, "\(totals.stood)", "figure.stand", standColor)
            ForEach(store.plan) { item in
                tile(
                    s.name(item.id), s.counter(item.id, totals.count(item.id)), item.exercise?.image ?? "figure.walk",
                    Palette.color(item.slot))
            }
        }
    }

    private func tile(_ title: String, _ value: String, _ symbol: String, _ mark: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(mark)
                Text(title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.weight(.semibold))
            Text(value)
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
                    .fill(next ? AnyShapeStyle(store.theme.gradient) : AnyShapeStyle(Color.primary.opacity(quiet ? 0.04 : 0.08)))
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
        return ([entry.stood ? s.stood : s.didNotStand] + entry.ordered.map { id, n in n > 0 ? s.amount(id, n) : s.none(id) })
            .joined(separator: " · ")
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
            ExercisePicker(store: store)
            Divider()
            Text(s.reminderTitle)
                .font(.headline)
            Picker(s.alertLabel, selection: $store.alertStyle) {
                ForEach(AlertStyle.allCases) { Text(s.alert($0)).tag($0) }
            }
            .frame(maxWidth: 360)
            Text(s.alertHint(store.alertStyle))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.musicTitle)
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)
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
            Text(s.lookTitle)
                .font(.headline)
            HStack(spacing: 10) {
                Text(s.themeLabel)
                ForEach(Theme.allCases) { theme in
                    Button {
                        store.theme = theme
                    } label: {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(store.theme == theme ? 0.9 : 0.15), lineWidth: store.theme == theme ? 2.5 : 1))
                            .padding(3)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(s.theme(theme))
                    .accessibilityLabel(s.theme(theme))
                }
                Spacer(minLength: 0)
                Text(s.theme(store.theme)).font(.caption).foregroundStyle(.secondary)
            }
            Picker(s.appearanceLabel, selection: $store.appearance) {
                ForEach(AppearanceChoice.allCases) { Text(s.appearance($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
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

struct ExercisePicker: View {
    @ObservedObject var store: Store

    var body: some View {
        let s = store.s
        VStack(alignment: .leading, spacing: 10) {
            Text(s.setTitle)
                .font(.headline)
            if store.plan.isEmpty {
                Text(s.onlyStandUp)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.plan) { item in
                if let exercise = item.exercise {
                    HStack(spacing: 10) {
                        Image(systemName: exercise.image)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.color(item.slot))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.name(item.id)).font(.body.weight(.semibold))
                            Text(s.muscles(item.id)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 6)
                        Stepper(value: store.target(item.id), in: exercise.range, step: exercise.step) {
                            Text(s.counter(item.id, item.target))
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                        }
                        .fixedSize()
                        Button {
                            store.removeExercise(item.id)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(s.removeExercise)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Menu {
                ForEach(Exercise.catalog.filter { item in !store.plan.contains { $0.id == item.id } }) { exercise in
                    Button {
                        store.addExercise(exercise.id)
                    } label: {
                        Label("\(s.name(exercise.id)) · \(s.muscles(exercise.id))", systemImage: exercise.image)
                    }
                }
            } label: {
                Label(s.addExercise, systemImage: "plus.circle.fill")
            }
            .fixedSize()
            .disabled(store.plan.count >= Palette.limit)
            Text(s.setHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// The first window a new owner sees: every choice in one place, then the reminders start.
struct SetupView: View {
    @ObservedObject var store: Store

    var body: some View {
        let s = store.s
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(s.welcomeTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(s.welcomeBody)
                    .font(.callout)
                    .opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(store.theme.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            ScrollView {
                SettingsForm(store: store, music: store.music).padding(.trailing, 12)
            }
            .frame(height: 520)
            Button {
                store.finishSetup()
            } label: {
                Label(s.startRise, systemImage: "figure.stand").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(width: 460)
    }
}

// Places its children left to right and wraps them onto new lines when the width runs out.
struct Flow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var line: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += line + lineSpacing
                x = 0
                line = 0
            }
            x += size.width + spacing
            line = max(line, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += line + lineSpacing
                x = bounds.minX
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}
