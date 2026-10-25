//
//  LocalLearningStoreV1.swift — §3.3/§6: the DURABLE, PRIVACY-BOUNDED persistence for Personal Learning V1.
//
//  WHAT THIS IS: the on-device, APP-PRIVATE store for (a) the learning ON/OFF toggle and the first-run consent
//  flag, and (b) the DURABLE proposals (pending + decided). It holds NO raw OCR/audio/transcript/screenshot and NO
//  content-id history — only the LocalLearningProposalV1 records (rule IDs, counts, dates, kinds, from→to, reason).
//  The volatile distinctness aggregates live ONLY in the engine's RAM and are NEVER written here (§3.3).
//
//  PRIVACY / KVKK (mandate §6 — NO "KVKK zero" claim, but real controls):
//   • App-private container (Application Support / an injected test dir). This is NOT the shared App Group — learning
//     evidence does not need the extension and must not widen its exposure surface.
//   • File protection .complete on the file (encrypted at rest when the device is locked).
//   • isExcludedFromBackup is SET (evaluated + decided: learning evidence should not propagate to iCloud/iTunes
//     backups — it is cheap, device-local, and regenerable from future explicit signals; excluding it keeps the
//     derived personalization strictly on THIS device, matching "global pool'a hiçbir otomatik yol yok", §6).
//   • DELETION really clears: resetAll() removes the file AND zeroes the in-memory engine (tested).
//   • SCHEMA VERSION + corrupt-data recovery: a bad/incompatible blob loads as EMPTY (never a crash, never a
//     silently-wrong success) and is reported, so "bozuk kayıt başarı gibi gösterilmez" (§6).
//
import Foundation
import GuardianCore

/// §3.3 / B1 — the serialized durable payload. Schema-versioned; proposals + (schema v2) the durable learning
/// AGGREGATES + the restart-safe UNDO patch + the install salt. A toggle + consent flag. No raw media.
///
/// SCHEMA HISTORY:
///   v1 — learningEnabled, consentShown, proposals.
///   v2 — ADDS: `aggregates` (restart-safe learning progress, mandate B1), `undoPatch` (restart-safe A2 undo),
///        `installSalt` (per-install pseudonymisation salt for content distinctness tokens, mandate B1). A v1 blob is
///        MIGRATED forward (missing fields default to empty / a fresh salt) — never discarded, never crashed.
public struct LocalLearningPersistentV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 2
    public var schema: Int
    public var learningEnabled: Bool
    public var consentShown: Bool                 // §4 — the first-run scope explanation has been shown + answered
    public var proposals: [LearningProposalV1]
    // v2 additions (all optional in the wire format so a v1 blob decodes and migrates):
    public var aggregates: LearningAggregatesSnapshotV1   // B1 — restart-safe independent-evidence counters
    public var undoPatch: LearningUndoPatchV1?            // A2 — restart-safe "last accepted change" inverse patch
    public var installSalt: String                       // B1 — per-install salt for pseudonymised distinctness tokens

    public init(schema: Int = LocalLearningPersistentV1.schemaVersion, learningEnabled: Bool = false,
                consentShown: Bool = false, proposals: [LearningProposalV1] = [],
                aggregates: LearningAggregatesSnapshotV1 = LearningAggregatesSnapshotV1(),
                undoPatch: LearningUndoPatchV1? = nil, installSalt: String = "") {
        self.schema = schema; self.learningEnabled = learningEnabled
        self.consentShown = consentShown; self.proposals = proposals
        self.aggregates = aggregates; self.undoPatch = undoPatch; self.installSalt = installSalt
    }

    // Custom decode so a v1 blob (no aggregates/undoPatch/installSalt) MIGRATES forward instead of failing (mandate B1).
    enum CodingKeys: String, CodingKey { case schema, learningEnabled, consentShown, proposals, aggregates, undoPatch, installSalt }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        self.learningEnabled = try c.decodeIfPresent(Bool.self, forKey: .learningEnabled) ?? false
        self.consentShown = try c.decodeIfPresent(Bool.self, forKey: .consentShown) ?? false
        self.proposals = try c.decodeIfPresent([LearningProposalV1].self, forKey: .proposals) ?? []
        self.aggregates = try c.decodeIfPresent(LearningAggregatesSnapshotV1.self, forKey: .aggregates) ?? LearningAggregatesSnapshotV1()
        self.undoPatch = try c.decodeIfPresent(LearningUndoPatchV1.self, forKey: .undoPatch)
        self.installSalt = try c.decodeIfPresent(String.self, forKey: .installSalt) ?? ""
        // Migrate the schema stamp forward once decoded so a re-save writes the current version.
        self.schema = LocalLearningPersistentV1.schemaVersion
    }
}

