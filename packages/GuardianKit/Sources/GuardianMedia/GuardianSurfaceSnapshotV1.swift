//
//  GuardianSurfaceSnapshotV1.swift — R3 §3: the ONE CANONICAL VERSIONED SURFACE SNAPSHOT every surface reads.
//
//  WHY THIS EXISTS (R3 §3 — the P0 defect): `GuardianLabModel.refreshUserVisibleState()` built the ActivityKit
//  Live-Activity state from the OLDER `GuardianSessionProjection` + `currentSurface`, while `realityProjection`
//  (GuardianRealityProjectionV1) existed on a SEPARATE path. Two projections could DISAGREE — the Live Activity could
//  show a carried-over GUARDIAN_ON while reality said STALE_ITEM. There must be ONE snapshot, derived once, that
//  ProductHomeView, Live Insight, the ActivityKit writer, and the timeline ALL read. This type is that snapshot.
//
//  It is DERIVED from `GuardianRealityProjectionV1` (the truth projection) PLUS the independent facts the projection
//  does not carry (session id, applied analysis state, item identities, policy revision, decision timestamp/reason,
//  evidence coverage, update/presentation status). It performs NO new safety reasoning — the surface + activeProtection
//  come straight from the reality projection, so there is no second decision engine (mandate: "Yeni bağımsız karar
//  motoru oluşturma"). The ActivityKit writer reads ONLY `islandSurfaceRaw` + `activeProtection` from here, which are
//  the projection's own values — so the writer can NEVER publish a surface the reality projection did not sanction.
//
//  INVARIANTS (R3 §3, enforced by GuardianSurfaceSnapshotTests):
//    • REALITY says STALE_ITEM  → snapshot.islandSurfaceRaw == "UNKNOWN", activeProtection == false → the writer
//      cannot publish the previous GUARDIAN_ON.
//    • REALITY says CAPTURE_NOT_RUNNING (requested/captureStarted/off/degraded) → canShowLiveProtection == false →
//      no "live protection" band.
//    • REALITY says UNKNOWN → no safe-looking numerical/positive value leaks (islandSurfaceRaw stays "UNKNOWN").
//
//  PURE + headless + Codable (so it can also cross the App Group unchanged if a future push path needs it). Lives in
//  GuardianMedia (GuardianCore is frozen), dual-compiled into the app (and harmlessly into the extension).
//
import Foundation

public struct GuardianSurfaceSnapshotV1: Sendable, Equatable, Codable {
    /// Schema version so a future reader can migrate without guessing.
    public static let schemaVersion = "guardian-surface-snapshot-v1"
    public let schemaVersion: String

    // --- Identity / provenance (the independent facts, carried verbatim — never inferred) ---
    public let sessionID: String
    public let currentItemIdentityRevision: Int?   // what is on screen NOW (nil = no per-content identity yet)
    public let decisionItemIdentityRevision: Int?  // what the last decision was produced FOR
    public let policyRevision: UInt64
    public let decisionEpochSeconds: Double        // the DECISION's own timestamp (0 = none)
    public let decisionReasonRaw: String           // the lock-safe reason code raw (never rule text / content)

    // --- Derived axes (straight from GuardianRealityProjectionV1 — NOT re-decided here) ---
    public let observationRaw: String              // GuardianObservationStateV1.rawValue
    public let decisionValidityRaw: String         // GuardianDecisionValidityV1.rawValue
    public let presentationRaw: String             // GuardianIslandPresentationTierV1.rawValue
    /// The lock-safe surface the Island should show. Equals the reality projection's `islandSurfaceRaw` — UNKNOWN
    /// (gray) on any non-valid decision, OFF when off, never a carried-over green.
    public let islandSurfaceRaw: String
    /// True ONLY when protection is genuinely active (analyzing + valid current-item decision). The single flag the
    /// ActivityKit writer/HUD gate on for "koruma aktif".
    public let activeProtection: Bool
    /// Evidence coverage for the current decision (lock-safe raw; e.g. "TEXT" / "VISUAL" / "NONE" / "UNKNOWN").
    public let evidenceCoverageRaw: String

