//
//  ReelsEvidenceProviderV1.swift — B1/C: honest PRE-EXPOSURE evidence for the CONTROLLED reels player.
//
//  WHY THIS EXISTS (mandate B1 + C): the Controlled Reels Player plays our OWN local, project-generated videos.
//  Because the content is app-owned and local, we are ALLOWED to analyse it BEFORE the user is exposed — this is
//  the legitimate pre-exposure analysis the constitution's north star asks for (§5). This component does exactly
//  one honest thing: extract the earliest frame(s) of a LOCAL asset, run REAL on-device Vision OCR over them, and
//  return the recognized text together with an HONEST provenance + coverage classification. It invents nothing:
//  if OCR produced no text it says so; it NEVER claims semantic "understanding" it did not perform (mandate C:
//  metadata is not presented as AI image-understanding; a test label is not "GEN8 solved the meaning").
//
//  The real shield decision is made by the FROZEN ShieldEvaluatorV2 over the text this provider returns — the
//  decision logic is not re-implemented here. This file is the media→text bridge only.
//
//  PROVENANCE HONESTY (mandate C): every evidence bundle is tagged with WHERE it came from:
//   - .userSuppliedMetadata : the content's declared title/metadata (known source; NOT image understanding)
//   - .realOCR              : text REALLY recognized by Apple Vision over a decoded frame (on-device)
//   - .none                 : no text evidence could be obtained (honest — not "safe")
//  A decision built only on metadata is labelled as such; it is never dressed up as a vision result.
//
//  This type lives in GuardianMedia (ungoverned) and is dual-compiled into the Gen8 app (it needs AVFoundation +
//  Vision, which never belong in GuardianCore). Headless-testable on macOS over generated fixtures.
//
import Foundation
import GuardianCore
import GuardianIntelligence
#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics

/// Where a piece of reel evidence came from — classified HONESTLY so the UI can never overstate what we know.
public enum ReelsEvidenceProvenanceV1: String, Sendable, Equatable, Codable {
    /// Declared metadata the content shipped with (a known-source title). NOT an AI understanding of the pixels.
    case userSuppliedMetadata = "USER_SUPPLIED_METADATA"
    /// Text REALLY recognized by Apple Vision OCR over a decoded frame of the local asset (on-device).
    case realOCR = "REAL_OCR"
    /// No usable text evidence was obtained. Honest abstention — NEVER treated as "safe".
    case none = "NONE"
}

/// The honest evidence bundle produced for ONE reel before exposure. Text + where it came from + how much of the
/// planned analysis actually ran (coverage) + whether real OCR executed at all.
public struct ReelsEvidenceV1: Sendable, Equatable {
    /// The strongest text evidence available, lower-cased join of metadata + any OCR text.
    public let combinedText: String
    /// The OCR text that Vision really recognized (empty if OCR produced nothing / did not run).
    public let ocrText: String
    /// The content's declared metadata/title text (always "known source", never image understanding).
    public let metadataText: String
    /// How many first-frames we planned to OCR vs how many actually decoded+ran (0...1). Honest coverage.
    public let frameCoverage: Double
    /// The dominant provenance of the combined text (what the decision will mostly rest on).
    public let provenance: ReelsEvidenceProvenanceV1
    /// True iff Apple Vision OCR actually executed over at least one decoded frame this pass.
    public let ocrExecuted: Bool
    /// The detected language signals (BCP-47-ish), best effort; may be empty.
    public let languages: [String]

    public init(combinedText: String, ocrText: String, metadataText: String, frameCoverage: Double,
                provenance: ReelsEvidenceProvenanceV1, ocrExecuted: Bool, languages: [String]) {
        self.combinedText = combinedText; self.ocrText = ocrText; self.metadataText = metadataText
        self.frameCoverage = frameCoverage; self.provenance = provenance
        self.ocrExecuted = ocrExecuted; self.languages = languages
    }

    /// An empty bundle — no evidence at all (honest UNKNOWN; never "safe").
    public static let empty = ReelsEvidenceV1(combinedText: "", ocrText: "", metadataText: "", frameCoverage: 0,
                                              provenance: .none, ocrExecuted: false, languages: [])
}

/// The pre-exposure evidence port. A real implementation decodes frames + runs Vision OCR; tests may inject a
/// deterministic implementation so the player state machine is testable without AVFoundation runtime variance.
public protocol ReelsEvidenceProviding: Sendable {
    /// Gather honest pre-exposure evidence for a local reel. `firstFrameSeconds` are the timestamps to OCR.
    func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1
}

/// REAL implementation: sparse-decode the earliest frame(s) via VideoFrameProvider, run Apple Vision OCR
/// (fast mode) over each, and fuse the recognized text with the content's declared metadata — all honestly
/// classified. No raw frames retained; ephemeral CGImages only (VideoFrameProvider contract).
public struct ReelsEvidenceProviderV1: ReelsEvidenceProviding {
    public static let version = "reels-evidence-provider-v1"
    private let ocr: VisionOCRProvider
    public init(ocrMode: VisionOCRProvider.Mode = .fast) { self.ocr = VisionOCRProvider(mode: ocrMode) }

    public func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double],
                               languages: [String]) async -> ReelsEvidenceV1 {
        let metadata = metadataTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // Pre-exposure frame decode of the earliest moments only (we analyse BEFORE playing, so sample the open).
        let times = firstFrameSeconds.isEmpty ? [0.1] : firstFrameSeconds
        let provider = VideoFrameProvider(url: url)
        let frames = await provider.frames(atSeconds: times)
        let decoded = frames.compactMap { $0.image }
        var ocrPieces: [String] = []
        for img in decoded {
            if Task.isCancelled { break }
            if let t = ocr.recognizeText(cgImage: img).value?.text, !t.isEmpty { ocrPieces.append(t) }
        }
        let ocrText = ocrPieces.joined(separator: " ")
        let coverage = times.isEmpty ? 0 : Double(decoded.count) / Double(times.count)
        return Self.fuse(ocrText: ocrText, metadataText: metadata, frameCoverage: coverage,
                         ocrExecuted: !decoded.isEmpty, languages: languages)
    }

    /// PURE fusion + honest provenance classification (testable without AVFoundation). The combined text is what
    /// the frozen evaluator runs against; the provenance says what the decision mostly rests on.
    public static func fuse(ocrText: String, metadataText: String, frameCoverage: Double,
                            ocrExecuted: Bool, languages: [String]) -> ReelsEvidenceV1 {
        let ocr = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = metadataText.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = [meta, ocr].filter { !$0.isEmpty }.joined(separator: " ")
        let provenance: ReelsEvidenceProvenanceV1 = {
            if !ocr.isEmpty { return .realOCR }       // real vision text present → that is the strongest honest basis
            if !meta.isEmpty { return .userSuppliedMetadata } // only declared metadata → say so (not image understanding)
            return .none                              // nothing → honest UNKNOWN
        }()
        return ReelsEvidenceV1(combinedText: combined, ocrText: ocr, metadataText: meta,
                               frameCoverage: max(0, min(1, frameCoverage)), provenance: provenance,
                               ocrExecuted: ocrExecuted, languages: languages)
    }
}
#endif
