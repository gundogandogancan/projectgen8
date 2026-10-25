//
//  GuardianAnalysisGateV1.swift — §A: the REAL cross-process analysis gate for `guardian.enabled`.
//
//  THE DEFECT THIS FIXES (mandate A): the Control Center `GuardianToggleIntent` already writes `guardian.enabled`
//  to the App Group (GuardianControlState / the app's GuardianActivationBridge), but NOTHING in the broadcast
//  extension ever CONSUMED it as a real analysis gate — the SampleHandler only honoured the user-controlled IDLE
//  mode. So "Guardian OFF" did not actually stop heavy analysis in the running broadcast: the extension kept running
//  OCR / Tier-1 / shield commits. That is a dishonest OFF (constitution rules 1 & 18: never claim a state we aren't
//  really in). This bridge is the SHARED reader the extension uses so OFF genuinely short-circuits the heavy path.
//
//  WHY A SEPARATE TYPE (not the app's GuardianActivationBridge): that bridge lives in the Gen8 app target
//  (NativeSurfaces.swift) and is NOT compiled into the broadcast extension. This type lives in GuardianMedia and is
//  dual-compiled into the app AND the extension (same pattern as GuardianObservationHeartbeatV1 /
//  GuardianSessionModeBridgeV1), reading the SAME App Group key `guardian.enabled`, so all processes agree with ONE
//  definition. It NEVER grants capture iOS doesn't provide; it only reflects the user's product on/off intent.
//
//  HONESTY (mandate A1 — TWO SEPARATE QUESTIONS, never conflated):
//   • BROADCAST LIVENESS: is the OS screen feed physically live? iOS owns it; it continues regardless of our intent.
//     For this question the ENABLED default on an absent/unreadable key is fine — we never claim we stopped the feed.
//   • ANALYSIS CONSENT: may we run the heavy per-content analysis path? This is a CONSENT question, and the A1 defect
//     was that `isEnabled` fail-OPEN meant an UNKNOWN / unreadable control state was treated as a valid "yes, analyse".
//     Unknown ≠ consent (constitution rule 7: UNKNOWN ≠ a verdict). So the ANALYSIS gate is FAIL-CLOSED: when we cannot
//     read a deliberate ENABLED intent (nil suite, missing key, or an unacknowledged OFF still in flight) we must NOT
//     run heavy analysis — we abstain. `isEnabled` is kept as the RAW intent reader (ENABLED-default) for the liveness
//     projection and the Control Center; the new `analysisConsent(...)` is the honest fail-closed gate the heavy path
//     must consult.
//
//  SESSION-SCOPED OFF ACK (mandate A1, reusing the applied-ACK pattern from GuardianSessionModeBridgeV1): an OFF
//  REQUEST is only honoured as "really applied" once the running analysis process has ACKed it for THIS session. The
//  ack carries the session id + the desired generation it applied, so a stale ack from a previous session (or an older
//  desired generation) can never read as a current OFF confirmation — the app shows İsteniyor vs Uygulandı honestly.
//
import Foundation

/// The user's product on/off INTENT for Guardian, shared across processes via the App Group. Read by the broadcast
/// extension as the real heavy-analysis gate; written by the app + the Control Center ON/OFF intent.
public enum GuardianAnalysisGateV1 {
    /// The canonical key — MUST match GuardianActivationBridge.key (app) and GuardianControlState.key (control ext).
    public static let enabledKey = "guardian.enabled"

    /// RAW intent reader. Defaults to ENABLED when absent (fresh install is on) and when the suite is nil (DEGRADED).
    /// Use for the BROADCAST-LIVENESS projection + the Control Center mirror — NOT as the heavy-analysis consent gate
    /// (for that, use `analysisConsent(...)`, which is fail-closed). Kept ENABLED-default so the liveness projection
    /// and existing readers are unchanged.
    public static func isEnabled(suite: UserDefaults?) -> Bool {
        guard let suite else { return true }
        return suite.object(forKey: enabledKey) as? Bool ?? true
    }

    /// WRITE (app / Control Center). No-op if the suite is unavailable (DEGRADED — the toggle stays process-local).
    /// Bumps the DESIRED GENERATION so the analysing process's OFF-ACK can be matched against the exact intent it
    /// applied (a later toggle advances the generation and invalidates an ack that applied an earlier one).
    public static func setEnabled(_ on: Bool, suite: UserDefaults?) {
        suite?.set(on, forKey: enabledKey)
        bumpDesiredGeneration(suite: suite)
    }

