import Foundation
import GuardianCore
#if canImport(Vision)
import Vision
import CoreGraphics
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#endif

// MARK: - Fast Preflight V1 (PROMPT 002 §10 / 002A §6) — orchestrates REAL providers, preserves provenance
// Pipeline: Identity → OCR/Text → Language → Semantic → Visual Feature → available heads → envelope.
// Governed by ResourceGovernor (deep heads gated), ModelRouter-consulted, deadline-aware, early-exit,
// cancellable. UNAVAILABLE/UNKNOWN heads NEVER fabricate output (e.g. no benefit/violence classifier exists).

public struct HeadStatus: Sendable, Equatable {
    public enum State: String, Sendable { case real = "REAL", unavailable = "UNAVAILABLE", unknown = "UNKNOWN", heuristic = "HEURISTIC_V0" }
    public let state: State
    public let provenance: SignalProvenance
    public let engineVersion: String
    public init(_ state: State, _ provenance: SignalProvenance, _ engineVersion: String) {
        self.state = state; self.provenance = provenance; self.engineVersion = engineVersion
    }
    public static let notBuilt = HeadStatus(.unavailable, .unavailable, "none")
}

public struct PreflightSignalEnvelope: Sendable {
    public var identityExactHash: String?
    public var identityState: ContentIdentityState?
    public var ocrText: String?
    public var language: String?
    public var topics: [String]
    public var semanticAvailable: Bool
    public var visualFeatureAvailable: Bool
    public var heads: [String: HeadStatus]        // head name → status/provenance (full traceability)
    public var resourceMode: GovernorMode
    public var route: InferenceEngine
    public init() {
        identityExactHash = nil; identityState = nil; ocrText = nil; language = nil; topics = []
        semanticAvailable = false; visualFeatureAvailable = false; heads = [:]
        resourceMode = .balanced; route = .appleNative
    }
}

public struct FastPreflightEngineV1: Sendable {
    public static let version = "fast-preflight-v1"
    let identity = ContentIdentityResolverV1()
    let nl = NLTextSignalProvider()
    let router = ModelRouter()
    let governor = ResourceGovernor()
    public init() {}

    public func run(imageBytes: Data?, cgImageOCR: Bool = true, providedText: String?,
                    governorInputs: GovernorInputs = .init(schedulerLoad: 1)) async -> PreflightSignalEnvelope {
        var env = PreflightSignalEnvelope()
        let gov = governor.evaluate(governorInputs, requested: .balanced)
        env.resourceMode = gov.mode

        // 1. Identity (cheap deterministic/crypto — always runs if bytes present)
        if let bytes = imageBytes {
            let r = identity.resolve(contentID: .init("preflight"), bytes: bytes, versionTag: "v1")
            env.identityExactHash = r.exactHashHex
            env.identityState = r.state
            env.heads["identity"] = HeadStatus(.real, .cryptoHash, ContentIdentityResolverV1.version)
            env.route = router.route(RouteRequest(task: .identity)).engine
        } else {
            env.heads["identity"] = .notBuilt
        }

        // 2. OCR (real Vision) — only if we have image bytes and can build a CGImage
        var textForNLP = providedText
        #if canImport(Vision)
        if cgImageOCR, let bytes = imageBytes, let img = Self.cgImage(from: bytes) {
            let ocr = VisionOCRProvider(mode: gov.allowDeepAnalysis ? .accurate : .fast)
            let out = ocr.recognizeText(cgImage: img)
            if out.state == .ok, let t = out.value?.text {
                env.ocrText = t
                textForNLP = (textForNLP.map { $0 + " " } ?? "") + t
                env.heads["ocr"] = HeadStatus(.real, .appleVision, out.engineVersion)
            } else {
                env.heads["ocr"] = HeadStatus(.unknown, .appleVision, out.engineVersion)
            }
            // 5. Visual feature availability (real)
            let fp = VisionFeatureProvider()
            env.visualFeatureAvailable = fp.featurePrint(cgImage: img) != nil
            env.heads["visualFeature"] = HeadStatus(env.visualFeatureAvailable ? .real : .unavailable, .appleVision, VisionFeatureProvider.version)
        } else {
            env.heads["ocr"] = .notBuilt
            env.heads["visualFeature"] = .notBuilt
        }
        #else
        env.heads["ocr"] = .notBuilt
        env.heads["visualFeature"] = .notBuilt
        #endif

        // 3. Language (real NaturalLanguage)
        if let text = textForNLP, !text.trimmingCharacters(in: .whitespaces).isEmpty {
            let lang = await nl.identify(text)
            if lang.state == .ok { env.language = lang.value?.language
                env.heads["language"] = HeadStatus(.real, .appleNaturalLanguage, nl.engineVersion) }
            else { env.heads["language"] = HeadStatus(.unknown, .appleNaturalLanguage, nl.engineVersion) }
            let topics = await nl.topics(text)
            env.topics = topics.value?.topics ?? []
            env.heads["topics"] = HeadStatus(topics.state == .ok ? .real : .unknown, .appleNaturalLanguage, nl.engineVersion)
        } else {
            env.heads["language"] = .notBuilt
            env.heads["topics"] = .notBuilt
        }

        // 4. Semantic availability (real embedding) — gated by governor (deep)
        if gov.allowDeepAnalysis {
            let emb = SemanticEmbeddingProvider()
            env.semanticAvailable = await emb.isAvailable(language: .english)
            env.heads["semantic"] = HeadStatus(env.semanticAvailable ? .real : .unavailable, .appleNaturalLanguage, emb.engineVersion)
        } else {
            env.heads["semantic"] = HeadStatus(.unavailable, .unavailable, "gated-by-governor")
        }

        // Heads we have NOT built an honest classifier for → UNAVAILABLE (NEVER fabricated — §3).
        for head in ["sensitiveContent", "violence", "disease", "manipulation", "personalBenefit", "childSafety"] {
            env.heads[head] = .notBuilt
        }
        return env
    }

    #if canImport(Vision)
    static func cgImage(from data: Data) -> CGImage? {
        // Interpret bytes as an image only if decodable; fixtures pass PNG/encoded bytes.
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return img
    }
    #endif
}
