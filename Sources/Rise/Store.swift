import AppKit
import RiseCore
import ServiceManagement
import UniformTypeIdentifiers

enum LoginState {
    case on, off, needsApproval, unavailable
}

struct Targets: Codable, Equatable {
    var pushups = 10
    var situps = 15
}

// What the check-in card is asking about: an alarm, a log by hand, or a test that records nothing.
struct Ring: Equatable, Identifiable {
    enum Kind: Equatable {
        case alarm, manual, test
    }

    var id = UUID()
    var kind: Kind
    var slot: Date
    var title: String
    var body: String
}

@MainActor
final class Store: ObservableObject {
    @Published var hours: WorkHours {
        didSet { defaults.set(try? JSONEncoder().encode(hours), forKey: Keys.hours) }
    }
    @Published var targets: Targets {
        didSet { defaults.set(try? JSONEncoder().encode(targets), forKey: Keys.targets) }
    }
    @Published var sound: Bool {
        didSet { defaults.set(sound, forKey: Keys.sound) }
    }
    @Published var tuneID: String {
        didSet {
            defaults.set(tuneID, forKey: Keys.tune)
            if music.isPlaying { previewTune(restart: true) }
        }
    }
    @Published var volume: Double {
        didSet {
            defaults.set(volume, forKey: Keys.volume)
            music.setVolume(Float(volume))
        }
    }
    @Published var language: LanguageChoice {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }
    @Published private(set) var pausedDay: DayKey?
    @Published private(set) var skipped: Set<Date>
    @Published private(set) var now = Date()
    @Published private(set) var login: LoginState = .off
    @Published private(set) var history = History()
    @Published private(set) var problem: String?
    @Published private(set) var ringing: Ring?

    let music = MusicPlayer()
    private let defaults = UserDefaults.standard
    private let file: HistoryFile
    private let forcedLang: Lang?
    private var lastRung: Date?
    private var snoozed: (ring: Ring, until: Date)?
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var observers: [NSObjectProtocol] = []

    private enum Keys {
        static let hours = "hours"
        static let targets = "targets"
        static let sound = "sound"
        static let tune = "tune"
        static let volume = "volume"
        static let language = "language"
        static let pausedDay = "pausedDay"
        static let skipped = "skipped"
        static let lastRung = "lastRung"
        static let loginSetUp = "loginSetUp"
        static let welcomed = "welcomedMenuBar"
    }

    init(file: HistoryFile = .standard, lang: Lang? = nil) {
        self.file = file
        forcedLang = lang
        let calendar = Calendar.autoupdatingCurrent
        hours = defaults.data(forKey: Keys.hours).flatMap { try? JSONDecoder().decode(WorkHours.self, from: $0) }
            ?? .standard
        targets = defaults.data(forKey: Keys.targets).flatMap { try? JSONDecoder().decode(Targets.self, from: $0) }
            ?? Targets()
        sound = defaults.object(forKey: Keys.sound) as? Bool ?? true
        tuneID = defaults.string(forKey: Keys.tune) ?? Tunes.defaultID
        volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.7
        language = defaults.string(forKey: Keys.language).flatMap(LanguageChoice.init(rawValue:)) ?? .system
        pausedDay = defaults.string(forKey: Keys.pausedDay).map(DayKey.init(rawValue:))
        let midnight = calendar.startOfDay(for: Date())
        let stored = (defaults.array(forKey: Keys.skipped) as? [Double]) ?? []
        skipped = Set(stored.map(Date.init(timeIntervalSince1970:)).filter { $0 >= midnight })
        lastRung = (defaults.object(forKey: Keys.lastRung) as? Double).map(Date.init(timeIntervalSince1970:))
        loadHistory()
    }

