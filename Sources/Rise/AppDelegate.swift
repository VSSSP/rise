import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let relay = NotificationRelay()
    private var window: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        relay.onAction = { [weak self] action in self?.store.handle(action: action) }
        UNUserNotificationCenter.current().delegate = relay
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        store.start()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        store.refreshSystemState()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let status = NSMenuItem(title: store.dockStatus, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(item("Levantei", #selector(standUp)))
        let skip = item("Pular o próximo", #selector(skipNext))
        skip.isEnabled = store.next != nil
        menu.addItem(skip)
        menu.addItem(item(store.isPausedToday ? "Retomar hoje" : "Pausar hoje", #selector(togglePause)))
        menu.addItem(item("Testar aviso", #selector(test)))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func standUp() { store.standUp() }
    @objc private func skipNext() { store.skipNext() }
    @objc private func togglePause() { store.togglePauseToday() }
    @objc private func test() { store.test() }

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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

final class NotificationRelay: NSObject, UNUserNotificationCenterDelegate {
    var onAction: (@MainActor (String) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        DispatchQueue.main.async { MainActor.assumeIsolated { self.onAction?(action) } }
        completionHandler()
    }
}

@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Sobre o Rise", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ocultar o Rise", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(
            withTitle: "Ocultar Outros", action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Encerrar o Rise", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let windowMenu = NSMenu(title: "Janela")
        windowMenu.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Fechar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let bar = NSMenu()
        for (title, menu) in [("Rise", appMenu), ("Janela", windowMenu)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu
            bar.addItem(item)
        }
        NSApp.windowsMenu = windowMenu
        return bar
    }
}
