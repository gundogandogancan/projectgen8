import Foundation
import NaturalLanguage
import GuardianCore

// MARK: - Apple NaturalLanguage provider (PROMPT 002 §4, §10) — a REAL non-fixture signal path.
// Language identification via NLLanguageRecognizer (on-device, offline, deterministic). This is the
// genuine "non-fixture semantic/classification path" required by §10. Topic extraction is a light,
// honest token-based signal (NOT claimed as production topic modeling).

public struct NLTextSignalProvider: LanguagePort, TopicMessagePort, Sendable {
    public let engineVersion = "apple-nl-v1"
    public init() {}

    public func identify(_ text: String) async -> PortOutcome<LanguageSignal> {
        let start = DispatchTime.now().uptimeNanoseconds
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return .unknown(engineVersion: engineVersion) }
        let rec = NLLanguageRecognizer()
        rec.processString(trimmed)
        guard let lang = rec.dominantLanguage else { return .unknown(engineVersion: engineVersion) }
        let hyp = rec.languageHypotheses(withMaximum: 1)
        let conf = hyp[lang].map { Double($0) }
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        return .init(state: .ok, value: LanguageSignal(lang.rawValue), confidence: conf,
                     provenance: .appleNaturalLanguage, engineVersion: engineVersion,
                     latencyNanos: lat, privacy: .onDeviceOnly, cost: .cheap)
    }

    public func topics(_ text: String) async -> PortOutcome<TopicSignal> {
        let start = DispatchTime.now().uptimeNanoseconds
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown(engineVersion: engineVersion) }
        // Honest light signal: significant lemmas via NLTagger (not production topic modeling).
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = trimmed
        var topics: [String] = []
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
            if tag == .noun {
                let w = String(trimmed[tokenRange]).lowercased()
                if w.count >= 4 && !topics.contains(w) { topics.append(w) }
            }
            return topics.count < 8
        }
        let lat = DispatchTime.now().uptimeNanoseconds &- start
        return .init(state: topics.isEmpty ? .unknown : .ok, value: TopicSignal(topics),
                     confidence: topics.isEmpty ? nil : 0.5, provenance: .appleNaturalLanguage,
                     engineVersion: engineVersion, latencyNanos: lat, privacy: .onDeviceOnly, cost: .cheap)
    }
}
