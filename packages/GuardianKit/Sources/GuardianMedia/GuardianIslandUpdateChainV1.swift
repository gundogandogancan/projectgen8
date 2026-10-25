//
//  GuardianIslandUpdateChainV1.swift — R2 §D: the EXPLICIT Island update chain with THREE SEPARATE evidence fields
//  and THREE explicit operating states. Never collapse APP GROUP WRITE ≠ ACTIVITYKIT UPDATE ≠ ISLAND PRESENTED.
//
//  WHY THIS EXISTS (mandate §D / §D1): the R1 projection (GuardianRealityProjectionV1) correctly separates
//  "accepted" from "on-screen", but it has no notion of WHO is foregrounded or WHETHER the app-side poller is even
//  running to pump ActivityKit. On iOS the ActivityKit update is driven from the APP process; the broadcast
//  extension can only WRITE to the App Group. When the app is SUSPENDED (user is in Instagram), the app-side poller
//  is NOT running, so an App Group write by the extension does NOT become an ActivityKit update until the app is
//  resumed OR a push-token update path exists. This type makes that gap EXPLICIT and HONEST rather than letting the
//  Island silently look live while it is actually frozen.
//
//  THE THREE EVIDENCE FIELDS (§D — never equated):
//    1. appGroupWrite        — the extension WROTE a fresh decision to the App Group. Proof of IPC write ONLY.
//    2. activityKitUpdate    — the APP actually called Activity.update(...) with that decision. Requires the app to
//                              be RUNNING (foreground, or a background-capable update path). An App Group write alone
//                              never implies this.
//    3. islandPresented      — the Island is PROVEN on screen by an OS callback. No public API provides this today,
//                              so it stays UNVERIFIED (DEVICE_UNVERIFIED) — carried for a future capability only.
//
//  THE THREE OPERATING STATES (§D1):
//    • appForeground               — GEN8 is foreground: the poller runs, a fresh App Group write CAN become an
//                                    ActivityKit update promptly. (Island still DEVICE_UNVERIFIED for presentation.)
//    • appSuspendedOtherForeground — another app (e.g. Instagram) is foreground, GEN8 is suspended: the extension
//                                    writes the App Group, but the app-side poller is NOT running → ActivityKit is
//                                    NOT updated from a fresh write until resume. This is the KNOWN GAP, reported as
//                                    BLOCKED (capability-gated), never pretended to work.
//    • captureEnded                — the broadcast ended / was OS-terminated: no fresh writes; any Live Activity must
//                                    be ended or shown stale→ended, never kept "live".
//
//  This type is PURE + headless (no IPC, no ActivityKit import) so it is exhaustively unit-testable. The app's Island
//  bridge supplies the three evidence fields + the operating state; this derives the honest chain status + a single
//  BLOCKED/gap flag. It lives in GuardianMedia (ungoverned) and compiles into the app (and the extension, harmlessly).
//
import Foundation

/// §D1 — which process is foreground and whether capture is still live. Supplied by the app (it alone knows its own
/// scene phase); the extension cannot observe this, which is exactly why the suspended case is a real gap.
public enum GuardianIslandOperatingStateV1: String, Sendable, Equatable {
    case appForeground = "APP_FOREGROUND"
    case appSuspendedOtherForeground = "APP_SUSPENDED_OTHER_FOREGROUND"
    case captureEnded = "CAPTURE_ENDED"
}

/// §D — the honest status of the Island update chain for the LATEST decision. Each rung is reachable only when its
/// evidence is present; the chain never "skips" a rung by inference.
public enum GuardianIslandChainStatusV1: String, Sendable, Equatable {
    case noDecision = "NO_DECISION"                       // nothing to present yet
    case writtenNotUpdated = "WRITTEN_NOT_UPDATED"        // App Group write done, ActivityKit NOT updated (the gap)
    case updatedPresentationUnverified = "UPDATED_PRESENTATION_UNVERIFIED"  // ActivityKit updated; on-screen UNPROVEN
    case updatedPresentationVerified = "UPDATED_PRESENTATION_VERIFIED"      // reserved: only with a real OS proof
    case endedNotPresenting = "ENDED_NOT_PRESENTING"      // capture ended → the activity must not look live
}

