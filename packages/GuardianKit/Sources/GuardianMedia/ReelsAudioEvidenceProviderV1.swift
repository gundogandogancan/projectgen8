//
//  ReelsAudioEvidenceProviderV1.swift — §D: AUDIO EVIDENCE V1, "The Guardian Learns to Hear".
//
//  WHAT THIS IS (mandate D): the FIRST real audio sense for the controlled reels player. It extracts the audio track
//  of a LOCAL, project-OWNED reel and runs Apple's built-in sound classifier (SoundAnalysis: SNAudioFileAnalyzer +
//  SNClassifySoundRequest) over it, producing honest AUDIO_EVENT records — the classifier's REAL returned labels with
//  their RAW model confidence. It is NOT a new decision engine and NOT a new risk model: it is a media→evidence bridge
//  exactly like ReelsEvidenceProviderV1 is for vision. The fusion into a Guardian decision happens in the EXISTING
//  shield path (the frozen SoundClassMatcher already matches a user `.soundClass` rule against these labels).
//
//  HONESTY LAWS THIS FILE OBEYS (mandate D1/D2/D3/J + constitution 1-7, 17, 18, 19):
//   • Only REAL labels: we emit exactly what the classifier returned (filtered to its own dictionary). We NEVER invent
//     a guaranteed class list, and a tone is a tone — we assert on what the classifier ACTUALLY returns, not a wish.
//   • RAW confidence ≠ Guardian risk: the record carries `rawModelConfidence` (the classifier's number), explicitly
//     NOT a calibrated risk score. A sound event is NOT auto-equated to user harm (scary music ≠ psychological harm).
//   • No microphone, no cross-app capture: we analyse the audio CHANNEL of a file we own, via public AVFoundation +
//     SoundAnalysis APIs only. No mic session is opened; no other app's audio is touched; no ReplayKit audio is claimed.
//   • Time ranges only if the request provides them. SNClassifySoundRequest emits per-window results carrying a real
//     CMTimeRange; we use THAT. We never fabricate a timestamp when the framework did not give one.
//   • Absence ≠ silence (D1/E1/H): "no audio track" / "analysis unavailable" is reported as UNAVAILABLE coverage, never
//     as a clean/safe signal. A missing sense narrows coverage honestly; it is never evidence of safety.
//   • Temp files: when we must extract a standalone audio file (some runtimes classify a file better than a track) we
//     write it to a short-lived temp URL and DELETE it immediately after analysis — raw audio is never retained.
//
//  macOS NOTE (mandate 4): SoundAnalysis IS available on macOS, so SNAudioFileAnalyzer tests run headless here. Where a
//  specific classifier label is OS-version dependent, the tests assert on MECHANICS + availability (did analysis run,
//  did it return the classifier's own labels) rather than on a fabricated label — real FP/FN claims only where real.
//
import Foundation
import GuardianCore
// §D — the PURE audio-evidence TYPES must exist wherever ReelsEvidenceV1 does (AVFoundation guard), so the visual
// provider can carry an optional `audio:` field on EVERY platform that has the reels player. SoundAnalysis is a
// SEPARATE capability (not importable on every iOS-simulator SDK): we import it conditionally and gate ONLY the real
// classifier call, so an SDK without SoundAnalysis still compiles (the provider then reports FRAMEWORK_UNAVAILABLE,
// honest absence — never a fabricated clean result).
#if canImport(AVFoundation)
import AVFoundation
#if canImport(SoundAnalysis)
import SoundAnalysis
#endif

/// §D3 — availability of the audio sense for one reel. Distinct from "no event found": UNAVAILABLE means we could not
/// even run the sense (no audio track / decode error / framework unavailable / deferred under thermal pressure), which
/// is NOT silence and NOT safety. `available` means analysis really ran (it may still have produced zero events).
public enum ReelsAudioAvailabilityV1: String, Sendable, Equatable, Codable {
    case available = "AVAILABLE"                 // SoundAnalysis ran over a real audio track
    case noAudioTrack = "NO_AUDIO_TRACK"         // the file has no audio channel (absence ≠ silence; coverage narrows)
    case decodeError = "DECODE_ERROR"            // the audio could not be decoded/analysed (honest failure, not safe)
    case frameworkUnavailable = "FRAMEWORK_UNAVAILABLE" // SoundAnalysis/analyzer could not be constructed on this runtime
    case deferredThermal = "DEFERRED_THERMAL"    // §H — audio analysis was skipped under thermal/budget pressure (not run)
}

