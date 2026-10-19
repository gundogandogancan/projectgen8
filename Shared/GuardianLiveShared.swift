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
        public init(schemaVersion: Int = 1, surface: String, label: String, sequence: UInt64) {
            self.schemaVersion = schemaVersion; self.surface = surface; self.label = label; self.sequence = sequence
        }
    }
    public var contentID: String
    public init(contentID: String) { self.contentID = contentID }
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
