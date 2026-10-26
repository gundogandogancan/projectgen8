//
//  ShieldStudioModel.swift — My Shield studio (PROMPT 006A §13,§26,§27)
//  "I don't want to see/hear this." Create rules, evaluate against sample content, preview the Guardian glyph.
//  Personal, local-only state. Low-confidence never silently hides; UNKNOWN never renders a safe glyph.
//
import Foundation
import Observation
import GuardianCore
import GuardianIntelligence
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

@MainActor
@Observable
final class ShieldStudioModel {
    private var index = ShieldIndex()
    private let evaluator: ShieldEvaluatorV2
    private let glyphEngine = GuardianGlyphEngine()
    private let semantic = ShieldSemanticDistance()

    private(set) var rules: [ShieldRuleV2] = []
    var sampleText: String = "A news clip about an earthquake disaster."
    var glyphStyle: GlyphStyle = .minimalSymbols

    // Draft inputs
    var draftLabel: String = ""
    var draftType: ShieldInputType = .textExact
    var draftAction: ShieldAction = .warn

    private(set) var lastOutcome: PersonalShieldDecision = .clear
    private(set) var lastGlyph: GlyphToken?

    /// §1.1 — rule IDs whose UNSAFE sound action (soundClass/audioReference bound to HIDE/BLUR/MUTE/SKIP) was
    /// DOWNGRADED to WARN by the store boundary on load (a legacy rule) OR when the user tried to compose one here.
    /// The UI reads this to show a VISIBLE "limited to WARN" flag — the downgrade is never silent (mandate §1.1).
    private(set) var soundRulesDowngraded: Set<String> = []
    /// §1.1 — would composing a rule of (type, action) be DOWNGRADED by the safety law? The composer consults this to
    /// PREVENT selecting HIDE for a sound rule up front (and to show why), so the limit is explained, not surprising.
    func wouldDowngrade(type: ShieldInputType, action: ShieldAction) -> Bool {
        SoundRuleSafetyV1.isSoundInput(type) && SoundRuleSafetyV1.disallowedSoundActions.contains(action)
    }
    func isDowngraded(_ rule: ShieldRuleV2) -> Bool { soundRulesDowngraded.contains(rule.ruleID) }

    // B1/B2 — durable local store in the SHARED App Group container so the broadcast extension (a separate
    // process) can read the SAME rules the user edits here. Survives relaunch; raw media never persisted; fully
    // deletable via deleteAll(). On every mutation the shared policyRevision is bumped so any in-flight extension
    // decision made under the old rule set is invalidated (mandate B2).
    private let shared = PersonalShieldSharedStoreV1()
    /// Honest IPC state for the UI: true when the shared App Group container is active (the extension can read the
    /// rules); false → DEGRADED (rules stay app-private; cross-app protection cannot be claimed).
    var sharedContainerActive: Bool { shared.sharedContainerActive }
    /// The live policy revision (bumped on every rule change). Shown to the user as a plain version number.
    var policyRevision: UInt64 { shared.policyRevision }

    // A2 — the key that records whether the ONE-TIME first-run seeding has already happened. Persisted in the SAME
    // shared suite as the rules so it survives relaunch. Its purpose is to keep three states DISTINCT (mandate A2):
    //   - genuine first run (never seeded, rules empty)           → may offer the starter examples (user choice)
    //   - empty shield AFTER the user deleted everything (seeded) → stays EMPTY; examples are NOT resurrected
    //   - storage failure (shared container inactive)             → never silently "seeds" or claims success
    private static let seededKey = "guardian.personal.shield.seededStarterRules.v1"
    private var suite: UserDefaults? { UserDefaults(suiteName: PersonalShieldStoreLocationV1.appGroupID) }

    /// True only on a GENUINE first run: the store is healthy (shared container active), empty, and we have never
    /// seeded before. After a delete-all (or any prior seed) this is false, so starter rules never reappear (A2).
    var isGenuineFirstRun: Bool {
        sharedContainerActive && rules.isEmpty && (suite?.bool(forKey: Self.seededKey) != true)
    }

    // C — the last policy revision this model has rendered. The shared store is the SINGLE SOURCE OF TRUTH; when
    // ANOTHER surface (e.g. LocalLearningModel.accept() applying a proposal, or the extension) advances the revision,
    // My Shield must reflect the new rule set WITHOUT an app restart. We track the revision we last loaded and reload
    // when it changes (poll via syncIfPolicyChanged() on the existing refresh cadence / onAppear).
    private var lastLoadedRevision: UInt64 = 0

