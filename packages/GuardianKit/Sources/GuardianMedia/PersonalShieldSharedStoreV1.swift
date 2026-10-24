//
//  PersonalShieldSharedStoreV1.swift — B1/B2: the user's REAL personal-shield rules, shared across processes.
//
//  WHY THIS EXISTS (mandate B — the measured defect): the broadcast extension (SampleHandler) evaluated a
//  HARDCODED demo rule `textExact:"spoiler"`, while the user's real rules lived only in the app's Application
//  Support directory — which is APP-PRIVATE and NOT visible to the extension process. So the cross-app shield pass
//  could never match anything the user actually configured. This adapter closes that gap WITHOUT touching frozen
//  GuardianCore: it points the FROZEN FileBackedPersonalShieldStore / ShieldStoreManager at the shared App Group
//  container, so BOTH the app (writer) and the extension (reader) see the same durable rule set. It consumes the
//  frozen public APIs only — it adds nothing to the matching/evaluation semantics.
//
//  POLICY VERSIONING (mandate B2 / security law): every rule mutation bumps a monotonic `policyRevision` persisted
//  in the shared App Group suite. A decision carries the revision it was produced under; when the user changes a
//  rule the revision advances, and any decision stamped with an older revision is STALE and must not be reused.
//  This is the "preference changed → previous decision invalidated" guarantee, enforced by a pure comparison.
//
//  PRIVACY / HONESTY (mandate B1): rules are stored on-device only, in the provisioned App Group container (file
//  protection complete, inherited from the frozen store). They are user-editable and fully DELETABLE via wipe().
//  Raw reference media is never persisted (frozen-store contract). When the App Group container is unavailable the
//  adapter degrades HONESTLY to the app-private Application Support directory and reports `sharedContainerActive =
//  false` — the extension then has NO rules to read and says so, rather than pretending to protect.
//
//  This type lives in GuardianMedia (ungoverned) and is dual-compiled into BOTH the Gen8 app and the
//  GuardianBroadcastExtension — identical pattern to GuardianObservationHeartbeatV1 / GuardianSessionTimelineV1.
//
import Foundation
import GuardianCore

/// Resolves the directory the personal-shield durable store lives in. Prefers the shared App Group container (so
/// the extension can read what the app wrote); falls back HONESTLY to the app-private Application Support dir.
public enum PersonalShieldStoreLocationV1 {
    /// The canonical App Group id (kept in sync with GuardianActivationBridge.appGroupID / the .entitlements).
    public static let appGroupID = "group.com.gen8.guardian.dev"
    /// Sub-path inside the chosen container so the shield store never collides with other shared files.
    public static let subdirectory = "Gen8/shield"

    /// (directory, sharedContainerActive). sharedContainerActive == false means we fell back to the app-private dir
    /// (the extension will then see an EMPTY rule set — surfaced honestly, never a silent "no rules == safe").
    public static func resolve(appGroupID: String = appGroupID) -> (directory: URL, sharedContainerActive: Bool) {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return (container.appendingPathComponent(subdirectory), true)
        }
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return (appSupport.appendingPathComponent(subdirectory), false)
    }
}

/// A revision-stamped bundle: the rebuilt index + the live policy revision + the raw rules. The extension loads one
/// of these at broadcast start; the Guardian decisions it produces carry `policyRevision` so a later rule change
/// can invalidate them.
public struct PersonalShieldLoadedPolicyV1: Sendable {
    public let index: ShieldIndex
    public let rules: [ShieldRuleV2]
    public let exceptions: [ShieldException]
    public let policyRevision: UInt64
    public let sharedContainerActive: Bool
    public init(index: ShieldIndex, rules: [ShieldRuleV2], exceptions: [ShieldException],
                policyRevision: UInt64, sharedContainerActive: Bool) {
        self.index = index; self.rules = rules; self.exceptions = exceptions
        self.policyRevision = policyRevision; self.sharedContainerActive = sharedContainerActive
    }
    /// A decision stamped with `stamped` is STALE (must not be reused) once the live revision has advanced past it.
    public static func isStaleDecision(stamped: UInt64, liveRevision: UInt64) -> Bool { stamped < liveRevision }
}

