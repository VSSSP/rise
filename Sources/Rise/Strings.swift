import Foundation

enum Lang: String {
    case en, pt

    var locale: Locale { Locale(identifier: self == .en ? "en_US" : "pt_BR") }
}

enum LanguageChoice: String, CaseIterable {
    case system, en, pt

    var resolved: Lang {
        switch self {
        case .en: return .en
        case .pt: return .pt
        case .system: return Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") == true ? .pt : .en
        }
    }
}

// Every text the user sees, in English (the main language) and Brazilian Portuguese.
struct Strings {
    let lang: Lang

    private func t(_ en: String, _ pt: String) -> String { lang == .en ? en : pt }

    private func count(_ n: Int, _ en: (String, String), _ pt: (String, String)) -> String {
        let pair = lang == .en ? en : pt
        return "\(n) \(n == 1 ? pair.0 : pair.1)"
    }

    func pushups(_ n: Int) -> String { count(n, ("push-up", "push-ups"), ("flexão", "flexões")) }
    func situps(_ n: Int) -> String { count(n, ("sit-up", "sit-ups"), ("abdominal", "abdominais")) }
    func standUps(_ n: Int) -> String { count(n, ("stand-up", "stand-ups"), ("levantada", "levantadas")) }
    func missed(_ n: Int) -> String {
        count(n, ("reminder with no answer", "reminders with no answer"), ("aviso sem resposta", "avisos sem resposta"))
    }

    var tabToday: String { t("Today", "Hoje") }
    var tabHistory: String { t("History", "Histórico") }
    var tabSettings: String { t("Settings", "Ajustes") }
    var section: String { t("Section", "Seção") }

    var pushupsTitle: String { t("Push-ups", "Flexões") }
    var situpsTitle: String { t("Sit-ups", "Abdominais") }
    var standUpsTitle: String { t("Stand-ups", "Levantadas") }
    var stoodRow: String { t("Stood up", "Levantei") }

    var noReminders: String { t("No reminders scheduled", "Sem avisos marcados") }
    var fixHours: String { t("Fix the work hours in Rise", "Ajuste o horário no Rise") }
    func nextReminder(_ time: String, _ when: String) -> String {
        t("Next reminder: \(time) (\(when))", "Próximo aviso: \(time) (\(when))")
    }
    func todaySummary(_ stood: Int, _ pushups: Int, _ situps: Int) -> String {
        "\(t("Today", "Hoje")): \(standUps(stood)) · \(self.pushups(pushups)) · \(self.situps(situps))"
    }

    var alarmTitle: String { t("Time to stand up", "Hora de levantar") }
    var snoozeOver: String {
        t("Snooze is over: stand up and do your set.", "Acabou o adiamento: bora levantar e fazer a série.")
    }
    var manualTitle: String { t("Log a set", "Registrar agora") }
    var manualBody: String { t("Mark what you did outside a reminder.", "Marque o que você fez fora do aviso.") }
    var testTitle: String { t("Rise test", "Teste do Rise") }
    var testBody: String {
        t("This is how the reminder arrives. A test saves nothing.", "É assim que o aviso chega. O teste não grava nada.")
    }
    func messages(_ minutes: Int) -> [String] {
        lang == .en
            ? [
                "\(minutes) minutes sitting. Stand up, do your set and stretch your back.",
                "Up you get: push-ups, sit-ups and a neck stretch.",
                "Stand up, do your set, then drink a glass of water.",
                "Leave the chair: set done and a quick walk to rest your eyes.",
            ]
            : [
                "\(minutes) minutos sentado. Levanta, faz a série e estica as costas.",
                "Bora levantar: flexões, abdominais e um alongamento no pescoço.",
                "Levanta, faz a série e depois bebe um copo d'água.",
                "Sai da cadeira: série feita e uma volta rápida pra descansar a vista.",
            ]
    }
    func unreadableHistory(_ file: String) -> String {
        t("The old history could not be read and was kept in \(file).", "O histórico antigo não abriu e foi guardado em \(file).")
    }
    func saveFailed(_ reason: String) -> String {
        t("Could not save the history: \(reason)", "Não consegui salvar o histórico: \(reason)")
    }
    func musicFailed(_ reason: String) -> String {
        t("Could not use that music file: \(reason)", "Não consegui usar esse arquivo de música: \(reason)")
    }

