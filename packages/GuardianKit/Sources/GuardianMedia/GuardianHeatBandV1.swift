//
//  GuardianHeatBandV1.swift — the pure, headless HEAT-MAP BAND model for the LIVE Dynamic Island (micro-iteration).
//
//  WHAT THIS IS: the Dynamic Island shows a categorical HEAT BAR where a marker slides to the band of the content
//  currently being watched. This file is the PURE, testable brain that maps a REAL decision state (+ its REAL
//  evidence confidence) to (1) a categorical band and (2) a CONTINUOUS position 0...1 for the marker. The SwiftUI
//  widget only renders the primitives this produces — all the logic lives here so it can be unit-tested in
//  GuardianMediaTests without ActivityKit (Live Activities don't render on the simulator → DEVICE_UNVERIFIED there).
//
//  HONESTY (constitution rule 8, score gate CLOSED) — §2.2 CALIBRATION-GATED FIXED ANCHORS:
//   - There is NO fabricated 0-100 number anywhere. The band is CATEGORICAL, derived ONLY from real decision states.
//   - `position` is a CONTINUOUS parameter 0...1. Until REAL independent calibration exists (score gate CLOSED), the
//     marker sits at a FIXED categorical ANCHOR per band (`GuardianHeatBandV1.anchor`). We NO LONGER modulate the
//     within-band position by "confidence": the earlier coverage/reason-derived 0/1 was NOT a calibrated probability,
//     so moving the marker by it implied a precision we do not have (§2.2: "sahte sayısal güveni kaldır"). The
//     continuous `position` TYPE is retained so a real calibrated score can slot into the SAME marker later WITHOUT
//     any UI redesign (set `position` from the score; keep the band for colour). This is documented, not hidden.
//   - `confidence` is retained as a DIAGNOSTIC-ONLY field (tests/telemetry). It never moves the marker anymore.
//     Missing evidence does NOT move the marker toward "clear": UNKNOWN sits in the gray zone regardless (rule 7).
//   - USER_OVERRIDDEN is its OWN band (§2.2): a conscious user exception is NOT "clear"/safe — it renders distinctly
//     (outlined/blue), and WARN/ASK-played content never auto-flips to green.
//
//  LAYOUT CONVENTION (shared with the widget): the bar runs COOL→HOT, left→right.
//     0.00 ────────────── 0.40 ───────── 0.65 ───────── 0.85 ────────── 1.00
//       │  CLEAR (green)    │ UNKNOWN(gray) │ CAUTION(amber) │  SHIELD (red)  │
//  A higher position is a "hotter"/more-protective-attention band. OFF has no marker (the bar is dormant).
//  USER_OVERRIDDEN anchors in the CLEAR zone's position (the content plays) but carries its OWN colour/outline so it
//  is never visually confused with an evidence-clear green.
//
import Foundation

/// The categorical heat band for the Dynamic Island marker. Derived ONLY from real decision states + evidence —
/// never from a fabricated score. A real numeric score, when calibration opens, drives `position` directly while
/// these bands keep providing the colour semantics.
public enum GuardianHeatBandV1: String, Sendable, Equatable, Codable {
    case off            = "OFF"      // Guardian off / dormant — the bar shows no live marker (never a protective look)
    case clear          = "CLEAR"    // GUARDIAN_ON / benign evidence / no match — green
    case unknown        = "UNKNOWN"  // insufficient evidence / observing-no-decision — gray (honest abstention, NOT "safe")
    case caution        = "CAUTION"  // caution signal — amber
    case shield         = "SHIELD"   // personal-shield match — red
    case userOverridden = "USER_OVERRIDDEN" // §2.2 — a CONSCIOUS user exception ("yine de göster"): content plays but
                                            // this is NOT an evidence-clear "safe" state. Rendered distinctly (blue/
                                            // outlined), NEVER green. WARN/ASK-played content maps here, not to CLEAR.

