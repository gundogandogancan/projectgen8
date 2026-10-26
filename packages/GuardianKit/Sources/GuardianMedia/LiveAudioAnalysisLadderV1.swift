//
//  LiveAudioAnalysisLadderV1.swift — R9 §1/§2.3/§3 (P0-1/P0-2/P0-3): the HONEST AUDIO-ANALYSIS STATE LADDER +
//  the explicit WINDOW-COMPLETION CONTRACT with a timeout policy + the ANALYZER-FRAME ↔ REPLAYKIT-PTS mapping contract.
//
//  WHY THIS EXISTS (the R9 P0 defect — mandate §1): the R8 live-audio path could set
//  `LiveAudioWindowEvidenceV1(availability: .available, events: [])` the INSTANT a window's worth of buffers was
//  drained — WITHOUT the SoundAnalysis classifier ever running. "Buffer geldi diye sesin analiz edildiğini iddia
//  etme." A buffer arriving is NOT analysis; an empty collector read immediately after `start()` is NOT a clean
//  result. That produced a FAKE `.available` that the world-model bridge and the coverage UI then trusted.
//
//  THE FIX (mandate §1): a buffer's journey to a real result is an explicit LADDER of states. `.available` is
//  reachable ONLY when the window genuinely climbed the ladder through the classifier:
//
//     audioBufferReceived → pcmConversionSucceeded → classifierInitialized → classifierWindowSubmitted
//        → classifierResultReceived  ─────────────────────────────┐
//        → analysisCompletedNoEvent (verified completion, no label)┤ → these two are the ONLY "analysis genuinely ran"
//                                                                  │   terminals (mandate §2.3 completion semantics)
//     ... or an honest NON-analysis terminal (NEVER .available):
//        analysisFailed · resourceDeferred · formatUnsupported · captureUnavailable · deviceUnverified
//
//  COMPLETION SEMANTICS (mandate §2.3): SUBMITTED ≠ RESULT_RECEIVED ≠ WINDOW_COMPLETE. Starting the analyzer and
//  immediately reading an empty collector is NOT success. `analysisCompletedNoEvent` is lawful ONLY after a REAL
//  submission (`classifierWindowSubmitted` was reached) AND the completion contract observed a genuine completion
//  (the analyzer finished the window, or `completeAnalysis()` flushed it) — never merely "the collector is empty now".
//  Until that, an un-completed window is `classifierWindowSubmitted` (pending), which maps to UNAVAILABLE, not clean.
//
//  TIMEBASE MAPPING (mandate §3): SoundAnalysis `timeRange`/`atAudioFramePosition:` is in the ANALYZER's own frame
//  domain (frames counted from the first buffer fed to THIS analyzer), NOT ReplayKit's absolute presentation PTS.
//  `AudioFrameToPTSMapV1` is the explicit, documented mapping: anchored to the REAL first-buffer PTS of the window +
//  the sample rate, it converts an analyzer frame position back to an absolute PTS. Unmappable (no anchor / no rate)
//  → nil → the evidence is UNBOUND/UNKNOWN for its timebase (never a fabricated absolute stamp).
//
//  Pure value types + a small mutating ladder + a pure completion contract. No SoundAnalysis import here (testable on
//  every SDK). Lives in GuardianMedia (GuardianCore frozen).
//
import Foundation

