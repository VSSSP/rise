import AVFoundation
import AppKit
import RiseCore
import SwiftUI

// Proves a build starts: lays every screen out and walks the check-in rules on scratch data only.
@MainActor
enum SelfTest {
    static func run() -> Int32 {
        defer { cleanUp() }
        var failures: [String] = []
        func check(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }

        var card = NSSize.zero
        for lang in [Lang.en, .pt] {
            for ids in [["pushups", "situps"], Array(Exercise.catalog.suffix(7).map(\.id))] {
                let store = scratchStore(sample: true, lang: lang, exercises: ids)
                for tab in Tab.allCases {
                    let size = fit(ContentView(store: store, tab: tab))
                    check(size.width <= 461 && size.height > 250, "\(lang) tab \(tab) is \(size)")
                }
                let ring = Ring(kind: .alarm, slot: Date(), title: store.s.alarmTitle, body: store.s.messages(45)[0])
                let size = fit(CheckInView(store: store, ring: ring))
                check(size.width <= 481 && size.height > 200, "\(lang) check-in card is \(size)")
                if ids.count == 2 { card = size }
                let menu = NSMenu()
                let delegate = AppDelegate(store: store)
                delegate.fill(menu)
                let titles = menu.items.map(\.title)
                check(titles.contains(store.s.logNowMenu) && titles.contains(store.s.quitRise), "\(lang) menu is \(titles)")
            }
            let fresh = scratchStore(sample: false, lang: lang, exercises: nil, setUp: false)
            check(!fresh.setupDone, "a new owner skips the setup")
            let setup = fit(ContentView(store: fresh))
            check(setup.width <= 461 && setup.height > 500, "\(lang) setup is \(setup)")
        }
        for exercise in Exercise.catalog {
            check(NSImage(systemSymbolName: exercise.symbol, accessibilityDescription: nil) != nil, "no symbol \(exercise.symbol)")
            check(Strings(lang: .en).name(exercise.id) != exercise.id, "no English name for \(exercise.id)")
            check(Strings(lang: .pt).muscles(exercise.id) != "", "no Portuguese muscles for \(exercise.id)")
        }
        if Bundle.main.bundleIdentifier != nil {
            check(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true, "the Dock icon is on")
        }
        let store = scratchStore(sample: false, lang: .en, exercises: nil)
        let tune = store.tune
        check(tune != nil && (try? AVAudioPlayer(contentsOf: tune!.url)) != nil, "no playable music: \(String(describing: tune))")
        check(Tunes.system.contains { $0.id == Tunes.defaultID }, "the default music is missing")
        failures += rules() + planRules()

        let verdict = failures.isEmpty ? "ok" : "failed: \(failures.joined(separator: "; "))"
        print("self-test \(verdict): check-in \(Int(card.width))x\(Int(card.height))")
        return failures.isEmpty ? 0 : 1
    }

    // The check-in rules: answers recorded, tests never, an unanswered alarm kept as missed.
    private static func rules() -> [String] {
        var failures: [String] = []
        let file = scratchFile(sample: false, exercises: [])
        let store = Store(file: file, lang: .en, defaults: scratchDefaults())
        let base = Calendar.current.date(bySettingHour: 9, minute: 45, second: 0, of: Date())!
        let slot = { (step: Int) in base.addingTimeInterval(Double(step) * 45 * 60) }

        store.present(Ring(kind: .alarm, slot: slot(0), title: "", body: ""))
        store.cancel()
        if store.ringing == nil { failures.append("an alarm closed without an answer") }
        store.checkIn(stood: true, counts: ["pushups": 10, "situps": 15])
        store.present(Ring(kind: .alarm, slot: slot(1), title: "", body: ""))
        store.present(Ring(kind: .alarm, slot: slot(2), title: "", body: ""))
        store.snooze()
        store.present(Ring(kind: .alarm, slot: slot(3), title: "", body: ""))
        store.checkIn(stood: true, counts: ["pushups": 0, "situps": 20])
        store.test()
        store.checkIn(stood: true, counts: ["pushups": 99])
        store.logNow()
        store.checkIn(stood: false, counts: ["squats": 5])

        let saved = (try? file.load())?.entries ?? []
        let alarms = saved.filter { $0.source == .alarm }
        let summary = alarms.map { "\($0.answered ? "a" : "m")\($0.count("pushups"))/\($0.count("situps"))" }
        if summary != ["a10/15", "m0/0", "m0/0", "a0/20"] { failures.append("alarms saved as \(summary)") }
        if saved.filter({ $0.source == .manual }).map({ $0.count("squats") }) != [5] { failures.append("manual log lost") }
        if saved.contains(where: { $0.count("pushups") == 99 }) { failures.append("a test was recorded") }
        if store.ringing != nil { failures.append("a card stayed open") }
        return failures
    }