    /// The [lo, hi) sub-range this band occupies on the continuous 0...1 bar. The continuous TYPE is retained for
    /// FUTURE calibration (a real score lands anywhere in 0...1 and the band is derived from the score's range).
    /// USER_OVERRIDDEN shares the CLEAR zone's horizontal range (the content plays) but carries its OWN colour.
    public var range: ClosedRange<Double> {
        switch self {
        case .off:            return 0.0...0.0
        case .clear:          return 0.00...0.40
        case .userOverridden: return 0.00...0.40
        case .unknown:        return 0.40...0.65
        case .caution:        return 0.65...0.85
        case .shield:         return 0.85...1.00
        }
    }

    /// §2.2 — the FIXED categorical ANCHOR this band's marker sits at (calibration gate CLOSED). This is a single
    /// representative point per band; the marker does NOT drift by "confidence" anymore (that implied uncalibrated
    /// precision). A future calibrated score will replace this anchor with the real score, same marker, no redesign.
    /// Anchors are the band mid-points, which keeps the strict cool→hot ordering clear < unknown < caution < shield.
    public var anchor: Double {
        switch self {
        case .off:            return 0.0
        // USER_OVERRIDDEN sits at the SAME x as CLEAR (content plays) — colour/outline, not position, distinguishes it.
        case .clear:          return 0.20
        case .userOverridden: return 0.20
        case .unknown:        return 0.525
        case .caution:        return 0.75
        case .shield:         return 0.925
        }
    }

    /// Whether this band legitimately implies active protective attention (never true for OFF/CLEAR/UNKNOWN/
    /// USER_OVERRIDDEN; UNKNOWN is honest abstention and a user override is a conscious exception, NOT protection).
    public var impliesAttention: Bool {
        switch self { case .caution, .shield: return true; default: return false }
    }

    /// §2.2 — is this band an evidence-CLEAR "safe-looking" (green) state? USER_OVERRIDDEN deliberately returns FALSE
    /// so a conscious exception is never rendered or reasoned about as an evidence-clear result.
    public var isEvidenceClear: Bool { self == .clear }

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
    /// when the app is foreground). §2.2: PLAYING (evidence clean) = clear; USER_OVERRIDDEN gets its OWN band (a
    /// conscious exception, NOT green); HIDDEN = shield (a real match executed); UNDETERMINED = unknown (explicit
    /// ask, never "safe"); PENDING/EVALUATING/SKIPPED = unknown (no decision yet).
    public static func band(fromReelStateRaw raw: String) -> GuardianHeatBandV1 {
        switch raw {
        case "PLAYING":         return .clear
        case "USER_OVERRIDDEN": return .userOverridden   // §2.2 — distinct from CLEAR; never auto-green
        case "HIDDEN":          return .shield
        // C1 — distinct applied actions on a real match: content is still shown but under an active preference, so
        // CAUTION (amber) — never green. BLUR/MUTE/WARN all imply attention without a full hide.
        case "BLURRED", "MUTED", "WARNED": return .caution
        case "ASK_USER":        return .unknown          // a real match awaiting approval → gray (never "safe")
        case "UNDETERMINED":    return .unknown
        // SKIPPED stays UNKNOWN: the raw state alone cannot distinguish a user B3 skip (no decision) from a C1
        // SKIP-action skip (a real match). The honest default is no-decision gray; a SKIP-action decision carries its
        // own reason for any surface that needs the shield semantics. PENDING_EVALUATION / EVALUATING also → unknown.
        default:                return .unknown
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

    /// §2.2 — the single pure constructor the whole app + extension go through. The marker sits at the band's FIXED
    /// categorical ANCHOR (calibration gate CLOSED): the position no longer drifts by `confidence`, because the
    /// coverage/reason-derived value was NOT a calibrated probability and moving the marker by it implied a
    /// precision we do not have. `confidence` is retained ONLY as a diagnostic (telemetry/tests). When real
    /// calibration opens, swap `band.anchor` here for the calibrated score — same marker, same bands, no redesign.
    public static func make(band: GuardianHeatBandV1, confidence: Double) -> GuardianHeatMarkerV1 {
        let c = min(1, max(0, confidence))
        return GuardianHeatMarkerV1(band: band, position: band.anchor, confidence: c)
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