/// R9 §1 — the EXPLICIT audio-analysis ladder state for ONE window. Ordered: a higher `rank` means the window climbed
/// further toward a real result. Only `.classifierResultReceived` and `.analysisCompletedNoEvent` are "analysis
/// genuinely ran" terminals. Every other state — including the PENDING `.classifierWindowSubmitted` — is NOT analysis
/// success and must map to an UNAVAILABLE audio modality (no sound ≠ safe).
public enum LiveAudioAnalysisStateV1: String, Sendable, Equatable, Codable, CaseIterable {
    // --- progress rungs (not yet a result) ---
    case audioBufferReceived      = "AUDIO_BUFFER_RECEIVED"       // a buffer arrived; nothing analyzed yet
    case pcmConversionSucceeded   = "PCM_CONVERSION_SUCCEEDED"    // the buffer became a valid AVAudioPCMBuffer
    case classifierInitialized    = "CLASSIFIER_INITIALIZED"      // SNAudioStreamAnalyzer + request armed
    case classifierWindowSubmitted = "CLASSIFIER_WINDOW_SUBMITTED" // analyze(_:atAudioFramePosition:) was called (PENDING)
    // --- the ONLY two "analysis genuinely ran" terminals ---
    case classifierResultReceived = "CLASSIFIER_RESULT_RECEIVED"  // a real SNClassificationResult arrived
    case analysisCompletedNoEvent = "ANALYSIS_COMPLETED_NO_EVENT" // the window COMPLETED (verified) with no label above floor
    // --- honest non-analysis terminals (NEVER .available) ---
    case analysisFailed           = "ANALYSIS_FAILED"            // the analyzer threw / errored mid-window
    case resourceDeferred         = "RESOURCE_DEFERRED"          // thermal/budget deferral — analysis did not run
    case formatUnsupported        = "FORMAT_UNSUPPORTED"         // PCM format could not drive the stream analyzer
    case captureUnavailable       = "CAPTURE_UNAVAILABLE"        // no audioApp buffers (capture gap) — nothing to analyze
    case deviceUnverified         = "DEVICE_UNVERIFIED"          // host cannot run SoundAnalysis inference (off-device)

    /// Monotonic progress rank (higher = climbed further). Used only for diagnostics/assertions; order is the ladder.
    public var rank: Int {
        switch self {
        case .audioBufferReceived:       return 1
        case .pcmConversionSucceeded:    return 2
        case .classifierInitialized:     return 3
        case .classifierWindowSubmitted: return 4
        case .classifierResultReceived:  return 5
        case .analysisCompletedNoEvent:  return 5   // a COMPLETED empty window is as "done" as a result
        default:                         return 0   // the honest non-analysis terminals carry no progress rank
        }
    }

    /// R9 §1 — did the classifier GENUINELY run and complete this window? TRUE only for the two real terminals.
    /// This is the single authority the caller uses to decide whether `availability == .available` is lawful.
    public var analysisGenuinelyRan: Bool {
        self == .classifierResultReceived || self == .analysisCompletedNoEvent
    }

    /// R9 §1 — map the ladder state onto the existing coarse availability enum. ONLY the two real terminals map to
    /// `.available`; `resourceDeferred`→thermal/resource, `formatUnsupported`→format, everything else (incl. the
    /// PENDING submitted rung) → a NON-available reason so the modality stays UNAVAILABLE (no fake clean result).
    public func toAvailability(wasThermalDeferral: Bool) -> LiveAudioAvailabilityV1 {
        switch self {
        case .classifierResultReceived, .analysisCompletedNoEvent:
            return .available
        case .resourceDeferred:
            return wasThermalDeferral ? .deferredThermal : .resourceDeferred
        case .formatUnsupported:
            return .formatUnsupported
        case .captureUnavailable:
            return .noBuffers
        case .deviceUnverified, .analysisFailed:
            return .frameworkUnavailable
        // The progress rungs below a real terminal are NOT analysis success — a window that was submitted but whose
        // completion was never verified is PENDING, which is UNAVAILABLE (never "analyzed clean"). §2.3 completion law.
        case .audioBufferReceived, .pcmConversionSucceeded, .classifierInitialized, .classifierWindowSubmitted:
            return .frameworkUnavailable
        }
    }
}

/// R9 §2.3 — the explicit WINDOW-COMPLETION CONTRACT. A window is a sequence of ladder transitions; this type is the
/// single pure authority on whether the window reached a lawful `.available` state. It enforces the completion
/// semantics mandate §2.3 demands: a result/completion is ONLY honoured if the window was actually SUBMITTED first,
/// and a completion that arrives after a timeout (or after the item changed) is NOT a success. Fully testable without
/// SoundAnalysis — the caller feeds it the real transitions it observed from the analyzer/observer.
public struct LiveAudioWindowCompletionContractV1: Sendable, Equatable {
    /// The furthest ladder rung the window reached.
    public private(set) var state: LiveAudioAnalysisStateV1
    /// True once `analyze(_:atAudioFramePosition:)` was genuinely called for this window (a real submission happened).
    public private(set) var submitted = false
    /// True once at least one real `SNClassificationResult` was received for this window.
    public private(set) var resultReceived = false
    /// True once the analyzer confirmed the window finished (completeAnalysis flushed / per-window completion fired).
    public private(set) var completionObserved = false
    /// True if a thermal/budget deferral set this window's terminal (so the availability maps to thermal vs resource).
    public private(set) var thermalDeferral = false
    /// The wall-clock (monotonic seconds) the window was submitted — used by the timeout policy.
    public private(set) var submittedAtSeconds: Double?

