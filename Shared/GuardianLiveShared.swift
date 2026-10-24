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
        public init(schemaVersion: Int = 2, surface: String, label: String, sequence: UInt64,
                    bandRaw: String = GuardianHeatBandRaw.clear, bandPosition: Double = 0,
                    sessionStart: Date = Date()) {
            self.schemaVersion = schemaVersion; self.surface = surface; self.label = label; self.sequence = sequence
            self.bandRaw = bandRaw; self.bandPosition = min(1, max(0, bandPosition)); self.sessionStart = sessionStart
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

    /// A dormant OFF band draws no live marker (never a protective look when Guardian is off/stopped).
    public static func isLive(_ raw: String) -> Bool { raw != off }

    /// Short, lock-safe band caption (no rule text). UNKNOWN is honest abstention, never "safe".
    public static func caption(_ raw: String) -> String {
        switch raw {
        case clear:   return "Temiz"
        case unknown: return "Belirsiz"
        case caution: return "Dikkat"
        case shield:  return "Kalkan"
        default:      return "—"
        }
    }
}
#if canImport(SwiftUI)
import SwiftUI
public extension GuardianHeatBandRaw {
    /// Band → marker/dot colour. Mirrors the system's state palette (green/gray/amber/red). Pure render projection.
    static func color(_ raw: String) -> Color {
        switch raw {
        case clear:   return .green
        case unknown: return .gray
        case caution: return .orange
        case shield:  return .red
        default:      return .secondary
        }
    }
}
#endif

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
