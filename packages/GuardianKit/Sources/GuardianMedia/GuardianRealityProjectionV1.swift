//
//  GuardianRealityProjectionV1.swift — §3: the SINGLE TRUTH PROJECTION for capture→Guardian→Island state.
//
//  WHY THIS EXISTS (mandate §3.1): eight DIFFERENT facts must never be collapsed into one another. The old code
//  inferred "active protection" from the in-app Guardian toggle alone; a green/safe Island could carry over to a
//  brand-new content item; a stale heartbeat could still read as live. This type makes the facts EXPLICIT and keeps
//  them SEPARATE, then derives the Island SURFACE STATE from them with honest degradation — UNKNOWN stays gray,
//  presentation is ALWAYS unverified without an OS callback, and a new item identity invalidates the prior decision.
//
//  THE EIGHT FACTS (§3.1) — each independent, none inferred from another:
//    1. userRequestedOn          — the user chose Guardian ON (intent). NOT proof capture started.
//    2. osCaptureStarted         — the OS actually started the ReplayKit broadcast. NOT proof frames arrive.
//    3. framesArriving           — the extension is receiving frames (fresh heartbeat). NOT proof analysis ran.
//    4. analysisActive           — analysis is actually running (not user-IDLE / not OFF-gated).
//    5. lastDecisionValid        — the last decision is valid FOR the current item identity + policy revision +
//                                  freshness (a decision for a PRIOR item/policy is NOT valid now).
//    6. appGroupIPCWorking       — the App Group IPC channel is actually functioning.
//    7. liveActivityAccepted     — ActivityKit ACCEPTED our Live Activity request. NOT proof it is on screen.
//    8. islandPresentationVerified — the Island is PROVEN on screen by an OS callback. Without that proof: FALSE,
//                                  ALWAYS (there is no public API that proves a Live Activity is visible — §3.2).
//
//  This type is PURE + headless + exhaustively unit-testable. It performs NO IPC itself — the caller (the extension
//  publishing facts, or the app's Island bridge deriving the surface) supplies the facts. It lives in GuardianMedia
//  (ungoverned) and is dual-compiled into BOTH the Gen8 app and the GuardianBroadcastExtension (same pattern as
//  GuardianObservationHeartbeatV1 / Tier1IdentityResolutionV1).
//
import Foundation

/// §3.1 — the eight separate facts. A caller fills in only what it can HONESTLY observe; anything it cannot prove
/// stays `false` / `nil`. The projection never upgrades a `false` to a `true` by inference.
public struct GuardianRealityFactsV1: Sendable, Equatable {
    public var userRequestedOn: Bool
    public var osCaptureStarted: Bool
    public var framesArriving: Bool
    public var analysisActive: Bool
    public var appGroupIPCWorking: Bool
    public var liveActivityAccepted: Bool
    /// §3.1/§3.2 — ONLY ever true when an OS callback actually proved the Island is on screen. There is no public
    /// iOS API that proves a Live Activity's visibility, so in practice this stays false → the projection reports
    /// DEVICE_UNVERIFIED presentation. We keep the field so a future capability-gated proof can set it honestly.
    public var islandPresentationVerified: Bool

    // --- Decision-validity inputs (fact 5 is DERIVED from the identity/policy/freshness triple, never assumed) ---
    /// The content item identity revision the last decision was produced for (nil = no decision yet).
    public var decisionItemIdentityRevision: Int?
    /// The policy revision the last decision was produced under (nil = no decision yet).
    public var decisionPolicyRevision: UInt64?
    /// Whether the decision's evidence is still fresh (within the observation freshness window).
    public var decisionFresh: Bool
    /// The CURRENT content item identity revision (what is on screen NOW).
    public var currentItemIdentityRevision: Int?
    /// The CURRENT live policy revision (what the user's rules are at NOW).
    public var currentPolicyRevision: UInt64?
    /// The lock-safe surface the last (valid) decision resolved to — e.g. GUARDIAN_ON / CAUTION / SHIELD_MATCH /
    /// UNKNOWN. Empty while observing with no per-content decision. NEVER rule text.
    public var lastDecisionSurfaceRaw: String

