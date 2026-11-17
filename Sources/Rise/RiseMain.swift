import AppKit

@main
@MainActor
enum RiseMain {
    static func main() {
        let app = NSApplication.shared
        let arguments = CommandLine.arguments
        if arguments.contains("--self-test") {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.run())
        }
        if let flag = arguments.firstIndex(of: "--snapshot"), flag + 1 < arguments.count {
            app.setActivationPolicy(.prohibited)
            exit(SelfTest.snapshot(to: arguments[flag + 1], dark: arguments.contains("--dark")))
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