/// A2 — the restart-safe UNDO patch for the most recently ACCEPTED proposal. Persisting this means "son değişikliği
/// geri al" survives an app restart and still targets the EXACT rule+from/to it was recorded against (never a guess).
public struct LearningUndoPatchV1: Sendable, Equatable, Codable {
    public let proposalID: String
    public let ruleID: String
    public let appliedAction: ShieldAction        // what the rule was set TO when accepted (undo expects this)
    public let priorAction: ShieldAction          // the rule's action BEFORE accept (undo restores this)
    public let appliedUnderRevision: UInt64        // the policy revision produced by the accept write
    public init(proposalID: String, ruleID: String, appliedAction: ShieldAction,
                priorAction: ShieldAction, appliedUnderRevision: UInt64) {
        self.proposalID = proposalID; self.ruleID = ruleID; self.appliedAction = appliedAction
        self.priorAction = priorAction; self.appliedUnderRevision = appliedUnderRevision
    }
}

/// §6 — the honest result of a load: the payload + whether the on-disk data was CORRUPT/incompatible (surfaced, not
/// hidden). `corruptRecovered == true` means a bad blob was found and replaced with an empty payload.
public struct LocalLearningLoadResultV1: Sendable, Equatable {
    public let payload: LocalLearningPersistentV1
    public let corruptRecovered: Bool
    public let fileProtectionComplete: Bool
    public let excludedFromBackup: Bool
}

// MARK: - 1F — CRASH-ATOMIC ACCEPT: the tiny write-ahead INTENT record.
//
// WHY (mandate 1F): accepting a proposal touches THREE separate durable writes that are NOT one atomic operation:
//   (1) the shield RULE FILE (PersonalShieldSharedStoreV1.store.save) ,
//   (2) the UserDefaults POLICY REVISION (bumpPolicyRevision) ,
//   (3) the learning STORE (the proposal marked accepted + the undo patch persisted).
// A crash BETWEEN any two leaves a HALF-APPLIED accept: a rule changed on disk with no record of why, or a proposal
// that re-surfaces as pending for a rule already moved (so a naive re-accept hits actionMismatch forever and the
// applied change has no undo). We close this with a SMALL (proposalID + phase + the from/to the accept targets)
// write-ahead intent file, written BEFORE touching the rule and advanced as each durable write lands. On the NEXT
// launch a recovery scan reads it and either COMPLETES (roll forward the remaining writes) or ROLLS BACK (restore the
// rule to its prior action) — deterministically, from the live rule state. This is a tiny reliable protocol, NOT a
// persistence framework (mandate 1F: "büyük persistence framework YOK").

/// The phase of an in-flight accept. Monotonic: a crash leaves the intent at the LAST phase whose write actually
/// completed, so recovery knows exactly how far the transaction got.
public enum LearningAcceptPhaseV1: String, Sendable, Equatable, Codable {
    /// The intent was recorded; NO durable rule/revision/learning write has happened yet. A crash here = roll back
    /// (nothing was applied) unless the live rule already shows the target (a race the recovery resolves by state).
    case intentRecorded = "INTENT_RECORDED"
    /// `mutateRuleAction` returned `.applied`: the RULE FILE + the POLICY REVISION are both committed, but the LEARNING
    /// store (proposal accepted + undo patch) has NOT yet been persisted. A crash here = roll FORWARD (complete step 3).
    case ruleWritten = "RULE_WRITTEN"
}

