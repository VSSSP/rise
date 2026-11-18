# Rise

A macOS menu bar app that reminds the owner to stand up and do a set (push-ups and sit-ups) every 45 minutes in
work hours. Each alarm opens a floating check-in card that stays until it is answered, and every answer goes to a
history with charts. No Dock icon (`LSUIElement`), no system notifications. Swift 6.1 toolchain from the Command
Line Tools (no Xcode), SwiftPM, AppKit with SwiftUI views and Swift Charts, macOS 14 or later.

## Layout

| Path | What lives there |
| --- | --- |
| `Sources/RiseCore` | Pure and tested with swift-testing: the alarm planner and the history (entries, day totals, the JSON file). |
| `Sources/Rise` | The app: `AppDelegate` (menu bar item and menu), `Store` (state, alarms, check-ins), `CheckInPanel`, `ContentView` (tabs), `HistoryView` (charts and list), `SelfTest`. |
| `Resources/Info.plist` | Bundle id `com.vsssp.rise`, the version, `LSUIElement`. |
| `scripts/make-icon.swift` | Draws the icon. |
| `scripts/build.sh` | Tests, app bundle in a temp folder, icon, ad-hoc signature, self-test and the dmg in `dist/`. |

## Commands

- `swift test` runs the planner and history tests.
- `scripts/build.sh` builds `dist/Rise-<version>.dmg` and runs the self-test inside the bundle.
- `swift run Rise --self-test` lays every screen out and walks the check-in rules on a scratch history.
- `swift run Rise --snapshot <file.png> [--tab today|history|settings] [--dark]` renders the window with sample data.
- `swift run Rise --snapshot-alert <file.png> [--kind alarm|manual] [--dark]` renders the check-in card.
- `Rise --log <push-ups> <sit-ups>` records a set by hand in the real history; `Rise --ring-test` opens the test card.

## Rules

- The owner allows commits and pushes straight to `main` in this repository (2026-11-17).
- Every new dmg raises `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
- No `Rise.app` stays on disk besides the installed one: Spotlight and Launchpad list every copy.
- The history is `~/Library/Application Support/Rise/history.json`; an unreadable file is moved aside, never overwritten.
- Commits are in English, conventional commits, with no AI co-author or attribution trailer.
- A comment is one line of at most 100 characters.
- Every text the user sees is in Brazilian Portuguese.