    func inMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return t("in \(minutes) min", "em \(minutes) min") }
        let rest = String(format: "%02d", minutes % 60)
        return t("in \(minutes / 60) h \(rest) min", "em \(minutes / 60) h \(rest) min")
    }
    var tomorrow: String { t("tomorrow", "amanhã") }

    var menuBarHint: String {
        t(
            "Rise lives in the menu bar, up top. Closing this window does not stop the reminders.",
            "O Rise fica na barra de menus, lá em cima. Fechar esta janela não desliga os avisos.")
    }
    var invalidHoursCaption: String { t("INVALID HOURS", "HORÁRIO INVÁLIDO") }
    var noRemindersCaption: String { t("NO REMINDERS", "SEM AVISOS") }
    var pausedCaption: String { t("PAUSED TODAY · NEXT REMINDER", "PAUSADO HOJE · PRÓXIMO AVISO") }
    var nextCaption: String { t("NEXT REMINDER", "PRÓXIMO AVISO") }
    var intervalDoesNotFit: String {
        t("The interval does not fit between start and end.", "O intervalo não cabe entre o início e o fim.")
    }
    var pickADay: String { t("Pick at least one day in Settings.", "Escolha pelo menos um dia em Ajustes.") }
    func eachReminder(_ pushups: Int, _ situps: Int) -> String {
        t(
            "Each reminder: stand up, \(self.pushups(pushups)) and \(self.situps(situps)).",
            "A cada aviso: levantar, \(self.pushups(pushups)) e \(self.situps(situps)).")
    }

    var todayReminders: String { t("Today's reminders", "Avisos de hoje") }
    var todayRemindersPaused: String { t("Today's reminders (paused)", "Avisos de hoje (pausado)") }
    var slotLegend: String {
        t(
            "✓ answered · ✕ no answer · tap a future time to skip it or bring it back.",
            "✓ respondido · ✕ sem resposta · toque num horário futuro para pular ou voltar a tocar.")
    }
    var bringBack: String { t("Bring it back", "Voltar a tocar") }
    var skipThis: String { t("Skip this one", "Pular este") }
    var noAnswer: String { t("No answer", "Sem resposta") }
    var stood: String { t("stood up", "levantou") }
    var didNotStand: String { t("did not stand", "não levantou") }
    var noPushups: String { t("no push-ups", "sem flexões") }
    var noSitups: String { t("no sit-ups", "sem abdominais") }

    var logNow: String { t("Log a set", "Registrar agora") }
    var skipNext: String { t("Skip the next", "Pular o próximo") }
    var pauseToday: String { t("Pause today", "Pausar hoje") }
    var resumeToday: String { t("Resume today", "Retomar hoje") }
    var testReminder: String { t("Test reminder", "Testar aviso") }

    var workHours: String { t("Work hours", "Expediente") }
    var start: String { t("Start", "Início") }
    var end: String { t("End", "Fim") }
    func every(_ minutes: Int) -> String { t("Remind every \(minutes) min", "Avisar a cada \(minutes) min") }
    var days: [(Int, String)] {
        let names = lang == .en
            ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
        return zip([2, 3, 4, 5, 6, 7, 1], names).map { ($0, $1) }
    }
    var setTitle: String { t("The set of each reminder", "Série de cada aviso") }
    var setHint: String {
        t("You can change the number on the card before marking Done.", "No aviso dá para mudar o número antes de marcar Fiz.")
    }
    var musicTitle: String { t("Reminder music", "Música do aviso") }
    var playMusic: String { t("Play music on the reminder", "Tocar música no aviso") }
    var music: String { t("Music", "Música") }
    var listen: String { t("Listen", "Ouvir") }
    var stop: String { t("Stop", "Parar") }
    var useFile: String { t("Use a file…", "Usar arquivo…") }
    var pickMusic: String { t("Pick a song for the reminder", "Escolha uma música para o aviso") }
    var volume: String { t("Volume", "Volume") }
    var language: String { t("Language", "Idioma") }
    var automatic: String { t("Automatic", "Automático") }
    var openAtLogin: String { t("Open at login", "Abrir ao iniciar a sessão") }
    var needsApproval: String { t("Rise still needs approval in Login Items.", "Falta aprovar o Rise em Itens de Início.") }
    var openSettings: String { t("Open Settings", "Abrir Ajustes") }
    var installFirst: String {
        t("Install Rise in Applications so it can open by itself.", "Instale o Rise em Aplicativos para ele abrir sozinho.")
    }
    var showHistoryFile: String { t("Show the history file", "Mostrar o arquivo do histórico") }

    var chartExercise: String { t("Push-ups and sit-ups per day", "Flexões e abdominais por dia") }
    var chartStandUps: String { t("Stand-ups per day", "Levantadas por dia") }
    var period: String { t("Period", "Período") }
    var sevenDays: String { t("7 days", "7 dias") }
    var thirtyDays: String { t("30 days", "30 dias") }
    var day: String { t("Day", "Dia") }
    var amount: String { t("Count", "Quantidade") }
    var exercise: String { t("Exercise", "Exercício") }
    var entries: String { t("Log", "Registros") }
    var nothingYet: String {
        t("Nothing logged yet. Answer a reminder or use Log a set.", "Nada registrado ainda. Responda um aviso ou use Registrar agora.")
    }
    var deleteQuestion: String { t("Delete this entry?", "Apagar este registro?") }
    var delete: String { t("Delete", "Apagar") }
    var deleteEntry: String { t("Delete entry", "Apagar registro") }
    var fromReminder: String { t("Reminder", "Aviso") }
    var byHand: String { t("Logged by hand", "Registrado à mão") }

    var done: String { t("Done", "Fiz") }
    var notDone: String { t("Not done", "Não fiz") }
    var snooze: String { t("Snooze 5 min", "Adiar 5 min") }
    var didNothing: String { t("Did nothing", "Não fiz nada") }
    var cancel: String { t("Cancel", "Cancelar") }
    var save: String { t("Save", "Salvar") }
    var allDone: String { t("All done", "Fiz tudo") }
    var saveHelp: String { t("Saves what you marked", "Grava o que você marcou") }
    var markEachLine: String { t("Mark Done or Not done on each line", "Marque Fiz ou Não fiz em cada linha") }

    var answerReminder: String { t("Answer the reminder…", "Responder o aviso…") }
    var logNowMenu: String { t("Log a set…", "Registrar agora…") }
    var skipNextReminder: String { t("Skip the next reminder", "Pular o próximo aviso") }
    var openRise: String { t("Open Rise…", "Abrir o Rise…") }
    var quitRise: String { t("Quit Rise", "Sair do Rise") }
    var aboutRise: String { t("About Rise", "Sobre o Rise") }
    var edit: String { t("Edit", "Editar") }
    var copy: String { t("Copy", "Copiar") }
    var paste: String { t("Paste", "Colar") }
    var window: String { t("Window", "Janela") }
    var minimize: String { t("Minimize", "Minimizar") }
    var close: String { t("Close", "Fechar") }
}
