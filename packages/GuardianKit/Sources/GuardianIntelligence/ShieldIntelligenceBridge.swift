import Foundation
import NaturalLanguage
import Vision
import CoreGraphics
import CryptoKit
import GuardianCore

// MARK: - Shield intelligence bridge (PROMPT 006A §4,§5,§6,§12)
// GuardianCore stays framework-free; this layer supplies REAL Apple-backed matching signal.
// Hard privacy boundaries: NO face biometric, NO speaker voiceprint, raw reference media DISCARDED after feature extraction.

/// Synchronous NLEmbedding-backed semantic distance for the pure-core SemanticTextMatcher closure.
/// NLEmbedding is not concurrency-safe → serialized behind a lock. Returns nil (UNAVAILABLE) when no embedding exists.
public final class ShieldSemanticDistance: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: NLEmbedding] = [:]
    public init() {}

    private func embedding(_ language: NLLanguage) -> NLEmbedding? {
        let key = language.rawValue
        if let e = cache[key] { return e }
        let e = NLEmbedding.sentenceEmbedding(for: language) ?? NLEmbedding.wordEmbedding(for: language)
        if let e { cache[key] = e }
        return e
    }

    public func distance(_ text: String, _ concept: String, _ locale: String) -> Double? {
        lock.lock(); defer { lock.unlock() }
        let lang: NLLanguage = locale.hasPrefix("tr") ? .turkish : .english
        guard let emb = embedding(lang) else { return nil }   // honest UNAVAILABLE
        let d = emb.distance(between: text, and: concept)
        return d.isFinite ? Double(d) : nil
    }

    /// Sendable closure for ShieldEvaluatorV2.standard(semanticDistance:).
    public var closure: @Sendable (String, String, String) -> Double? { { [self] a, b, c in self.distance(a, b, c) } }
}

/// 006C — ingests an image reference into a FUNCTIONALLY-DURABLE serializable signature (Strategy A), discards raw.
/// NO Vision feature-print dependency, NO face detection/biometric, NO raw pixels retained.
public struct ShieldImageReferenceIngestor: Sendable {
    public static let version = PersistedVisualReferenceSignature.currentEngineRevision
    private let engine: VisualSignatureEngine
    public init(engine: VisualSignatureEngine = VisualSignatureEngine()) { self.engine = engine }

    /// Produce the persisted signature + a durable DerivedReferenceFeature (serializedFeature = encoded signature bytes).
    public func ingest(cgImage: CGImage, ruleID: String, nowEpoch: Double) -> (signature: PersistedVisualReferenceSignature, feature: DerivedReferenceFeature)? {
        guard let sig = engine.signature(from: cgImage, ruleID: ruleID, nowEpoch: nowEpoch),
              let encoded = try? JSONEncoder().encode(sig) else { return nil }
        // Raw cgImage goes out of scope here and is never retained/persisted.
        let feature = DerivedReferenceFeature(featureID: "visualsig-" + ruleID, ruleID: ruleID, featureType: .image,
                                              engineID: VisualSignatureEngine.aHashAlgo, engineRevision: engine.engineRevision,
                                              vectorDimension: sig.components.reduce(0) { $0 + $1.dimension },
                                              serializedFeature: encoded, createdAtEpoch: nowEpoch)
        return (sig, feature)
    }
}

/// 006C — durable visual matcher. Consumes a PERSISTED signature (reconstructed from disk bytes) and a live frame.
/// After a true process teardown the reference comes only from persisted derived state — no in-memory object needed.
public struct ShieldVisualReferenceMatcher: Sendable {
    public static let version = PersistedVisualReferenceSignature.currentEngineRevision
    private let engine: VisualSignatureEngine
    private let comparator = VisualSignatureComparator()
    private let matcherID = ShieldMatcherID.visualReference.rawValue
    public init(engine: VisualSignatureEngine = VisualSignatureEngine()) { self.engine = engine }

    /// Compare a live frame against a persisted reference signature loaded from the durable store.
    public func match(frame: CGImage, reference: PersistedVisualReferenceSignature) -> ShieldMatchResult {
        guard let live = engine.signature(from: frame, ruleID: reference.ruleID, nowEpoch: 0) else {
            return ShieldMatchResult(ruleID: reference.ruleID, matcherID: matcherID, state: .matchabilityUnknown, rawConfidence: nil,
                                     reason: .matchabilityUnknown, modality: "image", engineVersion: Self.version)
        }
        let (state, d) = comparator.compare(live, reference)
        let reason: ShieldReasonCode = state == .matcherUnavailable ? .referenceReauthoring
            : (state.isNonDeterminable ? .matchabilityUnknown : .visualReference)
        let conf: Double? = d.map { max(0, 1 - Double($0.aHashHamming) / 32.0) }
        return ShieldMatchResult(ruleID: reference.ruleID, matcherID: matcherID, state: state, rawConfidence: conf,
                                 reason: reason, modality: "image", engineVersion: Self.version)
    }

    /// Decode a persisted signature from durable feature bytes (what the store hands back after relaunch).
    public static func decodeSignature(_ feature: DerivedReferenceFeature) -> PersistedVisualReferenceSignature? {
        try? JSONDecoder().decode(PersistedVisualReferenceSignature.self, from: feature.serializedFeature)
    }
}