    /// The monotonic DESIRED-intent generation (shared via the suite). Advances on every `setEnabled` so the OFF-ACK
    /// can prove it applied the CURRENT intent, not a superseded one. Absent ⇒ 0.
    public static let desiredGenerationKey = "guardian.analysis.desiredGeneration.v1"
    public static func desiredGeneration(suite: UserDefaults?) -> UInt64 {
        guard let suite else { return 0 }
        return UInt64(bitPattern: suite.object(forKey: desiredGenerationKey) as? Int64 ?? 0)
    }
    @discardableResult
    public static func bumpDesiredGeneration(suite: UserDefaults?) -> UInt64 {
        let next = desiredGeneration(suite: suite) &+ 1
        suite?.set(Int64(bitPattern: next), forKey: desiredGenerationKey)
        return next
    }

    // MARK: - A1 FAIL-CLOSED ANALYSIS CONSENT

    /// The honest resolution of "may we run heavy analysis right now?" — distinct from broadcast liveness.
    public enum AnalysisConsentV1: String, Sendable, Equatable {
        /// A deliberate, readable ENABLED intent → the heavy path may run.
        case consented = "CONSENTED"
        /// A deliberate, readable OFF intent → do NOT analyse (user turned Guardian off).
        case deniedOff = "DENIED_OFF"
        /// We could not read a deliberate ENABLED intent (nil suite / missing key). Unknown ≠ consent → ABSTAIN:
        /// the heavy path must NOT run, and the app surfaces this as an UNAVAILABLE/degraded analysis state (NOT a
        /// green "protected"). This is the A1 fix: UNKNOWN control state is never treated as a yes.
        case unknownAbstain = "UNKNOWN_ABSTAIN"

        /// The single boolean the heavy path consults: analysis may run ONLY when consent is explicitly CONSENTED.
        public var mayRunAnalysis: Bool { self == .consented }
    }

    /// FAIL-CLOSED analysis-consent resolver. Analysis is permitted ONLY when we can read a DELIBERATE ENABLED intent.
    ///   • nil suite              → .unknownAbstain (cannot read a deliberate intent; unknown ≠ consent)
    ///   • key absent             → .unknownAbstain (fresh/degraded; we do NOT assume consent for the HEAVY path)
    ///   • key == false           → .deniedOff
    ///   • key == true            → .consented
    /// NOTE: the "fresh install is ON" convenience of `isEnabled` is deliberately NOT applied here — a brand-new
    /// install has not yet produced a readable deliberate consent for the heavy per-content path, so we abstain until
    /// the app writes an explicit value (the app writes `true` on first run, flipping this to .consented immediately).
    public static func analysisConsent(suite: UserDefaults?) -> AnalysisConsentV1 {
        guard let suite else { return .unknownAbstain }
        guard let v = suite.object(forKey: enabledKey) as? Bool else { return .unknownAbstain }
        return v ? .consented : .deniedOff
    }
}

/// A1 — the SESSION-SCOPED OFF ACK. An OFF request is only treated as "really applied" once the analysing process has
/// ACKed it for THIS session + the desired generation it applied. Reuses the applied-ACK pattern (session id + acked
/// generation + timestamp) so a stale ack from a previous session or an older generation can never read as current.
/// Stored as a tiny JSON blob in the shared suite under its OWN key (distinct from the session-mode ack).
public struct GuardianAnalysisOffAckV1: Sendable, Equatable, Codable {
    public static let ackKey = "guardian.analysis.offAck.v1"
    /// The session the analysing process was running when it applied the OFF (so a new session invalidates it).
    public let sessionID: String
    /// The desired-intent generation the process had observed when it applied OFF (monotonic; stale gen ⇒ not current).
    public let appliedGeneration: UInt64
    /// True iff the applied state is OFF (analysis genuinely stopped). False means the process is running analysis.
    public let analysisOff: Bool
    public let epochSeconds: Double