    public init(sessionID: String,
                currentItemIdentityRevision: Int?,
                decisionItemIdentityRevision: Int?,
                policyRevision: UInt64,
                decisionEpochSeconds: Double,
                decisionReasonRaw: String,
                observationRaw: String,
                decisionValidityRaw: String,
                presentationRaw: String,
                islandSurfaceRaw: String,
                activeProtection: Bool,
                evidenceCoverageRaw: String,
                schemaVersion: String = GuardianSurfaceSnapshotV1.schemaVersion) {
        self.sessionID = sessionID
        self.currentItemIdentityRevision = currentItemIdentityRevision
        self.decisionItemIdentityRevision = decisionItemIdentityRevision
        self.policyRevision = policyRevision
        self.decisionEpochSeconds = decisionEpochSeconds
        self.decisionReasonRaw = decisionReasonRaw
        self.observationRaw = observationRaw
        self.decisionValidityRaw = decisionValidityRaw
        self.presentationRaw = presentationRaw
        self.islandSurfaceRaw = islandSurfaceRaw
        self.activeProtection = activeProtection
        self.evidenceCoverageRaw = evidenceCoverageRaw
        self.schemaVersion = schemaVersion
    }

    /// R3 §3 — DERIVE the one canonical snapshot from the reality projection + the independent facts. This is the ONLY
    /// place the snapshot is built. It copies the projection's surface/activeProtection verbatim (no re-decision), so
    /// every reader is guaranteed consistent with the truth projection.
    public static func derive(projection: GuardianRealityProjectionV1,
                              sessionID: String,
                              currentItemIdentityRevision: Int?,
                              decisionItemIdentityRevision: Int?,
                              policyRevision: UInt64,
                              decisionEpochSeconds: Double,
                              decisionReasonRaw: String,
                              evidenceCoverageRaw: String) -> GuardianSurfaceSnapshotV1 {
        GuardianSurfaceSnapshotV1(
            sessionID: sessionID,
            currentItemIdentityRevision: currentItemIdentityRevision,
            decisionItemIdentityRevision: decisionItemIdentityRevision,
            policyRevision: policyRevision,
            decisionEpochSeconds: decisionEpochSeconds,
            decisionReasonRaw: decisionReasonRaw,
            observationRaw: projection.observation.rawValue,
            decisionValidityRaw: projection.decisionValidity.rawValue,
            presentationRaw: projection.presentation.rawValue,
            islandSurfaceRaw: projection.islandSurfaceRaw,   // UNKNOWN on stale/any-non-valid — never carried green
            activeProtection: projection.activeProtection,
            evidenceCoverageRaw: evidenceCoverageRaw)
    }

    // --- Read-only gates every surface uses (so the gating logic lives in ONE place) ---

    /// §3 invariant — the capture is genuinely observing (the OS broadcast is live AND frames arrive). Only then may a
    /// surface claim "live protection". OFF / REQUESTED / CAPTURE_STARTED / DEGRADED all return false.
    public var captureRunning: Bool {
        observationRaw == GuardianObservationStateV1.observing.rawValue
            || observationRaw == GuardianObservationStateV1.analyzing.rawValue
    }

    /// §3 invariant — a surface may show LIVE PROTECTION only when capture is running AND protection is genuinely
    /// active. CAPTURE_NOT_RUNNING can never show live protection; a stale decision can never show live protection.
    public var canShowLiveProtection: Bool { captureRunning && activeProtection }

    /// §3 invariant — true when the current decision is for a DIFFERENT item than what is on screen now (STALE_ITEM).
    /// The writer must NOT publish the prior surface in this case (the snapshot already collapses it to UNKNOWN).
    public var isStaleItem: Bool { decisionValidityRaw == GuardianDecisionValidityV1.staleItem.rawValue }

    /// §3 invariant — the surface the ActivityKit writer should publish. Identical to `islandSurfaceRaw`; exposed as a
    /// named accessor so call sites read the INTENT ("what the Island shows") rather than reaching for a field and
    /// risking a second code path. UNKNOWN/OFF are honest gray; a green only ever appears when the projection allowed.
    public var islandPublishSurfaceRaw: String { islandSurfaceRaw }
}
