//
//  AppSettings.swift — user-facing presentation settings (PROMPT 007C)
//  Language (System / Türkçe / English) + Developer Mode (hides engineering/raw-reason-code UI by default).
//  Internal canonical reason codes are NOT affected — only presentation.
//
import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Sendable {
    case system = "SYSTEM", turkish = "tr", english = "en"
    var displayName: String {
        switch self {
        case .system: return String(localized: "System Default")
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
    var localeOverride: Locale? {
        switch self {
        case .system: return nil
        case .turkish: return Locale(identifier: "tr")
        case .english: return Locale(identifier: "en")
        }
    }
}

@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()
    private let langKey = "gen8.language"
    private let devKey = "gen8.developerMode"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: langKey) }
    }
    var developerMode: Bool {
        didSet { UserDefaults.standard.set(developerMode, forKey: devKey) }
    }
    init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: langKey) ?? "SYSTEM") ?? .system
        developerMode = UserDefaults.standard.bool(forKey: devKey)   // default false → clean normal UX
    }
}