    init() {
        evaluator = ShieldEvaluatorV2.standard(semanticDistance: semantic.closure)
        let loaded = shared.loadPolicy()
        index = loaded.index; rules = loaded.rules
        lastLoadedRevision = loaded.policyRevision
        soundRulesDowngraded = Set(loaded.soundRulesDowngraded)   // §1.1 — flag legacy soundClass+HIDE rules on load
        evaluate()
    }

    /// C — SINGLE SOURCE OF TRUTH SYNC. Reload the rule set from the shared store IFF the live policy revision has
    /// advanced past what this model last rendered (an accept/undo/delete on another surface, or the extension). Keeps
    /// My Shield + Learning + Reels on the SAME current revision view with no app restart. Returns true if it reloaded.
    /// Cheap: a revision read is a single UserDefaults integer; a full reload only happens on a real change.
    @discardableResult
    func syncIfPolicyChanged() -> Bool {
        let live = shared.policyRevision
        guard live != lastLoadedRevision else { return false }
        let loaded = shared.loadPolicy()
        index = loaded.index
        rules = loaded.rules
        lastLoadedRevision = loaded.policyRevision
        soundRulesDowngraded = Set(loaded.soundRulesDowngraded)
        evaluate()
        return true
    }

    /// A2 — seed the starter example rules EXACTLY ONCE, and ONLY on an explicit user choice (the onboarding/empty
    /// state offers this; nothing seeds automatically). Marks the one-time flag so a later delete-all leaves the
    /// shield genuinely empty forever after. No-op if it isn't a genuine first run (never resurrects examples).
    func seedStarterRulesIfUserChooses() {
        guard isGenuineFirstRun else { return }
        addRule(label: "spoiler", type: .textExact, action: .hideIfControlled)
        addRule(label: "graphic violence", type: .semanticConcept, action: .warn)
        suite?.set(true, forKey: Self.seededKey)
        evaluate()
    }

    func addDraft() {
        let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addRule(label: trimmed, type: draftType, action: draftAction)
        draftLabel = ""
        evaluate()
    }

    /// §7 (R8) — STABLE RULE IDENTITY. New personal rules use a UUID minted AT CREATION (not `String.hashValue`, which
    /// is unstable across process launches — the R2 photo-rule lesson). Legacy `ui-<n>-<hash>` ids already on disk are
    /// tolerated verbatim (we never rewrite a persisted id — that would orphan its photo/alias features and break
    /// delete). The prefix keeps the provenance readable; the UUID guarantees collision-free, relaunch-stable identity.
    static func freshRuleID(_ kind: String) -> String { "ui-\(kind)-\(UUID().uuidString)" }

    func addRule(label: String, type: ShieldInputType, action: ShieldAction) {
        let now = Date().timeIntervalSince1970
        let requested = ShieldRuleV2(ruleID: Self.freshRuleID("text"), inputType: type,
                                     rawUserLabel: label, locale: "en", action: action,
                                     createdAtEpoch: now, updatedAtEpoch: now)
        // §1.1 — apply the SAME sound-safety law locally so the in-memory rule set matches what the store will persist
        // (soundClass/audioReference + HIDE/BLUR/MUTE/SKIP → WARN), and FLAG it visibly if it was downgraded.
        let rule = SoundRuleSafetyV1.sanitized(requested)
        if SoundRuleSafetyV1.isUnsafeSoundRule(requested) { soundRulesDowngraded.insert(rule.ruleID) }
        index.upsert(rule)
        rules.append(rule)
        persist()
    }

    // MARK: §E2 — AUDIO PREFERENCES (the smallest honest version)
    //
    // The user can bind a SOUND CATEGORY to a preference. We deliberately restrict the first version:
    //  • Only labels the classifier's OWN dictionary actually contains are offerable (no made-up categories), so a
    //    rule can never reference a sound the engine can't detect (UNKNOWN/UNAVAILABLE honesty).
    //  • Only WARN/ASK are allowed by default — a calibrated-risk-free sound classification must NOT drive a hard-to-
    //    reverse auto-HIDE/MUTE/SKIP on its own (mandate E2). A stronger action requires explicit opt-in elsewhere.
    //  • The rule is a plain `.soundClass` ShieldRuleV2, so the FROZEN SoundClassMatcher evaluates it — no new engine.

    /// §E2 — the sound categories offerable to the user: the classifier's OWN dictionary (SoundAnalysis built-in
    /// classifier), so we never offer a label the engine can't actually detect. Empty when the classifier is
    /// unavailable on this runtime (then the audio-preference UI honestly shows "ses sınıflandırıcı kullanılamıyor").
    var availableSoundCategories: [String] { Self.soundClassifierDictionary() }