/// §D3 — ONE honest audio-event record: the classifier's REAL label + RAW model confidence, attributed to an audio
/// time range ONLY when the request supplied one (CMTimeRange → start/end seconds). Carries its own provenance + the
/// classifier version so the Evidence sheet can say exactly where this came from and never confuse it with vision.
public struct ReelsAudioEventV1: Sendable, Equatable, Codable {
    /// The classifier's own label string (e.g. "speech", "music", "siren") — EXACTLY as returned, never invented.
    public let label: String
    /// §D3 — the RAW model confidence from SNClassificationResult (0...1). This is the classifier's number, NOT a
    /// Guardian risk score and NOT calibrated — the UI labels it as such. nil would mean "unknown" (we always have it
    /// here because the classifier supplies it; a provider that cannot produce one must pass nil, never a placeholder).
    public let rawModelConfidence: Double?
    /// §D3 — the audio time range this event covers, IF the request provided one. nil when the framework did not give a
    /// range (we never fabricate a timestamp). start/end are seconds from the file origin.
    public let startSeconds: Double?
    public let endSeconds: Double?
    /// The classifier identifier/version this event came from (provenance; e.g. the SoundAnalysis built-in classifier).
    public let classifierVersion: String
    public init(label: String, rawModelConfidence: Double?, startSeconds: Double?, endSeconds: Double?,
                classifierVersion: String) {
        self.label = label; self.rawModelConfidence = rawModelConfidence
        self.startSeconds = startSeconds; self.endSeconds = endSeconds; self.classifierVersion = classifierVersion
    }
}

/// §D3 — the audio evidence bundle for one reel: the availability of the sense + the real events + the classifier
/// version + the set of distinct labels (what the frozen SoundClassMatcher is fed). Pure, Codable, player-free.
public struct ReelsAudioEvidenceV1: Sendable, Equatable, Codable {
    public let availability: ReelsAudioAvailabilityV1
    public let events: [ReelsAudioEventV1]
    public let classifierVersion: String
    public init(availability: ReelsAudioAvailabilityV1, events: [ReelsAudioEventV1], classifierVersion: String) {
        self.availability = availability; self.events = events; self.classifierVersion = classifierVersion
    }
    /// The DISTINCT classifier labels present (deduped, lower-cased), strongest-first by raw confidence. This is the
    /// `soundEvents` list threaded into the shield envelope so a user `.soundClass` rule can match (fusion in the
    /// EXISTING engine, not here). Empty when nothing was classified — which is NOT the same as "no audio sense".
    public var distinctLabels: [String] {
        var best: [String: Double] = [:]
        for e in events { let k = e.label.lowercased(); best[k] = max(best[k] ?? 0, e.rawModelConfidence ?? 0) }
        return best.sorted { $0.value > $1.value }.map { $0.key }
    }
    /// Honest coverage note: true only when the audio sense actually RAN. absence (no track / error / deferred) is
    /// NOT coverage — the decision layer must widen UNKNOWN, never claim "silent → safe".
    public var senseRan: Bool { availability == .available }
    /// An UNAVAILABLE bundle with an explicit reason (absence ≠ silence). No events, honest reason preserved.
    public static func unavailable(_ reason: ReelsAudioAvailabilityV1, classifierVersion: String) -> ReelsAudioEvidenceV1 {
        ReelsAudioEvidenceV1(availability: reason, events: [], classifierVersion: classifierVersion)
    }
}

/// §D — the audio evidence port. A real implementation runs SoundAnalysis; tests may inject a deterministic stub so the
/// fusion + coverage logic is testable without SoundAnalysis runtime variance (mirrors the vision provider's pattern).
public protocol ReelsAudioEvidenceProviding: Sendable {
    /// Analyse the audio track of a LOCAL owned reel. `thermal` lets the caller defer heavy analysis under pressure
    /// (§H) — a deferred run returns `.deferredThermal`, never a fabricated clean result. Honours Task cancellation.
    func gatherAudioEvidence(url: URL, thermal: ReelsThermalBucketV1) async -> ReelsAudioEvidenceV1
}

