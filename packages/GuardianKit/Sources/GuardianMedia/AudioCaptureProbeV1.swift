//
//  AudioCaptureProbeV1.swift — R8 §1 (P0-1): LIVE AUDIO CAPTURE CAPABILITY PROBE (honest, bounded, pure counters).
//
//  WHAT THIS IS (mandate §1.1): the honest measurement of whether the ReplayKit broadcast extension is actually
//  RECEIVING application-audio CMSampleBuffers — and in what shape. The extension's `processSampleBuffer` historically
//  dropped every non-video buffer (`guard type == .video else { return }`), so GEN8 had NO evidence about audio at all.
//  This probe records the FACTS the mandate enumerates for every `.audioApp` buffer the extension decides to observe:
//   • Buffer arrival (count).                    • Format description (sample rate / channels / PCM bit depth).
//   • Timestamp continuity (PTS monotonic?).     • Buffer duration (seconds, summed).
//   • Silence-vs-unavailable distinction.        • Dropped buffers (format-invalid / data-missing).
//   • Capture interruption (stream pause/resume).
//
//  WHAT THIS IS NOT (the honesty laws, mandate §1.1/§10):
//   • It NEVER opens the microphone. `.audioMic` is explicitly ignored by the caller (documented there); the probe only
//     ever sees buffers the caller forwarded, and it refuses to count anything tagged as mic (defense in depth below).
//   • It retains NO raw audio: it reads only the format description + timing + a cheap silence heuristic, never PCM
//     samples beyond a bounded RMS scan, and keeps NOTHING. No persistence, no upload, no cross-session carryover.
//   • AUDIO_CAPTURE_AVAILABLE is asserted ONLY when real buffers with a valid audio format actually arrived — so in
//     THIS host/off-device environment the verdict stays FEATURE_UNVERIFIED (no device delivers audioApp here). The
//     PROBE MECHANISM is the deliverable; the AVAILABLE verdict requires a real device run (DEVICE_UNVERIFIED by law).
//
//  Pure value type + a tiny mutating recorder. Lives in GuardianMedia (GuardianCore frozen). Compiles on EVERY SDK
//  (CoreMedia is always present); the ReplayKit import lives in the extension, not here, so the probe stays testable.
//
import Foundation
#if canImport(CoreMedia)
import CoreMedia
#endif

/// R8 §1 — the honest capture-availability verdict. FEATURE_UNVERIFIED is the DEFAULT and the only verdict reachable
/// off-device (no audioApp buffers arrive in the host/test environment). PRESENT_WITH_AUDIO is reachable ONLY when
/// real, format-valid audio buffers were observed — which can only happen on a device, so it is DEVICE_UNVERIFIED.
public enum AudioCaptureVerdictV1: String, Sendable, Equatable, Codable {
    case featureUnverified   = "FEATURE_UNVERIFIED"    // no audioApp buffers observed (default; the off-device state)
    case buffersMissingData  = "BUFFERS_PRESENT_NO_DATA" // buffers arrived but carried no usable audio format/data
    case presentWithAudio    = "PRESENT_WITH_AUDIO"    // real, format-valid audio arrived (DEVICE_UNVERIFIED only)
}

/// R8 §1 — the derived audio format facts of ONE observed buffer (never the samples themselves). All optional: a
/// buffer whose format could not be read yields nils and is counted as a dropped/invalid buffer, never silently clean.
public struct AudioBufferFactsV1: Sendable, Equatable, Codable {
    public let sampleRate: Double?
    public let channelCount: Int?
    public let bitsPerChannel: Int?
    public let isFloat: Bool?
    public let durationSeconds: Double?
    public let presentationSeconds: Double?
    public init(sampleRate: Double?, channelCount: Int?, bitsPerChannel: Int?, isFloat: Bool?,
                durationSeconds: Double?, presentationSeconds: Double?) {
        self.sampleRate = sampleRate; self.channelCount = channelCount; self.bitsPerChannel = bitsPerChannel
        self.isFloat = isFloat; self.durationSeconds = durationSeconds; self.presentationSeconds = presentationSeconds
    }
}

/// R8 §1 — the bounded, mutating recorder. Holds ONLY derived counters + the LAST format facts (for the summary) +
/// the last PTS (for continuity). No buffer list, no sample storage. Reset at session start; cleared at session end.
public struct AudioCaptureProbeV1: Sendable, Equatable, Codable {
    public private(set) var buffersObserved = 0
    public private(set) var buffersWithValidFormat = 0
    public private(set) var buffersDroppedInvalid = 0
    public private(set) var buffersSilent = 0            // RMS below the silence floor (silence ≠ unavailable)
    public private(set) var micBuffersRefused = 0        // defense in depth: a mic-tagged buffer is NEVER counted
    public private(set) var ptsDiscontinuities = 0       // PTS went backwards / jumped — continuity broken
    public private(set) var interruptions = 0            // stream paused/resumed (capture interruption)
    public private(set) var totalAudioSeconds = 0.0
    public private(set) var lastFacts: AudioBufferFactsV1? = nil
    private var lastPresentationSeconds: Double? = nil

    public init() {}

    /// R8 §1 — the silence floor (normalized RMS). Below this a buffer is SILENT (a real fact — the app emitted quiet
    /// audio), which is explicitly NOT "unavailable" and NOT "safe": silence is observed coverage, absence is not.
    public static let silenceRMSFloor = 0.003

