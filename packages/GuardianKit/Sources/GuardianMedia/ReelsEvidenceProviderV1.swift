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

/// §7 — ONE sampled timepoint's evidence record. The temporal path samples several points across the video
/// (start/mid/end, budgeted), and each carries its OWN timestamp + modality + OCR status + coverage so "a few
/// frames clean ≠ the whole video clean" stays honest and a MID-segment match is attributable to its real time.
public struct ReelsTimedEvidenceV1: Sendable, Equatable, Codable {
    /// The video timestamp (seconds) this evidence was sampled at.
    public let timestampSeconds: Double
    /// The modality that produced this record. Today: visual OCR (audio/semantics are NOT integrated — never faked).
    public let modality: ReelsEvidenceModalityV1
    /// The OCR outcome at this timepoint.
    public let ocrStatus: ReelsFrameOCRStatusV1
    /// The text recognized at this timepoint (empty unless ocrStatus == .ran).
    public let text: String
    /// §E1 — the ACTUAL rule id that matched AT THIS sample, if any. Set ONLY after a PER-SAMPLE shield evaluation
    /// (never a guess). A match is thereby attributable to its real timepoint; fusion across samples can never invent
    /// a claim that no single sample supports. nil = this sample produced no match (examined, clean, or not decoded).
    public let matchedRuleID: String?
    /// §E1 — whether THIS sample itself matched a shield rule (the per-sample verdict feeding the combined decision).
    public var matchedAtThisSample: Bool { matchedRuleID != nil }
    public init(timestampSeconds: Double, modality: ReelsEvidenceModalityV1, ocrStatus: ReelsFrameOCRStatusV1,
                text: String, matchedRuleID: String? = nil) {
        self.timestampSeconds = timestampSeconds; self.modality = modality; self.ocrStatus = ocrStatus
        self.text = text; self.matchedRuleID = matchedRuleID
    }
}

/// §7/§D — the modality a timepoint's evidence came from. Visual OCR has always been real; `audioEvent` is now a REAL
/// integrated modality (Apple Sound Analysis over the owned local file — §D). Each stays SEPARATE so the Evidence
/// sheet attributes a claim to the right sense and never fuses an OCR match and an audio event into one fake signal.
public enum ReelsEvidenceModalityV1: String, Sendable, Equatable, Codable {
    case visualOCR = "VISUAL_OCR"
    /// §D — a sound-classifier event (Apple SoundAnalysis label) attributed to an audio time range. Carries the REAL
    /// classifier label + RAW model confidence in the audio record, never dressed up as a Guardian risk score.
    case audioEvent = "AUDIO_EVENT"
}

/// §7 — per-timepoint OCR outcome (distinct from the bundle-level provenance).
public enum ReelsFrameOCRStatusV1: String, Sendable, Equatable, Codable {
    case ran = "RAN"               // OCR executed and produced non-empty text
    case ranNoText = "RAN_NO_TEXT" // OCR executed, no legible text at this timepoint
    case notDecoded = "NOT_DECODED"// the frame could not be decoded at this timepoint (counts against coverage)
}

/// §B2 — the reason sampling stopped before the full plan finished (honest, never "done"). `none` ⇒ ran the whole
/// attempted plan; `verifiedMatch` ⇒ a per-sample verdict confirmed a match so the rest was pointless; `cancelled` ⇒
/// the content changed under us (swipe/policy/etc.) and we abandoned; `budgetThermal` ⇒ the thermal-shrunk budget ran out.
public enum ReelsEarlyStopReasonV1: String, Sendable, Equatable, Codable {
    case none = "NONE"
    case verifiedMatch = "VERIFIED_MATCH"
    case cancelled = "CANCELLED"
    case budgetThermal = "BUDGET_THERMAL"
}

