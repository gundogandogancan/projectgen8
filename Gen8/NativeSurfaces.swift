//
//  NativeSurfaces.swift — Control Center + Live Activity adapters (PROMPT 007 §3,§5,§6,§24)
//  The real WidgetKit Control extension + ActivityKit Live Activity require an Apple Developer Team + a widget
//  extension target + on-device run (PENDING_EXTERNAL_DEPENDENCY). This file holds the code that COMPILES in the app:
//  the App-Group-ready shared activation bridge, the ActivityKit attributes, and the push adapter driven by the
//  headless-tested LiveActivityUpdatePolicy / NativeSurfaceState in GuardianCore. No sensitive Shield text ever leaves the app.
//
import Foundation
import GuardianCore

/// App-Group-ready shared Guardian activation state. Backed by the app group when present, else standard defaults.
/// This is the single source of truth a Control Center extension would read/write.
final class GuardianActivationBridge: @unchecked Sendable {
    static let shared = GuardianActivationBridge()
    static let appGroupID = "group.com.gen8.guardian.dev"   // canonical App Group id (real bundle family); provisioned via each target's .entitlements
    private let key = "guardian.enabled"
    private let defaults: UserDefaults
    /// TRUE when the App Group suite opened (real cross-process IPC); FALSE when we fell back to standard defaults (DEGRADED).
    /// Never silent: the fallback is recorded here and surfaced by P007EvidencePanel so a masked IPC failure cannot pass as success.
    let isAppGroupActive: Bool
    private init() {
        if let suite = UserDefaults(suiteName: Self.appGroupID) {
            defaults = suite
            isAppGroupActive = true
        } else {
            defaults = .standard                 // DEGRADED: app stays functional but cross-process state is NOT shared
            isAppGroupActive = false
        }
    }
    /// Honest, human-readable IPC state for diagnostic surfaces (HUD / evidence panel). Never claims success it can't back.
    var diagnostic: String {
        isAppGroupActive
            ? "ACTIVE · suite=\(Self.appGroupID) (cross-process IPC)"
            : "DEGRADED · App Group unavailable → UserDefaults.standard (NO cross-process IPC)"
    }
    var isEnabled: Bool { defaults.object(forKey: key) as? Bool ?? true }
    func setEnabled(_ on: Bool) { defaults.set(on, forKey: key) }
}

#if canImport(ActivityKit)
import ActivityKit

// GuardianActivityAttributes now lives in Shared/GuardianLiveShared.swift (one canonical type for app + extension).

/// Thin adapter: decides (via the tested update policy) whether to push, and maps to a lock-safe content state.
@available(iOS 16.1, *)
final class GuardianLiveActivityAdapter: @unchecked Sendable {
    private let policy = LiveActivityUpdatePolicy()
    private let engine = GuardianGlyphEngine()

    /// Returns the lock-safe content state to publish, or nil if the update should be suppressed/rejected.
    func contentState(contentID: String, sequence: UInt64, glyph: GlyphFamily, guardianEnabled: Bool,
                      nowNanos: UInt64) -> GuardianActivityAttributes.ContentState? {
        let surface = NativeSurfaceState.from(glyph: glyph, guardianEnabled: guardianEnabled)
        let escalation = (surface == .shieldMatch || surface == .caution)
        let decision = policy.consider(contentID: contentID, sequence: sequence, state: surface,
                                       nowNanos: nowNanos, isSafetyEscalation: escalation)
        guard decision == .accepted else { return nil }
        return .init(surface: surface.rawValue, label: surface.lockSafeLabel, sequence: sequence)
    }
    var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
}
#endif
