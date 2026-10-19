import Foundation
import GuardianCore

// MARK: - Specialist heads V1 (PROMPT 003 §8,§10,§11,§7). TR+EN. Topic presence ≠ truth ≠ exposure policy.
// Calibration is UNAVAILABLE (calibratedConfidence = nil) — raw confidence only, never fabricated.

// H2 — Mortality / Disease / Disaster (lexicon classifier; EMBEDDING upgrade hook documented).
public struct MortalityDiseaseDisasterHead: Sendable {
    public static let version = "mdd-head-v1"
    public static let task = "mortality_disease_disaster"
    public init() {}

    public func classify(text: String, language: String?) -> IntelligenceSignal<[MortalityDiseaseDisasterLabel]> {
        let start = DispatchTime.now().uptimeNanoseconds
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            return IntelligenceSignal(task: Self.task, value: nil, rawConfidence: nil, availability: .unknown,
                                      provenance: .lexiconV1, modelVersion: Self.version,
                                      abstentionReason: .insufficientEvidence, language: language)
        }
        var labels: [MortalityDiseaseDisasterLabel] = []
        var evidence: [EvidenceRef] = []
        func check(_ lex: [String: [String]], _ label: MortalityDiseaseDisasterLabel) {
            let hits = Lexicons.hits(trimmed, lexicon: lex, language: language)
            if !hits.isEmpty { labels.append(label); evidence.append(EvidenceRef(kind: "lexicon", detail: "\(label.rawValue): \(hits.prefix(3).joined(separator: ","))")) }
        }
        check(Lexicons.mortality, .mortality)
        check(Lexicons.diseaseIllness, .diseaseIllness)
        check(Lexicons.disaster, .disaster)
        check(Lexicons.severeAccident, .severeAccident)
        check(Lexicons.warConflict, .warConflict)
        check(Lexicons.medicalHospital, .medicalHospital)
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        if labels.isEmpty {
            return IntelligenceSignal(task: Self.task, value: [.noneOfAbove], rawConfidence: 0.5,
                                      availability: .available, provenance: .lexiconV1, modelVersion: Self.version,
                                      latencyNanos: lat, language: language)
        }
        let conf = min(1.0, Double(evidence.count) / 3.0 + 0.4)
        return IntelligenceSignal(task: Self.task, value: labels, rawConfidence: conf,
                                  availability: .available, provenance: .lexiconV1, modelVersion: Self.version,
                                  latencyNanos: lat, evidence: evidence, language: language)
    }
}

// H4 — Topic / Message + intent (NLTagger topics + lexical intent cues).
public struct TopicMessageHead: Sendable {
    public static let version = "topic-message-v1"
    public static let task = "topic_message"
    private let nl = NLTextSignalProvider()
    public init() {}

    public func analyze(text: String, language: String?) async -> IntelligenceSignal<TopicMessage> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            return IntelligenceSignal(task: Self.task, value: nil, rawConfidence: nil, availability: .unknown,
                                      provenance: .appleNaturalLanguage, modelVersion: Self.version,
                                      abstentionReason: .insufficientEvidence, language: language)
        }
        let topics = (await nl.topics(trimmed)).value?.topics ?? []
        let adHits = Lexicons.hits(trimmed, lexicon: Lexicons.repeatedCTA, language: language)
        let fearHits = Lexicons.hits(trimmed, lexicon: Lexicons.fear, language: language)
        let intent: ContentIntent
        if !adHits.isEmpty { intent = .advertisement }
        else if !fearHits.isEmpty { intent = .persuasive }
        else if topics.isEmpty { intent = .unknown }
        else { intent = .informational }
        let core = topics.first.map { "Primarily about \($0)" }
        let tm = TopicMessage(topics: topics, coreMessage: core, intent: intent)
        return IntelligenceSignal(task: Self.task, value: tm, rawConfidence: topics.isEmpty ? 0.3 : 0.6,
                                  availability: .available, provenance: .appleNaturalLanguage,
                                  modelVersion: Self.version, evidence: [EvidenceRef(kind: "nltagger", detail: "\(topics.count) topics")],
                                  language: language)
    }
}

// H5 — Attention / Manipulation OBSERVED signals (lexicon). OBSERVED, not hidden-intent inference.
public struct AttentionManipulationHead: Sendable {
    public static let version = "attention-v1"
    public static let task = "attention_manipulation"
    public init() {}

    public func analyze(text: String, language: String?) -> IntelligenceSignal<ManipulationSignals> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            return IntelligenceSignal(task: Self.task, value: nil, rawConfidence: nil, availability: .unknown,
                                      provenance: .lexiconV1, modelVersion: Self.version,
                                      abstentionReason: .insufficientEvidence, language: language)
        }
        var m = ManipulationSignals()
        m.urgency = Lexicons.hits(trimmed, lexicon: Lexicons.urgency, language: language).count
        m.scarcity = Lexicons.hits(trimmed, lexicon: Lexicons.scarcity, language: language).count
        m.fear = Lexicons.hits(trimmed, lexicon: Lexicons.fear, language: language).count
        m.anger = Lexicons.hits(trimmed, lexicon: Lexicons.anger, language: language).count
        m.repeatedCTA = Lexicons.hits(trimmed, lexicon: Lexicons.repeatedCTA, language: language).count
        m.clickbait = Lexicons.hits(trimmed, lexicon: Lexicons.clickbait, language: language).count
        return IntelligenceSignal(task: Self.task, value: m, rawConfidence: m.total > 0 ? min(1.0, Double(m.total) / 4.0) : 0.4,
                                  availability: .available, provenance: .lexiconV1, modelVersion: Self.version,
                                  evidence: [EvidenceRef(kind: "lexicon", detail: "observed count \(m.total)")], language: language)
    }
}

// H1 — Sensitive Visual: NO validated commercial-rights model found → UNAVAILABLE (do NOT improvise, §7).
public struct SensitiveVisualHead: Sendable {
    public static let version = "sensitive-visual-unavailable-v0"
    public static let task = "sensitive_visual"
    public init() {}
    public func classify() -> IntelligenceSignal<[String]> {
        // Honest: no validated, clearly-licensed on-device graphic-content model vendored.
        .unavailable(task: Self.task, version: Self.version, reason: .notImplemented)
    }
}
