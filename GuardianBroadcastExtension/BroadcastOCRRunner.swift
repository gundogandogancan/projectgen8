//
//  BroadcastOCRRunner.swift — REAL on-device Vision OCR for the broadcast pipeline (C3 fix)
//
//  WHY THIS EXISTS (defect C3 "vacuous shield"):
//  SampleHandler previously built every ShieldEvaluator envelope with `ocrText: nil`, so 100% of shield
//  decisions were NO_MATCH with zero semantic understanding. This file wires REAL VNRecognizeTextRequest
//  (Apple-supported, on-device, offline — the same request the in-app VisionOCRProvider uses) into the
//  cross-app broadcast path so protection evaluation receives actual text evidence.
//
//  COST DISCIPLINE (audit C1 thermal hazard + ~50MB extension budget — real-time constraint):
//  OCR is EXPENSIVE and must NEVER run per-frame. Two independent guards (both in BroadcastOCRThrottleV1,
//  which is pure/headless-testable):
//    1. EVENT-GATED: the caller invokes OCR only when the Tier-0 item grouper opens a NEW content item
//       (decision.openedNewItem) — i.e. on a committed shot boundary that begins a new item, never on
//       intra-shot motion and never on REUSED_ITEM frames. This is the cheapest correct hook: there is at
//       most one understanding per item by design (§9/§26).
//    2. RATE-LIMITED + SERIAL: a minimum inter-OCR interval (default 1000ms) plus an in-flight flag that
//       DROPS the request if an OCR is already running. No queue buildup — a burst of rapid item opens can
//       never stack OCR work; we skip rather than fall behind (real-time safety over completeness).
//  The pixel buffer is DOWNSCALED to <=720p before OCR and processed inside an autoreleasepool so the
//  transient CIImage/CGImage are released immediately; the raw broadcast buffer is never retained or copied
//  beyond the single synchronous OCR pass.
//
//  PRIVACY: derived text only, on-device, offline. Raw frames are never persisted (unchanged from C1/C2
//  discipline). The recognized text enters the ephemeral envelope and is used solely for shield matching.
//
import Foundation
import CoreVideo
#if canImport(Vision)
import Vision
import CoreImage
import CoreGraphics
#endif

// MARK: - Pure, headless-testable throttle (no Vision dependency → unit-testable off-device)

/// Decides whether an OCR run is PERMITTED right now, given a minimum interval and an in-flight guard.
/// Deterministic and side-effect-free except for the explicit `beginRun`/`endRun` lifecycle — this is the
/// one unit of C3 that is lawfully testable without the ReplayKit runtime.
struct BroadcastOCRThrottleV1 {
    /// Minimum milliseconds between the START of two OCR runs. Default 1s (audit C1 cadence guidance).
    let minIntervalMs: Double
    private var lastRunStartMs: Double? = nil
    private(set) var inFlight: Bool = false

    init(minIntervalMs: Double = 1000) { self.minIntervalMs = max(0, minIntervalMs) }

    /// Returns true iff an OCR run may start at `nowMs`: not already in flight AND enough time has elapsed
    /// since the previous run started. Does NOT mutate — call `beginRun` to actually commit a start.
    func shouldRun(nowMs: Double) -> Bool {
        if inFlight { return false }
        guard let last = lastRunStartMs else { return true }
        return (nowMs - last) >= minIntervalMs
    }

    /// Commit the start of an OCR run (sets in-flight, records the start time). Caller must pair with `endRun`.
    mutating func beginRun(nowMs: Double) {
        lastRunStartMs = nowMs
        inFlight = true
    }

    /// Mark the current OCR run finished (clears the in-flight guard). Does not affect the interval clock.
    mutating func endRun() { inFlight = false }
}

// MARK: - OCR run outcome — distinguishes "ran, no text" from "not run" (diagnostic surface, audit requirement)

/// Why an envelope did or did not get OCR text. Lets the proof log tell NO_TEXT (OCR ran, empty) apart from
/// SKIPPED (throttled / in-flight) — the C3 diagnostic requirement.
enum BroadcastOCRStatus: String {
    case ran           // OCR executed and produced non-empty text
    case ranNoText     // OCR executed but recognized nothing
    case skippedThrottle  // not run: min-interval not elapsed, or an OCR was already in flight
    case unavailable   // Vision unavailable or buffer could not be prepared
}

