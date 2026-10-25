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
    /// §1.1 — the rule IDs whose UNSAFE sound action was DOWNGRADED to WARN on load (a legacy soundClass+HIDE rule
    /// already on disk). Non-empty ⇒ the UI must show a visible "limited to WARN" flag for these rules; never silent.
    public let soundRulesDowngraded: [String]
    public init(index: ShieldIndex, rules: [ShieldRuleV2], exceptions: [ShieldException],
                policyRevision: UInt64, sharedContainerActive: Bool, soundRulesDowngraded: [String] = []) {
        self.index = index; self.rules = rules; self.exceptions = exceptions
        self.policyRevision = policyRevision; self.sharedContainerActive = sharedContainerActive
        self.soundRulesDowngraded = soundRulesDowngraded
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

    /// 1F (TEST/RECOVERY HOOK ONLY) — force the persisted revision to an exact value. Used by the crash-atomicity
    /// coordinator to REPRODUCE the "rule written, revision not bumped" disk state at an injected failure point (the
    /// frozen CAS performs its two writes internally, so there is no live seam to interpose). It is NOT part of the
    /// normal write path (mutations always go through bumpPolicyRevision) and never relaxes a safety law.
    public func setPolicyRevisionForTesting(_ value: UInt64) {
        suite?.set(Int64(bitPattern: value), forKey: Self.policyRevisionKey)
    }

    // MARK: Writer side (app)

    /// Persist the full rule set and bump the revision so any in-flight decision made under the old set is stale.
    /// §1.1 — SOUND-RULE SAFETY AT THE SAVE BOUNDARY: a `.soundClass`/`.audioReference` rule bound to a controlled
    /// EXECUTE action (hide/blur/mute/skip) is DOWNGRADED to WARN BEFORE it is written, so a freshly composed unsafe
    /// rule can never reach the durable store the app AND the extension read. The downgrade is applied by the shared
    /// pure `SoundRuleSafetyV1` validator (the same one the Personal Learning proposal engine uses), so there is ONE
    /// law, enforced at the store door rather than only in the UI (mandate §1.1). The write is of the SANITIZED set.
    @discardableResult
    public func saveRules(_ rules: [ShieldRuleV2], exceptions: [ShieldException] = []) throws -> UInt64 {
        let sanitized = SoundRuleSafetyV1.sanitize(rules).rules
        var snap = (try? store.load()) ?? ShieldStoreSnapshot()
        snap.rules = sanitized
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

    // MARK: A1/A2 — TRANSACTIONAL (compare-and-swap) single-rule action mutation.
    //
    // WHY (mandate A1): Personal Learning "accept" must be ATOMIC — a proposal may only change a rule if that rule is
    // STILL in the exact action the proposal was formed against, and the policy has not advanced underneath it. The
    // previous accept() path marked a proposal accepted FIRST and wrote the rule SECOND (and never checked the rule's
    // current action), so a store-write failure, a concurrent edit, or a stale proposal could leave disk + memory
    // inconsistent and still show "success". This CAS closes that: the write happens ONLY if the preconditions hold,
    // and the caller marks the proposal accepted ONLY after a SUCCEEDED result — never before (no optimistic accept).
    //
    // A3 (idempotency): applying the SAME move twice is a benign no-op — if the rule's current action already equals
    // `to`, we return `.noOpAlreadyAtTarget` WITHOUT bumping the revision, so a double-accept can never double-apply
    // or spuriously advance the policy.

    /// The honest outcome of a `mutateRuleAction` compare-and-swap.
    public enum ShieldMutationResultV1: Sendable, Equatable {
        /// The write SUCCEEDED. Carries the NEW policy revision (bumped exactly once).
        case applied(newRevision: UInt64)
        /// The rule's current action already equals the requested target — nothing written, revision UNCHANGED (A3).
        case noOpAlreadyAtTarget(revision: UInt64)
        /// The rule no longer exists (deleted since the proposal formed).
        case ruleMissing
        /// The rule's current action is NOT the expected "from" action — a manual edit / a stale proposal. Refused so
        /// an old proposal can never overwrite a value the user changed in the meantime (mandate A1/A2). Carries the
        /// action actually found, for an honest message.
        case actionMismatch(found: ShieldAction)
        /// The live policy revision has advanced past the expected one — the proposal was formed under an older policy.
        case revisionMismatch(found: UInt64)
        /// The durable write itself FAILED (disk error). NOTHING was persisted and the revision was NOT bumped — the
        /// caller MUST keep the proposal pending and surface the error (never a false "accepted").
        case writeFailed
    }

    /// A1/A2 — COMPARE-AND-SWAP a single rule's action. Reloads the CURRENT durable snapshot, verifies the rule exists,
    /// that its current action equals `expectedAction`, and (when `expectedRevision` is supplied) that the live policy
    /// revision still matches, THEN writes the full sanitized set and bumps the revision EXACTLY ONCE. Only on a
    /// returned `.applied` has anything changed; every other case leaves disk + revision untouched. This is the ONLY
    /// write path Personal Learning uses so "marked accepted" can never run ahead of a real, verified store write.
    @discardableResult
    public func mutateRuleAction(ruleID: String, expectedAction: ShieldAction, to target: ShieldAction,
                                 expectedRevision: UInt64? = nil) -> ShieldMutationResultV1 {
        // Revision precondition (optimistic concurrency): refuse if the policy advanced since the proposal was formed.
        if let expected = expectedRevision, policyRevision != expected {
            return .revisionMismatch(found: policyRevision)
        }
        var snap = (try? store.load()) ?? ShieldStoreSnapshot()
        guard let i = snap.rules.firstIndex(where: { $0.ruleID == ruleID }) else { return .ruleMissing }
        let current = snap.rules[i].action
        // A3 — idempotent: already at the target ⇒ benign no-op, do NOT write, do NOT bump the revision.
        if current == target { return .noOpAlreadyAtTarget(revision: policyRevision) }
        // A1/A2 — the rule must still be in the exact action the caller expects (the proposal's "from"); a manual edit
        // or a stale proposal fails here and is refused honestly rather than silently overwriting the user's value.
        guard current == expectedAction else { return .actionMismatch(found: current) }
        // §1.1 — the target is sanitized BEFORE the compare so a sound rule can never be CAS'd into a destructive
        // action; if sanitization changes the target to something equal to current, that too is a benign no-op.
        var candidate = snap.rules[i]
        candidate.action = target
        candidate.updatedAtEpoch = Date().timeIntervalSince1970
        let sanitized = SoundRuleSafetyV1.sanitized(candidate)
        if sanitized.action == current { return .noOpAlreadyAtTarget(revision: policyRevision) }
        snap.rules[i] = sanitized
        do {
            try store.save(snap)
        } catch {
            // The write FAILED: nothing persisted, revision NOT bumped. The caller keeps the proposal pending (A1).
            return .writeFailed
        }
        return .applied(newRevision: bumpPolicyRevision())
    }

    // MARK: Reader side (extension) — load the live policy to run the shield pass against

    /// Load the durable rules, rebuild the (crash-safe, never-trusted-from-disk) index, and attach the live policy
    /// revision. On any load failure returns an EMPTY policy (no rules) — honest: the extension then has nothing to
    /// match and will not claim protection, rather than matching a stale/garbage index.
    public func loadPolicy() -> PersonalShieldLoadedPolicyV1 {
        do {
            let (snap, index) = try manager.loadAndRebuild()
            // §1.1 — SOUND-RULE SAFETY AT THE LOAD BOUNDARY: a LEGACY `.soundClass`+HIDE rule already on disk (written
            // before the save-boundary fix, or hand-authored) must ALSO be handled safely. We sanitize the loaded rules
            // and, when anything was downgraded, REBUILD the index from the sanitized set so the matcher the extension
            // runs never sees the unsafe execute action — the rebuilt-from-disk index is never trusted verbatim. The
            // downgraded rule IDs are surfaced (never silent) so MyShieldView can flag them. No frozen store edit.
            let (safeRules, downgraded) = SoundRuleSafetyV1.sanitize(snap.rules)
            let safeIndex: ShieldIndex
            if downgraded.isEmpty {
                safeIndex = index
            } else {
                var rebuilt = ShieldIndex()
                for r in safeRules { rebuilt.upsert(r) }
                safeIndex = rebuilt
            }
            return PersonalShieldLoadedPolicyV1(index: safeIndex, rules: safeRules, exceptions: snap.exceptions,
                                                policyRevision: policyRevision,
                                                sharedContainerActive: sharedContainerActive,
                                                soundRulesDowngraded: downgraded)
        } catch {
            return PersonalShieldLoadedPolicyV1(index: ShieldIndex(), rules: [], exceptions: [],
                                                policyRevision: policyRevision,
                                                sharedContainerActive: sharedContainerActive)
        }
    }
}