/// 1F — the write-ahead intent record. Tiny by design: only what recovery needs to decide completion vs rollback,
/// bound to the SAME rule/action/revision the accept targeted (never a guess). No raw media. Schema-versioned.
public struct LearningAcceptIntentV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    public let proposalID: String
    public let ruleID: String
    public let fromAction: ShieldAction          // the rule's action the accept expects (CAS "from")
    public let toAction: ShieldAction            // the action the accept moves the rule TO
    public let expectedRevision: UInt64          // the policy revision the proposal was formed under
    public var phase: LearningAcceptPhaseV1
    public let startedAtEpoch: Double
    public var appliedRevision: UInt64?          // set when phase reaches .ruleWritten (the new revision from the CAS)

    public init(proposalID: String, ruleID: String, fromAction: ShieldAction, toAction: ShieldAction,
                expectedRevision: UInt64, phase: LearningAcceptPhaseV1 = .intentRecorded,
                startedAtEpoch: Double, appliedRevision: UInt64? = nil,
                schema: Int = LearningAcceptIntentV1.schemaVersion) {
        self.schema = schema; self.proposalID = proposalID; self.ruleID = ruleID
        self.fromAction = fromAction; self.toAction = toAction; self.expectedRevision = expectedRevision
        self.phase = phase; self.startedAtEpoch = startedAtEpoch; self.appliedRevision = appliedRevision
    }
}

/// 1F — the PURE recovery decision. Given the in-flight intent + the LIVE rule/revision state observed at launch,
/// decides what the recovery orchestrator must do to make the half-applied accept whole-or-nothing. This is PURE and
/// exhaustively unit-testable (the 4 mandate crash scenarios map directly onto its cases); the orchestrator
/// (LocalLearningModel) only executes the returned action against the real store — it holds NO policy of its own.
public enum LearningAcceptRecoveryActionV1: Sendable, Equatable {
    /// The accept never applied (rule still at `from`, revision unmoved) → drop the intent, keep the proposal PENDING.
    /// Nothing is written to the rule. (Scenario: crash before/at the very start of the CAS.)
    case rollBackNothingApplied
    /// The rule FILE was written to `to` but the REVISION was NOT bumped (crash inside the CAS, between the two
    /// writes) → BUMP the revision now, mark the proposal accepted, persist the undo patch under the new revision.
    /// This rolls the transaction FORWARD to a consistent applied state. (Scenario 1: rule-written/revision-stale.)
    case completeBumpRevisionThenAccept
    /// The rule + revision were both committed (phase .ruleWritten, OR .intentRecorded observed already-applied) but
    /// the LEARNING store (accepted + undo patch) did not land → mark accepted + persist the undo patch idempotently
    /// under `appliedRevision`. (Scenario 2: revision-advanced/proposal-unsaved; Scenario 3: mid-transaction kill.)
    case completeAcceptOnly(appliedRevision: UInt64)
    /// The world moved on in a way we must NOT clobber: the rule is at some OTHER action (a user edit), or the policy
    /// advanced with the rule NOT at our target — abandon the intent WITHOUT writing. The proposal is re-evaluated by
    /// the normal refresh (it may now actionMismatch and stay pending honestly). (Guards against double/stale applies.)
    case abandonDoNotClobber
    /// The proposal was ALREADY accepted before the crash (idempotent re-accept guard): the rule is at `to`, the
    /// learning store already records it accepted → just clear the intent. (Scenario 4: double-accept.)
    case alreadyComplete
}

public enum LearningAcceptRecoveryV1 {
    /// PURE resolver. `currentRuleAction` nil = the rule no longer exists (deleted) → nothing to complete, abandon.
    /// `proposalAlreadyAccepted` = the learning store already shows this proposal accepted (idempotency input).
    public static func resolve(intent: LearningAcceptIntentV1,
                               currentRuleAction: ShieldAction?,
                               liveRevision: UInt64,
                               proposalAlreadyAccepted: Bool) -> LearningAcceptRecoveryActionV1 {
        guard let current = currentRuleAction else { return .abandonDoNotClobber }   // rule gone → nothing safe to do

        switch intent.phase {
        case .ruleWritten:
            // The CAS returned .applied before the crash: rule + revision are committed, and the coordinator ALWAYS
            // stamps `appliedRevision` when it writes this phase. If it is somehow missing (a hand-authored / older
            // intent), we do NOT fabricate one from `liveRevision` — an unrelated edit may have advanced it, so binding
            // the undo patch to it would be wrong. We abandon instead, surfacing the anomaly rather than papering over
            // it (the applied rule state itself is intact; only the auto-undo is forgone for this corrupt intent).
            guard let applied = intent.appliedRevision else { return .abandonDoNotClobber }
            if current != intent.toAction {
                // The user hand-edited the rule after the crash point → never overwrite; their value wins.
                return .abandonDoNotClobber
            }
            return proposalAlreadyAccepted ? .alreadyComplete : .completeAcceptOnly(appliedRevision: applied)

        case .intentRecorded:
            // The CAS had not confirmed .applied — but the crash may have landed BETWEEN the rule-file write and the
            // revision bump. Decide purely from the observed live state.
            if current == intent.toAction {
                if liveRevision == intent.expectedRevision {
                    // Rule written to target, revision NOT bumped (Scenario 1). Roll forward: bump + accept + undo.
                    return .completeBumpRevisionThenAccept
                }
                if liveRevision > intent.expectedRevision {
                    // Rule + revision both already advanced (the bump DID happen before the crash, intent just not
                    // advanced). If already recorded accepted, done; else complete the learning-store write.
                    return proposalAlreadyAccepted ? .alreadyComplete
                                                   : .completeAcceptOnly(appliedRevision: liveRevision)
                }
                // liveRevision < expected is impossible for a monotonic counter; be safe and abandon.
                return .abandonDoNotClobber
            }
            if current == intent.fromAction && liveRevision == intent.expectedRevision {
                // Nothing was applied before the crash — clean rollback, proposal stays pending.
                return .rollBackNothingApplied
            }
            // Rule at some other action, or revision advanced with the rule not at our target → don't clobber.
            return .abandonDoNotClobber
        }
    }
}