struct BroadcastOCRResult {
    let status: BroadcastOCRStatus
    let text: String?           // non-nil & non-empty only when status == .ran
    let languages: [String]     // languages Vision reported for recognized text (empty if none)
    let latencyMs: Double
    let downscaledLongSide: Int // the longer dimension actually fed to Vision (proof of <=720p downscale)
}

// MARK: - Vision OCR runner (downscale -> VNRecognizeTextRequest). Synchronous, serial by construction.

enum BroadcastOCRRunnerV1 {
    /// Target maximum long-side after downscale. <=720p keeps the transient image small (memory budget) while
    /// preserving enough resolution for on-screen caption/UI text. Vision does its own internal tiling above this.
    static let maxLongSide = 720

    #if canImport(Vision)
    // One reusable CIContext (software path is fine; the extension has no persistent GPU surface and we want a
    // small, predictable footprint). Created lazily, reused across runs — not per-frame allocation.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Run REAL on-device OCR on a DOWNSCALED copy of `px`. Synchronous: the caller guarantees seriality via
    /// BroadcastOCRThrottleV1 (in-flight guard). Everything transient is released inside the autoreleasepool.
    static func recognize(_ px: CVPixelBuffer, fastMode: Bool = true) -> BroadcastOCRResult {
        let start = DispatchTime.now().uptimeNanoseconds
        return autoreleasepool { () -> BroadcastOCRResult in
            let w = CVPixelBufferGetWidth(px), h = CVPixelBufferGetHeight(px)
            guard w > 0, h > 0 else {
                return BroadcastOCRResult(status: .unavailable, text: nil, languages: [], latencyMs: 0, downscaledLongSide: 0)
            }
            // Downscale to <=720p long side. Scaling down only (never up) — cost is bounded by the target, not the source.
            let longSide = max(w, h)
            let scale = longSide > maxLongSide ? Double(maxLongSide) / Double(longSide) : 1.0
            let outLong = Int((Double(longSide) * scale).rounded())

            var ci = CIImage(cvPixelBuffer: px)
            if scale < 1.0 {
                ci = ci.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
            }
            guard let cg = ciContext.createCGImage(ci, from: ci.extent) else {
                let lat = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
                return BroadcastOCRResult(status: .unavailable, text: nil, languages: [], latencyMs: lat, downscaledLongSide: 0)
            }

            let req = VNRecognizeTextRequest()
            req.recognitionLevel = fastMode ? .fast : .accurate   // .fast: lower CPU/thermal, adequate for UI/caption text
            req.usesLanguageCorrection = true
            // Let Vision auto-detect language rather than forcing a set (cheap; avoids a false "en" assumption).
            // HONEST NOTE: Vision does not expose the per-result DETECTED language cheaply. We therefore report the
            // request's configured recognition languages (what we asked it to look for) and leave the recognized
            // set unclaimed — the envelope builder defaults to ["en"] when we pass nothing, which is the same
            // behavior as before, so we never invent a language signal we cannot substantiate.
            if #available(iOS 16.0, *) { req.automaticallyDetectsLanguage = true }
            let configuredLangs = req.recognitionLanguages   // what Vision will attempt (may be empty under auto-detect)

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try handler.perform([req]) } catch {
                let lat = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000
                return BroadcastOCRResult(status: .unavailable, text: nil, languages: [], latencyMs: lat, downscaledLongSide: outLong)
            }

            let obs = (req.results ?? []).compactMap { $0 as? VNRecognizedTextObservation }
            let text = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            let langs = configuredLangs
            let lat = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1_000_000

            if text.isEmpty {
                return BroadcastOCRResult(status: .ranNoText, text: nil, languages: [], latencyMs: lat, downscaledLongSide: outLong)
            }
            return BroadcastOCRResult(status: .ran, text: text, languages: langs, latencyMs: lat, downscaledLongSide: outLong)
        }
    }
    #else
    static func recognize(_ px: CVPixelBuffer, fastMode: Bool = true) -> BroadcastOCRResult {
        return BroadcastOCRResult(status: .unavailable, text: nil, languages: [], latencyMs: 0, downscaledLongSide: 0)
    }
    #endif
}
