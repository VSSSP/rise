import AppKit
import Combine
import RiseCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store: Store
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private lazy var checkIn = CheckInPanel(store: store)
    private var watchers: Set<AnyCancellable> = []

    init(store: Store? = nil) {
        self.store = store ?? Store()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(store.s)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.button?.toolTip = "Rise"
        statusItem = item
        store.$ringing
            .sink { [weak self] ring in self?.checkIn.update(ring) }
            .store(in: &watchers)
        Publishers.CombineLatest(store.$ringing, store.$pausedDay)
            .sink { [weak self] ring, paused in self?.paintIcon(ringing: ring != nil, paused: paused) }
            .store(in: &watchers)
        store.start()
        if CommandLine.arguments.contains("--ring-test") { store.test() }
        if !store.welcomed {
            store.welcomed = true
            showWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        store.refreshSystemState()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        store.tick()
        fill(menu)
    }

    func fill(_ menu: NSMenu) {
        let s = store.s
        menu.removeAllItems()
        for line in [store.menuStatus, store.todaySummary] {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        if store.ringing?.kind == .alarm {
            menu.addItem(item(s.answerReminder, #selector(logNow)))
        } else {
            menu.addItem(item(s.logNowMenu, #selector(logNow)))
        }
        let skip = item(s.skipNextReminder, #selector(skipNext))
        skip.isEnabled = store.next != nil
        menu.addItem(skip)
        menu.addItem(item(store.isPausedToday ? s.resumeToday : s.pauseToday, #selector(togglePause)))
        menu.addItem(item(s.testReminder, #selector(test)))
        menu.addItem(.separator())
        menu.addItem(item(s.openRise, #selector(openWindow), key: ","))
        menu.addItem(item(s.quitRise, #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func logNow() { store.logNow() }
    @objc private func skipNext() { store.skipNext() }
    @objc private func togglePause() { store.togglePauseToday() }
    @objc private func test() { store.test() }
    @objc private func openWindow() { showWindow() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func paintIcon(ringing: Bool, paused: DayKey?) {
        guard let button = statusItem?.button else { return }
        let pausedToday = paused == store.today
        let symbol = ringing ? "figure.wave" : (pausedToday ? "moon.zzz" : "figure.stand")
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: ringing ? .bold : .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Rise")?.withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = ringing ? .systemOrange : nil
    }

    private func showWindow() {
        if window == nil {
            let controller = NSHostingController(rootView: ContentView(store: store))
            controller.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: controller)
            window.title = "Rise"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("RiseMain")
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
enum MainMenu {
    static func make(_ s: Strings) -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: s.aboutRise, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: s.quitRise, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editMenu = NSMenu(title: s.edit)
        editMenu.addItem(withTitle: s.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: s.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let windowMenu = NSMenu(title: s.window)
        windowMenu.addItem(withTitle: s.minimize, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: s.close, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let bar = NSMenu()
        for (title, menu) in [("Rise", appMenu), (s.edit, editMenu), (s.window, windowMenu)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu
            bar.addItem(item)
        }
        NSApp.windowsMenu = windowMenu
        return bar
    }
}
