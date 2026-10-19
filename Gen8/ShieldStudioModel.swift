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

    // 006B §5 — durable local store under Application Support (survives relaunch). Raw media never persisted.
    private let manager: ShieldStoreManager
    private var snapshot = ShieldStoreSnapshot()

    init() {
        evaluator = ShieldEvaluatorV2.standard(semanticDistance: semantic.closure)
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))?.appendingPathComponent("Gen8/shield")
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Gen8/shield")
        manager = ShieldStoreManager(store: FileBackedPersonalShieldStore(directory: dir))
        if let loaded = try? manager.loadAndRebuild() {
            snapshot = loaded.snapshot; index = loaded.index; rules = loaded.snapshot.rules
        }
        if rules.isEmpty {   // seed defaults on first launch only
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

    private func persist() {
        snapshot.rules = rules
        try? manager.store.save(snapshot)
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