/// Thin façade over the FROZEN ShieldStoreManager + FileBackedPersonalShieldStore, pointed at the shared container,
/// plus a monotonic policy-revision counter in the shared suite. Writer side (app) mutates; reader side (extension)
/// loads. Serial by contract on each side (the app on the MainActor; the extension at broadcastStarted).
public final class PersonalShieldSharedStoreV1: @unchecked Sendable {
    /// The App Group key holding the monotonic policy revision (distinct from heartbeat / timeline keys).
    public static let policyRevisionKey = "guardian.personal.shield.policyRevision.v1"

    private let manager: ShieldStoreManager
    private let store: PersonalShieldStore
    private let suite: UserDefaults?
    public let sharedContainerActive: Bool

    /// Default: resolve the shared container automatically. `suite` carries the revision counter (same App Group).
    public init(appGroupID: String = PersonalShieldStoreLocationV1.appGroupID) {
        let (dir, shared) = PersonalShieldStoreLocationV1.resolve(appGroupID: appGroupID)
        self.sharedContainerActive = shared
        self.suite = UserDefaults(suiteName: appGroupID)
        self.store = FileBackedPersonalShieldStore(directory: dir)
        self.manager = ShieldStoreManager(store: self.store)
    }

    /// Test / injection initializer — explicit directory + suite (no entitlement needed).
    public init(directory: URL, suite: UserDefaults?, sharedContainerActive: Bool = false) {
        self.sharedContainerActive = sharedContainerActive
        self.suite = suite
        self.store = FileBackedPersonalShieldStore(directory: directory)
        self.manager = ShieldStoreManager(store: self.store)
    }

    // MARK: Revision counter (monotonic; shared across processes via the App Group suite)

    public var policyRevision: UInt64 {
        guard let suite else { return 0 }
        return UInt64(bitPattern: suite.object(forKey: Self.policyRevisionKey) as? Int64 ?? 0)
    }
    /// Bump the revision (called by the WRITER on every rule mutation). Returns the new revision.
    @discardableResult
    public func bumpPolicyRevision() -> UInt64 {
        let next = policyRevision &+ 1
        suite?.set(Int64(bitPattern: next), forKey: Self.policyRevisionKey)
        return next
    }

    // MARK: Writer side (app)

    /// Persist the full rule set and bump the revision so any in-flight decision made under the old set is stale.
    @discardableResult
    public func saveRules(_ rules: [ShieldRuleV2], exceptions: [ShieldException] = []) throws -> UInt64 {
        var snap = (try? store.load()) ?? ShieldStoreSnapshot()
        snap.rules = rules
        snap.exceptions = exceptions
        try store.save(snap)
        return bumpPolicyRevision()
    }

    /// FULL on-device deletion (mandate B1: user can delete everything). Wipes the durable store AND resets the
    /// revision counter; a fresh revision still advances so any prior decision is invalidated.
    public func wipeAll() throws {
        try store.wipe()
        bumpPolicyRevision()
    }

    // MARK: Reader side (extension) — load the live policy to run the shield pass against

    /// Load the durable rules, rebuild the (crash-safe, never-trusted-from-disk) index, and attach the live policy
    /// revision. On any load failure returns an EMPTY policy (no rules) — honest: the extension then has nothing to
    /// match and will not claim protection, rather than matching a stale/garbage index.
    public func loadPolicy() -> PersonalShieldLoadedPolicyV1 {
        do {
            let (snap, index) = try manager.loadAndRebuild()
            return PersonalShieldLoadedPolicyV1(index: index, rules: snap.rules, exceptions: snap.exceptions,
                                                policyRevision: policyRevision,
                                                sharedContainerActive: sharedContainerActive)
        } catch {
            return PersonalShieldLoadedPolicyV1(index: ShieldIndex(), rules: [], exceptions: [],
                                                policyRevision: policyRevision,
                                                sharedContainerActive: sharedContainerActive)
        }
    }
}
