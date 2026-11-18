# Rise

A macOS menu bar app, open source under MIT, that reminds you to stand up and do a set of home exercises (chosen
from a catalog of 15, up to 7) at a configurable interval in work hours. Each alarm opens a check-in card in one of
four alert styles that stays until it is answered and plays music (macOS's own ringtones or the user's song); every
answer goes to a history with line charts. A first-run setup asks for everything; six color themes. No Dock icon
(`LSUIElement`), no system notifications. Swift 6.1 toolchain from the Command Line Tools (no Xcode), SwiftPM,
AppKit with SwiftUI views and Swift Charts, macOS 14 or later, universal binary (arm64 and x86_64).

## Layout

| Path | What lives there |
| --- | --- |
| `Sources/RiseCore` | Pure and tested with swift-testing: the alarm planner and the history (entries, day totals, the JSON file). |
| `Sources/Rise` | The app: `AppDelegate` (menu bar item and menu), `Store` (state, alarms, check-ins), `Exercise` (catalog, the owner's set, color slots), `CheckInPanel` (card and alert styles), `Look` (themes), `Music`, `Strings` (every visible text in English and Portuguese), `ContentView` (tabs, setup), `HistoryView` (charts and list), `SelfTest`. |
| `Resources/Info.plist` | Bundle id `com.vsssp.rise`, the version, `LSUIElement`. |
| `scripts/make-icon.swift` | Draws the icon. |
| `scripts/build.sh` | Tests, universal app bundle in a temp folder, icon, ad-hoc signature, self-test and the dmg in `dist/`; `--install` swaps `/Applications/Rise.app` and restarts it. |
| `docs/images` | README screenshots, rendered with `--snapshot` and `--snapshot-alert`. |

## Commands

- `swift test` runs the planner and history tests.
- `scripts/build.sh [--install]` builds `dist/Rise-<version>.dmg`, runs the self-test inside the bundle and, with
  `--install`, updates the installed app in place (the owner never reinstalls by hand).
- `swift run Rise --self-test` lays every screen out and walks the check-in and exercise-set rules on scratch data.
- `swift run Rise --snapshot <file.png> [--tab today|history|settings|setup] [--lang en|pt] [--exercises a,b] [--dark]`.
- `swift run Rise --snapshot-alert <file.png> [--kind alarm|manual] [--lang en|pt] [--exercises a,b] [--dark]`.
- `Rise --log pushups=5 situps=7` records a set by hand in the real history; `Rise --ring-test` opens the test card.

## Rules

- The owner allows commits and pushes straight to `main` in this repository (2026-11-17).
- Every new dmg raises `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
- No `Rise.app` stays on disk besides the installed one: Spotlight and Launchpad list every copy.
- The history is `~/Library/Application Support/Rise/history.json`; an unreadable file is moved aside, never overwritten.
  Old files (push-ups and sit-ups as fields) still load.
- The self-test and snapshots use only scratch data: the `com.vsssp.rise.selftest` domain and a temp history file.
- The owner's own set is 5 push-ups and 7 sit-ups (2026-11-18); the catalog default stays 10 and 15.
- Commits are in English, conventional commits, with no AI co-author or attribution trailer.
- A comment is one line of at most 100 characters.
- Every text the user sees lives in `Strings`, in English (the main language) and Brazilian Portuguese.
- A release is a GitHub release `v<version>` with the dmg attached; the README links to the latest one.
