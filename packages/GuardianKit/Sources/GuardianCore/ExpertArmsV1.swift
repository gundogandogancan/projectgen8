import Foundation

// MARK: - P009B §5–§14 — the expert arms. Pure GuardianCore logic; raw-media providers (Apple Vision, OCR,
// SoundAnalysis, Speech, NaturalLanguage) live in GuardianIntelligence/GuardianMedia and feed ExpertInputV2
// with DERIVED results only. Missing provider input → honest UNAVAILABLE evidence, never fabrication.
// All evidence is UNCALIBRATED or HEURISTIC in P009B; no score, no glyph.

// MARK: - helpers

enum LexMatch {
    /// TR+EN lexicon hit count against lowercased text (word-boundary-ish containment — the P003 approach).
    static func hits(_ text: String, _ lexicon: [String: [String]]) -> Int {
        let lower = text.lowercased()
        var n = 0
        for (_, words) in lexicon { for w in words where lower.contains(w.lowercased()) { n += 1 } }
        return n
    }
}

// MARK: - §5 VISION BRAIN (provider-injected labels; real provider = Apple Vision in GuardianIntelligence).

public struct VisionExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .vision
    public let availability: ExpertAvailabilityV2
    public let modelVersion = "vision-expert-v1/apple-vision-baseline"
    public let resourceCost: Double = 5                   // deep: image classification path
    public init(availability: ExpertAvailabilityV2 = .realButLabOnly) { self.availability = availability }
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard let labels = input.visualLabels, !labels.isEmpty else {
            return .unavailable(.vision, reason: "no-visual-provider-input", generation: context.generation)
        }
        // provider labels → canonical scene/object evidence; never identity, never sensitive traits (§5 rules)
        let conf = min(1, max(0, input.visualConfidence ?? 0.3))
        let ood = conf < 0.15
        var features: [String: Double] = ["labelCount": Double(labels.count)]
        if let d = input.editDensityCutsPerMinute { features["editDensity"] = d }
        return ExpertEvidenceV2(domain: .vision, labels: labels.map { "scene:\($0)" }, features: features,
                                confidence: conf, coverage: 1, uncertainty: 1 - conf, oodIndicator: ood,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "vision-expert-v1←apple-vision-provider", modelVersion: modelVersion,
                                resourceCost: resourceCost, calibrationStatus: .implementedUncalibrated,
                                generation: context.generation)
    }
}

// MARK: - §6 OCR / LANGUAGE BRAIN (real P003 TR+EN lexicon heads; OCR text provider-injected, never persisted).

public struct LanguageOCRExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .languageOCR
    public let availability: ExpertAvailabilityV2
    public let modelVersion = "language-ocr-expert-v1/lexicon-v1"
    public let resourceCost: Double = 3
    public init(availability: ExpertAvailabilityV2 = .realButLabOnly) { self.availability = availability }
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard let text = input.ocrText, !text.isEmpty else {
            return .unavailable(.languageOCR, reason: "no-ocr-text", generation: context.generation)
        }
        let lang = input.detectedLanguage ?? "und"
        let supported = ["tr", "en"].contains(lang)
        if !supported {
            return ExpertEvidenceV2(domain: .languageOCR, labels: ["language:\(lang)", "UNSUPPORTED_LANGUAGE"],
                                    confidence: 0, coverage: 0, uncertainty: 1, oodIndicator: true,
                                    shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                    provenance: "language-ocr-expert-v1", modelVersion: modelVersion,
                                    calibrationStatus: .unavailable, generation: context.generation)   // §22 abstain
        }
        var labels = ["language:\(lang)"]
        var features: [String: Double] = [:]
        let mortality = LexMatch.hits(text, Lexicons.mortality) + LexMatch.hits(text, Lexicons.warConflict)
        let disease = LexMatch.hits(text, Lexicons.diseaseIllness) + LexMatch.hits(text, Lexicons.medicalHospital)
        let disaster = LexMatch.hits(text, Lexicons.disaster) + LexMatch.hits(text, Lexicons.severeAccident)
        let manipulation = LexMatch.hits(text, Lexicons.urgency) + LexMatch.hits(text, Lexicons.scarcity)
                         + LexMatch.hits(text, Lexicons.repeatedCTA) + LexMatch.hits(text, Lexicons.clickbait)
        let emotional = LexMatch.hits(text, Lexicons.fear) + LexMatch.hits(text, Lexicons.anger)
        if mortality > 0 { labels.append("topic:mortality"); features["mortalityHits"] = Double(mortality) }
        if disease > 0 { labels.append("topic:disease"); features["diseaseHits"] = Double(disease) }
        if disaster > 0 { labels.append("topic:disaster"); features["disasterHits"] = Double(disaster) }
        if manipulation > 0 { labels.append("pattern:manipulation-language"); features["manipulationHits"] = Double(manipulation) }
        if emotional > 0 { labels.append("pattern:emotional-language"); features["emotionalHits"] = Double(emotional) }
        let noisy = text.count < 6
        let conf = noisy ? 0.2 : 0.6                        // OCR uncertainty retained; lexicon evidence is uncalibrated
        return ExpertEvidenceV2(domain: .languageOCR, labels: labels, features: features, confidence: conf,
                                coverage: 1, uncertainty: 1 - conf, oodIndicator: noisy,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "language-ocr-expert-v1←ocr-provider+lexicon-v1(TR/EN)", modelVersion: modelVersion,
                                resourceCost: resourceCost, calibrationStatus: .implementedUncalibrated,
                                generation: context.generation)
    }
}

