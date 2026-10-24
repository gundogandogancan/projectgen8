//
//  GuardianHeatBandV1.swift — the pure, headless HEAT-MAP BAND model for the LIVE Dynamic Island (micro-iteration).
//
//  WHAT THIS IS: the Dynamic Island shows a categorical HEAT BAR where a marker slides to the band of the content
//  currently being watched. This file is the PURE, testable brain that maps a REAL decision state (+ its REAL
//  evidence confidence) to (1) a categorical band and (2) a CONTINUOUS position 0...1 for the marker. The SwiftUI
//  widget only renders the primitives this produces — all the logic lives here so it can be unit-tested in
//  GuardianMediaTests without ActivityKit (Live Activities don't render on the simulator → DEVICE_UNVERIFIED there).
//
//  HONESTY (constitution rule 8, score gate CLOSED):
//   - There is NO fabricated 0-100 number anywhere. The band is CATEGORICAL, derived ONLY from real decision states.
//   - `position` is a CONTINUOUS parameter 0...1 fed TODAY by (band base anchor) + (real evidence confidence within
//     the band's sub-range). It is NOT a score and is never shown as a number. It exists so a real calibrated numeric
//     score can slot into the SAME marker later WITHOUT any UI redesign (set `position` from the score; keep the band
//     for colour). This dual meaning is documented, not hidden.
//   - Confidence here = REAL evaluator evidence (coverage ∈ 0...1, and 1 − uncertainty ∈ 0...1). Missing evidence does
//     NOT move the marker toward "clear" — an UNKNOWN band sits in the gray zone regardless (rule 7: UNKNOWN ≠ BAD, and
//     UNKNOWN ≠ GOOD either). Low confidence only widens toward the band's uncertain edge, never across a band.
//
//  LAYOUT CONVENTION (shared with the widget): the bar runs COOL→HOT, left→right.
//     0.00 ────────────── 0.40 ───────── 0.65 ───────── 0.85 ────────── 1.00
//       │  CLEAR (green)    │ UNKNOWN(gray) │ CAUTION(amber) │  SHIELD (red)  │
//  A higher position is a "hotter"/more-protective-attention band. OFF has no marker (the bar is dormant).
//
import Foundation

/// The categorical heat band for the Dynamic Island marker. Derived ONLY from real decision states + evidence —
/// never from a fabricated score. A real numeric score, when calibration opens, drives `position` directly while
/// these bands keep providing the colour semantics.
public enum GuardianHeatBandV1: String, Sendable, Equatable, Codable {
    case off     = "OFF"      // Guardian off / dormant — the bar shows no live marker (never a protective look)
    case clear   = "CLEAR"    // GUARDIAN_ON / benign evidence / no match — green
    case unknown = "UNKNOWN"  // insufficient evidence / observing-no-decision — gray (honest abstention, NOT "safe")
    case caution = "CAUTION"  // caution signal — amber
    case shield  = "SHIELD"   // personal-shield match — red

    /// The [lo, hi) sub-range this band occupies on the continuous 0...1 bar. `position` is clamped inside it today;
    /// a future real score can also land anywhere in 0...1 and the band is then derived from the score's range.
    public var range: ClosedRange<Double> {
        switch self {
        case .off:     return 0.0...0.0
        case .clear:   return 0.00...0.40
        case .unknown: return 0.40...0.65
        case .caution: return 0.65...0.85
        case .shield:  return 0.85...1.00
        }
    }

    /// Whether this band legitimately implies active protective attention (never true for OFF; UNKNOWN is honest
    /// abstention and does NOT claim protection). Mirrors GuardianUserVisibleState.impliesActiveProtection intent.
    public var impliesAttention: Bool {
        switch self { case .caution, .shield: return true; default: return false }
    }

    /// Map the lock-safe NativeSurfaceState raw value → a band. Pure 1:1 projection of EXISTING surface semantics.
    /// Unmapped/empty → UNKNOWN (never a positive/safe default), consistent with the rest of the system.
    public static func band(fromSurfaceRaw raw: String) -> GuardianHeatBandV1 {
        switch raw {
        case "GUARDIAN_ON": return .clear
        case "CAUTION":     return .caution
        case "SHIELD_MATCH":return .shield
        case "OFF":         return .off
        case "UNKNOWN":     return .unknown
        default:            return .unknown
        }
    }