    // A chosen exercise keeps its color slot; old push-up and sit-up targets carry over.
    private static func planRules() -> [String] {
        var failures: [String] = []
        let defaults = scratchDefaults()
        defaults.set(try? JSONEncoder().encode(["pushups": 5, "situps": 7]), forKey: "targets")
        let store = Store(file: scratchFile(sample: false, exercises: []), lang: .en, defaults: defaults)
        let carried = store.plan.map { "\($0.id):\($0.target):\($0.slot)" }
        if carried != ["pushups:5:0", "situps:7:1"] { failures.append("old targets became \(carried)") }
        store.addExercise("squats")
        store.removeExercise("pushups")
        store.addExercise("plank")
        let slots = store.plan.map { "\($0.id):\($0.slot)" }
        if slots != ["situps:1", "squats:2", "plank:0"] { failures.append("slots are \(slots)") }
        for id in ["lunges", "dips", "burpees", "stretch", "wallsit"] { store.addExercise(id) }
        if store.plan.count != Palette.limit { failures.append("the set grew to \(store.plan.count)") }
        if Set(store.plan.map(\.slot)).count != Palette.limit { failures.append("two exercises share a color") }
        let reloaded = Store(file: scratchFile(sample: false, exercises: []), lang: .en, defaults: defaults)
        if reloaded.plan != store.plan { failures.append("the set was not saved") }
        return failures
    }

    static func snapshot(to path: String, dark: Bool, tab: String, lang: Lang, exercises: [String]?) -> Int32 {
        defer { cleanUp() }
        let pick: Tab = ["history": .history, "settings": .settings][tab] ?? .today
        let store = scratchStore(sample: true, lang: lang, exercises: exercises, setUp: tab != "setup")
        let view = ContentView(store: store, tab: pick).background(Color(nsColor: .windowBackgroundColor))
        return render(view, to: path, dark: dark)
    }

    static func snapshotAlert(to path: String, dark: Bool, kind: String, lang: Lang, exercises: [String]?) -> Int32 {
        defer { cleanUp() }
        let store = scratchStore(sample: true, lang: lang, exercises: exercises)
        let s = store.s
        let ring =
            kind == "manual"
            ? Ring(kind: .manual, slot: Date(), title: s.manualTitle, body: s.manualBody)
            : Ring(kind: .alarm, slot: Date(), title: s.alarmTitle, body: s.messages(45)[0])
        return render(CheckInView(store: store, ring: ring).padding(20), to: path, dark: dark)
    }

    private static func fit<V: View>(_ view: V) -> NSSize {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 460, height: 900)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private static func render<V: View>(_ view: V, to path: String, dark: Bool) -> Int32 {
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 1000), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 1 }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return 1 }
        return (try? png.write(to: URL(fileURLWithPath: path))) == nil ? 1 : 0
    }

    // Settings in one throwaway domain, emptied for every scratch store, never the owner's.
    private static let suite = "com.vsssp.rise.selftest"

    private static func scratchDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private static func cleanUp() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    private static func scratchStore(sample: Bool, lang: Lang, exercises: [String]?, setUp: Bool = true) -> Store {
        let defaults = scratchDefaults()
        if setUp { defaults.set(true, forKey: "setupDone") }
        let ids = exercises ?? ["pushups", "situps"]
        let plan = ids.enumerated().compactMap { index, id in
            Exercise.find(id).map { PlanItem(id: id, target: $0.target, slot: index % Palette.limit) }
        }
        defaults.set(try? JSONEncoder().encode(plan), forKey: "exercises")
        return Store(file: scratchFile(sample: sample, exercises: ids), lang: lang, defaults: defaults)
    }

    // A history file in a temporary folder, never the real one.
    private static func scratchFile(sample: Bool, exercises: [String]) -> HistoryFile {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rise-selftest-\(UUID().uuidString)/history.json")
        let file = HistoryFile(url: url)
        guard sample else { return file }
        let calendar = Calendar.current
        var history = History()
        for back in 0..<9 where back != 3 {
            let day = calendar.date(byAdding: .day, value: -back, to: Date())!
            for (index, hour) in [10, 11, 14, 16].enumerated() where back > 0 || hour <= 11 {
                let at = calendar.date(bySettingHour: hour, minute: 15, second: 0, of: day)!
                if (back + index) % 5 == 4 {
                    history.add(.missed(at: at))
                    continue
                }
                var counts: [String: Int] = [:]
                for (offset, id) in exercises.enumerated() {
                    let skip = (back + index + offset) % 4 == 3
                    counts[id] = skip ? 0 : Exercise.find(id)?.target ?? 10
                }
                history.add(Entry(at: at, source: .alarm, stood: true, counts: counts))
            }
        }
        try? file.save(history)
        return file
    }
}