    /// R9 §2.3 — the completion timeout. A window that was submitted but produced neither a result NOR an observed
    /// completion within this budget is TIMED OUT → `analysisFailed` (NOT a clean empty result). Small + fixed: a live
    /// window is ~1s of audio; the streaming classifier produces per-window results within a second or two on-device.
    public static let completionTimeoutSeconds: Double = 3.0

    public init() { self.state = .captureUnavailable }

    /// Begin a window: we have (or will have) buffers to analyze. Resets to the first progress rung.
    public mutating func beginWindow() {
        state = .audioBufferReceived
        submitted = false; resultReceived = false; completionObserved = false; thermalDeferral = false
        submittedAtSeconds = nil
    }

    /// Record a deferral terminal (analysis genuinely did NOT run). `thermal` picks the honest availability reason.
    public mutating func markDeferred(thermal: Bool) {
        state = .resourceDeferred; thermalDeferral = thermal
    }
    /// Record that no audioApp buffers were available for this window (capture gap). Never "clean".
    public mutating func markNoBuffers() { state = .captureUnavailable }
    /// Record that PCM conversion succeeded (a valid AVAudioPCMBuffer exists for at least one buffer).
    public mutating func markPCMConverted() { if state.rank < LiveAudioAnalysisStateV1.pcmConversionSucceeded.rank { state = .pcmConversionSucceeded } }
    /// Record that the stream analyzer + request were armed.
    public mutating func markClassifierInitialized() { if state.rank < LiveAudioAnalysisStateV1.classifierInitialized.rank { state = .classifierInitialized } }
    /// Record that the PCM format could not drive the analyzer (unsupported format). Honest non-analysis terminal.
    public mutating func markFormatUnsupported() { state = .formatUnsupported }
    /// Record that the analyzer could not be constructed / the host cannot run inference. Off-device terminal.
    public mutating func markDeviceUnverified() { state = .deviceUnverified }
    /// Record an analyzer error mid-window.
    public mutating func markAnalysisFailed() { state = .analysisFailed }

    /// R9 §2.3 — record a REAL submission: `analyze(_:atAudioFramePosition:)` was actually called. Stamps the submit
    /// time for the timeout policy. Until completion is observed this is the PENDING rung (maps to UNAVAILABLE).
    public mutating func markSubmitted(atSeconds: Double) {
        submitted = true; submittedAtSeconds = atSeconds
        if state.rank < LiveAudioAnalysisStateV1.classifierWindowSubmitted.rank { state = .classifierWindowSubmitted }
    }

    /// R9 §2.3 — record that a real classification RESULT arrived. Lawful ONLY if the window was submitted first
    /// (a result without a submission is impossible and is ignored — defense in depth against a stray observer call).
    public mutating func markResultReceived() {
        guard submitted else { return }
        resultReceived = true
        state = .classifierResultReceived
    }

    /// R9 §2.3 — record that the analyzer CONFIRMED the window finished (completeAnalysis flushed, or a final per-window
    /// completion fired). Lawful ONLY after a submission. With a result already in hand this stays
    /// `.classifierResultReceived`; with NO result it becomes the verified `.analysisCompletedNoEvent` (the sense ran,
    /// found nothing above the floor) — which is the ONLY path to a clean empty `.available`.
    public mutating func markCompletionObserved() {
        guard submitted else { return }
        completionObserved = true
        if resultReceived { state = .classifierResultReceived }
        else { state = .analysisCompletedNoEvent }
    }