    public init(sessionID: String, appliedGeneration: UInt64, analysisOff: Bool, epochSeconds: Double) {
        self.sessionID = sessionID; self.appliedGeneration = appliedGeneration
        self.analysisOff = analysisOff; self.epochSeconds = epochSeconds
    }

    /// WRITE (analysing process, e.g. the broadcast extension) — record that it applied the given OFF/ON state for
    /// this session + generation. No-op on a nil suite (DEGRADED; the app then shows the ack as absent → pending).
    public static func writeAck(_ ack: GuardianAnalysisOffAckV1, suite: UserDefaults?) {
        guard let suite, let data = try? JSONEncoder().encode(ack) else { return }
        suite.set(data, forKey: ackKey)
    }

    /// READ (app) — the last ack, or nil if absent/undecodable.
    public static func readAck(suite: UserDefaults?) -> GuardianAnalysisOffAckV1? {
        guard let suite, let data = suite.object(forKey: ackKey) as? Data else { return nil }
        return try? JSONDecoder().decode(GuardianAnalysisOffAckV1.self, from: data)
    }

    /// CLEAR (session-end cleanup) so a stale ack never survives into the next session as a false confirmation.
    public static func clear(suite: UserDefaults?) { suite?.removeObject(forKey: ackKey) }

    /// A1 — is a DELIBERATE OFF actually CONFIRMED-APPLIED right now? True ONLY when: the user's intent is OFF, AND a
    /// live ack exists for THIS session, AND that ack applied OFF at the CURRENT desired generation. Any mismatch
    /// (no ack, wrong session, stale generation, ack still says running) ⇒ false: the app must NOT claim "koruma
    /// kapatıldı (uygulandı)" — only "İsteniyor" — because we cannot prove the analysing process really stopped. A
    /// silent bypass (intent OFF but analysis still running) is thereby SURFACED, never hidden (acceptance #12).
    public static func offConfirmedApplied(intentOff: Bool, liveSessionID: String, liveDesiredGeneration: UInt64,
                                           suite: UserDefaults?) -> Bool {
        guard intentOff else { return false }
        guard let ack = readAck(suite: suite) else { return false }
        return ack.analysisOff && ack.sessionID == liveSessionID && ack.appliedGeneration == liveDesiredGeneration
    }
}

/// §B — the HONEST separation the mandate demands: BROADCAST state (is the OS screen feed physically live?) and
/// ANALYSIS state (is the heavy per-content path really running?) are DISTINCT booleans, never one "protected" flag.
/// A broadcast can be live while analysis is OFF (Guardian disabled OR user-controlled idle): the OS red bar keeps
/// running — we never claim we stopped it — yet we make NO protection claim. This pure projection is what the app
/// reads to render the two facts separately, so "yayın sürüyor" and "analiz çalışıyor" can never be conflated.
public struct GuardianObservationProjectionV1: Sendable, Equatable {
    /// True iff a FRESH broadcast heartbeat proves the OS screen feed is physically live right now.
    public let broadcasting: Bool
    /// True iff the heavy analysis path is really running: broadcasting AND guardian enabled AND not user-idle.
    /// This is the ONLY boolean that may back an "analiz çalışıyor / koruma aktif" claim.
    public let analysisRunning: Bool
    /// True iff the OS broadcast is physically live but heavy analysis is OFF (disabled or idle). The honest case the
    /// mandate calls out: surface copy must say the OS feed continues even though we are not analysing.
    public var broadcastingButAnalysisOff: Bool { broadcasting && !analysisRunning }

    public init(broadcasting: Bool, analysisRunning: Bool) {
        self.broadcasting = broadcasting; self.analysisRunning = analysisRunning
    }

    /// PURE projection — the single authority for the two separate booleans. `guardianEnabled` is the product on/off
    /// intent (GuardianAnalysisGateV1); `broadcastFresh` is the real heartbeat freshness; `userIdle` is the desired
    /// idle mode. Analysis runs ONLY when all three agree (live feed + enabled + not idle). OFF never looks live;
    /// ON-without-a-fresh-heartbeat never claims analysis.
    public static func project(guardianEnabled: Bool, broadcastFresh: Bool, userIdle: Bool) -> GuardianObservationProjectionV1 {
        GuardianObservationProjectionV1(broadcasting: broadcastFresh,
                                        analysisRunning: broadcastFresh && guardianEnabled && !userIdle)
    }
}
