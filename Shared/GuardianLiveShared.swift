//
//  GuardianLiveShared.swift — CANONICAL shared Live Activity contract (PROMPT 007C §2)
//  ONE definition compiled into BOTH the app and the widget extension (added to both targets' Sources phases).
//  A Live Activity only renders when the app starts an Activity whose attributes type is identical to the widget's —
//  so this type must be shared, not duplicated. Minimal + privacy-safe: no Shield rule text, versioned content state.
//
import Foundation
#if canImport(ActivityKit)
import ActivityKit

public struct GuardianActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var schemaVersion: Int
        public var surface: String      // NativeSurfaceState raw value (GUARDIAN_ON/CAUTION/SHIELD_MATCH/UNKNOWN/OFF)
        public var label: String        // already-localized, lock-safe label (no rule text) — set by the app
        public var sequence: UInt64     // monotonic; used for out-of-order rejection
        // --- LIVE HEAT-MAP BAR (micro-iteration) ---
        // The Dynamic Island draws a categorical heat bar with a marker that slides to the WATCHED content's band the
        // instant content changes. These fields are the PRIMITIVES the widget renders — the categorical band logic +
        // the continuous position are computed by the pure GuardianHeatMarkerV1 (GuardianMedia) and passed in here, so
        // the widget extension needs NO GuardianMedia dependency (it compiles only this shared file).
        /// Categorical band raw value: OFF / CLEAR / UNKNOWN / CAUTION / SHIELD. Drives the marker COLOUR (honest,
        /// state-derived — NOT a score). Default CLEAR keeps older encoded states decodable.
        public var bandRaw: String
        /// CONTINUOUS marker position 0...1 (cool→hot, left→right). TODAY: band anchor + real evidence confidence.
        /// FUTURE: a calibrated numeric score drops in here with ZERO UI redesign. NEVER shown as a number (rule 8).
        public var bandPosition: Double
        /// When the current observation/playback session began — drives the SYSTEM-ANIMATED Text(timerInterval:)
        /// "Gözlemde · MM:SS" timer that ticks with ZERO app updates (the always-alive element).
        public var sessionStart: Date
        /// §2.1 — the user's chosen display MODE (HEAT_MAP / EMOJI / NUMBER), carried to the widget so the SAME real
        /// state renders in the style the user picked. ALL styles render the SAME GuardianUserVisibleState + band —
        /// there is NEVER separate decision logic per style. Default HEAT_MAP keeps older encoded states decodable.
        public var displayStyleRaw: String
        /// §2.3 — a concise, STATE-SPECIFIC Island title (Gözlemde / Rölanti / Analiz / Kapalı …), set by the app so
        /// the widget never hard-codes a single "Gözlemde". Default keeps older encoded states decodable.
        public var title: String
        public init(schemaVersion: Int = 2, surface: String, label: String, sequence: UInt64,
                    bandRaw: String = GuardianHeatBandRaw.clear, bandPosition: Double = 0,
                    sessionStart: Date = Date(),
                    displayStyleRaw: String = GuardianDisplayStyleRaw.heatMap,
                    title: String = "Gözlemde") {
            self.schemaVersion = schemaVersion; self.surface = surface; self.label = label; self.sequence = sequence
            self.bandRaw = bandRaw; self.bandPosition = min(1, max(0, bandPosition)); self.sessionStart = sessionStart
            self.displayStyleRaw = displayStyleRaw; self.title = title
        }

        // Tolerant decode: an older ContentState JSON without displayStyleRaw/title still decodes (defaults).
        private enum CodingKeys: String, CodingKey {
            case schemaVersion, surface, label, sequence, bandRaw, bandPosition, sessionStart, displayStyleRaw, title
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
            surface = try c.decode(String.self, forKey: .surface)
            label = try c.decode(String.self, forKey: .label)
            sequence = try c.decode(UInt64.self, forKey: .sequence)
            bandRaw = try c.decodeIfPresent(String.self, forKey: .bandRaw) ?? GuardianHeatBandRaw.clear
            bandPosition = min(1, max(0, try c.decodeIfPresent(Double.self, forKey: .bandPosition) ?? 0))
            sessionStart = try c.decodeIfPresent(Date.self, forKey: .sessionStart) ?? Date()
            displayStyleRaw = try c.decodeIfPresent(String.self, forKey: .displayStyleRaw) ?? GuardianDisplayStyleRaw.heatMap
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Gözlemde"
        }
    }
    public var contentID: String
    public init(contentID: String) { self.contentID = contentID }
}

/// Band raw-value constants + rendering helpers, SELF-CONTAINED here so the widget extension (which compiles only
/// this shared file) can colour the heat bar without importing GuardianMedia. The categorical logic itself lives in
/// the pure, unit-tested GuardianHeatBandV1 (GuardianMedia); these are the thin render-side projections of its raws.
public enum GuardianHeatBandRaw {
    public static let off = "OFF", clear = "CLEAR", unknown = "UNKNOWN", caution = "CAUTION", shield = "SHIELD"
    /// §2.2 — a CONSCIOUS user exception ("yine de göster"). The content plays, but this is NOT an evidence-clear
    /// "safe" (green) state: it renders distinctly (blue/outlined) so a user override is never confused with CLEAR.
    public static let userOverridden = "USER_OVERRIDDEN"

