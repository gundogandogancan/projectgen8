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
//  HONESTY: the key defaults to ENABLED when absent (a fresh install is on). nil suite → DEGRADED: the extension
//  cannot read the app's intent, so it must NOT silently assume OFF — it falls back to ENABLED and the app surfaces
//  the DEGRADED IPC state separately (it already does for the heartbeat). This keeps the OFF claim honest: we only
//  short-circuit when we can really read a deliberate OFF.
//
import Foundation

/// The user's product on/off INTENT for Guardian, shared across processes via the App Group. Read by the broadcast
/// extension as the real heavy-analysis gate; written by the app + the Control Center ON/OFF intent.
public enum GuardianAnalysisGateV1 {
    /// The canonical key — MUST match GuardianActivationBridge.key (app) and GuardianControlState.key (control ext).
    public static let enabledKey = "guardian.enabled"

    /// READ (extension + app). Defaults to ENABLED when absent (fresh install is on) and when the suite is nil
    /// (DEGRADED: we cannot read a deliberate OFF, so we do NOT fabricate one — the app surfaces DEGRADED separately).
    public static func isEnabled(suite: UserDefaults?) -> Bool {
        guard let suite else { return true }
        return suite.object(forKey: enabledKey) as? Bool ?? true
    }

    /// WRITE (app / Control Center). No-op if the suite is unavailable (DEGRADED — the toggle stays process-local).
    public static func setEnabled(_ on: Bool, suite: UserDefaults?) {
        suite?.set(on, forKey: enabledKey)
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