    /// §E2 — the actions a sound preference may use in the FIRST version: WARN/ASK only (reversible, non-destructive).
    /// A classifier label is NOT calibrated risk, so it must not silently HIDE/MUTE/SKIP on its own (mandate E2).
    static let audioPreferenceAllowedActions: [ShieldAction] = [.warn, .ask]

    /// §E2 — add a per-sound-category preference. The `label` MUST be one the classifier dictionary contains, and the
    /// `action` MUST be WARN or ASK; otherwise this is a no-op (we never create a rule the engine can't honour, nor a
    /// destructive audio auto-action in v1). Returns true if a rule was really added.
    @discardableResult
    func addAudioPreference(category label: String, action: ShieldAction) -> Bool {
        let dict = Self.soundClassifierDictionary()
        guard dict.contains(where: { $0.caseInsensitiveCompare(label) == .orderedSame }),
              Self.audioPreferenceAllowedActions.contains(action) else { return false }
        let now = Date().timeIntervalSince1970
        let rule = ShieldRuleV2(ruleID: Self.freshRuleID("audio"), inputType: .soundClass,
                                rawUserLabel: label, locale: "en", action: action,
                                createdAtEpoch: now, updatedAtEpoch: now)
        index.upsert(rule); rules.append(rule); persist(); evaluate()
        return true
    }

    // MARK: §7 (R8) — PERSONAL ALIAS REFERENCE (canonical name + user-typed aliases → live word-boundary match)
    //
    // The user names a reference they want flagged (a public figure, a show, a brand) and the alternate names THEY
    // type for it. On the live OCR path the extension runs PersonalAliasMatchV1 (word-boundary, TR+EN folded) and a
    // real DIRECT mention of the canonical name OR any alias is a DIRECT_REFERENCE personal match (WARN-only on the
    // uncontrolled 3rd-party surface). This is the user's AVOIDANCE PREFERENCE, never a harm verdict about the person.
    // The data rides on the FROZEN ShieldRuleV2 (`.entity` input + `rawUserLabel` canonical + `aliases`), so no new
    // store schema is introduced — the existing versioned tolerant Codable store persists it unchanged.

    /// §7 — the entry-time ambiguity verdict for ONE term (canonical or alias): OK / TOO_SHORT / COMMON_WORD. The UI
    /// shows this as a WARNING before saving so a collision-prone term ("Ali", "ve") is never silently actioned.
    func aliasAmbiguity(of term: String) -> PersonalAliasAmbiguityV1 { PersonalAliasMatchV1.ambiguity(of: term) }

