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
        if arguments.contains("--self-test") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.run())
        }
        if let path = value(after: "--snapshot") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.snapshot(to: path, dark: dark, tab: value(after: "--tab") ?? "today"))
        }
        if let path = value(after: "--snapshot-alert") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.snapshotAlert(to: path, dark: dark, kind: value(after: "--kind") ?? "alarm"))
        }
        if let index = arguments.firstIndex(of: "--log"), index + 2 < arguments.count,
            let pushups = Int(arguments[index + 1]), let situps = Int(arguments[index + 2])
        {
            do {
                let day = try Store.log(pushups: pushups, situps: situps)
                print("gravado: hoje \(Format.count(day.stood, "levantada", "levantadas")), \(day.pushups) flexões, \(day.situps) abdominais")
                exit(0)
            } catch {
                print("não gravou: \(error)")
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
