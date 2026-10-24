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

/// Reader/writer for the user-controlled session mode over the App Group. Pure IPC plumbing; the idle POLICY (what
/// the extension skips in idle) lives in the extension, driven by the mode this returns.
public enum GuardianSessionModeBridgeV1 {
    public static let modeKey = "guardian.session.mode.v1"

    /// WRITE (app / Control Center side). Stores the user's chosen mode. No-op if the suite is unavailable (DEGRADED).
    public static func write(_ mode: GuardianSessionModeV1, suite: UserDefaults?) {
        suite?.set(mode.rawValue, forKey: modeKey)
    }

    /// READ (extension + app side). Defaults to ACTIVE when nothing is set (a fresh session is active, not idle).
    public static func read(suite: UserDefaults?) -> GuardianSessionModeV1 {
        guard let raw = suite?.string(forKey: modeKey), let m = GuardianSessionModeV1(rawValue: raw) else {
            return .active
        }
        return m
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

    /// CLEAR (session end) — removes the flag so a NEW session starts ACTIVE, never inheriting a prior idle choice.
    public static func clear(suite: UserDefaults?) { suite?.removeObject(forKey: modeKey) }
}