/// §B2 — SEPARATED coverage counters. Each is a distinct, honest fact; the UI copy derives from these and may NEVER
/// present an early-stopped 1/5 as 5/5, nor 5/5 as "the whole video".
public struct ReelsCoverageCountersV1: Sendable, Equatable, Codable {
    public let plannedSampleCount: Int    // the full adaptive plan size (how many points we intended to examine)
    public let attemptedSampleCount: Int  // how many plan points we actually reached (early-stop/cancel reduces this)
    public let decodedSampleCount: Int    // of the attempted points, how many decoded a real frame
    public let ocrExecutedCount: Int      // of the decoded frames, how many OCR actually ran over
    public let earlyStopped: Bool         // did we stop before attempting the whole plan?
    public let earlyStopReason: ReelsEarlyStopReasonV1
    /// Always true for sampled analysis: examined points ≠ the whole video. Surfaced so "clean" is scoped honestly.
    public let temporalCoverageLimited: Bool
    public init(plannedSampleCount: Int, attemptedSampleCount: Int, decodedSampleCount: Int, ocrExecutedCount: Int,
                earlyStopped: Bool, earlyStopReason: ReelsEarlyStopReasonV1, temporalCoverageLimited: Bool = true) {
        self.plannedSampleCount = plannedSampleCount; self.attemptedSampleCount = attemptedSampleCount
        self.decodedSampleCount = decodedSampleCount; self.ocrExecutedCount = ocrExecutedCount
        self.earlyStopped = earlyStopped; self.earlyStopReason = earlyStopReason
        self.temporalCoverageLimited = temporalCoverageLimited
    }
    public static let empty = ReelsCoverageCountersV1(plannedSampleCount: 0, attemptedSampleCount: 0,
                                                      decodedSampleCount: 0, ocrExecutedCount: 0,
                                                      earlyStopped: false, earlyStopReason: .none)
}

/// The honest evidence bundle produced for ONE reel before exposure. Text + where it came from + how much of the
/// planned analysis actually ran (coverage) + whether real OCR executed at all + §7 per-timepoint records.
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
    /// §7 — the per-timepoint records (start/mid/end …). Empty for the legacy single-frame path / stubbed evidence.
    public let timedRecords: [ReelsTimedEvidenceV1]
    /// §B2 — HONEST, SEPARATED coverage accounting. These must never be collapsed into one "N/M frames" or presented
    /// as "the whole video". `plannedSampleCount` is the full adaptive plan size; `attemptedSampleCount` is how many
    /// of those points we actually reached (early-stop reduces this); `decodedSampleCount` is how many of the
    /// attempted points decoded a frame; `ocrExecutedCount` is how many decoded frames OCR actually ran over;
    /// `earlyStopped` + `earlyStopReason` say whether (and why) we stopped before the plan finished. A 1/5 early-stop
    /// is NEVER shown as 5/5, and 5/5 is never "all of the video".
    public let planCounters: ReelsCoverageCountersV1
    /// §D/§E — the AUDIO evidence for this reel (Apple Sound Analysis over the owned file), or nil when the audio
    /// sense was not run for this evaluation (e.g. a stub/vision-only path). SEPARATE provenance from the visual OCR
    /// above — the two are never fused into one claim (E1/E3). `nil` here means "audio not gathered" (coverage narrows,
    /// never "silent/safe"); a non-nil bundle with `.noAudioTrack`/`.deferredThermal` is the honest absence report.
    public let audio: ReelsAudioEvidenceV1?
    /// §7 — PARTIAL_COVERAGE honesty: true when we did NOT decode every planned timepoint, so "clean" is scoped to
    /// what we actually sampled (a few clean frames ≠ the whole video clean). Drives the UNKNOWN/"Neden?" copy.
    public var partialCoverage: Bool { frameCoverage < 1.0 }

    /// §E — the distinct REAL classifier labels the audio sense produced (empty when audio not run / no events). This
    /// is the `soundEvents` list threaded into the frozen shield envelope so a user `.soundClass` rule can match —
    /// fusion happens in the EXISTING evaluator, not re-implemented here.
    public var audioLabels: [String] { audio?.distinctLabels ?? [] }

    public init(combinedText: String, ocrText: String, metadataText: String, frameCoverage: Double,
                provenance: ReelsEvidenceProvenanceV1, ocrExecuted: Bool, languages: [String],
                timedRecords: [ReelsTimedEvidenceV1] = [],
                planCounters: ReelsCoverageCountersV1 = .empty,
                audio: ReelsAudioEvidenceV1? = nil) {
        self.combinedText = combinedText; self.ocrText = ocrText; self.metadataText = metadataText
        self.frameCoverage = frameCoverage; self.provenance = provenance
        self.ocrExecuted = ocrExecuted; self.languages = languages; self.timedRecords = timedRecords
        self.planCounters = planCounters; self.audio = audio
    }

    /// §D/§E — a copy of this evidence bundle with audio attached (so the model can gather visual first, then audio,
    /// and merge — keeping the two senses' provenance separate). Pure; never mutates the visual facts.
    public func withAudio(_ audio: ReelsAudioEvidenceV1?) -> ReelsEvidenceV1 {
        ReelsEvidenceV1(combinedText: combinedText, ocrText: ocrText, metadataText: metadataText,
                        frameCoverage: frameCoverage, provenance: provenance, ocrExecuted: ocrExecuted,
                        languages: languages, timedRecords: timedRecords, planCounters: planCounters, audio: audio)
    }

    /// §7 — the subset of timepoints where OCR really ran (used to attribute a match to its real video time).
    public var sampledTimepointsSeconds: [Double] { timedRecords.map { $0.timestampSeconds } }

    /// An empty bundle — no evidence at all (honest UNKNOWN; never "safe").
    public static let empty = ReelsEvidenceV1(combinedText: "", ocrText: "", metadataText: "", frameCoverage: 0,
                                              provenance: .none, ocrExecuted: false, languages: [])
}

