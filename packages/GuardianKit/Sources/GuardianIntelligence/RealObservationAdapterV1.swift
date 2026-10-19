import Foundation
import CoreGraphics
import GuardianCore

// MARK: - P009B-R1 §4 — RealObservationToExpertInputAdapterV1.
// The REAL perception path: owned/rights-clear in-process media → REAL Apple providers (Vision OCR,
// Vision classification, NaturalLanguage) → derived ExpertInputV2 → the expert mesh.
// LAW: there is NO synthetic/corpus fallback in this adapter. A provider that yields nothing leaves its
// field nil, and the mesh answers with honest UNAVAILABLE evidence downstream. Raw pixels never leave
// this function; only derived text/labels cross into GuardianCore.

public struct RealObservationToExpertInputAdapterV1: Sendable {
    public static let version = "real-observation-adapter-v1"
    public struct AdaptedV1: Sendable {
        public let input: ExpertInputV2
        public let providerProvenance: [String]            // which REAL providers actually produced each field
        public let sourceMode: String                      // always "REAL_IN_PROCESS" from this adapter
    }
    private let ocr = VisionOCRProvider(mode: .accurate)
    private let visual = VisualSemanticBaselineV1()
    private let language = NLTextSignalProvider()
    public init() {}

    /// Image/frame path: real Vision OCR + real Vision classification + real NL language identification.
    public func adapt(cgImage: CGImage, editDensityCutsPerMinute: Double? = nil,
                      elapsedItemMs: Double? = nil) async -> AdaptedV1 {
        var provenance: [String] = []
        var input = ExpertInputV2()
        input.editDensityCutsPerMinute = editDensityCutsPerMinute
        input.elapsedItemMs = elapsedItemMs

        let ocrOutcome = ocr.recognizeText(cgImage: cgImage)                 // REAL VNRecognizeTextRequest
        if let text = ocrOutcome.value?.text, !text.isEmpty {
            input.ocrText = text
            provenance.append("ocr←\(VisionOCRProvider.version)")
            let lang = await language.identify(text)                         // REAL NLLanguageRecognizer
            if let l = lang.value?.language {
                input.detectedLanguage = l
                provenance.append("language←\(language.engineVersion)")
            }
        }
        let semantics = visual.analyze(cgImage: cgImage)                     // REAL VNClassifyImageRequest
        if !semantics.imageCategories.isEmpty {
            input.visualLabels = semantics.imageCategories.map { $0.label }
            input.visualConfidence = Double(semantics.imageCategories.first?.confidence ?? 0)
            provenance.append("visual←\(VisualSemanticEvidenceV1.version)")
        }
        return AdaptedV1(input: input, providerProvenance: provenance, sourceMode: "REAL_IN_PROCESS")
    }

    /// Text-only path (e.g., accessibility/caption text already extracted by a real provider upstream).
    public func adapt(providerText: String) async -> AdaptedV1 {
        var input = ExpertInputV2()
        var provenance: [String] = []
        if !providerText.isEmpty {
            input.ocrText = providerText
            provenance.append("text←upstream-real-provider")
            if let l = (await language.identify(providerText)).value?.language {
                input.detectedLanguage = l
                provenance.append("language←\(language.engineVersion)")
            }
        }
        return AdaptedV1(input: input, providerProvenance: provenance, sourceMode: "REAL_IN_PROCESS")
    }
}
