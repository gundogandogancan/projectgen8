import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics

// MARK: - Real media asset layer (PROMPT 005 §3, §4) — AVFoundation lives HERE, never in GuardianCore.
// Async metadata loading (no MainActor block); explicit failure/unknown; cancellation-aware.

public struct MediaMetadata: Sendable, Equatable {
    public let durationSeconds: Double
    public let hasVideo: Bool
    public let hasAudio: Bool
    public let width: Int
    public let height: Int
    public let nominalFrameRate: Float
}

public enum MediaError: String, Error, Sendable {
    case fileMissing, unreadable, unsupported, noTracks, cancelled
}

public struct MediaAssetSource: Sendable {
    public static let version = "media-asset-source-v1"
    public init() {}

    public func loadMetadata(url: URL, signposter: GuardianSignposter? = nil) async -> Result<MediaMetadata, MediaError> {
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.fileMissing) }
        let token = signposter?.begin(GuardianStage.identity)
        defer { if let token { signposter?.end(GuardianStage.identity, token) } }
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            if Task.isCancelled { return .failure(.cancelled) }
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if videoTracks.isEmpty && audioTracks.isEmpty { return .failure(.noTracks) }
            var w = 0, h = 0, fps: Float = 0
            if let vt = videoTracks.first {
                let size = try await vt.load(.naturalSize)
                w = Int(abs(size.width)); h = Int(abs(size.height))
                fps = try await vt.load(.nominalFrameRate)
            }
            let secs = CMTimeGetSeconds(duration)
            guard secs.isFinite, secs >= 0 else { return .failure(.unreadable) }
            return .success(MediaMetadata(durationSeconds: secs, hasVideo: !videoTracks.isEmpty,
                                          hasAudio: !audioTracks.isEmpty, width: w, height: h, nominalFrameRate: fps))
        } catch {
            return .failure(.unreadable)
        }
    }

    /// Detect audio track presence quickly (for AudioWindowPlanner / speech availability).
    public func hasAudioTrack(url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        return ((try? await asset.loadTracks(withMediaType: .audio))?.isEmpty == false)
    }
}
#endif
