import Foundation
#if canImport(AVFoundation)
import AVFoundation

// MARK: - Synthetic audio generator (PROMPT 006 §8/§9) — OWNED legally-safe audio fixtures, headless.
public enum SyntheticAudio {
    /// Write a mono sine-tone WAV (no copyrighted audio). Returns true on success.
    public static func writeTone(frequency: Double = 440, seconds: Double = 2.0, sampleRate: Double = 16000, to url: URL) -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else { return false }
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return false }
        buffer.frameLength = frames
        if let ch = buffer.floatChannelData?[0] {
            for i in 0..<Int(frames) {
                ch[i] = Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)) * 0.5
            }
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return true
        } catch { return false }
    }

    /// Write speech audio via AVSpeechSynthesizer (OWNED, synthetic). Best-effort; returns true on success.
    public static func writeSpeech(_ text: String, language: String, to url: URL) async -> Bool {
        try? FileManager.default.removeItem(at: url)
        let synth = AVSpeechSynthesizer()
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: language)
        let box = SpeechWriteBox(url: url)
        return await withCheckedContinuation { cont in
            synth.write(utt) { buf in
                guard let pcm = buf as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    if let result = box.finish() { cont.resume(returning: result) }   // resume exactly once
                    return
                }
                box.append(pcm)
            }
        }
    }
}

/// Thread-safe single-resume helper for AVSpeechSynthesizer.write (avoids continuation misuse).
final class SpeechWriteBox: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var file: AVAudioFile?
    private var wroteAny = false
    private var finished = false
    init(url: URL) { self.url = url }
    func append(_ pcm: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        if finished { return }
        do {
            if file == nil { file = try AVAudioFile(forWriting: url, settings: pcm.format.settings) }
            try file?.write(from: pcm); wroteAny = true
        } catch { /* ignore */ }
    }
    /// Returns the result exactly once; nil on subsequent calls (do not resume again).
    func finish() -> Bool? {
        lock.lock(); defer { lock.unlock() }
        if finished { return nil }
        finished = true
        return wroteAny
    }
}
#endif