/// §D — the REAL implementation: Apple SoundAnalysis over the owned local file. It wraps the EXISTING GeneralAudioHeadV1
/// (which already drives SNAudioFileAnalyzer + SNClassifySoundRequest) and shapes its output into time-attributed audio
/// events with honest availability. No raw audio retained; any extracted temp file is deleted right after analysis.
public struct ReelsAudioEvidenceProviderV1: ReelsAudioEvidenceProviding {
    public static let version = "reels-audio-evidence-provider-v1"
    public init() {}

    /// §H — under CRITICAL thermal pressure we DEFER audio analysis entirely (it is the secondary sense; visual leads).
    /// This is honest deferral, not a clean result: the coverage narrows and the decision layer treats it as UNKNOWN.
    public func gatherAudioEvidence(url: URL, thermal: ReelsThermalBucketV1) async -> ReelsAudioEvidenceV1 {
        if Task.isCancelled { return .unavailable(.deferredThermal, classifierVersion: Self.version) }
        if thermal == .critical {
            return .unavailable(.deferredThermal, classifierVersion: GeneralAudioHeadV1.version)
        }
        // §D2 — first establish whether the file even HAS an audio track (absence ≠ silence; we must report it honestly).
        let asset = AVURLAsset(url: url)
        let hasAudio = await Self.hasAudioTrack(asset: asset)
        if hasAudio == false {
            return .unavailable(.noAudioTrack, classifierVersion: GeneralAudioHeadV1.version)
        }
        if Task.isCancelled { return .unavailable(.deferredThermal, classifierVersion: Self.version) }
        let classifierVersion = GeneralAudioHeadV1.version
        #if canImport(SoundAnalysis)
        // §D1/§D3 — run the REAL classifier via the existing head's TIMED path. It drives SNAudioFileAnalyzer over the
        // file directly (SoundAnalysis reads the file's audio channel), so no mic session is opened and no temp
        // extraction is needed for the common case. Each per-window result carries the classifier's REAL label + raw
        // confidence + the REAL CMTimeRange the request supplied (converted to seconds) — never a fabricated stamp.
        let head = GeneralAudioHeadV1()
        // §1.2 — REAL CANCELLABLE analysis: a superseding swipe/policy change cancels the enclosing Task and the
        // completion-handler path arms SNAudioFileAnalyzer.cancelAnalysis(), so the analysis actually stops and a
        // cancelled result (UNAVAILABLE) is never applied to a different reel. The MainActor is not blocked.
        let timed = await head.classifyTimedCancellable(url: url)
        switch timed.availability {
        case .unavailable:
            // The analyzer/request could not be constructed on this runtime → the sense is genuinely unavailable.
            return .unavailable(.frameworkUnavailable, classifierVersion: classifierVersion)
        case .available, .unknown:
            // §1.3 — TIME ACCURACY: the SAME label found in TWO SEPARATE time ranges must NOT be collapsed into one
            // min(start)..max(end) "continuous event". The old code took the widest span per label, which fabricated a
            // single long event spanning a silent gap (a siren at 0-1s and again at 8-9s became one "0..9s siren"). The
            // fix MERGES only ADJACENT/OVERLAPPING windows of the same label (gap ≤ maxMergeGapSeconds) and keeps
            // DISTANT occurrences as SEPARATE records — observed windows, honestly attributed. Ranges stay REAL (or nil).
            let events = Self.mergeAdjacentWindows(timed.events, classifierVersion: classifierVersion)
            // `available` even with zero events: the sense RAN (coverage is real); it simply found nothing above the
            // classifier's own floor. That is NOT "no audio sense" and NOT "silence" (absence ≠ safe).
            return ReelsAudioEvidenceV1(availability: .available, events: events, classifierVersion: classifierVersion)
        }
        #else
        // §D/§J — SoundAnalysis is not importable on this SDK (e.g. an iOS simulator SDK without the framework). We do
        // NOT fabricate a result: the audio sense is genuinely unavailable here, reported honestly so coverage narrows
        // (absence ≠ silence ≠ safe). The TYPES still exist so the rest of the pipeline compiles on every platform.
        return .unavailable(.frameworkUnavailable, classifierVersion: classifierVersion)
        #endif
    }

