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
}