/// §E2 — an optional per-sample EARLY-STOP probe the caller injects. Given a decoded sample's recognized text, it
/// returns true iff that text VERIFIES a match (a real rule matched). The provider stops decoding the rest of the
/// plan once this fires — no value in sampling further once we know the item will be acted on. nil ⇒ no early stop
/// (sample the whole plan). Always a REAL per-sample verdict (the caller runs the frozen evaluator), never a guess.
public typealias ReelsSampleMatchProbe = @Sendable (_ sampleText: String) -> Bool

/// The pre-exposure evidence port. A real implementation decodes frames + runs Vision OCR; tests may inject a
/// deterministic implementation so the player state machine is testable without AVFoundation runtime variance.
public protocol ReelsEvidenceProviding: Sendable {
    /// Gather honest pre-exposure evidence for a local reel. `firstFrameSeconds` are the timestamps to OCR.
    func gatherEvidence(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String]) async -> ReelsEvidenceV1
    /// §E2 — adaptive variant: duration-based budgeted sampling with optional early-stop + thermal awareness. Default
    /// implementation ignores the extra params so existing stub providers keep working unchanged.
    func gatherEvidenceAdaptive(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String],
                                thermal: ReelsThermalBucketV1, earlyStopProbe: ReelsSampleMatchProbe?) async -> ReelsEvidenceV1
}