// MARK: - §7 SPEECH BRAIN (provider-injected transcript; honest UNAVAILABLE when authorization/model absent).

public struct SpeechExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .speech
    public let availability: ExpertAvailabilityV2
    public let modelVersion = "speech-expert-v1/on-device-sfspeech"
    public let resourceCost: Double = 6
    public init(availability: ExpertAvailabilityV2 = .realButLabOnly) { self.availability = availability }
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard input.speechAvailable else {
            return .unavailable(.speech, reason: "speech-authorization-or-model-unavailable", generation: context.generation)
        }
        guard let t = input.speechTranscript, !t.isEmpty else {
            return ExpertEvidenceV2(domain: .speech, labels: ["speech:none-detected"], confidence: 0.5, coverage: 1,
                                    uncertainty: 0.5, shotID: context.shotID, itemID: context.itemID,
                                    itemProvisional: context.itemProvisional, provenance: "speech-expert-v1",
                                    modelVersion: modelVersion, calibrationStatus: .implementedUncalibrated,
                                    generation: context.generation)
        }
        var labels = ["speech:present"]
        let sensitive = LexMatch.hits(t, Lexicons.mortality) + LexMatch.hits(t, Lexicons.fear)
        if sensitive > 0 { labels.append("speech:sensitive-language") }
        return ExpertEvidenceV2(domain: .speech, labels: labels, features: ["transcriptLength": Double(t.count)],
                                confidence: 0.5, coverage: 0.8, uncertainty: 0.5,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "speech-expert-v1←on-device-transcriber (no identity, no raw retention)",
                                modelVersion: modelVersion, resourceCost: resourceCost,
                                calibrationStatus: .implementedUncalibrated, generation: context.generation)
    }
}

// MARK: - §8 AUDIO BRAIN (validated SoundAnalysis classes only — never a violence classifier).

public struct AudioEventExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .audioEvent
    public let availability: ExpertAvailabilityV2
    public let modelVersion = "audio-event-expert-v1/soundanalysis"
    public let resourceCost: Double = 4
    /// Only classes validated through the real SoundAnalysis provider in P005/P006 are mapped.
    public static let validatedClasses: Set<String> = ["speech", "music", "siren", "alarm", "crowd", "applause",
                                                       "silence", "nature", "water", "traffic", "engine", "noise"]
    public init(availability: ExpertAvailabilityV2 = .realButLabOnly) { self.availability = availability }
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard let events = input.soundEvents else {
            return .unavailable(.audioEvent, reason: "no-audio-provider-input", generation: context.generation)
        }
        let mapped = events.filter { Self.validatedClasses.contains($0.lowercased()) }
        let unsupported = events.count - mapped.count
        var labels = mapped.map { "audio:\($0.lowercased())" }
        if unsupported > 0 { labels.append("audio:unsupported-classes:\(unsupported)") }   // honest, not guessed
        // zero validated classes → explicit no-validated marker EVEN IF unsupported classes were seen
        // (TUNE-discovered defect: unsupported-only input previously suppressed this honest-state label)
        if mapped.isEmpty { labels.append("audio:no-validated-events") }
        return ExpertEvidenceV2(domain: .audioEvent, labels: labels,
                                features: ["validated": Double(mapped.count), "unsupported": Double(unsupported)],
                                confidence: mapped.isEmpty ? 0.2 : 0.55, coverage: 1,
                                uncertainty: mapped.isEmpty ? 0.8 : 0.45, oodIndicator: unsupported > mapped.count,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "audio-event-expert-v1←soundanalysis-provider(validated-only)",
                                modelVersion: modelVersion, resourceCost: resourceCost,
                                calibrationStatus: .implementedUncalibrated, generation: context.generation)
    }
}

