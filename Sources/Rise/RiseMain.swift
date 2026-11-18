import AppKit

@main
@MainActor
enum RiseMain {
    static func main() {
        let app = NSApplication.shared
        let arguments = CommandLine.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        let dark = arguments.contains("--dark")
        let lang = value(after: "--lang").flatMap(Lang.init(rawValue:)) ?? .en
        let exercises = value(after: "--exercises").map { $0.split(separator: ",").map(String.init) }
        if arguments.contains("--self-test") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.run())
        }
        if let path = value(after: "--snapshot") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.snapshot(to: path, dark: dark, tab: value(after: "--tab") ?? "today", lang: lang, exercises: exercises))
        }
        if let path = value(after: "--snapshot-alert") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.snapshotAlert(to: path, dark: dark, kind: value(after: "--kind") ?? "alarm", lang: lang, exercises: exercises))
        }
        if let index = arguments.firstIndex(of: "--log") {
            var counts: [String: Int] = [:]
            for pair in arguments[(index + 1)...] where pair.contains("=") {
                let parts = pair.split(separator: "=")
                if parts.count == 2, let value = Int(parts[1]) { counts[String(parts[0])] = value }
            }
            do {
                let day = try Store.log(counts)
                print("saved: today \(day.stood) stand-ups, \(day.counts)")
                exit(0)
            } catch {
                print("not saved: \(error)")
                exit(1)
            }
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
