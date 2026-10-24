//
//  GuardianObservationHeartbeatV1.swift — A3 FIX: REAL observation-active evidence over App Group IPC.
//
//  WHY THIS EXISTS (A3 — the measured defect): GuardianLabModel synthesized `userStarted`+`osConfirmedActive`
//  whenever the in-app Guardian toggle flipped on, so the UI claimed the session was ACTIVE even though NO real
//  ReplayKit broadcast had started. "The in-app button ≠ the broadcast started." In PRODUCT mode, observation-
//  active must be derived from REAL broadcast-lifecycle evidence: the broadcast extension (a separate process)
//  writes a HEARTBEAT to the shared App Group on each processed-frame cadence; the app reads it and treats the
//  session as active ONLY while the heartbeat is FRESH. A stale/absent heartbeat (IPC unavailable, broadcast
//  stopped/crashed) degrades to DEGRADED/UNAVAILABLE — never "active". No private API: this is UserDefaults in a
//  provisioned App Group suite, the same IPC class GuardianActivationBridge already uses.
//
//  PRIVACY: derived scalars only — a timestamp, a monotonic sequence, a lock-safe surface raw value and a reason
//  code. NEVER raw frames / OCR text / titles. Short-lived by construction (freshness window); cleared on finish.
//
//  This type lives in GuardianMedia (ungoverned) and is dual-compiled into BOTH the Gen8 app and the
//  GuardianBroadcastExtension (same pattern as Tier1IdentityResolutionV1 / Tier1ItemIdentityV1).
//
import Foundation

/// The derived, privacy-safe observation heartbeat the broadcast extension publishes and the app consumes.
public struct GuardianObservationHeartbeatV1: Sendable, Equatable, Codable {
    /// Wall-clock capture instant (seconds since 1970) — compared against the reader's clock for freshness.
    public let epochSeconds: Double
    /// Monotonic per-session sequence — lets the reader reject out-of-order / detect a new session.
    public let sequence: UInt64
    /// Lock-safe surface raw value for the current resolved item (GUARDIAN_ON/CAUTION/SHIELD_MATCH/UNKNOWN/OFF),
    /// or empty while observing with no per-content decision yet. NEVER rule text / titles.
    public let surfaceRaw: String
    /// The current reason code raw value (GuardianReasonCodeV1) — real engine fact, drives the app "Neden?".
    public let reasonCodeRaw: String
    /// Whether the extension believes a broadcast is live (true between broadcastStarted/broadcastFinished).
    public let broadcasting: Bool

    public init(epochSeconds: Double, sequence: UInt64, surfaceRaw: String, reasonCodeRaw: String, broadcasting: Bool) {
        self.epochSeconds = epochSeconds; self.sequence = sequence
        self.surfaceRaw = surfaceRaw; self.reasonCodeRaw = reasonCodeRaw; self.broadcasting = broadcasting
    }
}

/// Reader/writer over the App Group suite. Pure IPC plumbing; freshness policy is explicit and testable.
public enum GuardianObservationHeartbeatBridgeV1 {
    public static let heartbeatKey = "guardian.observation.heartbeat.v1"
    /// How long a heartbeat is considered FRESH. The extension writes at frame cadence (many Hz) but we only need
    /// a generous window that survives a brief stall without ever outliving a stopped broadcast. 3s: a stopped or
    /// crashed broadcast goes UNAVAILABLE within ~3s; a transient frame gap does not flicker the UI.
    public static let freshnessWindowSeconds: Double = 3.0

    /// WRITE (extension side). Encodes the heartbeat into the suite. No-op if the suite is unavailable (DEGRADED).
    public static func write(_ hb: GuardianObservationHeartbeatV1, suite: UserDefaults?) {
        guard let suite, let data = try? JSONEncoder().encode(hb) else { return }
        suite.set(data, forKey: heartbeatKey)
    }

    /// READ (app side). Decodes the last heartbeat, or nil if none/undecodable.
    public static func read(suite: UserDefaults?) -> GuardianObservationHeartbeatV1? {
        guard let suite, let data = suite.data(forKey: heartbeatKey),
              let hb = try? JSONDecoder().decode(GuardianObservationHeartbeatV1.self, from: data) else { return nil }
        return hb
    }

    /// CLEAR (extension broadcastFinished / app session-end). Removes the heartbeat so nothing looks live after stop.
    public static func clear(suite: UserDefaults?) { suite?.removeObject(forKey: heartbeatKey) }

    /// Freshness decision — PURE and testable without any IPC. A heartbeat is fresh iff it exists, claims to be
    /// broadcasting, and its age is within the window. This is the single authority for "is observation active".
    public static func isFresh(_ hb: GuardianObservationHeartbeatV1?, nowEpoch: Double,
                               window: Double = freshnessWindowSeconds) -> Bool {
        guard let hb, hb.broadcasting else { return false }
        let age = nowEpoch - hb.epochSeconds
        return age >= 0 && age <= window
    }

    /// The app-facing freshness classification (drives DEGRADED/UNAVAILABLE honesty).
    public enum Freshness: String, Sendable, Equatable { case active = "ACTIVE", stale = "STALE", absent = "ABSENT" }
    public static func classify(_ hb: GuardianObservationHeartbeatV1?, nowEpoch: Double,
                                window: Double = freshnessWindowSeconds) -> Freshness {
        guard let hb else { return .absent }
        return isFresh(hb, nowEpoch: nowEpoch, window: window) ? .active : .stale
    }
}
