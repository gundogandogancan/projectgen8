//
//  GuardianSessionState.swift — P3 (PRODUCT): the user-visible Guardian observation-session state machine.
//
//  WHY THIS EXISTS (product mandate P3): the REAL session state machine (GuardianCore.ObservationSessionState,
//  AutomaticGuardianRuntime.swift) and the REAL lock-safe surface state (GuardianCore.NativeSurfaceState) already
//  exist and are tested headless — but NOTHING in the product UI consumed them. This file is the PROJECTION that
//  maps those EXISTING core semantics onto a single user-visible state the HUD and Live Activity both read. It
//  invents NO new safety semantics: every case is derived from an existing core enum.
//
//  LAWS (constitution rules 7, 17; mandate P3/P4):
//   - Guardian OFF or a stopped/unavailable broadcast must NEVER look protection-active. OFF/UNAVAILABLE map to
//     surfaces that cannot claim protection (NativeSurfaceState.off / .unknown), and GuardianActivation.
//     canClaimProtection is the authority consulted before any protective surface is shown.
//   - A content change invalidates the prior decision: `onResolvedIdentityChange` resets the per-content surface to
//     ANALYZING so a stale CAUTION/SHIELD can never survive across resolved items.
//   - NO numeric 0-100 production score anywhere (none is produced or displayed here; it's categorical only).
//
import Foundation
import GuardianCore

/// The single user-visible observation-session state. Each case is a projection of EXISTING core semantics
/// (ObservationSessionState for the session lifecycle; NativeSurfaceState for the per-content surface).
public enum GuardianUserVisibleState: String, Sendable, Equatable {
    case off = "OFF"                         // ObservationSessionState.off  / Guardian disabled
    case unavailable = "UNAVAILABLE"         // ObservationSessionState.unavailable / .error / .restartRequired
    case starting = "STARTING"               // ObservationSessionState.permissionRequired / .ready / .starting / .recoverable
    case observing = "OBSERVING"             // ACTIVE session, no per-content evidence yet (surface GUARDIAN_ON)
    case observingIdle = "OBSERVING_IDLE"    // §5.4 ACTIVE broadcast but USER-CONTROLLED IDLE: heavy analysis is OFF;
                                             // cheap heartbeat only. NO "koruma aktif" claim. Band OFF-like gray.
    case analyzing = "ANALYZING"             // ACTIVE session, a new resolved item is being analyzed
    case evidenceAvailable = "EVIDENCE_AVAILABLE" // ACTIVE, aligned/benign evidence present (surface GUARDIAN_ON)
    case caution = "CAUTION"                 // surface CAUTION
    case unknown = "UNKNOWN"                 // surface UNKNOWN — honest abstention; NEVER "safe"
    case shieldMatch = "SHIELD_MATCH"        // surface SHIELD_MATCH

    /// A human, lock-safe label (no rule text). Mirrors NativeSurfaceState.lockSafeLabel where applicable.
    public var label: String {
        switch self {
        case .off: return "Off"
        case .unavailable: return "Unavailable"
        case .starting: return "Starting…"
        case .observing: return "Observing"
        case .observingIdle: return "Idle (paused)"
        case .analyzing: return "Analyzing…"
        case .evidenceAvailable: return "Evidence available"
        case .caution: return "Caution"
        case .unknown: return "Unknown"
        case .shieldMatch: return "Shield match"
        }
    }

    /// §2.3 — the concise, STATE-SPECIFIC Turkish Island/Insight TITLE (Gözlemde / Rölanti / Analiz / Kapalı …).
    /// The title is a separate concept from the band and the timer: it names WHAT the session is doing right now.
    public var islandTitle: String {
        switch self {
        case .off: return "Kapalı"
        case .unavailable: return "Kullanılamıyor"
        case .starting: return "Başlatılıyor"
        case .observing: return "Gözlemde"
        case .observingIdle: return "Rölanti"                 // §5.4 — idle; NEVER "koruma aktif"
        case .analyzing: return "Analiz"
        case .evidenceAvailable: return "Gözlemde"
        case .caution: return "Dikkat"
        case .unknown: return "Belirsiz"
        case .shieldMatch: return "Kalkan"
        }
    }