/// §D — the three separate evidence facts + the operating state. A caller fills in only what it can HONESTLY observe.
public struct GuardianIslandUpdateFactsV1: Sendable, Equatable {
    public var operatingState: GuardianIslandOperatingStateV1
    /// 1. The extension wrote a FRESH decision to the App Group (freshness decided by the caller / heartbeat).
    public var appGroupWriteFresh: Bool
    /// 2. The APP actually called Activity.update for that decision (requires the app to be running to pump it).
    public var activityKitUpdateApplied: Bool
    /// 3. An OS callback PROVED the Island is on screen (no public API → stays false in production).
    public var islandPresentationVerified: Bool

    public init(operatingState: GuardianIslandOperatingStateV1,
                appGroupWriteFresh: Bool = false,
                activityKitUpdateApplied: Bool = false,
                islandPresentationVerified: Bool = false) {
        self.operatingState = operatingState
        self.appGroupWriteFresh = appGroupWriteFresh
        self.activityKitUpdateApplied = activityKitUpdateApplied
        self.islandPresentationVerified = islandPresentationVerified
    }
}

/// §D — the derived, honest chain projection. `blockedBySuspension` is the capability-gated KNOWN GAP flag: true when
/// there is a fresh App Group write that CANNOT currently reach ActivityKit because the app is suspended while another
/// app is foreground (no background-capable update path in V1). This is reported, never hidden, never worked around.
public struct GuardianIslandUpdateChainV1: Sendable, Equatable {
    public let status: GuardianIslandChainStatusV1
    public let operatingState: GuardianIslandOperatingStateV1
    public let blockedBySuspension: Bool
    /// A short, lock-safe reason code for the UI/diagnostics (never raw content).
    public let reasonRaw: String

    public init(status: GuardianIslandChainStatusV1, operatingState: GuardianIslandOperatingStateV1,
                blockedBySuspension: Bool, reasonRaw: String) {
        self.status = status; self.operatingState = operatingState
        self.blockedBySuspension = blockedBySuspension; self.reasonRaw = reasonRaw
    }

    /// §D — the PURE derivation. Given the three facts + operating state, produce the honest chain status. Never
    /// upgrades a write into an update, nor an update into a verified presentation.
    public static func derive(_ f: GuardianIslandUpdateFactsV1) -> GuardianIslandUpdateChainV1 {
        // Capture ended: the activity must not look live regardless of leftover writes.
        if f.operatingState == .captureEnded {
            return GuardianIslandUpdateChainV1(status: .endedNotPresenting, operatingState: f.operatingState,
                                               blockedBySuspension: false, reasonRaw: "CAPTURE_ENDED")
        }
        guard f.appGroupWriteFresh else {
            return GuardianIslandUpdateChainV1(status: .noDecision, operatingState: f.operatingState,
                                               blockedBySuspension: false, reasonRaw: "NO_FRESH_WRITE")
        }
        // There IS a fresh write. Did ActivityKit actually update?
        if f.activityKitUpdateApplied {
            if f.islandPresentationVerified {
                return GuardianIslandUpdateChainV1(status: .updatedPresentationVerified, operatingState: f.operatingState,
                                                   blockedBySuspension: false, reasonRaw: "OS_PROVED_ON_SCREEN")
            }
            return GuardianIslandUpdateChainV1(status: .updatedPresentationUnverified, operatingState: f.operatingState,
                                               blockedBySuspension: false, reasonRaw: "ACTIVITYKIT_UPDATED_PRESENTATION_UNVERIFIED")
        }
        // Fresh write but ActivityKit NOT updated. If the app is suspended while another app is foreground, this is
        // the KNOWN GAP (the poller is not running) — flag it as BLOCKED, honestly. If the app is foreground and we
        // still have not updated, that is a transient (poller not yet ticked) — still WRITTEN_NOT_UPDATED, not blocked.
        let suspended = f.operatingState == .appSuspendedOtherForeground
        return GuardianIslandUpdateChainV1(
            status: .writtenNotUpdated, operatingState: f.operatingState,
            blockedBySuspension: suspended,
            reasonRaw: suspended ? "APP_SUSPENDED_ACTIVITYKIT_UPDATE_BLOCKED" : "APP_FOREGROUND_UPDATE_PENDING")
    }
}