    public init(userRequestedOn: Bool = false, osCaptureStarted: Bool = false, framesArriving: Bool = false,
                analysisActive: Bool = false, appGroupIPCWorking: Bool = false, liveActivityAccepted: Bool = false,
                islandPresentationVerified: Bool = false,
                decisionItemIdentityRevision: Int? = nil, decisionPolicyRevision: UInt64? = nil,
                decisionFresh: Bool = false, currentItemIdentityRevision: Int? = nil,
                currentPolicyRevision: UInt64? = nil, lastDecisionSurfaceRaw: String = "") {
        self.userRequestedOn = userRequestedOn; self.osCaptureStarted = osCaptureStarted
        self.framesArriving = framesArriving; self.analysisActive = analysisActive
        self.appGroupIPCWorking = appGroupIPCWorking; self.liveActivityAccepted = liveActivityAccepted
        self.islandPresentationVerified = islandPresentationVerified
        self.decisionItemIdentityRevision = decisionItemIdentityRevision
        self.decisionPolicyRevision = decisionPolicyRevision; self.decisionFresh = decisionFresh
        self.currentItemIdentityRevision = currentItemIdentityRevision
        self.currentPolicyRevision = currentPolicyRevision; self.lastDecisionSurfaceRaw = lastDecisionSurfaceRaw
    }
}

/// §3.1 — the honest OBSERVATION state the projection derives. This is the "are we really watching?" axis, kept
/// strictly separate from the per-content surface state. Each step UP requires the step below to be TRUE — the
/// projection never skips a rung (e.g. it cannot be `analyzing` without frames arriving).
public enum GuardianObservationStateV1: String, Sendable, Equatable {
    case off           = "OFF"            // the user did not request Guardian on
    case requested     = "REQUESTED"      // user asked ON, but the OS capture has NOT started → NOT protecting yet
    case captureStarted = "CAPTURE_STARTED" // OS broadcast started, but NO frames are arriving yet → NOT protecting
    case observing     = "OBSERVING"      // frames are arriving but analysis is paused/idle (cheap heartbeat only)
    case analyzing     = "ANALYZING"      // frames arriving AND analysis active → the only genuine "protecting" state
    case degraded      = "DEGRADED"       // IPC/heartbeat problem: we requested + maybe started, but cannot confirm
}

/// §3.1 — the validity of the LAST decision for the CURRENT item. Kept separate from the observation state so the
/// Island never shows a stale "safe" for new content.
public enum GuardianDecisionValidityV1: String, Sendable, Equatable {
    case none            = "NONE"             // no decision produced yet
    case valid           = "VALID"            // decision matches current item identity + policy + is fresh
    case staleItem       = "STALE_ITEM"       // a NEW item is on screen → the prior decision does not apply
    case stalePolicy     = "STALE_POLICY"     // the policy changed since the decision → must re-evaluate
    case staleFreshness  = "STALE_FRESHNESS"  // the decision's evidence aged out of the freshness window
}

/// §3.2/§3.3 — the honest presentation tier for the Island. We separate "we asked ActivityKit" from "the OS accepted
/// it" from "it is actually on the user's screen". The last is never claimed without an OS callback proof.
public enum GuardianIslandPresentationTierV1: String, Sendable, Equatable {
    case notRequested   = "NOT_REQUESTED"       // no Live Activity requested
    case requested      = "REQUESTED"           // we asked ActivityKit, outcome not yet known
    case accepted       = "ACCEPTED"            // ActivityKit accepted the request (activity exists)
    case deviceUnverified = "DEVICE_UNVERIFIED" // accepted, but on-screen visibility is UNPROVEN (no public proof API)
    case verified       = "VERIFIED"            // an OS callback proved it is on screen (reserved; not reachable today)
}

/// §3 — the derived, Island-ready projection. All three axes are independent; the Island writer reads THIS and never
/// infers one axis from another.
public struct GuardianRealityProjectionV1: Sendable, Equatable {
    public let observation: GuardianObservationStateV1
    public let decisionValidity: GuardianDecisionValidityV1
    public let presentation: GuardianIslandPresentationTierV1
    /// The lock-safe surface the Island should show. §3.3: on a NEW item (staleItem) or any non-valid decision this
    /// collapses to UNKNOWN (gray) — a prior "safe"/green is NEVER carried over. Empty means "observing, no decision".
    public let islandSurfaceRaw: String
    /// True only when protection is GENUINELY active: analyzing + a valid current-item decision. The mandate's
    /// "Guardian ON + capture absent ≠ active protection" maps directly onto this being false.
    public let activeProtection: Bool