    /// May this state legitimately imply active protection to the user? FALSE for OFF/UNAVAILABLE/STARTING, for
    /// honest-abstention UNKNOWN, and for OBSERVING_IDLE (§5.4 — idle makes NO protection claim). Firewall against
    /// "OFF/idle looks protected".
    public var impliesActiveProtection: Bool {
        switch self {
        case .observing, .analyzing, .evidenceAvailable, .caution, .shieldMatch: return true
        case .off, .unavailable, .starting, .unknown, .observingIdle: return false
        }
    }

    /// The lock-safe native surface this maps to (what the Dynamic Island / Live Activity shows). Pure projection
    /// onto the EXISTING NativeSurfaceState (GUARDIAN_ON/CAUTION/SHIELD_MATCH/UNKNOWN/OFF).
    public var nativeSurface: NativeSurfaceState {
        switch self {
        case .off: return .off
        case .unavailable: return .off              // a dead session must not look "on" — surface OFF, label says why
        case .starting: return .unknown             // not yet observing → never a positive surface
        case .observing, .evidenceAvailable: return .guardianOn
        case .observingIdle: return .off            // §5.4 — idle: OFF-like gray band; no protective look, no "aktif"
        case .analyzing: return .unknown            // mid-analysis is not a safe claim
        case .caution: return .caution
        case .unknown: return .unknown
        case .shieldMatch: return .shieldMatch
        }
    }
}

/// Maps the REAL core enums to the single user-visible state. No new semantics — a pure function of existing ones.
public enum GuardianSessionProjection {
    /// - session: the live ObservationSessionState (GuardianCore).
    /// - activation: the GuardianActivation (authority on whether protection may be claimed at all).
    /// - surface: the per-content NativeSurfaceState for the CURRENT resolved item, or nil if none analyzed yet.
    /// - userIdle: §5.4 — the USER-CONTROLLED idle flag. When the broadcast is ACTIVE but the user has flipped the
    ///   session to IDLE (via the app or the Control Center toggle), heavy analysis is OFF and we must NOT claim
    ///   protection. An ACTIVE session with userIdle=true projects to OBSERVING_IDLE regardless of any prior surface.
    public static func userVisible(session: ObservationSessionState,
                                   activation: GuardianActivation,
                                   surface: NativeSurfaceState?,
                                   userIdle: Bool = false) -> GuardianUserVisibleState {
        // Hard floors first — OFF / cannot-claim-protection outrank any per-content surface.
        if activation == .disabled || activation == .paused { return .off }
        switch session {
        case .off: return .off
        case .unavailable, .error: return .unavailable
        case .restartRequired: return .unavailable
        case .permissionRequired, .ready, .starting, .recoverable, .interrupted: return .starting
        case .active:
            break   // fall through to surface mapping below
        }
        // §5.4 — ACTIVE broadcast but user-controlled IDLE: heavy analysis is off; never a per-content/protective
        // claim. This outranks any (now stale) surface — on wake the surface is re-derived from fresh evidence.
        if userIdle { return .observingIdle }
        // Session is ACTIVE. If activation cannot claim protection (restricted), degrade to UNKNOWN (never positive).
        guard activation.canClaimProtection else { return .unknown }
        // Per-content surface mapping (content change resets this to nil → OBSERVING until analysis produces one).
        guard let s = surface else { return .observing }
        switch s {
        case .guardianOn: return .evidenceAvailable
        case .caution: return .caution
        case .shieldMatch: return .shieldMatch
        case .unknown: return .unknown
        case .off: return .off
        }
    }
}

/// Short Dynamic-Island trailing text for a user-visible state (mirrors the widget's `short(_:)` vocabulary).
public enum GuardianIslandText {
    public static func short(_ state: GuardianUserVisibleState) -> String {
        switch state {
        case .off: return "Off"
        case .unavailable: return "N/A"
        case .starting: return "…"
        case .observing: return "On"
        case .observingIdle: return "Idle"
        case .analyzing: return "Analyzing"
        case .evidenceAvailable: return "On"
        case .caution: return "Caution"
        case .unknown: return "Unknown"
        case .shieldMatch: return "Shield"
        }
    }
}