// MARK: - §9 MUSIC BRAIN (music/non-music real; identity UNAVAILABLE; no metaphysics).

public struct MusicExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .music
    public let availability: ExpertAvailabilityV2
    public let modelVersion = "music-expert-v1"
    public let resourceCost: Double = 2
    public init(availability: ExpertAvailabilityV2 = .realButLabOnly) { self.availability = availability }
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard let present = input.musicPresence else {
            return .unavailable(.music, reason: "no-music-provider-input", generation: context.generation)
        }
        var labels = [present ? "music:present" : "music:absent"]
        var features: [String: Double] = [:]
        if present, let e = input.musicTempoEnergy, e.isFinite { features["tempoEnergy"] = max(0, min(1, e)) }
        labels.append("music-identity:UNAVAILABLE")        // Shazam/provider identity honestly unavailable
        return ExpertEvidenceV2(domain: .music, labels: labels, features: features, confidence: 0.6, coverage: 1,
                                uncertainty: 0.4, shotID: context.shotID, itemID: context.itemID,
                                itemProvisional: context.itemProvisional,
                                provenance: "music-expert-v1←audio-provider (no moral/health inference)",
                                modelVersion: modelVersion, resourceCost: resourceCost,
                                calibrationStatus: .implementedUncalibrated, generation: context.generation)
    }
}

// MARK: - §10 SYMBOL BRAIN (pure; contextual ambiguity represented; no single-symbol verdict).

public struct SymbolExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .symbol
    public let availability: ExpertAvailabilityV2 = .realRuntime     // pure text-symbol semantics, runs anywhere text exists
    public let modelVersion = "symbol-expert-v1"
    public let resourceCost: Double = 1
    static let warning: Set<Character> = ["⚠", "☠", "🔞", "⛔", "🚫"]
    static let positive: Set<Character> = ["✅", "🧠", "💡", "🍃", "♪", "🙂"]
    public init() {}
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard let text = input.ocrText, !text.isEmpty else {
            return .unavailable(.symbol, reason: "no-text-input", generation: context.generation)
        }
        let warn = text.filter { Self.warning.contains($0) }.count
        let pos = text.filter { Self.positive.contains($0) }.count
        var labels: [String] = []
        if warn > 0 { labels.append("symbol:warning-candidates:\(warn)") }
        if pos > 0 { labels.append("symbol:positive-candidates:\(pos)") }
        if labels.isEmpty { labels = ["symbol:none-detected"] }
        labels.append("symbol:context-dependent")          // §10: no single-symbol safety verdict
        return ExpertEvidenceV2(domain: .symbol, labels: labels,
                                features: ["warning": Double(warn), "positive": Double(pos)],
                                confidence: 0.4, coverage: 1, uncertainty: 0.6,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "symbol-expert-v1", modelVersion: modelVersion,
                                calibrationStatus: .heuristicSupportOnly, generation: context.generation)
    }
}

// MARK: - §11 TEMPORAL BRAIN — escalation law: later strong risk escalates; earlier benign never suppresses.