    /// §1.3 — the MERGE GAP threshold: windows of the SAME label within this many seconds of each other are treated
    /// as one continuous observed event (adjacent/overlapping); a larger gap keeps them as SEPARATE records. 0.5s is
    /// a conservative "same continuous sound" window (the classifier's own analysis windows are ~0.5-1s).
    public static let maxMergeGapSeconds: Double = 0.5

    /// §1.3 — PURE, testable window merging. Groups per-window classifications by label, sorts each label's windows by
    /// start time, and merges ONLY runs of adjacent/overlapping windows (gap ≤ maxMergeGapSeconds). Each merged run is
    /// ONE ReelsAudioEventV1 with its REAL min(start)..max(end) span and the STRONGEST raw confidence of that run.
    /// DISTANT occurrences of the same label stay as DISTINCT records (never fused across a silent gap). Windows with
    /// NO time range (start/end nil) cannot be ordered/merged by time, so each such window is kept as its own record
    /// with nil range (we never fabricate a stamp to merge them). Output ordering: strongest run first (stable).
    static func mergeAdjacentWindows(_ windows: [TimedAudioClassification],
                                     classifierVersion: String) -> [ReelsAudioEventV1] {
        guard !windows.isEmpty else { return [] }
        var out: [ReelsAudioEventV1] = []
        // Group by label.
        var byLabel: [String: [TimedAudioClassification]] = [:]
        for w in windows { byLabel[w.label, default: []].append(w) }
        for (label, group) in byLabel {
            // Windows WITH a real start: sort by start, then greedily merge adjacent/overlapping runs.
            let timed = group.filter { $0.startSeconds != nil }.sorted { ($0.startSeconds ?? 0) < ($1.startSeconds ?? 0) }
            let untimed = group.filter { $0.startSeconds == nil }
            var runStart: Double? = nil
            var runEnd: Double? = nil
            var runConf = 0.0
            func flush() {
                if runStart != nil {
                    out.append(ReelsAudioEventV1(label: label, rawModelConfidence: runConf,
                                                 startSeconds: runStart, endSeconds: runEnd,
                                                 classifierVersion: classifierVersion))
                }
                runStart = nil; runEnd = nil; runConf = 0
            }
            for w in timed {
                let s = w.startSeconds!
                let e = w.endSeconds ?? s
                if let prevEnd = runEnd, s - prevEnd <= maxMergeGapSeconds {
                    // Adjacent/overlapping → extend the current run.
                    runEnd = max(prevEnd, e)
                    runConf = max(runConf, w.confidence)
                } else {
                    // A gap larger than the threshold (or the first window) → start a NEW separate record.
                    flush()
                    runStart = s; runEnd = e; runConf = w.confidence
                }
            }
            flush()
            // Untimed windows (no range): each is its own honest record with nil range (never merged by a faked stamp).
            for w in untimed {
                out.append(ReelsAudioEventV1(label: label, rawModelConfidence: w.confidence,
                                             startSeconds: nil, endSeconds: nil, classifierVersion: classifierVersion))
            }
        }
        // Strongest-first, with a stable tiebreak on start time so the ordering is deterministic for tests.
        return out.sorted {
            if $0.rawModelConfidence != $1.rawModelConfidence {
                return ($0.rawModelConfidence ?? 0) > ($1.rawModelConfidence ?? 0)
            }
            return ($0.startSeconds ?? 0) < ($1.startSeconds ?? 0)
        }
    }

    /// §D2 — does the asset have at least one audio track? Best-effort via the async AVAsset API; nil on load failure
    /// (treated by the caller as an attempt that could not establish a track → we proceed to classify, and a decode
    /// error there becomes FRAMEWORK_UNAVAILABLE / no events, never a fabricated clean result).
    static func hasAudioTrack(asset: AVURLAsset) async -> Bool? {
        if let tracks = try? await asset.loadTracks(withMediaType: .audio) { return !tracks.isEmpty }
        return nil
    }
}
#endif
