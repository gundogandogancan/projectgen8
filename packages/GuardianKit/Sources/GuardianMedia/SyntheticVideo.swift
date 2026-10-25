import Foundation
#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreText
import CoreMedia
import AudioToolbox

// MARK: - Synthetic MP4 generator (PROMPT 005 §30) — project-OWNED, legally-safe real media fixtures.
// Writes a real H.264 MP4 headless via AVAssetWriter so the decode/OCR/scene pipeline can be proven on
// a genuine video-decode path (not synthetic frame descriptors). No copyrighted/private media.

public enum SyntheticVideo {

    public struct Spec: Sendable {
        public let durationSeconds: Double
        public let fps: Int
        public let width: Int
        public let height: Int
        /// (timeSeconds, text) overlays drawn at/after the given time.
        public let textEvents: [(Double, String)]
        /// (timeSeconds, gray) background scene changes.
        public let sceneChanges: [(Double, CGFloat)]
        public init(durationSeconds: Double, fps: Int = 6, width: Int = 320, height: Int = 180,
                    textEvents: [(Double, String)] = [], sceneChanges: [(Double, CGFloat)] = []) {
            self.durationSeconds = durationSeconds; self.fps = fps; self.width = width; self.height = height
            self.textEvents = textEvents; self.sceneChanges = sceneChanges
        }
    }