public final class TemporalExpertV1: MultimodalExpertV2, @unchecked Sendable {
    public let domain: ExpertDomainV2 = .temporal
    public let availability: ExpertAvailabilityV2 = .realRuntime
    public let modelVersion = "temporal-expert-v1"
    public let resourceCost: Double = 1
    private let lock = NSLock()
    private var maxRiskSeen: Double = 0                   // monotone-max — the §11 safety law
    private var riskEverSeen = false
    private var shotCount = 0
    private var lastTopicLabels: Set<String> = []
    private var topicShifts = 0
    public init() {}
    public func reset() { lock.lock(); maxRiskSeen = 0; riskEverSeen = false; shotCount = 0; lastTopicLabels = []; topicShifts = 0; lock.unlock() }
    /// Feed cross-expert observations over time (risk from safety evidence, topics from language).
    public func observe(riskLevel: Double, topicLabels: Set<String>) {
        lock.lock(); defer { lock.unlock() }
        shotCount += 1
        if riskLevel > 0 { riskEverSeen = true }
        maxRiskSeen = max(maxRiskSeen, min(1, max(0, riskLevel)))     // benign later values can NEVER lower this
        if !topicLabels.isEmpty && !lastTopicLabels.isEmpty && topicLabels.isDisjoint(with: lastTopicLabels) { topicShifts += 1 }
        if !topicLabels.isEmpty { lastTopicLabels = topicLabels }
    }
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        lock.lock(); defer { lock.unlock() }
        var labels = ["temporal:shots:\(shotCount)"]
        if maxRiskSeen >= 0.6 { labels.append("temporal:risk-escalated") }
        if topicShifts > 0 { labels.append("temporal:narrative-shift:\(topicShifts)") }
        if context.itemProvisional { labels.append("temporal:identity-provisional") }   // works on provisional identity (§11)
        return ExpertEvidenceV2(domain: .temporal, labels: labels,
                                features: ["maxRisk": maxRiskSeen, "topicShifts": Double(topicShifts)],
                                confidence: 0.7, coverage: 1, uncertainty: 0.3,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "temporal-expert-v1 (monotone-max risk; benign-never-suppresses)",
                                modelVersion: modelVersion, calibrationStatus: .implementedUncalibrated,
                                generation: context.generation)
    }
}

// MARK: - §12 SAFETY EVIDENCE BRAIN — dimension evidence, NOT a score; H1 explicit UNAVAILABLE.

public struct SafetyEvidenceExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .safetyEvidence
    public let availability: ExpertAvailabilityV2 = .realRuntime     // lexicon dimensions are pure + real
    public let modelVersion = "safety-evidence-expert-v1/lexicon-v1"
    public let resourceCost: Double = 2
    /// §12 per-dimension capability tags — honest, carried into every evidence record.
    public static let dimensionStatus: [String: EvidenceCalibrationStatusV2] = [
        "sensitive-death-disease-news": .implementedUncalibrated,     // P003 TR/EN lexicons (real)
        "fear-threat": .heuristicSupportOnly,
        "manipulation-attention": .implementedUncalibrated,
        "violence-injury-visual": .unavailable,                       // H1 BLOCKER — no dedicated audited classifier
        "explicit-sexual-visual": .unavailable,                       // H1 BLOCKER
        "self-harm": .unavailable,
        "drugs-alcohol": .unavailable,
        "gambling": .unavailable,
        "dangerous-behavior": .unavailable,
        "profanity": .unavailable
    ]
    public init() {}
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        var labels: [String] = []
        var features: [String: Double] = [:]
        var anySignal = false
        if let text = input.ocrText ?? input.speechTranscript, !text.isEmpty {
            let death = LexMatch.hits(text, Lexicons.mortality) + LexMatch.hits(text, Lexicons.disaster)
                      + LexMatch.hits(text, Lexicons.diseaseIllness) + LexMatch.hits(text, Lexicons.warConflict)
            let fear = LexMatch.hits(text, Lexicons.fear)
            if death > 0 { labels.append("safety:sensitive-death-disease-news"); features["deathHits"] = Double(death); anySignal = true }
            if fear > 0 { labels.append("safety:fear-threat-candidate"); features["fearHits"] = Double(fear); anySignal = true }
        }
        // §12: H1 visual dimensions are explicit blockers — declared, never guessed from generic labels.
        labels.append("safety:H1-visual-dimensions:UNAVAILABLE")
        // §12: no "safe" conclusion from absence of weak evidence.
        if !anySignal { labels.append("safety:no-lexical-signal (NOT a safe verdict)") }
        return ExpertEvidenceV2(domain: .safetyEvidence, labels: labels, features: features,
                                confidence: anySignal ? 0.5 : 0.0, coverage: input.ocrText == nil && input.speechTranscript == nil ? 0 : 0.6,
                                uncertainty: anySignal ? 0.5 : 1.0,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "safety-evidence-expert-v1←lexicon-v1 (dimension tags per §12; H1 open)",
                                modelVersion: modelVersion, resourceCost: resourceCost,
                                calibrationStatus: .implementedUncalibrated, generation: context.generation)
    }
}

