//
//  ShieldStudioModel.swift — My Shield studio (PROMPT 006A §13,§26,§27)
//  "I don't want to see/hear this." Create rules, evaluate against sample content, preview the Guardian glyph.
//  Personal, local-only state. Low-confidence never silently hides; UNKNOWN never renders a safe glyph.
//
import Foundation
import Observation
import GuardianCore
import GuardianIntelligence

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

    init() {
        evaluator = ShieldEvaluatorV2.standard(semanticDistance: semantic.closure)
        let loaded = shared.loadPolicy()
        index = loaded.index; rules = loaded.rules
        if rules.isEmpty {   // seed a demonstrable default on first launch only (user-editable / deletable)
            addRule(label: "spoiler", type: .textExact, action: .hideIfControlled)
            addRule(label: "graphic violence", type: .semanticConcept, action: .warn)
        }
        evaluate()
    }

    func addDraft() {
        let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addRule(label: trimmed, type: draftType, action: draftAction)
        draftLabel = ""
        evaluate()
    }

    func addRule(label: String, type: ShieldInputType, action: ShieldAction) {
        let now = Date().timeIntervalSince1970
        let rule = ShieldRuleV2(ruleID: "ui-\(rules.count)-\(abs(label.hashValue))", inputType: type,
                                rawUserLabel: label, locale: "en", action: action,
                                createdAtEpoch: now, updatedAtEpoch: now)
        index.upsert(rule)
        rules.append(rule)
        persist()
    }

    func delete(_ rule: ShieldRuleV2) {
        index.remove(rule.ruleID)
        rules.removeAll { $0.ruleID == rule.ruleID }
        persist()
        evaluate()
    }

    /// B1 — full on-device deletion of every personal rule (user control). Wipes the shared durable store and
    /// bumps the revision so any extension decision made under the old rules is invalidated.
    func deleteAll() {
        rules.removeAll()
        index = ShieldIndex()
        try? shared.wipeAll()
        evaluate()
    }

    /// Persist to the SHARED store and bump the policy revision (mandate B2: preference change ⇒ prior decision stale).
    private func persist() {
        _ = try? shared.saveRules(rules)
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
