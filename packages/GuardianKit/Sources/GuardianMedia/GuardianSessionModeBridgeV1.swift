//
//  GuardianSessionModeBridgeV1.swift — §5 USER-CONTROLLED ACTIVE/IDLE over the App Group (honest first version).
//
//  WHY THIS EXISTS (mandate §5.1–§5.5): the mandate's north star is a source-aware, adaptive session that goes IDLE
//  when the user leaves the content worth analysing. The HONEST problem (§5.2): reliable APP-IDENTITY from inside a
//  ReplayKit broadcast upload extension is NOT verified on device — RPApplicationInfoBundleIdentifierKey /
//  broadcastAnnotated(withApplicationInfo:) behaviour across iOS versions/foreground changes is DEVICE_UNVERIFIED
//  (see GuardianBroadcastCapabilityProbeV1). Private foreground queries are FORBIDDEN (rule 19; §5.2). So APP-BASED
//  auto-idle is NOT enabled → it is reported FEATURE_UNAVAILABLE. What we CAN ship truthfully TODAY is a USER-
//  CONTROLLED ACTIVE/IDLE switch (§5.5): one tap from the app or the Control Center flips the extension into idle
//  via THIS App Group flag; the extension polls it on the heartbeat cadence. In idle the extension skips the heavy
//  path (OCR/Tier-1/shield commit consumers) and keeps only a cheap heartbeat with an OBSERVING_IDLE state, so the
//  "koruma aktif" claim is suppressed and honesty holds.
//
//  SAME IPC CLASS as GuardianObservationHeartbeatBridgeV1 / GuardianActivationBridge: a UserDefaults flag in the
//  provisioned App Group suite. No private API. nil suite → DEGRADED (the toggle cannot cross processes); callers
//  surface that honestly rather than pretending the extension went idle.
//
//  Dual-compiled into the Gen8 app, the GuardianBroadcastExtension, AND the GuardianControlExtension (same pattern
//  as the heartbeat bridge), so all three agree on the key + semantics with ONE definition.
//
import Foundation

/// The desired session MODE the user selected. ACTIVE = full analysis; IDLE = user paused heavy analysis (cheap
/// heartbeat only). This is INTENT written by the app/Control Center and OBSERVED by the broadcast extension.
public enum GuardianSessionModeV1: String, Sendable, Equatable, Codable {
    case active = "ACTIVE"
    case idle   = "IDLE"
}

/// §B — the extension's APPLIED acknowledgement of the desired mode. The app writes the DESIRED mode; the broadcast
/// extension, once it has actually CONSUMED that mode on its own heartbeat cadence, writes back the mode it applied
/// together with the DESIRED generation it was acking. The app compares desired-vs-applied so the Live Insight can
/// show "İsteniyor/Uygulandı" divergence HONESTLY — a user tap is not "applied" until the extension really consumed
/// it. Empty/absent ack → the extension has not confirmed yet (honest: shown as "Uygulandı: bekleniyor").
public struct GuardianSessionModeAckV1: Sendable, Equatable, Codable {
    /// The mode the extension actually APPLIED (what the heavy-analysis gate is really doing).
    public let appliedMode: GuardianSessionModeV1
    /// The DESIRED generation this ack corresponds to (monotonic; advances on every app write). The app treats the
    /// ack as current only when `ackedGeneration == desiredGeneration`; an older ack means the latest tap is still
    /// in flight to the extension.
    public let ackedGeneration: UInt64
    /// Wall-clock instant the extension wrote this ack (freshness; a dead extension's ack ages out like the heartbeat).
    public let epochSeconds: Double
    public init(appliedMode: GuardianSessionModeV1, ackedGeneration: UInt64, epochSeconds: Double) {
        self.appliedMode = appliedMode; self.ackedGeneration = ackedGeneration; self.epochSeconds = epochSeconds
    }
}

/// Reader/writer for the user-controlled session mode over the App Group. Pure IPC plumbing; the idle POLICY (what
/// the extension skips in idle) lives in the extension, driven by the mode this returns.
///
/// §B — DESIRED vs APPLIED. The app writes DESIRED (mode + a monotonic generation that advances on every write); the
/// extension reads DESIRED and, once it has consumed it, writes APPLIED (an ack carrying the generation it saw). The
/// two are SEPARATE keys so a stale ack can never be mistaken for the live desire, and the app can render the honest
/// divergence ("İsteniyor: Rölanti · Uygulandı: Aktif") while a tap is still crossing processes.
public enum GuardianSessionModeBridgeV1 {
    public static let modeKey = "guardian.session.mode.v1"
    public static let desiredGenerationKey = "guardian.session.mode.desiredGen.v1"
    public static let appliedAckKey = "guardian.session.mode.appliedAck.v1"

