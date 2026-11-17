import RiseCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatusCard(store: store)
            if !store.todaySlots.isEmpty {
                TodayGrid(store: store)
            }
            Actions(store: store)
            Divider()
            SettingsForm(store: store)
            if store.permission == .denied || store.permission == .notDetermined {
                PermissionNote(store: store)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

private let sunrise = LinearGradient(
    colors: [
        Color(red: 0.16, green: 0.17, blue: 0.42), Color(red: 0.62, green: 0.25, blue: 0.52),
        Color(red: 0.95, green: 0.42, blue: 0.40), Color(red: 1.0, green: 0.64, blue: 0.33),
    ],
    startPoint: .topLeading, endPoint: .bottomTrailing)

struct StatusCard: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .opacity(0.85)
            Text(time)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.callout)
                .opacity(0.92)
            Text(tally)
                .font(.footnote)
                .opacity(0.8)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(sunrise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var caption: String {
        guard store.hours.isValid else { return "HORÁRIO INVÁLIDO" }
        guard store.next != nil else { return "SEM ALARMES" }
        return store.isPausedToday ? "PAUSADO HOJE · PRÓXIMO ALARME" : "PRÓXIMO ALARME"
    }

    private var time: String {
        store.next.map { Format.clock.string(from: $0) } ?? "--:--"
    }

    private var detail: String {
        guard store.hours.isValid else { return "O intervalo não cabe entre o início e o fim." }
        guard let next = store.next else { return "Escolha pelo menos um dia abaixo." }
        return Format.until(next, from: store.now, calendar: store.calendar)
    }

    private var tally: String {
        switch store.standUps {
        case 0: return "Toque em Levantei quando levantar."
        case 1: return "1 levantada hoje"
        default: return "\(store.standUps) levantadas hoje"
        }
    }
}

struct TodayGrid: View {
    @ObservedObject var store: Store
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.isPausedToday ? "Hoje (pausado)" : "Hoje")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.todaySlots, id: \.self) { slot in
                    chip(slot)
                }
            }
            Text("Toque num horário para pular ou voltar a tocar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ slot: Date) -> some View {
        let past = slot <= store.now
        let skipped = store.skipped.contains(slot)
        let next = slot == store.next
        let quiet = past || skipped || store.isPausedToday
        return Button {
            store.toggleSkip(slot)
        } label: {
            Text(Format.clock.string(from: slot))
                .font(.system(.callout, design: .rounded).weight(next ? .bold : .regular))
                .monospacedDigit()
                .strikethrough(skipped)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(next ? Color.white : (quiet ? Color.secondary : Color.primary))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(next ? AnyShapeStyle(sunrise) : AnyShapeStyle(Color.primary.opacity(quiet ? 0.04 : 0.08)))
                )
        }
        .buttonStyle(.plain)
        .disabled(past)
        .help(skipped ? "Voltar a tocar" : "Pular este")
    }
}

struct Actions: View {
    @ObservedObject var store: Store

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Button {
                    store.standUp()
                } label: {
                    Label("Levantei", systemImage: "figure.stand").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                Button {
                    store.skipNext()
                } label: {
                    Label("Pular o próximo", systemImage: "forward.end").frame(maxWidth: .infinity)
                }
                .disabled(store.next == nil)
            }
            GridRow {
                Button {
                    store.togglePauseToday()
                } label: {
                    Label(
                        store.isPausedToday ? "Retomar hoje" : "Pausar hoje",
                        systemImage: store.isPausedToday ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                Button {
                    store.test()
                } label: {
                    Label("Testar aviso", systemImage: "bell").frame(maxWidth: .infinity)
                }
            }
        }
        .controlSize(.large)
    }
}

struct SettingsForm: View {
    @ObservedObject var store: Store
    private let days = [(2, "Seg"), (3, "Ter"), (4, "Qua"), (5, "Qui"), (6, "Sex"), (7, "Sáb"), (1, "Dom")]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expediente")
                .font(.headline)
            HStack {
                DatePicker("Início", selection: minutes(\.start), displayedComponents: .hourAndMinute)
                Spacer()
                DatePicker("Fim", selection: minutes(\.end), displayedComponents: .hourAndMinute)
            }
            Stepper(value: $store.hours.interval, in: 15...120, step: 5) {
                Text("Avisar a cada \(store.hours.interval) min")
            }
            HStack(spacing: 6) {
                ForEach(days, id: \.0) { day, name in
                    Toggle(name, isOn: weekday(day))
                        .toggleStyle(.button)
                }
            }
            Toggle("Tocar som", isOn: $store.sound)
            Toggle("Abrir ao iniciar a sessão", isOn: loginBinding)
                .disabled(store.login == .unavailable)
            switch store.login {
            case .needsApproval:
                HStack {
                    Text("Falta aprovar o Rise em Itens de Início.")
                        .font(.caption)
                    Button("Abrir Ajustes") { store.openLoginSettings() }
                        .controlSize(.small)
                }
            case .unavailable:
                Text("Instale o Rise em Aplicativos para ele abrir sozinho.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(get: { store.login == .on || store.login == .needsApproval }, set: { store.setLogin($0) })
    }

    private func minutes(_ key: WritableKeyPath<WorkHours, Int>) -> Binding<Date> {
        Binding(
            get: {
                let value = store.hours[keyPath: key]
                return store.calendar.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: store.now)
                    ?? store.now
            },
            set: { date in
                let parts = store.calendar.dateComponents([.hour, .minute], from: date)
                store.hours[keyPath: key] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }

    private func weekday(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { store.hours.weekdays.contains(day) },
            set: { on in
                if on { store.hours.weekdays.insert(day) } else { store.hours.weekdays.remove(day) }
            })
    }
}

struct PermissionNote: View {
    @ObservedObject var store: Store

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    store.permission == .denied
                        ? "As notificações do Rise estão bloqueadas." : "O Rise ainda não pode mandar notificações."
                )
                .font(.callout)
                Button(store.permission == .denied ? "Abrir Ajustes de Notificações" : "Permitir notificações") {
                    if store.permission == .denied {
                        store.openNotificationSettings()
                    } else {
                        Task { await store.requestPermission() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