    /// R9 §2.3 — resolve the window against the timeout. If it was submitted but neither a result nor a completion was
    /// observed within the budget, it is TIMED OUT → `analysisFailed` (NOT a clean result). Returns the final state.
    /// `nowSeconds` is the caller's monotonic clock; a nil submit time (never submitted) is left untouched.
    @discardableResult
    public mutating func resolveTimeout(nowSeconds: Double) -> LiveAudioAnalysisStateV1 {
        if submitted, !resultReceived, !completionObserved,
           let t = submittedAtSeconds, nowSeconds - t >= Self.completionTimeoutSeconds {
            state = .analysisFailed
        }
        return state
    }

    /// R9 §1/§2.3 — the SINGLE authority: may this window produce `availability == .available`? TRUE only when the
    /// classifier genuinely ran and completed (result received, or a VERIFIED completed-no-event). A submitted-but-
    /// pending window, a deferral, a format reject, a device-unverified host — all FALSE.
    public var mayReportAvailable: Bool { state.analysisGenuinelyRan }

    /// The honest coarse availability this window maps to (for `LiveAudioWindowEvidenceV1`).
    public var availability: LiveAudioAvailabilityV1 { state.toAvailability(wasThermalDeferral: thermalDeferral) }
}

/// R9 §3 — the ANALYZER-FRAME ↔ REPLAYKIT-PTS mapping contract. SoundAnalysis counts frames from the first buffer fed
/// to the analyzer (the analyzer's own domain); ReplayKit stamps each CMSampleBuffer with an absolute presentation
/// time. To attribute an audio event to a REAL absolute PTS span (for identity binding + world-model temporal scope)
/// we anchor the analyzer's frame-0 to the REAL first-buffer PTS of the window and convert via the sample rate.
/// Unmappable (no anchor PTS, non-positive rate) → nil (the evidence stays UNBOUND/UNKNOWN for its timebase — mandate
/// §3: "SoundAnalysis'ın framePosition değerlerini ReplayKit'in absolute PTS'siyle doğrudan aynı zaman ekseni kabul
/// etme"). Pure + testable.
public struct AudioFrameToPTSMapV1: Sendable, Equatable, Codable {
    /// The REAL absolute presentation time (seconds) of the FIRST buffer fed to the analyzer for this window.
    public let anchorPTSSeconds: Double?
    /// The PCM sample rate the analyzer is running at (Hz). Non-positive / nil → unmappable.
    public let sampleRate: Double?
    public init(anchorPTSSeconds: Double?, sampleRate: Double?) {
        self.anchorPTSSeconds = anchorPTSSeconds; self.sampleRate = sampleRate
    }
    /// Convert an ANALYZER frame position (frames since analyzer start) to an ABSOLUTE PTS (seconds). nil when the map
    /// has no anchor or a non-positive rate — the caller then treats the timebase as UNKNOWN (never fabricates one).
    public func absolutePTS(forAnalyzerFrame frame: Double) -> Double? {
        guard let anchor = anchorPTSSeconds, let rate = sampleRate, rate > 0, frame >= 0 else { return nil }
        return anchor + (frame / rate)
    }
    /// Convert an ANALYZER time range (seconds in the analyzer domain, as SNClassificationResult.timeRange reports) to
    /// an ABSOLUTE PTS range. nil when unmappable. The analyzer-domain seconds are frame/rate already, so we just add
    /// the anchor — but ONLY when an anchor exists (otherwise the range is analyzer-relative and NOT an absolute PTS).
    public func absolutePTSRange(analyzerStartSeconds: Double?, analyzerEndSeconds: Double?) -> (start: Double?, end: Double?) {
        guard let anchor = anchorPTSSeconds else { return (nil, nil) }
        let s = analyzerStartSeconds.map { anchor + $0 }
        let e = analyzerEndSeconds.map { anchor + $0 }
        return (s, e)
    }
    /// True when this map can produce absolute PTS (has an anchor + a positive rate). When false the caller must leave
    /// the window's PTS span nil (UNBOUND timebase) rather than fabricate an absolute stamp.
    public var isMappable: Bool { anchorPTSSeconds != nil && (sampleRate ?? 0) > 0 }
}