    /// WRITE DESIRED (app / Control Center side). Stores the user's chosen mode AND advances the desired generation so
    /// the extension's next ack can be matched to THIS tap. No-op if the suite is unavailable (DEGRADED).
    public static func write(_ mode: GuardianSessionModeV1, suite: UserDefaults?) {
        guard let suite else { return }
        suite.set(mode.rawValue, forKey: modeKey)
        // Advance the desired generation on every write so an applied-ack can be matched to the exact tap it acked.
        let next = (suite.object(forKey: desiredGenerationKey) as? UInt64 ?? 0) &+ 1
        suite.set(next, forKey: desiredGenerationKey)
    }

    /// READ DESIRED (extension + app side). Defaults to ACTIVE when nothing is set (a fresh session is active, not idle).
    public static func read(suite: UserDefaults?) -> GuardianSessionModeV1 {
        guard let raw = suite?.string(forKey: modeKey), let m = GuardianSessionModeV1(rawValue: raw) else {
            return .active
        }
        return m
    }

    /// The live DESIRED generation (0 when nothing was ever written). The app passes this as the ack target; the
    /// extension stamps its ack with the generation it actually observed when it applied the mode.
    public static func desiredGeneration(suite: UserDefaults?) -> UInt64 {
        suite?.object(forKey: desiredGenerationKey) as? UInt64 ?? 0
    }

    /// Convenience predicate the extension polls on its heartbeat cadence.
    public static func isIdle(suite: UserDefaults?) -> Bool { read(suite: suite) == .idle }

    /// Flip the mode (one-tap toggle semantics for the Control Center / app). Returns the NEW mode.
    @discardableResult
    public static func toggle(suite: UserDefaults?) -> GuardianSessionModeV1 {
        let next: GuardianSessionModeV1 = read(suite: suite) == .idle ? .active : .idle
        write(next, suite: suite)
        return next
    }

    /// §B — WRITE APPLIED (extension side). Called by the extension once it has actually consumed the desired mode on
    /// its heartbeat cadence. Stamps the desired generation it saw so the app can tell a current ack from a stale one.
    public static func writeAppliedAck(_ applied: GuardianSessionModeV1, ackedGeneration: UInt64,
                                       nowEpoch: Double, suite: UserDefaults?) {
        guard let suite, let data = try? JSONEncoder().encode(
            GuardianSessionModeAckV1(appliedMode: applied, ackedGeneration: ackedGeneration, epochSeconds: nowEpoch))
        else { return }
        suite.set(data, forKey: appliedAckKey)
    }

    /// §B — READ APPLIED (app side). The extension's last applied-mode ack, or nil if it never acked (honest: the app
    /// then shows "Uygulandı: bekleniyor" rather than pretending the tap took effect).
    public static func readAppliedAck(suite: UserDefaults?) -> GuardianSessionModeAckV1? {
        guard let suite, let data = suite.data(forKey: appliedAckKey),
              let ack = try? JSONDecoder().decode(GuardianSessionModeAckV1.self, from: data) else { return nil }
        return ack
    }

    /// §B — is the extension's applied mode CURRENT with the user's latest desire? True only when a fresh ack exists
    /// AND it acked the live desired generation. A pending tap (generation advanced, no matching ack yet) → false, so
    /// the UI honestly shows the request is still crossing to the extension.
    public static func appliedIsCurrent(suite: UserDefaults?, nowEpoch: Double,
                                        window: Double = GuardianObservationHeartbeatBridgeV1.freshnessWindowSeconds) -> Bool {
        guard let ack = readAppliedAck(suite: suite) else { return false }
        let desiredGen = desiredGeneration(suite: suite)
        let age = nowEpoch - ack.epochSeconds
        return ack.ackedGeneration == desiredGen && age >= 0 && age <= window
    }

    /// CLEAR (session end) — removes the flag so a NEW session starts ACTIVE, never inheriting a prior idle choice.
    public static func clear(suite: UserDefaults?) {
        suite?.removeObject(forKey: modeKey)
        suite?.removeObject(forKey: desiredGenerationKey)
        suite?.removeObject(forKey: appliedAckKey)
    }
}
