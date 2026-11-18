import AppKit
import SwiftUI

// The check-in card: in a corner, in the middle or over a dimmed screen, and it stays until answered.
@MainActor
final class CheckInPanel {
    private let store: Store
    private var panel: NSPanel?
    private var backdrop: NSWindow?
    private var shown: UUID?
    private var played: UUID?
    private var chime: Timer?

    init(store: Store) {
        self.store = store
    }

    func update(_ ring: Ring?) {
        guard let ring else {
            if shown != nil || played != nil { store.music.stop() }
            played = nil
            return hide()
        }
        if played != ring.id {
            played = ring.id
            if ring.kind != .manual { store.playAlarm() }
            scheduleChime(for: ring)
        }
        let style = store.alertStyle
        if style == .discreet, ring.kind == .alarm, !ring.opened { return hide(keepMusic: true) }
        let panel = self.panel ?? make()
        if shown != ring.id {
            shown = ring.id
            let host = FirstClickHostingView(rootView: CheckInView(store: store, ring: ring))
            panel.contentView = host
            panel.setContentSize(host.fittingSize)
        }
        let screen = currentScreen()
        place(panel, style: style, on: screen)
        let dim = style == .fullscreen && ring.kind != .manual
        if dim, let screen { showBackdrop(on: screen) } else { backdrop?.orderOut(nil) }
        let fresh = !panel.isVisible
        if fresh { panel.alphaValue = 0 }
        panel.orderFrontRegardless()
        if fresh {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().alphaValue = 1
            }
        }
    }

    private func hide(keepMusic: Bool = false) {
        if !keepMusic {
            chime?.invalidate()
            chime = nil
        }
        shown = nil
        backdrop?.orderOut(nil)
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard self?.shown == nil else { return }
                panel.orderOut(nil)
            }
        })
    }

    // The music once more three minutes later if an alarm is still waiting for its answer.
    private func scheduleChime(for ring: Ring) {
        chime?.invalidate()
        guard ring.kind == .alarm else { return }
        chime = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.played == ring.id, self.store.ringing?.id == ring.id else { return }
                self.store.playAlarm()
            }
        }
    }

    private func make() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        self.panel = panel
        return panel
    }

    private func showBackdrop(on screen: NSScreen) {
        let window = backdrop ?? {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.6)
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            backdrop = window
            return window
        }()
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
    }

    private func currentScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    private func place(_ panel: NSPanel, style: AlertStyle, on screen: NSScreen?) {
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        if style == .card || style == .discreet {
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 14, y: visible.maxY - size.height - 10))
        } else {
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2 + 40))
        }
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct InkKey: EnvironmentKey {
    static let defaultValue = Theme.sunrise.ink
}

extension EnvironmentValues {
    var ink: Color {
        get { self[InkKey.self] }
        set { self[InkKey.self] = newValue }
    }
}

struct CheckInView: View {
    @ObservedObject var store: Store
    let ring: Ring
    @State private var stood: Bool?
    @State private var answers: [String: Bool] = [:]
    @State private var counts: [String: Int]

    init(store: Store, ring: Ring) {
        self.store = store
        self.ring = ring
        _counts = State(initialValue: Dictionary(store.plan.map { ($0.id, $0.target) }) { first, _ in first })
    }

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            VStack(spacing: 8) {
                row(s.stoodRow, "figure.stand", answer: $stood, exercise: nil)
                ForEach(store.plan) { item in
                    if let exercise = item.exercise {
                        row(s.name(item.id), exercise.image, answer: answer(item.id), exercise: exercise)
                    }
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            footer
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(width: 480)
        .background(store.theme.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
        .environment(\.ink, store.theme.ink)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: ring.kind == .manual ? "square.and.pencil" : "figure.wave")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 50, height: 50)
                .background(.white.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ring.title).font(.title2.weight(.bold))
                    Spacer()
                    Text(Format.clock.string(from: ring.slot))
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .opacity(0.85)
                }
                Text(ring.body)
                    .font(.callout)
                    .opacity(0.95)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func answer(_ id: String) -> Binding<Bool?> {
        Binding(get: { answers[id] }, set: { answers[id] = $0 })
    }

    private func count(_ id: String) -> Binding<Int> {
        Binding(get: { counts[id] ?? 0 }, set: { counts[id] = $0 })
    }

    private func row(_ title: String, _ symbol: String, answer: Binding<Bool?>, exercise: Exercise?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 24)
            Text(title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            if let exercise {
                Counter(value: count(exercise.id), exercise: exercise, label: s.counter(exercise.id, counts[exercise.id] ?? 0))
            }
            Choice(label: s.done, symbol: "checkmark", on: answer.wrappedValue == true) { answer.wrappedValue = true }
            Choice(label: s.notDone, symbol: "xmark", on: answer.wrappedValue == false) {
                answer.wrappedValue = false
            }
        }
        .frame(minHeight: 34)
    }

    private var complete: Bool { stood != nil && store.plan.allSatisfy { answers[$0.id] != nil } }

    private var footer: some View {
        HStack(spacing: 8) {
            if ring.kind == .alarm {
                PanelButton(label: s.snooze, style: .quiet) { store.snooze() }
                PanelButton(label: s.didNothing, style: .quiet) {
                    store.checkIn(stood: false, counts: Dictionary(store.plan.map { ($0.id, 0) }) { first, _ in first })
                }
            } else {
                PanelButton(label: s.cancel, style: .quiet) { store.cancel() }
            }
            Spacer(minLength: 4)
            PanelButton(label: s.save, style: .plain) {
                let done = store.plan.map { ($0.id, answers[$0.id] == true ? counts[$0.id] ?? 0 : 0) }
                store.checkIn(stood: stood == true, counts: Dictionary(done) { first, _ in first })
            }
            .disabled(!complete)
            .opacity(complete ? 1 : 0.45)
            .help(complete ? s.saveHelp : s.markEachLine)
            PanelButton(label: s.allDone, style: .strong) {
                let all = store.plan.map { ($0.id, counts[$0.id] ?? $0.target) }
                store.checkIn(stood: true, counts: Dictionary(all) { first, _ in first })
            }
        }
    }
}

private struct Counter: View {
    @Binding var value: Int
    let exercise: Exercise
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            step("minus") { value = max(exercise.range.lowerBound, value - exercise.step) }
            Text(label)
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
                .frame(minWidth: exercise.unit == .seconds ? 44 : 30)
            step("plus") { value = min(exercise.range.upperBound, value + exercise.step) }
        }
        .padding(2)
        .background(.white.opacity(0.16), in: Capsule())
        .fixedSize()
    }

    private func step(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct Choice: View {
    @Environment(\.ink) private var ink
    let label: String
    let symbol: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 9)
                .frame(height: 28)
                .fixedSize()
                .foregroundStyle(on ? ink : .white)
                .background(Capsule().fill(on ? Color.white : Color.white.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PanelButton: View {
    @Environment(\.ink) private var ink

    enum Style {
        case quiet, plain, strong
    }

    let label: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(style == .quiet ? .medium : .bold))
                .padding(.horizontal, style == .quiet ? 10 : 14)
                .frame(height: 32)
                .foregroundStyle(style == .strong ? ink : .white)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(style == .strong ? Color.white : Color.white.opacity(style == .plain ? 0.26 : 0.12)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
