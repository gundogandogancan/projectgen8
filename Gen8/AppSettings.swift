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

/// §2.1 — the user's chosen Guardian DISPLAY MODE. Raw values match GuardianDisplayStyleRaw so the preference flows
/// straight into the Live Activity ContentState / reels surfaces with no translation. ALL modes render the SAME real
/// GuardianUserVisibleState + band — there is NEVER separate decision logic per mode. NUMBER is visible but LOCKED
/// (score gate CLOSED, rule 8) until real independent calibration exists.
enum GuardianDisplayStyle: String, CaseIterable, Sendable {
    case heatMap = "HEAT_MAP"
    case emoji   = "EMOJI"
    case number  = "NUMBER"   // visible-but-locked ("kalibrasyon tamamlanınca aktif")

    var displayName: String {
        switch self {
        case .heatMap: return "Isı haritası"
        case .emoji:   return "Emoji"
        case .number:  return "Sayı"
        }
    }
    /// §2.1 — NUMBER is not yet a real output mode. The UI shows it but it is locked with honest copy.
    var isLocked: Bool { self == .number }
    var lockedNote: String { isLocked ? "Kalibrasyon tamamlanınca aktif" : "" }
}

@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()
    private let langKey = "gen8.language"
    private let devKey = "gen8.developerMode"
    private let styleKey = "gen8.displayStyle"   // §2.1 — app-private, persisted on device

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: langKey) }
    }
    var developerMode: Bool {
        didSet { UserDefaults.standard.set(developerMode, forKey: devKey) }
    }
    /// §2.1 — the user's chosen display mode. A NUMBER selection is IGNORED for real output (locked): the effective
    /// style falls back to HEAT_MAP until calibration opens, so we never render a fabricated number.
    var displayStyle: GuardianDisplayStyle {
        didSet {
            // Never persist NUMBER as the effective mode while it is locked — keep the user's pick for the UI toggle
            // state, but the EFFECTIVE style used by surfaces is resolved via `effectiveDisplayStyleRaw`.
            UserDefaults.standard.set(displayStyle.rawValue, forKey: styleKey)
        }
    }
    /// The raw style surfaces should actually render: a LOCKED mode (NUMBER) degrades to HEAT_MAP (honest; never a
    /// fabricated score). The widget also guards NUMBER, so this is belt-and-braces at the app boundary.
    var effectiveDisplayStyleRaw: String {
        displayStyle.isLocked ? GuardianDisplayStyle.heatMap.rawValue : displayStyle.rawValue
    }
    init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: langKey) ?? "SYSTEM") ?? .system
        developerMode = UserDefaults.standard.bool(forKey: devKey)   // default false → clean normal UX
        displayStyle = GuardianDisplayStyle(rawValue: UserDefaults.standard.string(forKey: styleKey) ?? "HEAT_MAP") ?? .heatMap
    }
}