    /// Write the MP4 to `url`. Returns true on success. Overwrites existing.
    public static func write(_ spec: Spec, to url: URL) async -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: spec.width,
            AVVideoHeightKey: spec.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: spec.width,
            kCVPixelBufferHeightKey as String: spec.height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        let totalFrames = Int(spec.durationSeconds * Double(spec.fps))
        let scale: Int32 = 600
        for i in 0..<totalFrames {
            let t = Double(i) / Double(spec.fps)
            // current scene gray = last sceneChange ≤ t (default 0.9 light)
            let gray = spec.sceneChanges.filter { $0.0 <= t }.last?.1 ?? 0.9
            // current text = last textEvent ≤ t within 1.0s window
            let text = spec.textEvents.filter { $0.0 <= t && t < $0.0 + 1.0 }.last?.1
            guard let img = frame(gray: gray, text: text, w: spec.width, h: spec.height),
                  let pb = pixelBuffer(from: img, w: spec.width, h: spec.height) else { continue }
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 1_000_000) }
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(Int32(i) * (scale / Int32(spec.fps))), timescale: scale))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed
    }

    /// §1.4 — write an MP4 with BOTH a real H.264 VIDEO track AND an embedded PCM AUDIO track (a sine tone), so the
    /// full VIDEO→AudioProvider→SoundAnalysis path can be proven end-to-end on an OWNED file (not a bare WAV and not
    /// a video-only MP4). The audio is a project-owned synthetic tone — no copyrighted/private media. Returns true on
    /// success. The audio track is written in sample-buffer chunks via a second AVAssetWriterInput.
    public static func writeWithAudioTone(_ spec: Spec, toneFrequency: Double = 440, sampleRate: Double = 44_100,
                                          to url: URL) async -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        // VIDEO input (same settings as `write`).
        let vSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                         AVVideoWidthKey: spec.width, AVVideoHeightKey: spec.height]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vInput.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                                    kCVPixelBufferWidthKey as String: spec.width,
                                    kCVPixelBufferHeightKey as String: spec.height]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput, sourcePixelBufferAttributes: attrs)
        // AUDIO input: AAC-encoded mono from a PCM tone.
        let aSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1,
                                        AVSampleRateKey: sampleRate, AVEncoderBitRateKey: 64_000]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        aInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(vInput), writer.canAdd(aInput) else { return false }
        writer.add(vInput); writer.add(aInput)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        // --- CANONICAL PUMP MODEL (hang fix, attempt 2) ---
        // A multi-input AVAssetWriter must be fed via requestMediaDataWhenReady(on:): the writer
        // PULLS from each input on its own queue and handles interleaving itself. Both the original
        // video-first ordering AND a polled time-segment interleave can deadlock/starve on long
        // (600s) assets because `isReadyForMoreMediaData` for non-realtime inputs is only reliably
        // pumped through the callback mechanism. Short clips masked this inside buffering slack.
        guard let audioFmt = toneAudioFormatDescription(sampleRate: sampleRate) else { return false }
        let totalFrames = Int(spec.durationSeconds * Double(spec.fps))
        let scale: Int32 = 600
        let totalAudioFrames = Int(spec.durationSeconds * sampleRate)
        let audioChunk = Int(sampleRate / 10)

        let videoQueue = DispatchQueue(label: "gen8.synthvideo.video")
        let audioQueue = DispatchQueue(label: "gen8.synthvideo.audio")
        let group = DispatchGroup()

        // VIDEO pump
        group.enter()
        var vFrame = 0
        var vFailed = false
        vInput.requestMediaDataWhenReady(on: videoQueue) {
            while vInput.isReadyForMoreMediaData {
                if vFrame >= totalFrames { vInput.markAsFinished(); group.leave(); return }
                let t = Double(vFrame) / Double(spec.fps)
                let gray = spec.sceneChanges.filter { $0.0 <= t }.last?.1 ?? 0.9
                let text = spec.textEvents.filter { $0.0 <= t && t < $0.0 + 1.0 }.last?.1
                if let img = frame(gray: gray, text: text, w: spec.width, h: spec.height),
                   let pb = pixelBuffer(from: img, w: spec.width, h: spec.height) {
                    if !adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(Int32(vFrame) * (scale / Int32(spec.fps))), timescale: scale)) {
                        vFailed = true; vInput.markAsFinished(); group.leave(); return
                    }
                }
                vFrame += 1
            }
        }

        // AUDIO pump
        group.enter()
        var aFrame = 0
        var aFailed = false
        aInput.requestMediaDataWhenReady(on: audioQueue) {
            while aInput.isReadyForMoreMediaData {
                if aFrame >= totalAudioFrames { aInput.markAsFinished(); group.leave(); return }
                let n = min(audioChunk, totalAudioFrames - aFrame)
                guard let sb = toneSampleBuffer(fmt: audioFmt, startFrame: aFrame, count: n,
                                                frequency: toneFrequency, sampleRate: sampleRate) else {
                    aFailed = true; aInput.markAsFinished(); group.leave(); return
                }
                if !aInput.append(sb) { aFailed = true; aInput.markAsFinished(); group.leave(); return }
                aFrame += n
            }
        }

        // Bounded overall wait (fail loud, never hang): generous ceiling for 600s generation.
        // Once-guard: group.notify and the timeout can both fire; CheckedContinuation traps on
        // double resume, so resume exactly once through a lock-protected flag.
        let waited = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let lock = NSLock()
            var resumed = false
            func resumeOnce(_ value: Bool) {
                lock.lock(); defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: value)
            }
            group.notify(queue: .global()) { resumeOnce(true) }
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(480)) { resumeOnce(false) }
        }
        if !waited || vFailed || aFailed { writer.cancelWriting(); return false }
        await writer.finishWriting()
        return writer.status == .completed
    }

    /// Shared tone format description (extracted so segmented appends reuse one instance).
    static func toneAudioFormatDescription(sampleRate: Double) -> CMAudioFormatDescription? {
        var asbd = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
                                               mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var formatDesc: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
                                             magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                             formatDescriptionOut: &formatDesc) == noErr else { return nil }
        return formatDesc
    }

    /// Build one tone CMSampleBuffer for [startFrame, startFrame+count) — used by the pump model.
    static func toneSampleBuffer(fmt: CMAudioFormatDescription, startFrame: Int, count: Int,
                                 frequency: Double, sampleRate: Double) -> CMSampleBuffer? {
        var samples = [Int16](repeating: 0, count: count)
        for j in 0..<count {
            let s = sin(2.0 * Double.pi * frequency * Double(startFrame + j) / sampleRate) * 0.5
            samples[j] = Int16(max(-1.0, min(1.0, s)) * 32767.0)
        }
        let byteCount = count * 2
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
                                                 blockLength: byteCount, blockAllocator: kCFAllocatorDefault,
                                                 customBlockSource: nil, offsetToData: 0, dataLength: byteCount,
                                                 flags: 0, blockBufferOut: &blockBuffer) == noErr,
              let bb = blockBuffer else { return nil }
        samples.withUnsafeBytes { raw in
            _ = CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: bb, offsetIntoDestination: 0, dataLength: byteCount)
        }
        var sampleBuffer: CMSampleBuffer?
        let pts = CMTime(value: CMTimeValue(startFrame), timescale: CMTimeScale(sampleRate))
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
                                        presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sampleSize = 2
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: bb, formatDescription: fmt,
                                        sampleCount: count, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                        sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
                                        sampleBufferOut: &sampleBuffer) == noErr else { return nil }
        return sampleBuffer
    }

    /// §1.4 — synthesize a mono 16-bit PCM sine tone and append it to the audio input as CMSampleBuffers in chunks.
    static func appendToneAudio(to input: AVAssetWriterInput, seconds: Double, frequency: Double, sampleRate: Double) -> Bool {
        var asbd = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
                                               mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var formatDesc: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
                                             magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                             formatDescriptionOut: &formatDesc) == noErr, let fmt = formatDesc else {
            return false
        }
        let totalFrames = Int(seconds * sampleRate)
        let chunkFrames = Int(sampleRate / 10)   // ~100ms chunks
        var frameIndex = 0
        var good = true
        while frameIndex < totalFrames {
            let n = min(chunkFrames, totalFrames - frameIndex)
            var samples = [Int16](repeating: 0, count: n)
            for j in 0..<n {
                let s = sin(2.0 * Double.pi * frequency * Double(frameIndex + j) / sampleRate) * 0.5
                samples[j] = Int16(max(-1.0, min(1.0, s)) * 32767.0)
            }
            let byteCount = n * 2
            var blockBuffer: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
                                                     blockLength: byteCount, blockAllocator: kCFAllocatorDefault,
                                                     customBlockSource: nil, offsetToData: 0, dataLength: byteCount,
                                                     flags: 0, blockBufferOut: &blockBuffer) == noErr,
                  let bb = blockBuffer else { good = false; break }
            samples.withUnsafeBytes { raw in
                _ = CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: bb, offsetIntoDestination: 0, dataLength: byteCount)
            }
            var sampleBuffer: CMSampleBuffer?
            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(sampleRate))
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
                                            presentationTimeStamp: pts, decodeTimeStamp: .invalid)
            var sampleSize = 2
            guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: bb, formatDescription: fmt,
                                            sampleCount: n, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
                                            sampleBufferOut: &sampleBuffer) == noErr, let sb = sampleBuffer else {
                good = false; break
            }
            // Spin briefly until the writer is ready (headless, bounded).
            var spins = 0
            while !input.isReadyForMoreMediaData && spins < 100_000 { spins += 1 }
            if !input.append(sb) { good = false; break }
            frameIndex += n
        }
        return good
    }

    static func frame(gray: CGFloat, text: String?, w: Int, h: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        if let text {
            let font = CTFontCreateWithName("Helvetica" as CFString, 40, nil)
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs) as CFAttributedString)
            ctx.textPosition = CGPoint(x: 16, y: CGFloat(h)/2 - 14)
            CTLineDraw(line, ctx)
        }
        return ctx.makeImage()
    }

    static func pixelBuffer(from image: CGImage, w: Int, h: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB, attrs, &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buf
    }
}
#endif
