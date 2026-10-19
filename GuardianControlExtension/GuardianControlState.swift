//
//  GuardianControlState.swift — shared activation read/write for the Control extension (PROMPT 007A §7,§9)
//  App-Group-ready; falls back to standard defaults when no App Group entitlement is provisioned (R1).
//  NOTE: the App Group id below is PROPOSED only — not registered, not an identity change (see P007A_R2_SIGNING_HANDOFF).
//
import Foundation

final class GuardianControlState: @unchecked Sendable {
    static let shared = GuardianControlState()
    static let proposedAppGroupID = "group.com.aymedo.Gen8"   // PROPOSED — not created/registered in this prompt
    private let key = "guardian.enabled"
    private let defaults: UserDefaults
    private init() { defaults = UserDefaults(suiteName: Self.proposedAppGroupID) ?? .standard }
    var isEnabled: Bool { defaults.object(forKey: key) as? Bool ?? true }
    func setEnabled(_ on: Bool) { defaults.set(on, forKey: key) }
}
