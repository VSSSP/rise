# Rise

A macOS app that reminds the owner to stand up: a notification every 45 minutes, only in work hours. It has a
Dock icon, a window and a Dock menu. Swift 6.1 toolchain from the Command Line Tools (no Xcode), SwiftPM,
AppKit with SwiftUI views, macOS 14 or later.

## Layout

| Path | What lives there |
| --- | --- |
| `Sources/RiseCore` | The alarm planner: pure and tested with swift-testing. |
| `Sources/Rise` | The app: `AppDelegate`, `Store` (state, alarms, notifications, login item), `ContentView`, `SelfTest`. |
| `Resources/Info.plist` | Bundle id `com.vsssp.rise`, the version. |
| `scripts/make-icon.swift` | Draws the icon. |
| `scripts/build.sh` | Tests, app bundle, icon, ad-hoc signature, self-test and the dmg in `dist/`. |

## Commands

- `swift test` runs the planner tests.
- `scripts/build.sh` builds `build/Rise.app` and `dist/Rise-<version>.dmg`.
- `build/Rise.app/Contents/MacOS/Rise --self-test` lays the window out without showing it.
- `build/Rise.app/Contents/MacOS/Rise --snapshot <file.png> [--dark]` renders the window to a picture.

## Rules

- The owner allows commits and pushes straight to `main` in this repository (2026-11-17).
- Every new dmg raises `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
- Commits are in English, conventional commits, with no AI co-author or attribution trailer.
- A comment is one line of at most 100 characters.
- Every text the user sees is in Brazilian Portuguese.
