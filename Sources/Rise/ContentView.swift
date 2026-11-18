import RiseCore
import SwiftUI

enum Tab: String, CaseIterable {
    case today = "Hoje"
    case history = "Histórico"
    case settings = "Ajustes"
}

struct ContentView: View {
    @ObservedObject var store: Store
    @State var tab: Tab = .today

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Seção", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case .today: TodayTab(store: store)
            case .history: HistoryTab(store: store)
            case .settings: SettingsForm(store: store)
            }
            if let problem = store.historyProblem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

let sunrise = LinearGradient(
    colors: [
        Color(red: 0.16, green: 0.17, blue: 0.42), Color(red: 0.62, green: 0.25, blue: 0.52),
        Color(red: 0.95, green: 0.42, blue: 0.40), Color(red: 1.0, green: 0.64, blue: 0.33),
    ],
    startPoint: .topLeading, endPoint: .bottomTrailing)

struct TodayTab: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusCard(store: store)
            TotalsRow(totals: store.todayTotals)
            if !store.todaySlots.isEmpty {
                TodayGrid(store: store)
            }
            Actions(store: store)
            Label("O Rise fica na barra de menus, lá em cima. Fechar esta janela não desliga os avisos.", systemImage: "menubar.arrow.up.rectangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

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
            Text("A cada aviso: levantar, \(store.targets.pushups) flexões e \(store.targets.situps) abdominais.")
                .font(.footnote)
                .opacity(0.85)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(sunrise, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var caption: String {
        guard store.hours.isValid else { return "HORÁRIO INVÁLIDO" }
        guard store.next != nil else { return "SEM AVISOS" }
        return store.isPausedToday ? "PAUSADO HOJE · PRÓXIMO AVISO" : "PRÓXIMO AVISO"
    }

    private var time: String {
        store.next.map { Format.clock.string(from: $0) } ?? "--:--"
    }

    private var detail: String {
        guard store.hours.isValid else { return "O intervalo não cabe entre o início e o fim." }
        guard let next = store.next else { return "Escolha pelo menos um dia em Ajustes." }
        return Format.until(next, from: store.now, calendar: store.calendar)
    }
}

struct TotalsRow: View {
    let totals: DayTotals

    var body: some View {
        HStack(spacing: 10) {
            tile("Levantadas", totals.stood, "figure.stand", nil)
            tile("Flexões", totals.pushups, "figure.strengthtraining.functional", Series.pushups.color)
            tile("Abdominais", totals.situps, "figure.core.training", Series.situps.color)
        }
    }

    private func tile(_ title: String, _ value: Int, _ symbol: String, _ mark: Color?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(mark ?? Color.secondary)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TodayGrid: View {
    @ObservedObject var store: Store
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.isPausedToday ? "Avisos de hoje (pausado)" : "Avisos de hoje")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.todaySlots, id: \.self) { slot in
                    chip(slot)
                }
            }
            Text("✓ respondido · ✕ sem resposta · toque num horário futuro para pular ou voltar a tocar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ slot: Date) -> some View {
        let past = slot <= store.now
        let skipped = store.skipped.contains(slot)
        let next = slot == store.next
        let quiet = past || skipped || store.isPausedToday
        let entry = store.history.alarmEntry(at: slot)
        return Button {
            store.toggleSkip(slot)
        } label: {
            HStack(spacing: 4) {
                Text(Format.clock.string(from: slot))
                    .monospacedDigit()
                    .strikethrough(skipped)
                if let entry {
                    Image(systemName: entry.answered ? "checkmark" : "xmark")
                        .font(.caption2.weight(.bold))
                }
            }
            .font(.system(.callout, design: .rounded).weight(next ? .bold : .regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(next ? Color.white : (quiet && entry == nil ? Color.secondary : Color.primary))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(next ? AnyShapeStyle(sunrise) : AnyShapeStyle(Color.primary.opacity(quiet ? 0.04 : 0.08)))
            )
        }
        .buttonStyle(.plain)
        .disabled(past)
        .help(help(entry, skipped))
    }

    private func help(_ entry: Entry?, _ skipped: Bool) -> String {
        guard let entry else { return skipped ? "Voltar a tocar" : "Pular este" }
        guard entry.answered else { return "Ficou sem resposta" }
        return "\(entry.stood ? "Levantou" : "Não levantou") · \(entry.pushups) flexões · \(entry.situps) abdominais"
    }
}

struct Actions: View {
    @ObservedObject var store: Store

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Button {
                    store.logNow()
                } label: {
                    Label("Registrar agora", systemImage: "square.and.pencil").frame(maxWidth: .infinity)
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
            Divider()
            Text("Série de cada aviso")
                .font(.headline)
            Stepper(value: $store.targets.pushups, in: 1...200) {
                Text("\(store.targets.pushups) flexões")
            }
            Stepper(value: $store.targets.situps, in: 1...200) {
                Text("\(store.targets.situps) abdominais")
            }
            Text("No aviso dá para mudar o número antes de marcar Fiz.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Toggle("Tocar som no aviso", isOn: $store.sound)
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
            Button("Mostrar o arquivo do histórico") { store.openHistoryFolder() }
                .controlSize(.small)
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