// MARK: - §13 BENEFIT EVIDENCE — intentionally separate from safety.

public struct BenefitEvidenceExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .benefitEvidence
    public let availability: ExpertAvailabilityV2 = .realRuntime
    public let modelVersion = "benefit-evidence-expert-v1"
    public let resourceCost: Double = 1
    static let educational: [String: [String]] = [
        "en": ["learn", "how to", "tutorial", "explain", "lesson", "guide", "science", "history"],
        "tr": ["öğren", "nasıl yapılır", "ders", "anlat", "rehber", "bilim", "tarih", "eğitim"]]
    static let calm: [String: [String]] = ["en": ["nature", "calm", "relax", "forest", "ocean"],
                                           "tr": ["doğa", "sakin", "huzur", "orman", "deniz"]]
    public init() {}
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        guard let text = input.ocrText ?? input.speechTranscript, !text.isEmpty else {
            return .unavailable(.benefitEvidence, reason: "no-text-evidence", generation: context.generation)
        }
        var labels: [String] = []
        let edu = LexMatch.hits(text, Self.educational), calm = LexMatch.hits(text, Self.calm)
        if edu > 0 { labels.append("benefit:educational-candidate") }
        if calm > 0 { labels.append("benefit:calm-nature-candidate") }
        if input.musicPresence == true { labels.append("benefit:music-presence") }
        if labels.isEmpty { labels = ["benefit:none-detected"] }
        return ExpertEvidenceV2(domain: .benefitEvidence, labels: labels,
                                features: ["eduHits": Double(edu), "calmHits": Double(calm)],
                                confidence: labels[0] == "benefit:none-detected" ? 0 : 0.4, coverage: 0.5, uncertainty: 0.6,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "benefit-evidence-expert-v1 (separate from safety by design)",
                                modelVersion: modelVersion, calibrationStatus: .heuristicSupportOnly,
                                generation: context.generation)
    }
}

// MARK: - §14 ATTENTION / MANIPULATION PRESSURE — behavioral/content pattern, no psychological diagnosis.

public struct AttentionPressureExpertV1: MultimodalExpertV2 {
    public let domain: ExpertDomainV2 = .attentionPressure
    public let availability: ExpertAvailabilityV2 = .realRuntime
    public let modelVersion = "attention-pressure-expert-v1/lexicon-v1"
    public let resourceCost: Double = 1
    public init() {}
    public func evaluate(_ input: ExpertInputV2, context: ExpertTaskContextV2) -> ExpertEvidenceV2 {
        var labels: [String] = []
        var features: [String: Double] = [:]
        if let d = input.editDensityCutsPerMinute, d.isFinite {
            features["editDensity"] = d
            if d >= 25 { labels.append("attention:rapid-edit-density") }
        }
        if let text = input.ocrText, !text.isEmpty {
            let urgency = LexMatch.hits(text, Lexicons.urgency) + LexMatch.hits(text, Lexicons.scarcity)
            let cta = LexMatch.hits(text, Lexicons.repeatedCTA) + LexMatch.hits(text, Lexicons.clickbait)
            if urgency > 0 { labels.append("attention:urgency-language"); features["urgencyHits"] = Double(urgency) }
            if cta > 0 { labels.append("attention:cta-clickbait"); features["ctaHits"] = Double(cta) }
        }
        if labels.isEmpty {
            if features.isEmpty { return .unavailable(.attentionPressure, reason: "no-pattern-inputs", generation: context.generation) }
            labels = ["attention:no-pressure-pattern"]
        }
        return ExpertEvidenceV2(domain: .attentionPressure, labels: labels, features: features,
                                confidence: 0.45, coverage: 0.6, uncertainty: 0.55,
                                shotID: context.shotID, itemID: context.itemID, itemProvisional: context.itemProvisional,
                                provenance: "attention-pressure-expert-v1 (behavioral pattern, not diagnosis)",
                                modelVersion: modelVersion, calibrationStatus: .heuristicSupportOnly,
                                generation: context.generation)
    }
}