public final class LocalLearningStoreV1: @unchecked Sendable {
    public static let fileName = "personal-learning-v1.json"
    /// 1F — the write-ahead intent file. DELIBERATELY SEPARATE from the main payload so it survives independently of
    /// (and is scanned before) the proposal/undo state: its mere PRESENCE at launch means "an accept was in flight".
    public static let intentFileName = "personal-learning-accept-intent-v1.json"

    private let fileURL: URL
    private let intentURL: URL
    private let fm = FileManager.default
    private let lock = NSLock()

    /// 1F / 2.1 — TEST-ONLY injected failure for the write-ahead intent write, so tests can prove "no durable intent ⇒
    /// no shield mutation" and "a failed phase-advance leaves a recoverable state" deterministically (no filesystem
    /// fragility). The store counts intent writes from 1; a write whose ordinal is in `failIntentWriteOrdinals` returns
    /// false WITHOUT touching disk (the earlier/later writes succeed normally). E.g. {1} fails only the first
    /// (.intentRecorded) write; {2} lets .intentRecorded + CAS succeed then fails the .ruleWritten advance. Production
    /// never sets this (default empty ⇒ real disk writes always).
    public var failIntentWriteOrdinals: Set<Int> = []
    private var intentWriteCount = 0

    /// Default: the app-private Application Support directory (NOT the shared App Group). Learning stays device-local.
    public init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Gen8/learning", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(Self.fileName)
        self.intentURL = dir.appendingPathComponent(Self.intentFileName)
    }

    /// Test / injection initializer — explicit directory (no app container needed).
    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(Self.fileName)
        self.intentURL = directory.appendingPathComponent(Self.intentFileName)
    }

    public var storeURL: URL { fileURL }
    public var intentStoreURL: URL { intentURL }
    public var fileExists: Bool { fm.fileExists(atPath: fileURL.path) }
    public var intentExists: Bool { fm.fileExists(atPath: intentURL.path) }

    /// B1 — generate a fresh, app-private per-install salt (random 128-bit hex). Stored once in the durable payload and
    /// used to pseudonymise content-distinctness tokens so they cannot be cross-referenced to a global id set without
    /// this device's private salt. Regenerated on reset (resetAll) so a wipe genuinely breaks linkage to prior tokens.
    public static func newInstallSalt() -> String {
        var hex = ""
        for _ in 0..<16 { hex += String(format: "%02x", UInt8.random(in: 0...255)) }
        return hex
    }

    /// §6 — LOAD. Missing file ⇒ empty default (NOT corrupt). Undecodable/incompatible ⇒ empty + corruptRecovered.
    public func load() -> LocalLearningLoadResultV1 {
        lock.lock(); defer { lock.unlock() }
        guard fm.fileExists(atPath: fileURL.path) else {
            return LocalLearningLoadResultV1(payload: LocalLearningPersistentV1(), corruptRecovered: false,
                                             fileProtectionComplete: false, excludedFromBackup: false)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(LocalLearningPersistentV1.self, from: data) else {
            // Undecodable/corrupt (NOT a known-schema blob): recover to EMPTY honestly (never crash, never a wrong
            // "success"). A v1 blob is NOT corrupt — the migrating decoder upgrades it to v2 in-place (mandate B1).
            return LocalLearningLoadResultV1(payload: LocalLearningPersistentV1(), corruptRecovered: true,
                                             fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
        }
        return LocalLearningLoadResultV1(payload: decoded, corruptRecovered: false,
                                         fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
    }

    /// §6 — SAVE with file protection .complete + isExcludedFromBackup. Atomic write. Returns true on success.
    @discardableResult
    public func save(_ payload: LocalLearningPersistentV1) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        do {
            try data.write(to: fileURL, options: [.atomic])
            applyFileProtection()
            applyExcludedFromBackup()
            return true
        } catch { return false }
    }

    /// §6 — DELETION really clears: remove BOTH the payload AND any in-flight intent. After this, load() returns an
    /// empty default (no residue) and no half-applied accept can be "recovered" from a wiped install.
    @discardableResult
    public func resetAll() -> Bool {
        lock.lock(); defer { lock.unlock() }
        try? fm.removeItem(at: intentURL)   // 1F — a wipe cancels any pending recovery (best-effort; absence = OK)
        guard fm.fileExists(atPath: fileURL.path) else { return true }
        do { try fm.removeItem(at: fileURL); return true } catch { return false }
    }

    // MARK: - 1F — write-ahead accept intent (tiny, atomic, separate file).

    /// 1F — WRITE/UPDATE the write-ahead intent atomically. Called BEFORE the rule write (phase .intentRecorded) and
    /// again right AFTER the CAS applied (phase .ruleWritten). A crash at any point leaves the LAST fully-written
    /// intent on disk for the recovery scan. Atomic write ⇒ the intent file is never torn. Returns true on success.
    @discardableResult
    public func writeAcceptIntent(_ intent: LearningAcceptIntentV1) -> Bool {
        lock.lock(); defer { lock.unlock() }
        intentWriteCount += 1
        if failIntentWriteOrdinals.contains(intentWriteCount) { return false }  // 1F/2.1 test injection
        guard let data = try? JSONEncoder().encode(intent) else { return false }
        do {
            try data.write(to: intentURL, options: [.atomic])
            applyIntentFileProtection()
            return true
        } catch { return false }
    }

    /// 1F — READ the in-flight intent, if any. nil = no accept was in flight at the last clean point (nothing to
    /// recover). A CORRUPT intent is treated as nil AND removed (we never crash, never act on garbage — the worst
    /// case is a lost undo for a change the rule state itself still reveals, which the recovery resolves by state).
    public func readAcceptIntent() -> LearningAcceptIntentV1? {
        lock.lock(); defer { lock.unlock() }
        guard fm.fileExists(atPath: intentURL.path) else { return nil }
        guard let data = try? Data(contentsOf: intentURL),
              let intent = try? JSONDecoder().decode(LearningAcceptIntentV1.self, from: data) else {
            try? fm.removeItem(at: intentURL)   // undecodable → drop it; recovery falls back to rule state
            return nil
        }
        return intent
    }

    /// 1F — CLEAR the intent (the transaction completed OR recovery finished). Idempotent: absence is success.
    @discardableResult
    public func clearAcceptIntent() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard fm.fileExists(atPath: intentURL.path) else { return true }
        do { try fm.removeItem(at: intentURL); return true } catch { return false }
    }

    private func applyIntentFileProtection() {
        #if canImport(UIKit)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: intentURL.path)
        #endif
    }

    // MARK: - §6 privacy attributes (evaluated + applied; honest about platform availability).

    private func applyFileProtection() {
        #if canImport(UIKit)
        // iOS: complete protection (encrypted at rest when locked). macOS/headless tests have no file protection —
        // we do NOT pretend it was set there (honest: the flag simply isn't applicable on that platform).
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
        #endif
    }
    private func protectionIsComplete() -> Bool {
        #if canImport(UIKit)
        let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.protectionKey] as? FileProtectionType) == .complete
        #else
        return false
        #endif
    }
    private func applyExcludedFromBackup() {
        var url = fileURL
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
    private func isExcluded() -> Bool {
        (try? fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup ?? false
    }
}
