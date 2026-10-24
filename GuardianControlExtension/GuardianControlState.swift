//
//  GuardianControlState.swift — shared activation read/write for the Control extension (PROMPT 007A §7,§9)
//  App-Group-ready; falls back to standard defaults when no App Group entitlement is provisioned (R1).
//  The App Group id is the canonical group.com.gen8.guardian.dev, provisioned via each target's .entitlements.
//  Fallback is NEVER silent: isAppGroupActive records whether real cross-process IPC with the app actually opened.
//
import Foundation

final class GuardianControlState: @unchecked Sendable {
    static let shared = GuardianControlState()
    static let appGroupID = "group.com.gen8.guardian.dev"   // canonical App Group id — must match the app (GuardianActivationBridge.appGroupID)
    private let key = "guardian.enabled"
    private let defaults: UserDefaults
    /// TRUE when the shared App Group suite opened; FALSE when degraded to standard defaults (toggle would NOT reach the app).
    let isAppGroupActive: Bool
    private init() {
        if let suite = UserDefaults(suiteName: Self.appGroupID) {
            defaults = suite
            isAppGroupActive = true
        } else {
            defaults = .standard                 // DEGRADED: control toggle stays local; it does NOT cross to the app process
            isAppGroupActive = false
        }
    }
    var isEnabled: Bool { defaults.object(forKey: key) as? Bool ?? true }
    func setEnabled(_ on: Bool) { defaults.set(on, forKey: key) }

    /// §6 — the App Group suite the broadcast extension reads the user-controlled session mode from. nil when
    /// DEGRADED (no entitlement): the idle toggle cannot reach the extension and we surface that honestly.
    var suite: UserDefaults? { isAppGroupActive ? defaults : nil }

    /// §6 — the live broadcast heartbeat (so the Control Center can show a TRUTHFUL state: a broadcast is only
    /// "aktif" when a FRESH heartbeat proves it — never from the Guardian intent toggle alone, mandate §6).
    var heartbeatFresh: Bool {
        guard let suite else { return false }
        let hb = GuardianObservationHeartbeatBridgeV1.read(suite: suite)
        return GuardianObservationHeartbeatBridgeV1.isFresh(hb, nowEpoch: Date().timeIntervalSince1970)
    }

    /// §6 — the user-controlled IDLE flag (shared with the broadcast extension via GuardianSessionModeBridgeV1).
    var isIdle: Bool { GuardianSessionModeBridgeV1.isIdle(suite: suite) }
    func setIdle(_ idle: Bool) { GuardianSessionModeBridgeV1.write(idle ? .idle : .active, suite: suite) }

    /// §6 — the four honest Control Center states. "aktif" requires a FRESH broadcast heartbeat (not just the intent
    /// toggle). Guardian OFF → kapalı. Guardian ON + no broadcast yet → izin-bekliyor (needs the system picker). ON +
    /// live broadcast + idle → rölanti. ON + live broadcast + active → aktif.
    enum ControlDisplayState: String { case off, permissionPending, idle, active }
    var displayState: ControlDisplayState {
        if !isEnabled { return .off }
        guard heartbeatFresh else { return .permissionPending }   // ON intent but no live broadcast yet
        return isIdle ? .idle : .active
    }
}
