import AppKit
import Charts
import RiseCore
import SwiftUI

// Exercises that need no equipment; names and muscles live in Strings, in both languages.
struct Exercise: Identifiable, Hashable {
    enum Unit {
        case reps, seconds
    }

    let id: String
    let symbol: String
    let unit: Unit
    let target: Int

    var step: Int { unit == .seconds ? 5 : 1 }
    var range: ClosedRange<Int> { unit == .seconds ? 5...600 : 1...200 }

    var image: String {
        NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil ? "figure.walk" : symbol
    }

    static let catalog: [Exercise] = [
        Exercise(id: "pushups", symbol: "figure.strengthtraining.functional", unit: .reps, target: 10),
        Exercise(id: "situps", symbol: "figure.core.training", unit: .reps, target: 15),
        Exercise(id: "squats", symbol: "figure.cross.training", unit: .reps, target: 15),
        Exercise(id: "lunges", symbol: "figure.step.training", unit: .reps, target: 10),
        Exercise(id: "glutebridges", symbol: "figure.pilates", unit: .reps, target: 12),
        Exercise(id: "calfraises", symbol: "figure.stairs", unit: .reps, target: 20),
        Exercise(id: "dips", symbol: "figure.strengthtraining.traditional", unit: .reps, target: 10),
        Exercise(id: "jumpingjacks", symbol: "figure.mixed.cardio", unit: .reps, target: 20),
        Exercise(id: "burpees", symbol: "figure.highintensity.intervaltraining", unit: .reps, target: 5),
        Exercise(id: "mountainclimbers", symbol: "figure.climbing", unit: .reps, target: 20),
        Exercise(id: "legraises", symbol: "figure.roll", unit: .reps, target: 10),
        Exercise(id: "supermans", symbol: "figure.yoga", unit: .reps, target: 10),
        Exercise(id: "plank", symbol: "figure.barre", unit: .seconds, target: 30),
        Exercise(id: "wallsit", symbol: "figure.cooldown", unit: .seconds, target: 30),
        Exercise(id: "stretch", symbol: "figure.flexibility", unit: .seconds, target: 60),
    ]

    static func find(_ id: String) -> Exercise? {
        catalog.first { $0.id == id }
    }

    static func order(_ id: String) -> Int {
        catalog.firstIndex { $0.id == id } ?? catalog.count
    }
}

// One exercise of the owner's set: how many per reminder and the chart color it keeps.
struct PlanItem: Codable, Equatable, Identifiable {
    var id: String
    var target: Int
    var slot: Int

    var exercise: Exercise? { Exercise.find(id) }
}

// Seven series colors validated for both modes; a distinct shape per slot carries identity too.
enum Palette {
    static let limit = 7
    private static let light: [UInt32] = [0x2A78D6, 0xEB6834, 0x1BAF7A, 0xEDA100, 0xE87BA4, 0x008300, 0xE34948]
    private static let dark: [UInt32] = [0x3987E5, 0xD95926, 0x199E70, 0xC98500, 0xD55181, 0x0CA30C, 0xE66767]

    static func color(_ slot: Int) -> Color {
        let index = min(max(slot, 0), limit - 1)
        return dynamicColor(light: light[index], dark: dark[index])
    }

    static let shapes: [BasicChartSymbolShape] = [.circle, .square, .triangle, .diamond, .pentagon, .plus, .cross]
}

extension Entry {
    // The exercises of this entry in catalog order.
    var ordered: [(String, Int)] {
        counts.sorted { Exercise.order($0.key) < Exercise.order($1.key) }.map { ($0.key, $0.value) }
    }
}
