import AppKit
import SwiftUI

// A floating card under the menu bar that stays until it is answered, over every Space and app.
@MainActor
final class CheckInPanel {
    private let store: Store
    private var panel: NSPanel?
    private var shown: UUID?
    private var chime: Timer?

    init(store: Store) {
        self.store = store
    }

    func update(_ ring: Ring?) {
        guard let ring else {
            if shown != nil { store.music.stop() }
            return hide()
        }
        let panel = self.panel ?? make()
        if shown != ring.id {
            shown = ring.id
            let host = FirstClickHostingView(rootView: CheckInView(store: store, ring: ring))
            panel.contentView = host
            panel.setContentSize(host.fittingSize)
            if ring.kind != .manual { store.playAlarm() }
            scheduleChime(for: ring)
        }
        place(panel)
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

    private func hide() {
        chime?.invalidate()
        chime = nil
        shown = nil
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
                guard let self, self.shown == ring.id else { return }
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

    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 14, y: visible.maxY - size.height - 10))
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private let ink = Color(red: 0.13, green: 0.14, blue: 0.36)

struct CheckInView: View {
    @ObservedObject var store: Store
    let ring: Ring
    @State private var stood: Bool?
    @State private var didPushups: Bool?
    @State private var didSitups: Bool?
    @State private var pushups: Int
    @State private var situps: Int

    init(store: Store, ring: Ring) {
        self.store = store
        self.ring = ring
        _pushups = State(initialValue: store.targets.pushups)
        _situps = State(initialValue: store.targets.situps)
    }

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            VStack(spacing: 8) {
                row(s.stoodRow, "figure.stand", answer: $stood, count: nil)
                row(s.pushupsTitle, "figure.strengthtraining.functional", answer: $didPushups, count: $pushups)
                row(s.situpsTitle, "figure.core.training", answer: $didSitups, count: $situps)
            }
            .padding(10)
            .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            footer
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(width: 480)
        .background(sunrise, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
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

    private func row(_ title: String, _ symbol: String, answer: Binding<Bool?>, count: Binding<Int>?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 24)
            Text(title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            if let count {
                Counter(value: count)
            }
            Choice(label: s.done, symbol: "checkmark", on: answer.wrappedValue == true) { answer.wrappedValue = true }
            Choice(label: s.notDone, symbol: "xmark", on: answer.wrappedValue == false) {
                answer.wrappedValue = false
            }
        }
        .frame(minHeight: 34)
    }

    private var complete: Bool { stood != nil && didPushups != nil && didSitups != nil }

    private var footer: some View {
        HStack(spacing: 8) {
            if ring.kind == .alarm {
                PanelButton(label: s.snooze, style: .quiet) { store.snooze() }
                PanelButton(label: s.didNothing, style: .quiet) {
                    store.checkIn(stood: false, pushups: 0, situps: 0)
                }
            } else {
                PanelButton(label: s.cancel, style: .quiet) { store.cancel() }
            }
            Spacer(minLength: 4)
            PanelButton(label: s.save, style: .plain) {
                store.checkIn(stood: stood == true, pushups: didPushups == true ? pushups : 0, situps: didSitups == true ? situps : 0)
            }
            .disabled(!complete)
            .opacity(complete ? 1 : 0.45)
            .help(complete ? s.saveHelp : s.markEachLine)
            PanelButton(label: s.allDone, style: .strong) {
                store.checkIn(stood: true, pushups: pushups, situps: situps)
            }
        }
    }
}

private struct Counter: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 0) {
            step("minus") { value = max(1, value - 1) }
            Text("\(value)")
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
                .frame(minWidth: 30)
            step("plus") { value = min(500, value + 1) }
        }
        .padding(2)
        .background(.white.opacity(0.16), in: Capsule())
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
