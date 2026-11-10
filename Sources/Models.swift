import Foundation
import SwiftUI

enum PalettePreset: String, CaseIterable, Codable, Identifiable {
    case ionBloom = "Ion Bloom"
    case roseQuartz = "Rose Quartz"
    case solarFlare = "Solar Flare"
    case acidGlass = "Acid Glass"

    var id: String { rawValue }
    var primary: Color {
        switch self {
        case .ionBloom: return Color(hex: 0x6CEBFF)
        case .roseQuartz: return Color(hex: 0xFF69C8)
        case .solarFlare: return Color(hex: 0xAB38FF)
        case .acidGlass: return Color(hex: 0xA7F77C)
        }
    }
    var secondary: Color {
        switch self {
        case .ionBloom: return Color(hex: 0xAE83FF)
        case .roseQuartz: return Color(hex: 0x71E9C6)
        case .solarFlare: return Color(hex: 0xFFD04A)
        case .acidGlass: return Color(hex: 0xF44378)
        }
    }
    var descriptor: String {
        switch self {
        case .ionBloom: return "electric blue / cyan"
        case .roseQuartz: return "rose pink / lilac"
        case .solarFlare: return "violet / gold"
        case .acidGlass: return "acid green / teal"
        }
    }
}

enum WakePreset: String, CaseIterable, Codable, Identifiable {
    case softBoot = "Soft Boot"
    case prismWake = "Prism Wake"
    case orbitSync = "Orbit Sync"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .softBoot: return "Jack"
        case .prismWake: return "Shatter"
        case .orbitSync: return "Wake"
        }
    }
    var detail: String {
        switch self {
        case .softBoot: return "A quick, playful entrance."
        case .prismWake: return "A brief shard of color static."
        case .orbitSync: return "A bright ring locks in."
        }
    }
}

struct AppSettings: Codable {
    var userName = ""
    var palette: PalettePreset = .ionBloom
    var wake: WakePreset = .softBoot
    var speakingStyle = "Warm deadpan"
    var mood = "Curious"
    var humor = 0.62
    var friendliness = 0.74
    var sass = 0.38
    var proactivity = 0.36
    var checkInMinutes = 30
    var quietMode = false
    var model = "gemma4:e4b"
    var voiceInput = false
    var spokenReplies = false
    var voiceIdentifier = ""
    var screenCommentaryEnabled = false
    var screenCommentaryMinutes = 15

    private enum CodingKeys: String, CodingKey {
        case userName, palette, wake, speakingStyle, mood, humor, friendliness, sass
        case proactivity, checkInMinutes, quietMode, model, voiceInput, spokenReplies
        case voiceIdentifier, screenCommentaryEnabled, screenCommentaryMinutes
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        userName = try values.decodeIfPresent(String.self, forKey: .userName) ?? ""
        palette = try values.decodeIfPresent(PalettePreset.self, forKey: .palette) ?? .ionBloom
        wake = try values.decodeIfPresent(WakePreset.self, forKey: .wake) ?? .softBoot
        speakingStyle = try values.decodeIfPresent(String.self, forKey: .speakingStyle) ?? "Warm deadpan"
        mood = try values.decodeIfPresent(String.self, forKey: .mood) ?? "Curious"
        humor = try values.decodeIfPresent(Double.self, forKey: .humor) ?? 0.62
        friendliness = try values.decodeIfPresent(Double.self, forKey: .friendliness) ?? 0.74
        sass = try values.decodeIfPresent(Double.self, forKey: .sass) ?? 0.38
        proactivity = try values.decodeIfPresent(Double.self, forKey: .proactivity) ?? 0.36
        checkInMinutes = try values.decodeIfPresent(Int.self, forKey: .checkInMinutes) ?? 30
        quietMode = try values.decodeIfPresent(Bool.self, forKey: .quietMode) ?? false
        model = try values.decodeIfPresent(String.self, forKey: .model) ?? "gemma4:e4b"
        voiceInput = try values.decodeIfPresent(Bool.self, forKey: .voiceInput) ?? false
        spokenReplies = try values.decodeIfPresent(Bool.self, forKey: .spokenReplies) ?? false
        voiceIdentifier = try values.decodeIfPresent(String.self, forKey: .voiceIdentifier) ?? ""
        screenCommentaryEnabled = try values.decodeIfPresent(Bool.self, forKey: .screenCommentaryEnabled) ?? false
        screenCommentaryMinutes = try values.decodeIfPresent(Int.self, forKey: .screenCommentaryMinutes) ?? 15
    }
}

struct MemoryItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: MessageRole
    var text: String
    var date = Date()
    var isCheckIn = false
}

enum MainPage {
    case companion
    case mainframe
}

enum OllamaState: Equatable {
    case checking
    case connected
    case missingModel
    case unavailable(String)

    var shortTitle: String {
        switch self {
        case .checking: return "LINKING"
        case .connected: return "LOCAL LINK OK"
        case .missingModel: return "MODEL NOT FOUND"
        case .unavailable: return "OLLAMA OFFLINE"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

enum LocalStore {
    private static let defaults = UserDefaults.standard

    static func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data) else { return fallback }
        return value
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