    public init(observation: GuardianObservationStateV1, decisionValidity: GuardianDecisionValidityV1,
                presentation: GuardianIslandPresentationTierV1, islandSurfaceRaw: String, activeProtection: Bool) {
        self.observation = observation; self.decisionValidity = decisionValidity
        self.presentation = presentation; self.islandSurfaceRaw = islandSurfaceRaw
        self.activeProtection = activeProtection
    }

    /// §3 — the PURE derivation. Given the eight facts, produce the three-axis projection. This is the only place
    /// the facts are combined, and it combines them WITHOUT inference leaks (each axis reads only the facts it owns).
    public static func derive(_ f: GuardianRealityFactsV1) -> GuardianRealityProjectionV1 {
        let observation = deriveObservation(f)
        let validity = deriveValidity(f)
        let presentation = derivePresentation(f)

        // §3.3 — the Island surface. A prior decision's surface is shown ONLY when the decision is VALID for the
        // current item/policy/freshness AND we are genuinely observing. Otherwise UNKNOWN (gray), never a carried-
        // over green. OFF shows OFF. A non-valid decision degrades to UNKNOWN regardless of what the old surface was.
        let surface: String
        switch observation {
        case .off:
            surface = "OFF"
        case .requested, .captureStarted, .degraded:
            // We cannot confirm live observation → never present a content surface as current.
            surface = "UNKNOWN"
        case .observing, .analyzing:
            surface = (validity == .valid && !f.lastDecisionSurfaceRaw.isEmpty) ? f.lastDecisionSurfaceRaw : "UNKNOWN"
        }

        // Active protection: ONLY analyzing with a valid current-item decision. Toggle-on alone, capture-started
        // alone, or a stale decision never counts (§3 mandate: "Guardian ON + capture absent ≠ active protection").
        let active = (observation == .analyzing) && (validity == .valid)

        return GuardianRealityProjectionV1(observation: observation, decisionValidity: validity,
                                           presentation: presentation, islandSurfaceRaw: surface,
                                           activeProtection: active)
    }

    /// §3.1 — the observation axis. Strict rungs: OFF → REQUESTED → CAPTURE_STARTED → OBSERVING → ANALYZING, with a
    /// DEGRADED off-ramp when IPC is broken while the user wants it on.
    private static func deriveObservation(_ f: GuardianRealityFactsV1) -> GuardianObservationStateV1 {
        guard f.userRequestedOn else { return .off }
        // The user wants it on. If the IPC channel is down we cannot trust any downstream fact → DEGRADED (honest:
        // we requested but cannot confirm). Exception: if the OS capture never even started, REQUESTED is the truth.
        if !f.appGroupIPCWorking {
            return f.osCaptureStarted ? .degraded : .requested
        }
        guard f.osCaptureStarted else { return .requested }
        guard f.framesArriving else { return .captureStarted }
        return f.analysisActive ? .analyzing : .observing
    }

    /// §3.1 (fact 5) — decision validity, DERIVED from the identity/policy/freshness triple. A decision is valid only
    /// when it was produced for the item on screen now, under the live policy, and is still fresh. New item → stale.
    private static func deriveValidity(_ f: GuardianRealityFactsV1) -> GuardianDecisionValidityV1 {
        guard let dItem = f.decisionItemIdentityRevision, let dPolicy = f.decisionPolicyRevision else { return .none }
        // §3.3 — a new item identity invalidates the prior decision FIRST (safety: no green carryover to new content).
        if let cur = f.currentItemIdentityRevision, cur != dItem { return .staleItem }
        if let curPol = f.currentPolicyRevision, curPol != dPolicy { return .stalePolicy }
        if !f.decisionFresh { return .staleFreshness }
        return .valid
    }

    /// §3.2/§3.3 — the presentation tier. We NEVER return `.verified` without an explicit OS-callback proof, which no
    /// public API provides today → `.deviceUnverified` is the honest ceiling once ActivityKit accepts.
    private static func derivePresentation(_ f: GuardianRealityFactsV1) -> GuardianIslandPresentationTierV1 {
        guard f.liveActivityAccepted else { return .notRequested }
        if f.islandPresentationVerified { return .verified }   // reserved: only when a real OS callback sets the fact
        return .deviceUnverified                               // accepted, but on-screen visibility is UNPROVEN
    }
}
