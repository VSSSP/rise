import AppKit
import SwiftUI

// Lays the window out once without showing it, so a build can prove the bundle starts.
@MainActor
enum SelfTest {
    static func run() -> Int32 {
        let store = Store()
        let host = NSHostingView(rootView: ContentView(store: store))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 800)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let ok = size.width >= 380 && size.height > 300 && Bundle.main.bundleIdentifier != nil
        let next = store.next.map { Format.clock.string(from: $0) } ?? "none"
        print("self-test \(ok ? "ok" : "failed"): view \(Int(size.width))x\(Int(size.height)), next alarm \(next)")
        return ok ? 0 : 1
    }

    static func snapshot(to path: String, dark: Bool) -> Int32 {
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let view = ContentView(store: Store()).background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 800), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.setFrameSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 1 }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return 1 }
        return (try? png.write(to: URL(fileURLWithPath: path))) == nil ? 1 : 0
    }
}