public extension ReelsEvidenceProviding {
    /// Default: fall back to the plain gather (stub providers don't need the adaptive machinery).
    func gatherEvidenceAdaptive(url: URL, metadataTitle: String, firstFrameSeconds: [Double], languages: [String],
                                thermal: ReelsThermalBucketV1, earlyStopProbe: ReelsSampleMatchProbe?) async -> ReelsEvidenceV1 {
        await gatherEvidence(url: url, metadataTitle: metadataTitle, firstFrameSeconds: firstFrameSeconds, languages: languages)
    }
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
        await gatherEvidenceAdaptive(url: url, metadataTitle: metadataTitle, firstFrameSeconds: firstFrameSeconds,
                                     languages: languages, thermal: Self.liveThermalBucket(), earlyStopProbe: nil)
    }

    /// §E2 — the ADAPTIVE gather. Budgeted, duration-based sampling (≤5, thermal-shrunk) via ReelsAdaptiveSamplerV1;
    /// SEQUENTIAL decode so an EARLY-STOP probe can halt once a sample verifies a match (the rest of the plan is
    /// pointless then); CANCELLATION-aware (a content change cancels the Task → we stop and the caller discards the
    /// stale result). Each OCR result is attributed to its REAL requested timestamp — a mid-segment match is stamped
    /// with the mid timestamp (no cross-sample string invention; the engine re-checks per sample for the matched rule).
    public func gatherEvidenceAdaptive(url: URL, metadataTitle: String, firstFrameSeconds: [Double],
                                       languages: [String], thermal: ReelsThermalBucketV1,
                                       earlyStopProbe: ReelsSampleMatchProbe?) async -> ReelsEvidenceV1 {
        let metadata = metadataTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let times = await Self.adaptiveSampleTimes(url: url, seedEarly: firstFrameSeconds, thermal: thermal)
        let provider = VideoFrameProvider(url: url)
        let earlyStop = ReelsEarlyStopV1()
        var records: [ReelsTimedEvidenceV1] = []
        var ocrPieces: [String] = []
        var decodedCount = 0
        var ocrExecutedCount = 0  // §B2 — decoded frames OCR actually ran over (RAN or RAN_NO_TEXT), separated honestly
        var plannedExecuted = 0   // how many planned points we actually reached (early-stop reduces this honestly)
        var earlyStopReason: ReelsEarlyStopReasonV1 = .none
        let planned = times.count   // §B2 — the full adaptive plan size (intended points)
        for t in times {
            if Task.isCancelled { earlyStopReason = .cancelled; break }  // content changed → caller discards the stale evidence
            plannedExecuted += 1
            let fs = await provider.frames(atSeconds: [t])   // one point at a time so we can stop between points
            let f = fs.first
            let ts = f?.actualTimeSeconds ?? t
            guard let img = f?.image else {
                records.append(.init(timestampSeconds: ts, modality: .visualOCR, ocrStatus: .notDecoded, text: ""))
                continue
            }
            decodedCount += 1
            let text = ocr.recognizeText(cgImage: img).value?.text ?? ""
            ocrExecutedCount += 1  // OCR ran over this decoded frame regardless of whether it found legible text
            if text.isEmpty {
                records.append(.init(timestampSeconds: ts, modality: .visualOCR, ocrStatus: .ranNoText, text: ""))
            } else {
                records.append(.init(timestampSeconds: ts, modality: .visualOCR, ocrStatus: .ran, text: text))
                ocrPieces.append(text)
                // §E2 EARLY-STOP: if this sample's REAL text verifies a match, there is no value decoding the rest.
                if let probe = earlyStopProbe, earlyStop.shouldStop(verifiedMatchAtSample: probe(text)) {
                    earlyStopReason = .verifiedMatch; break
                }
            }
        }
        // combinedText fuses ALL examined timepoints' text so the overall shield pass catches a match at any sampled
        // time; the engine ALSO re-evaluates each sample to cite the matched rule per timepoint (E1). Coverage is the
        // fraction of the points we ACTUALLY executed that decoded (not the whole plan — early-stop is honest).
        let ocrText = ocrPieces.joined(separator: " ")
        let coverage = plannedExecuted == 0 ? 0 : Double(decodedCount) / Double(plannedExecuted)
        let earlyStopped = plannedExecuted < planned || earlyStopReason != .none
        let counters = ReelsCoverageCountersV1(plannedSampleCount: planned, attemptedSampleCount: plannedExecuted,
                                               decodedSampleCount: decodedCount, ocrExecutedCount: ocrExecutedCount,
                                               earlyStopped: earlyStopped,
                                               earlyStopReason: earlyStopped && earlyStopReason == .none ? .budgetThermal : earlyStopReason)
        return Self.fuse(ocrText: ocrText, metadataText: metadata, frameCoverage: coverage,
                         ocrExecuted: decodedCount > 0, languages: languages, timedRecords: records,
                         planCounters: counters)
    }

    /// Map the live ProcessInfo thermal state to the sampler's pure bucket (the only place the real API is read).
    public static func liveThermalBucket() -> ReelsThermalBucketV1 {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal; case .fair: return .fair; case .serious: return .serious
        case .critical: return .critical; @unknown default: return .serious
        }
    }

    /// §E2 — compute the ADAPTIVE sample timestamps via ReelsAdaptiveSamplerV1 (duration-based, budgeted, thermal).
    /// Reads the real duration (best effort); on failure falls back to the seed early points only (no fabricated mid/
    /// end). Replaces the old fixed start/mid/end `temporalSampleTimes`.
    static func adaptiveSampleTimes(url: URL, seedEarly: [Double], thermal: ReelsThermalBucketV1) async -> [Double] {
        let meta = await MediaAssetSource().loadMetadata(url: url)
        let dur: Double = { if case .success(let m) = meta, m.durationSeconds > 0 { return m.durationSeconds }; return 0 }()
        return ReelsAdaptiveSamplerV1().sampleTimes(durationSeconds: dur, seedEarly: seedEarly, thermal: thermal)
    }

    /// PURE fusion + honest provenance classification (testable without AVFoundation). The combined text is what
    /// the frozen evaluator runs against; the provenance says what the decision mostly rests on.
    public static func fuse(ocrText: String, metadataText: String, frameCoverage: Double,
                            ocrExecuted: Bool, languages: [String],
                            timedRecords: [ReelsTimedEvidenceV1] = [],
                            planCounters: ReelsCoverageCountersV1 = .empty) -> ReelsEvidenceV1 {
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
                               ocrExecuted: ocrExecuted, languages: languages, timedRecords: timedRecords,
                               planCounters: planCounters)
    }
}
#endif
