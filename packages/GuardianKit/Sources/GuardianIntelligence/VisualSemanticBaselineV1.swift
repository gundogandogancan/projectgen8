import Foundation
import Vision
import CoreGraphics
import GuardianCore

// MARK: - Real Visual Semantic Baseline V1 (PROMPT 008A §3) — Apple public Vision + OCR, NO external VLM.
// Produces derived VisualSemanticEvidenceV1. Never claims "full scene understanding" from generic labels.

public struct VisualSemanticEvidenceV1: Sendable, Equatable {
    public static let version = "visual-semantic-baseline-v1"
    public var imageCategories: [(label: String, confidence: Float)]
    public var ocrConcepts: [String]
    public var hasFeaturePrint: Bool
    public var availability: String        // "available" | "partial" | "unavailable"
    public static func == (l: VisualSemanticEvidenceV1, r: VisualSemanticEvidenceV1) -> Bool {
        l.ocrConcepts == r.ocrConcepts && l.hasFeaturePrint == r.hasFeaturePrint && l.availability == r.availability
            && l.imageCategories.map { $0.label } == r.imageCategories.map { $0.label }
    }
}

public struct VisualSemanticBaselineV1: Sendable {
    public init() {}
    public func analyze(cgImage: CGImage, topK: Int = 5, minConfidence: Float = 0.1) -> VisualSemanticEvidenceV1 {
        var categories: [(String, Float)] = []
        var hasFP = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // 1) Public image classification (categorization — NOT full semantics).
        let classify = VNClassifyImageRequest()
        if (try? handler.perform([classify])) != nil {
            let obs = (classify.results ?? []).filter { $0.confidence >= minConfidence }
                .sorted { $0.confidence > $1.confidence }.prefix(topK)
            categories = obs.map { ($0.identifier, $0.confidence) }
        }
        // 2) Feature print presence (visual similarity capability).
        let fp = VNGenerateImageFeaturePrintRequest()
        if (try? handler.perform([fp])) != nil, (fp.results?.first as? VNFeaturePrintObservation) != nil { hasFP = true }

        // 3) OCR concepts (reuse the real OCR provider) — tokens only, ephemeral.
        var ocrConcepts: [String] = []
        let ocr = VisionOCRProvider().recognizeText(cgImage: cgImage)
        if let t = ocr.value?.text, !t.isEmpty {
            ocrConcepts = t.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        }
        let availability = (!categories.isEmpty || !ocrConcepts.isEmpty || hasFP) ? "available" : "unavailable"
        return VisualSemanticEvidenceV1(imageCategories: categories, ocrConcepts: ocrConcepts,
                                        hasFeaturePrint: hasFP, availability: availability)
    }

    /// Map the baseline into provenance-bearing ModalEvidenceSignals for MultimodalContentUnderstandingV1.
    public func evidence(_ e: VisualSemanticEvidenceV1) -> [ModalEvidenceSignal] {
        var out: [ModalEvidenceSignal] = []
        for c in e.imageCategories {
            out.append(ModalEvidenceSignal(modality: .visual, kind: "topic", value: c.label, rawConfidence: Double(c.confidence),
                calibratedConfidence: nil, evidenceClass: .modelInference, modelID: "apple-vision-classify",
                modelRevision: VisualSemanticEvidenceV1.version, rawMediaRetention: "none"))
        }
        for t in e.ocrConcepts.prefix(10) {
            out.append(ModalEvidenceSignal(modality: .ocr, kind: "concept", value: t, rawConfidence: 0.6,
                calibratedConfidence: nil, evidenceClass: .observedFact, modelID: "apple-vision-ocr",
                modelRevision: VisualSemanticEvidenceV1.version, rawMediaRetention: "none"))
        }
        return out
    }
}