    /// R8 §1 — record ONE observed audio buffer's derived facts. `isMicTagged` lets the caller assert the buffer was
    /// NOT a mic buffer (it must never be — the caller drops `.audioMic` — but we refuse-and-count defensively).
    /// `normalizedRMS` is an optional cheap loudness scalar (0..1) the caller may compute in place for the silence
    /// distinction; nil means "not measured" (then the buffer is never classified as silent, only as present).
    public mutating func record(facts: AudioBufferFactsV1, isMicTagged: Bool, normalizedRMS: Double?) {
        if isMicTagged { micBuffersRefused += 1; return }   // mic is never part of the capture contract (§1.1)
        buffersObserved += 1
        // Format validity: a real audio buffer has a positive sample rate AND at least one channel.
        let validFormat = (facts.sampleRate ?? 0) > 0 && (facts.channelCount ?? 0) > 0
        if validFormat {
            buffersWithValidFormat += 1
            totalAudioSeconds += max(0, facts.durationSeconds ?? 0)
            lastFacts = facts
            // PTS continuity: a presentation time that moves BACKWARDS (or repeats) breaks the stream's monotonicity.
            if let now = facts.presentationSeconds {
                if let prev = lastPresentationSeconds, now < prev - 0.0005 { ptsDiscontinuities += 1 }
                lastPresentationSeconds = now
            }
            if let rms = normalizedRMS, rms < Self.silenceRMSFloor { buffersSilent += 1 }
        } else {
            buffersDroppedInvalid += 1
        }
    }

    /// R8 §1 — record a capture interruption (ReplayKit paused/resumed the sample stream). On resume the PTS baseline
    /// is reset so a legitimate gap across the interruption is NOT counted as a discontinuity error.
    public mutating func noteInterruption() { interruptions += 1; lastPresentationSeconds = nil }

    /// R8 §1 — the HONEST availability verdict. PRESENT_WITH_AUDIO only when format-valid buffers actually arrived;
    /// BUFFERS_PRESENT_NO_DATA when buffers came but none carried a usable format; FEATURE_UNVERIFIED when nothing
    /// arrived (the default off-device state). This NEVER upgrades itself without real data — the device gate.
    public var verdict: AudioCaptureVerdictV1 {
        if buffersWithValidFormat > 0 { return .presentWithAudio }
        if buffersObserved > 0 { return .buffersMissingData }
        return .featureUnverified
    }

    /// R8 §1 — true only when real audio was captured. Off-device this is ALWAYS false (no device delivers audioApp
    /// here), so AUDIO_CAPTURE_AVAILABLE stays DEVICE_UNVERIFIED — the probe measures, it never fabricates the result.
    public var audioCaptureAvailable: Bool { verdict == .presentWithAudio }

    /// One derived, privacy-safe summary line for the session proof log (never raw audio; only counters + format).
    public var summary: String {
        let f = lastFacts
        let fmt = f.map { "sr=\($0.sampleRate.map { String(format: "%.0f", $0) } ?? "-") ch=\($0.channelCount.map(String.init) ?? "-") bits=\($0.bitsPerChannel.map(String.init) ?? "-") float=\($0.isFloat.map(String.init) ?? "-")" } ?? "fmt=none"
        return "verdict=\(verdict.rawValue) observed=\(buffersObserved) validFormat=\(buffersWithValidFormat) droppedInvalid=\(buffersDroppedInvalid) silent=\(buffersSilent) micRefused=\(micBuffersRefused) ptsDisc=\(ptsDiscontinuities) interruptions=\(interruptions) audioSec=\(String(format: "%.2f", totalAudioSeconds)) \(fmt) (AUDIO_CAPTURE_AVAILABLE=\(audioCaptureAvailable); off-device=DEVICE_UNVERIFIED)"
    }
}

#if canImport(CoreMedia)
extension AudioCaptureProbeV1 {
    /// R8 §1 — extract the derived FACTS from a real audio CMSampleBuffer WITHOUT retaining any samples. Reads only the
    /// format description (AudioStreamBasicDescription) + timing. Pure read; the sample data is never copied here.
    /// Returns nil only when there is no format description at all (then the caller records a dropped/invalid buffer).
    public static func facts(from sampleBuffer: CMSampleBuffer) -> AudioBufferFactsV1? {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let presentation: Double? = (pts.isValid && !pts.seconds.isNaN) ? pts.seconds : nil
        let dur = CMSampleBufferGetDuration(sampleBuffer)
        let duration: Double? = (dur.isValid && !dur.seconds.isNaN && dur.seconds >= 0) ? dur.seconds : nil
        guard let fmtDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc) else {
            // No audio format description → not a usable audio buffer; the caller counts it as dropped/invalid.
            return AudioBufferFactsV1(sampleRate: nil, channelCount: nil, bitsPerChannel: nil, isFloat: nil,
                                      durationSeconds: duration, presentationSeconds: presentation)
        }
        let d = asbd.pointee
        let isFloat = (d.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        return AudioBufferFactsV1(sampleRate: d.mSampleRate > 0 ? d.mSampleRate : nil,
                                  channelCount: d.mChannelsPerFrame > 0 ? Int(d.mChannelsPerFrame) : nil,
                                  bitsPerChannel: d.mBitsPerChannel > 0 ? Int(d.mBitsPerChannel) : nil,
                                  isFloat: isFloat, durationSeconds: duration, presentationSeconds: presentation)
    }
}
#endif
