import AVFoundation
import AppKit
import RiseCore
import SwiftUI

// Proves a build starts: lays every screen out and walks the check-in rules on a scratch history.
@MainActor
enum SelfTest {
    static func run() -> Int32 {
        var failures: [String] = []
        func check(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }

        var card = NSSize.zero
        for lang in [Lang.en, .pt] {
            let store = Store(file: scratchFile(sample: true), lang: lang)
            for tab in Tab.allCases {
                let size = fit(ContentView(store: store, tab: tab))
                check(size.width <= 461 && size.height > 250, "\(lang) tab \(tab) is \(size)")
            }
            let ring = Ring(kind: .alarm, slot: Date(), title: store.s.alarmTitle, body: store.s.messages(45)[0])
            card = fit(CheckInView(store: store, ring: ring))
            check(card.width <= 481 && card.height > 200, "\(lang) check-in card is \(card)")
            let menu = NSMenu()
            let delegate = AppDelegate(store: store)
            delegate.fill(menu)
            let titles = menu.items.map(\.title)
            check(titles.contains(store.s.logNowMenu) && titles.contains(store.s.quitRise), "\(lang) menu is \(titles)")
        }
        let store = Store(file: scratchFile(sample: false), lang: .en)
        let tune = store.tune
        check(tune != nil && (try? AVAudioPlayer(contentsOf: tune!.url)) != nil, "no playable music: \(String(describing: tune))")
        check(Tunes.system.contains { $0.id == Tunes.defaultID }, "the default music is missing")
        if Bundle.main.bundleIdentifier != nil {
            check(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true, "the Dock icon is on")
        }
        let symbols = [
            "figure.stand", "figure.wave", "figure.strengthtraining.functional", "figure.core.training", "moon.zzz",
            "menubar.arrow.up.rectangle", "square.and.pencil",
        ]
        for name in symbols {
            check(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "no symbol \(name)")
        }
        failures += rules()

        let next = store.next.map { Format.clock.string(from: $0) } ?? "none"
        let verdict = failures.isEmpty ? "ok" : "failed: \(failures.joined(separator: "; "))"
        print("self-test \(verdict): check-in \(Int(card.width))x\(Int(card.height)), next alarm \(next)")
        return failures.isEmpty ? 0 : 1
    }

    // The check-in rules: answers recorded, tests never, an unanswered alarm kept as missed.
    private static func rules() -> [String] {
        var failures: [String] = []
        let file = scratchFile(sample: false)
        let store = Store(file: file, lang: .en)
        let base = Calendar.current.date(bySettingHour: 9, minute: 45, second: 0, of: Date())!
        let slot = { (step: Int) in base.addingTimeInterval(Double(step) * 45 * 60) }

        store.present(Ring(kind: .alarm, slot: slot(0), title: "", body: ""))
        store.cancel()
        if store.ringing == nil { failures.append("an alarm closed without an answer") }
        store.checkIn(stood: true, pushups: 10, situps: 15)
        store.present(Ring(kind: .alarm, slot: slot(1), title: "", body: ""))
        store.present(Ring(kind: .alarm, slot: slot(2), title: "", body: ""))
        store.snooze()
        store.present(Ring(kind: .alarm, slot: slot(3), title: "", body: ""))
        store.checkIn(stood: true, pushups: 0, situps: 20)
        store.test()
        store.checkIn(stood: true, pushups: 99, situps: 99)
        store.logNow()
        store.checkIn(stood: false, pushups: 5, situps: 0)

        let saved = (try? file.load())?.entries ?? []
        let alarms = saved.filter { $0.source == .alarm }
        let summary = alarms.map { "\($0.answered ? "a" : "m")\($0.pushups)/\($0.situps)" }
        if summary != ["a10/15", "m0/0", "m0/0", "a0/20"] { failures.append("alarms saved as \(summary)") }
        if saved.filter({ $0.source == .manual }).map(\.pushups) != [5] { failures.append("manual log lost") }
        if saved.contains(where: { $0.pushups == 99 }) { failures.append("a test was recorded") }
        if store.ringing != nil { failures.append("a panel stayed open") }
        return failures
    }

    static func snapshot(to path: String, dark: Bool, tab: String, lang: Lang) -> Int32 {
        let pick: Tab = ["history": .history, "settings": .settings][tab] ?? .today
        let store = Store(file: scratchFile(sample: true), lang: lang)
        let view = ContentView(store: store, tab: pick).background(Color(nsColor: .windowBackgroundColor))
        return render(view, to: path, dark: dark)
    }

    static func snapshotAlert(to path: String, dark: Bool, kind: String, lang: Lang) -> Int32 {
        let store = Store(file: scratchFile(sample: true), lang: lang)
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 900), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 1 }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return 1 }
        return (try? png.write(to: URL(fileURLWithPath: path))) == nil ? 1 : 0
    }

    // A history file in a temporary folder, never the real one.
    private static func scratchFile(sample: Bool) -> HistoryFile {
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
                } else {
                    let skip = (back + index) % 4 == 3
                    history.add(Entry(at: at, source: .alarm, stood: true, pushups: skip ? 0 : 10, situps: 15))
                }
            }
        }
        try? file.save(history)
        return file
    }
}