    /// Map a controlled-reel lifecycle state raw value → a band (so in-app reels decisions ALSO drive the Island
    /// when the app is foreground). PLAYING/USER_OVERRIDDEN = clear; HIDDEN = shield (a real match executed);
    /// UNDETERMINED = unknown (explicit ask, never "safe"); PENDING/EVALUATING/SKIPPED = unknown (no decision yet).
    public static func band(fromReelStateRaw raw: String) -> GuardianHeatBandV1 {
        switch raw {
        case "PLAYING", "USER_OVERRIDDEN": return .clear
        case "HIDDEN":                     return .shield
        case "UNDETERMINED":               return .unknown
        default:                           return .unknown   // PENDING_EVALUATION / EVALUATING / SKIPPED
        }
    }
}

/// The marker payload the Island renders: a categorical band + a continuous position. `confidence` is retained for
/// diagnostics/tests but is NEVER shown as a number. `isLive` is false for OFF/dormant (no marker drawn).
public struct GuardianHeatMarkerV1: Sendable, Equatable, Codable {
    public let band: GuardianHeatBandV1
    /// Continuous 0...1 marker position. TODAY: band anchor modulated by real confidence within the band's range.
    /// FUTURE (score gate open): set directly from the calibrated score; band derived from the score's range.
    public let position: Double
    /// REAL evidence confidence 0...1 that produced the within-band offset (coverage, or 1 − uncertainty). Diagnostic.
    public let confidence: Double
    public var isLive: Bool { band != .off }

    public init(band: GuardianHeatBandV1, position: Double, confidence: Double) {
        self.band = band
        self.position = min(1, max(0, position))
        self.confidence = min(1, max(0, confidence))
    }

    /// The single pure constructor the whole app + extension go through. Given a REAL band and a REAL confidence
    /// (0...1; 0 = no/low evidence, 1 = full coverage), place the marker WITHIN the band's sub-range:
    ///   - HIGH confidence → sit at the band's HOT edge for an attention band (caution/shield) and at the COOL edge
    ///     for CLEAR (confidently clear = far left). This keeps "more certain protective signal" = "further right".
    ///   - LOW confidence  → drift toward the band's boundary with UNKNOWN (less committed), NEVER across it.
    /// UNKNOWN always sits mid-gray (abstention is not a position you can be "confident" about either way).
    public static func make(band: GuardianHeatBandV1, confidence: Double) -> GuardianHeatMarkerV1 {
        let c = min(1, max(0, confidence))
        let r = band.range
        let span = r.upperBound - r.lowerBound
        let position: Double
        switch band {
        case .off:
            position = 0
        case .clear:
            // Confidently clear → cool (left) edge; low confidence → drift up toward the UNKNOWN boundary.
            position = r.upperBound - c * span
        case .unknown:
            // Abstention: stay mid-band; confidence barely nudges (there is no "safe" or "bad" direction to commit to).
            position = r.lowerBound + span * 0.5
        case .caution, .shield:
            // Confident attention signal → hot (right) edge; low confidence → drift down toward UNKNOWN boundary.
            position = r.lowerBound + c * span
        }
        return GuardianHeatMarkerV1(band: band, position: position, confidence: c)
    }

    /// Convenience: build directly from a lock-safe surface raw + confidence (the heartbeat / lab path).
    public static func fromSurfaceRaw(_ raw: String, confidence: Double) -> GuardianHeatMarkerV1 {
        make(band: .band(fromSurfaceRaw: raw), confidence: confidence)
    }

    /// Convenience: build directly from a controlled-reel state raw + confidence (the in-app reels path).
    public static func fromReelStateRaw(_ raw: String, confidence: Double) -> GuardianHeatMarkerV1 {
        make(band: .band(fromReelStateRaw: raw), confidence: confidence)
    }
}
