import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics

// MARK: - Real sparse frame extraction (PROMPT 005 §5, §6) — AVAssetImageGenerator async, timestamp-driven.
// NO full-FPS decode loop. Ephemeral frames (no persistence). Sampler controls the provider.

public struct ExtractedFrame: Sendable {
    public let requestedTimeSeconds: Double
    public let actualTimeSeconds: Double?
    public let image: CGImage?          // ephemeral — caller must not persist
    public let latencyNanos: UInt64
    public let error: String?
}

public actor VideoFrameProvider {
    public static let version = "video-frame-provider-v1"
    private let generator: AVAssetImageGenerator
    public init(url: URL, maxSize: CGSize = CGSize(width: 512, height: 512), toleranceSeconds: Double = 0.2) {
        let asset = AVURLAsset(url: url)
        let g = AVAssetImageGenerator(asset: asset)
        g.appliesPreferredTrackTransform = true
        g.maximumSize = maxSize
        let tol = CMTime(seconds: toleranceSeconds, preferredTimescale: 600)
        g.requestedTimeToleranceBefore = tol
        g.requestedTimeToleranceAfter = tol
        self.generator = g
    }

    /// Extract frames at the requested timestamps (sparse). Each frame is released after being returned.
    public func frames(atSeconds times: [Double]) async -> [ExtractedFrame] {
        var out: [ExtractedFrame] = []
        for t in times {
            if Task.isCancelled { break }                 // cancellation → stop; stale results discarded by caller
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                let cm = CMTime(seconds: t, preferredTimescale: 600)
                let result = try await generator.image(at: cm)
                let lat = DispatchTime.now().uptimeNanoseconds &- start
                out.append(ExtractedFrame(requestedTimeSeconds: t,
                                          actualTimeSeconds: CMTimeGetSeconds(result.actualTime),
                                          image: result.image, latencyNanos: lat, error: nil))
            } catch {
                let lat = DispatchTime.now().uptimeNanoseconds &- start
                out.append(ExtractedFrame(requestedTimeSeconds: t, actualTimeSeconds: nil,
                                          image: nil, latencyNanos: lat, error: "\(error)"))
            }
        }
        return out
    }
}
#endif