    /// A dormant OFF band draws no live marker (never a protective look when Guardian is off/stopped).
    public static func isLive(_ raw: String) -> Bool { raw != off }

    /// §2.2 — is this an evidence-CLEAR green state? USER_OVERRIDDEN returns FALSE (conscious exception, not green).
    public static func isEvidenceClear(_ raw: String) -> Bool { raw == clear }

    /// §2.2 — a user override is a conscious exception; the widget draws it as an OUTLINED (hollow) marker so it is
    /// visually distinct from an evidence-clear filled marker even to a quick glance.
    public static func isUserOverride(_ raw: String) -> Bool { raw == userOverridden }

    /// Short, lock-safe band caption (no rule text). UNKNOWN is honest abstention, never "safe". USER_OVERRIDDEN is
    /// explicitly the user's own exception, NOT a "temiz/safe" claim.
    public static func caption(_ raw: String) -> String {
        switch raw {
        case clear:          return "Temiz"
        case unknown:        return "Belirsiz"
        case caution:        return "Dikkat"
        case shield:         return "Kalkan"
        case userOverridden: return "Senin istisnan"
        default:             return "—"
        }
    }
}
#if canImport(SwiftUI)
import SwiftUI
public extension GuardianHeatBandRaw {
    /// Band → marker/dot colour. Mirrors the system's state palette (green/gray/amber/red). §2.2: USER_OVERRIDDEN is
    /// BLUE (a conscious exception — deliberately NOT green, so it never reads as an evidence-clear safe state).
    static func color(_ raw: String) -> Color {
        switch raw {
        case clear:          return .green
        case unknown:        return .gray
        case caution:        return .orange
        case shield:         return .red
        case userOverridden: return .blue
        default:             return .secondary
        }
    }
}
#endif

/// §2.1 — the THREE user-selectable display modes. ALL three render the SAME GuardianUserVisibleState + band + policy
/// (never separate decision logic): HEAT_MAP is the categorical bar; EMOJI is the SAME band shown as a face/glyph;
/// NUMBER is visible in the UI but LOCKED until REAL independent calibration exists (score gate CLOSED — rule 8).
/// Self-contained here (constants + emoji projection) so the widget extension (which compiles ONLY this shared file)
/// can render EMOJI without importing GuardianMedia.
public enum GuardianDisplayStyleRaw {
    public static let heatMap = "HEAT_MAP", emoji = "EMOJI", number = "NUMBER"
    /// NUMBER is NOT yet selectable for real output — the UI shows it as an option but it is locked.
    public static func isLocked(_ raw: String) -> Bool { raw == number }
    /// §2.1 — the EMOJI projection of a BAND (same real state as the heat bar). 🟢😊 clear / ⬜🤔 unknown /
    /// 🟡⚠️ caution / 🔴🛡️ shield / 🔵 user-override (conscious exception, NOT green). OFF/unmapped → neutral.
    public static func emojiFace(_ bandRaw: String) -> String {
        switch bandRaw {
        case GuardianHeatBandRaw.clear:          return "🟢"
        case GuardianHeatBandRaw.unknown:        return "⬜"
        case GuardianHeatBandRaw.caution:        return "🟡"
        case GuardianHeatBandRaw.shield:         return "🔴"
        case GuardianHeatBandRaw.userOverridden: return "🔵"
        default:                                 return "⚫"
        }
    }
    /// A secondary expressive glyph, paired with the colour face (🟢😊 ⬜🤔 🟡⚠️ 🔴🛡️). Same band, no new logic.
    public static func emojiGlyph(_ bandRaw: String) -> String {
        switch bandRaw {
        case GuardianHeatBandRaw.clear:          return "😊"
        case GuardianHeatBandRaw.unknown:        return "🤔"
        case GuardianHeatBandRaw.caution:        return "⚠️"
        case GuardianHeatBandRaw.shield:         return "🛡️"
        case GuardianHeatBandRaw.userOverridden: return "🙋"
        default:                                 return "💤"
        }
    }
}

/// Surface-raw → SF Symbol (shared by app + extension). UNKNOWN/unmapped → questionmark (never a positive/safe default).
public enum GuardianSurfaceSymbol {
    public static func icon(_ surface: String) -> String {
        switch surface {
        case "GUARDIAN_ON": return "shield.lefthalf.filled"
        case "CAUTION": return "exclamationmark.triangle"
        case "SHIELD_MATCH": return "eye.slash"
        case "OFF": return "shield.slash"
        default: return "questionmark.circle"
        }
    }
}
#endif