    /// §7 — add a personal alias reference. `canonicalName` is the primary term; `aliases` are the user's alternate
    /// names. Terms are trimmed; empties dropped. Returns the new rule's id (UUID-stable) or nil when the canonical
    /// name is empty. The action is WARN by default (reversible, honest on a 3rd-party surface). Ambiguous terms are
    /// still accepted (the UI warned); the matcher's own min-length / common-word guards prevent false mentions.
    @discardableResult
    func addAliasReference(canonicalName: String, aliases: [String], action: ShieldAction = .warn) -> String? {
        let canonical = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return nil }
        let cleanAliases = aliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let now = Date().timeIntervalSince1970
        let rule = ShieldRuleV2(ruleID: Self.freshRuleID("alias"), inputType: .entity,
                                rawUserLabel: canonical, locale: "tr", aliases: cleanAliases, action: action,
                                createdAtEpoch: now, updatedAtEpoch: now)
        index.upsert(rule); rules.append(rule); persist(); evaluate()
        return rule.ruleID
    }

    /// §7 — EDIT an existing alias reference in place (keeps the SAME stable rule id so delete/relaunch stay coherent).
    /// Replaces the canonical name + alias list. Returns true if the rule existed and was updated.
    @discardableResult
    func updateAliasReference(ruleID: String, canonicalName: String, aliases: [String]) -> Bool {
        guard let i = rules.firstIndex(where: { $0.ruleID == ruleID }) else { return false }
        let canonical = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return false }
        var r = rules[i]
        r.rawUserLabel = canonical
        r.aliases = aliases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        r.updatedAtEpoch = Date().timeIntervalSince1970
        rules[i] = r
        index.upsert(r); persist(); evaluate()
        return true
    }

    /// §7 — the user's alias-reference rules (for the composer list). An `.entity` rule carrying aliases is treated as
    /// an alias reference; a plain entity rule with no aliases still shows (its canonical name is the only term).
    var aliasReferenceRules: [ShieldRuleV2] { rules.filter { $0.inputType == .entity } }

    /// §E2 — the classifier's REAL label dictionary (Apple SoundAnalysis built-in version1), or [] when SoundAnalysis
    /// is unavailable. We read the framework's own known-classifications list so the preference UI is grounded in what
    /// the engine can actually detect — never a fabricated category menu.
    static func soundClassifierDictionary() -> [String] {
        #if canImport(SoundAnalysis)
        if let req = try? SNClassifySoundRequest(classifierIdentifier: .version1) {
            return (try? req.knownClassifications) ?? []
        }
        #endif
        return []
    }

    func delete(_ rule: ShieldRuleV2) {
        index.remove(rule.ruleID)
        rules.removeAll { $0.ruleID == rule.ruleID }
        persist()
        evaluate()
    }

    #if canImport(CoreGraphics)
    /// P1-5 — add a PERSONAL PHOTO REFERENCE. Extracts the local DERIVED visual signature (P006C schema) from the
    /// picked image, persists the image-reference rule + its signature through the shared store (a real policyRevision
    /// is produced), and syncs the in-memory rule list. The raw photo is NEVER persisted. On a third-party surface the
    /// action is WARN-only (rule 18). Returns true if a reference rule was really added.
    @discardableResult
    func addPhotoReference(_ cgImage: CGImage, label: String, action: ShieldAction = .warn) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Fotoğraf referansı" : trimmed
        let now = Date().timeIntervalSince1970
        guard let added = PersonalPhotoShieldV1.addReference(cgImage: cgImage, label: name, action: action,
                                                             nowEpoch: now, store: shared, existingRules: rules) else {
            return false   // honest: signature extraction / store write failed → nothing added
        }
        // Re-sync the in-memory rule list + index from the durable store (so the new image rule + revision show up).
        let loaded = shared.loadPolicy()
        rules = loaded.rules
        index = loaded.index
        lastLoadedRevision = added.revision
        evaluate()
        return true
    }
    #endif

    /// B1 — full on-device deletion of every personal rule (user control). Wipes the shared durable store and
    /// bumps the revision so any extension decision made under the old rules is invalidated.
    func deleteAll() {
        rules.removeAll()
        index = ShieldIndex()
        try? shared.wipeAll()
        lastLoadedRevision = shared.policyRevision   // C — our wipe is the current truth; don't re-reload for it
        // A2 — mark the shield as INTENTIONALLY empty so the starter examples are NEVER re-created on the next launch
        // (the old `rules.isEmpty` seed could not tell "deleted everything" apart from "first run"). An empty shield
        // after a delete stays empty until the user explicitly adds rules again.
        suite?.set(true, forKey: Self.seededKey)
        evaluate()
    }

    /// Persist to the SHARED store and bump the policy revision (mandate B2: preference change ⇒ prior decision stale).
    /// C — record the new revision as the one we've rendered, so our own write does not later look like an external
    /// change that needs a reload.
    private func persist() {
        if let newRev = try? shared.saveRules(rules) { lastLoadedRevision = newRev }
    }

    func evaluate() {
        var env = ContentObservationEnvelope()
        env.structuredText = sampleText.isEmpty ? [] : [TextSource(origin: .structured, text: sampleText)]
        env.languageSignals = ["en"]
        lastOutcome = evaluator.evaluate(.init(envelope: env, controlledSurface: true), index: index)

        // 006B §10 firewall — a shield match drives the guardian axis and outranks positive content character.
        let inputs = GlyphInputs(shieldState: lastOutcome.matchState,
                                 contentCharacter: lastOutcome.matchState == .noMatch ? .learning : .neutral,
                                 minConfidence: 0.9)
        lastGlyph = glyphEngine.token(for: inputs, style: glyphStyle)
    }

    var ruleCount: Int { index.count }
    var outcomeSummary: String { "\(lastOutcome.matchState.rawValue) → \(lastOutcome.layerDecision.rawValue)" }

    // 006C §12 — surface the rule's functional state so the UI never claims active protection when it can't protect.
    func functionalState(_ rule: ShieldRuleV2) -> ShieldRuleFunctionalState {
        rule.functionalState(nowEpoch: Date().timeIntervalSince1970)
    }
    func needsReauthoring(_ rule: ShieldRuleV2) -> Bool {
        functionalState(rule) == .referenceReauthoringRequired
    }
}