    var lang: Lang { forcedLang ?? language.resolved }
    var s: Strings { Strings(lang: lang) }
    var calendar: Calendar { .autoupdatingCurrent }
    var planner: Planner { Planner(hours: hours, calendar: calendar) }
    var today: DayKey { DayKey(now, calendar: calendar) }
    var isPausedToday: Bool { pausedDay == today }
    var next: Date? { planner.upcoming(after: now, pausedDay: pausedDay, skipped: skipped, limit: 1).first }
    var todaySlots: [Date] { planner.slots(on: now) }
    var todayTotals: DayTotals { history.totals(on: now, calendar: calendar) }
    var tunes: [Tune] { Tunes.custom + Tunes.system }
    var tune: Tune? {
        let all = tunes
        return all.first { $0.id == tuneID } ?? all.first { $0.id == Tunes.defaultID } ?? all.first
    }
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }

    var welcomed: Bool {
        get { defaults.bool(forKey: Keys.welcomed) }
        set { defaults.set(newValue, forKey: Keys.welcomed) }
    }

    var menuStatus: String {
        guard let next else { return hours.isValid ? s.noReminders : s.fixHours }
        return s.nextReminder(Format.clock.string(from: next), Format.until(next, from: now, calendar: calendar, s))
    }

    var todaySummary: String {
        let day = todayTotals
        return s.todaySummary(day.stood, day.pushups, day.situps)
    }

    func start() {
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Stand-up reminders")
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            })
        observers.append(
            NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            })
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 2
        refreshLogin()
        setUpLoginOnce()
        tick()
    }

    func tick() {
        let previousDay = today
        now = Date()
        if today != previousDay { startNewDay() }
        if let snoozed, now >= snoozed.until {
            self.snoozed = nil
            var ring = snoozed.ring
            ring.id = UUID()
            ring.body = s.snoozeOver
            present(ring)
        }
        if let slot = planner.due(at: now, after: lastRung, pausedDay: pausedDay, skipped: skipped) {
            lastRung = slot
            defaults.set(slot.timeIntervalSince1970, forKey: Keys.lastRung)
            present(Ring(kind: .alarm, slot: slot, title: s.alarmTitle, body: message(for: slot)))
        }
    }

    // Records the answer of the open card; a test records nothing.
    func checkIn(stood: Bool, pushups: Int, situps: Int) {
        guard let ring = ringing else { return }
        switch ring.kind {
        case .alarm:
            record(Entry(at: ring.slot, source: .alarm, stood: stood, pushups: pushups, situps: situps))
        case .manual:
            record(Entry(at: Date(), source: .manual, stood: stood, pushups: pushups, situps: situps))
        case .test:
            break
        }
        ringing = nil
    }

    func snooze() {
        guard let ring = ringing else { return }
        if ring.kind == .alarm { snoozed = (ring, Date().addingTimeInterval(5 * 60)) }
        ringing = nil
    }

    // Closes a manual log or a test; an alarm only closes with an answer or a snooze.
    func cancel() {
        guard let ring = ringing, ring.kind != .alarm else { return }
        ringing = nil
    }

    func logNow() {
        if let ringing, ringing.kind == .alarm { return present(ringing) }
        present(Ring(kind: .manual, slot: Date(), title: s.manualTitle, body: s.manualBody))
    }

    func test() {
        if let ringing, ringing.kind == .alarm { return present(ringing) }
        present(Ring(kind: .test, slot: Date(), title: s.testTitle, body: s.testBody))
    }

    func playAlarm() {
        guard sound else { return }
        music.play(tune?.url, volume: Float(volume), seconds: 45, loop: true)
    }

    func previewTune(restart: Bool = false) {
        if music.isPlaying && !restart { return music.stop() }
        music.play(tune?.url, volume: Float(volume), seconds: 15, loop: false)
    }

    func chooseTuneFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.message = s.pickMusic
        NSApp.activate()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.adoptTune(url) }
        }
    }

    func remove(_ entry: Entry) {
        history.remove(id: entry.id)
        saveHistory()
    }

    func skipNext() {
        guard let next else { return }
        toggleSkip(next)
    }

    func toggleSkip(_ slot: Date) {
        if skipped.contains(slot) {
            skipped.remove(slot)
        } else if slot > now {
            skipped.insert(slot)
        }
        defaults.set(skipped.map(\.timeIntervalSince1970), forKey: Keys.skipped)
    }

    func togglePauseToday() {
        pausedDay = isPausedToday ? nil : today
        defaults.set(pausedDay?.rawValue, forKey: Keys.pausedDay)
    }

    func refreshSystemState() {
        refreshLogin()
    }

    func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Rise: login item: \(error.localizedDescription)")
        }
        refreshLogin()
    }

    func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func openHistoryFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    // Appends one log straight to the file; used by the command line before the app runs.
    static func log(pushups: Int, situps: Int, file: HistoryFile = .standard) throws -> DayTotals {
        var history = try file.load()
        history.add(Entry(at: Date(), source: .manual, stood: true, pushups: pushups, situps: situps))
        try file.save(history)
        return history.totals(on: Date(), calendar: .autoupdatingCurrent)
    }

    func present(_ ring: Ring) {
        if let current = ringing, current.kind == .alarm, current.slot != ring.slot {
            record(.missed(at: current.slot))
        }
        if let held = snoozed, held.ring.slot != ring.slot, ring.kind == .alarm {
            snoozed = nil
            record(.missed(at: held.ring.slot))
        }
        ringing = ring
    }

    private func adoptTune(_ url: URL) {
        do {
            let copy = try Tunes.copyIn(url)
            tuneID = "file:\(copy.lastPathComponent)"
            previewTune(restart: true)
        } catch {
            problem = s.musicFailed(error.localizedDescription)
        }
    }

    private func record(_ entry: Entry) {
        history.add(entry)
        saveHistory()
    }

    private func loadHistory() {
        do {
            history = try file.load()
        } catch {
            let aside = try? file.setAside()
            history = History()
            problem = s.unreadableHistory(aside?.lastPathComponent ?? "history-unreadable")
        }
    }

    private func saveHistory() {
        do {
            try file.save(history)
        } catch {
            problem = s.saveFailed(error.localizedDescription)
        }
    }

    private func refreshLogin() {
        switch SMAppService.mainApp.status {
        case .enabled: login = .on
        case .requiresApproval: login = .needsApproval
        case .notRegistered: login = isInstalled ? .off : .unavailable
        default: login = .unavailable
        }
    }

    private var isInstalled: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    private func setUpLoginOnce() {
        guard isInstalled, !defaults.bool(forKey: Keys.loginSetUp) else { return }
        defaults.set(true, forKey: Keys.loginSetUp)
        setLogin(true)
    }

    private func startNewDay() {
        let midnight = calendar.startOfDay(for: now)
        skipped = skipped.filter { $0 >= midnight }
        defaults.set(skipped.map(\.timeIntervalSince1970), forKey: Keys.skipped)
        if pausedDay != today {
            pausedDay = nil
            defaults.removeObject(forKey: Keys.pausedDay)
        }
    }

    private func message(for slot: Date) -> String {
        let lines = s.messages(hours.interval)
        let minute = calendar.component(.hour, from: slot) * 60 + calendar.component(.minute, from: slot)
        return lines[(minute / max(hours.interval, 1)) % lines.count]
    }
}

enum Format {
    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func formatter(_ lang: Lang, _ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = lang.locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    static func weekday(_ date: Date, _ lang: Lang) -> String {
        formatter(lang, "EEEE").string(from: date)
    }

    static func dayTitle(_ date: Date, _ lang: Lang) -> String {
        sentence(formatter(lang, "EEEEdMMMM").string(from: date))
    }

    static func sentence(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    static func until(_ date: Date, from now: Date, calendar: Calendar, _ s: Strings) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return s.inMinutes(max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up))))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return s.tomorrow
        }
        return weekday(date, s.lang)
    }
}
