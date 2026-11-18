import AppKit
import SwiftUI

// The color of the cards and highlights; white text sits on every one of them.
enum Theme: String, CaseIterable, Identifiable {
    case sunrise, ocean, forest, grape, graphite, ember

    var id: String { rawValue }

    private var hexes: [UInt32] {
        switch self {
        case .sunrise: return [0x292B6B, 0x9E4085, 0xF26B66, 0xFFA354]
        case .ocean: return [0x0B1F4D, 0x13497B, 0x0E7C8A, 0x2BB3A3]
        case .forest: return [0x0F2A1D, 0x1E4D2B, 0x2F6B3A, 0x6E9E3A]
        case .grape: return [0x2A1043, 0x4B1F6F, 0x7A2C8F, 0xC04F9E]
        case .graphite: return [0x1C1C1E, 0x2C2C2E, 0x3A3A3C, 0x5A5A5F]
        case .ember: return [0x3B0A0A, 0x7A1616, 0xB23A1E, 0xE0702A]
        }
    }

    var colors: [Color] {
        hexes.map { hex in
            Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var ink: Color { colors[0] }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

// How hard a reminder asks for attention.
enum AlertStyle: String, CaseIterable, Identifiable {
    case card, center, fullscreen, discreet

    var id: String { rawValue }
}
