import AppKit
import RiseCore
import ServiceManagement
import UserNotifications

enum LoginState {
    case on, off, needsApproval, unavailable
}

enum Action {
    static let category = "rise.standup"
    static let done = "rise.done"
    static let snooze = "rise.snooze"
}

@MainActor
final class Store: ObservableObject {
    @Published var hours: WorkHours {
        didSet { defaults.set(try? JSONEncoder().encode(hours), forKey: Keys.hours) }
    }
    @Published var sound: Bool {
        didSet { defaults.set(sound, forKey: Keys.sound) }
    }
    @Published private(set) var pausedDay: DayKey?
    @Published private(set) var skipped: Set<Date>
    @Published private(set) var standUps: Int
    @Published private(set) var now = Date()
    @Published private(set) var permission: UNAuthorizationStatus = .notDetermined
    @Published private(set) var login: LoginState = .off

    private let defaults = UserDefaults.standard
    private lazy var center = UNUserNotificationCenter.current()
    private var lastRung: Date?
    private var snoozeUntil: Date?
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var observers: [NSObjectProtocol] = []

    private enum Keys {
        static let hours = "hours"
        static let sound = "sound"
        static let pausedDay = "pausedDay"
        static let skipped = "skipped"
        static let lastRung = "lastRung"
        static let standUps = "standUps"
        static let standUpsDay = "standUpsDay"
        static let loginSetUp = "loginSetUp"
    }

    init() {
        let calendar = Calendar.autoupdatingCurrent
        let data = defaults.data(forKey: Keys.hours)
        hours = data.flatMap { try? JSONDecoder().decode(WorkHours.self, from: $0) } ?? .standard
        sound = defaults.object(forKey: Keys.sound) as? Bool ?? true
        pausedDay = defaults.string(forKey: Keys.pausedDay).map(DayKey.init(rawValue:))
        let midnight = calendar.startOfDay(for: Date())
        let stored = (defaults.array(forKey: Keys.skipped) as? [Double]) ?? []
        skipped = Set(stored.map(Date.init(timeIntervalSince1970:)).filter { $0 >= midnight })
        lastRung = (defaults.object(forKey: Keys.lastRung) as? Double).map(Date.init(timeIntervalSince1970:))
        let today = DayKey(Date(), calendar: calendar).rawValue
        standUps = defaults.string(forKey: Keys.standUpsDay) == today ? defaults.integer(forKey: Keys.standUps) : 0
    }

    var calendar: Calendar { .autoupdatingCurrent }
    var planner: Planner { Planner(hours: hours, calendar: calendar) }
    var today: DayKey { DayKey(now, calendar: calendar) }
    var isPausedToday: Bool { pausedDay == today }
    var next: Date? { planner.upcoming(after: now, pausedDay: pausedDay, skipped: skipped, limit: 1).first }
    var todaySlots: [Date] { planner.slots(on: now) }

    var dockStatus: String {
        guard let next else { return hours.isValid ? "Sem alarmes marcados" : "Ajuste o horário na janela" }
        let when = calendar.isDate(next, inSameDayAs: now) ? "" : " (\(Format.until(next, from: now, calendar: calendar)))"
        return "Próximo alarme: \(Format.clock.string(from: next))\(when)"
    }

    func start() {
        let done = UNNotificationAction(identifier: Action.done, title: "Levantei", options: [])
        let later = UNNotificationAction(identifier: Action.snooze, title: "Adiar 5 min", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Action.category, actions: [done, later], intentIdentifiers: [], options: [])
        ])
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Alarmes para levantar")
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
        Task { await requestPermission() }
        refreshLogin()
        setUpLoginOnce()
        tick()
    }

    func tick() {
        let previousDay = today
        now = Date()
        if today != previousDay { startNewDay() }
        if let until = snoozeUntil, now >= until {
            snoozeUntil = nil
            ring(title: "Hora de levantar", body: "Acabou o adiamento: levanta agora.")
        }
        if let slot = planner.due(at: now, after: lastRung, pausedDay: pausedDay, skipped: skipped) {
            lastRung = slot
            defaults.set(slot.timeIntervalSince1970, forKey: Keys.lastRung)
            ring(title: "Hora de levantar", body: message(for: slot))
        }
    }

    func standUp() {
        if DayKey(now, calendar: calendar).rawValue != defaults.string(forKey: Keys.standUpsDay) { standUps = 0 }
        standUps += 1
        defaults.set(standUps, forKey: Keys.standUps)
        defaults.set(today.rawValue, forKey: Keys.standUpsDay)
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

    func test() {
        ring(title: "Teste do Rise", body: "É assim que o aviso para levantar vai chegar.")
    }

    func handle(action: String) {
        switch action {
        case Action.done: standUp()
        case Action.snooze: snoozeUntil = Date().addingTimeInterval(5 * 60)
        default: break
        }
    }

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshPermission()
    }

    func refreshSystemState() {
        refreshLogin()
        Task { await refreshPermission() }
    }

    func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? "com.vsssp.rise"
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
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

    private func refreshPermission() async {
        permission = await center.notificationSettings().authorizationStatus
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
        standUps = 0
        let midnight = calendar.startOfDay(for: now)
        skipped = skipped.filter { $0 >= midnight }
        defaults.set(skipped.map(\.timeIntervalSince1970), forKey: Keys.skipped)
        if pausedDay != today {
            pausedDay = nil
            defaults.removeObject(forKey: Keys.pausedDay)
        }
    }

    private func ring(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil
        content.categoryIdentifier = Action.category
        content.threadIdentifier = "rise"
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func message(for slot: Date) -> String {
        let lines = [
            "\(hours.interval) minutos sentado. Levanta, estica as costas e anda um pouco.",
            "Bora levantar: alonga o pescoço e os ombros.",
            "Levanta e vai beber um copo d'água.",
            "Dá uma volta rápida e descansa a vista da tela.",
        ]
        let minute = calendar.component(.hour, from: slot) * 60 + calendar.component(.minute, from: slot)
        return lines[(minute / max(hours.interval, 1)) % lines.count]
    }
}

enum Format {
    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static func until(_ date: Date, from now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let minutes = max(1, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
            return minutes < 60 ? "em \(minutes) min" : "em \(minutes / 60) h \(String(format: "%02d", minutes % 60)) min"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "amanhã"
        }
        return weekday.string(from: date)
    }
}
