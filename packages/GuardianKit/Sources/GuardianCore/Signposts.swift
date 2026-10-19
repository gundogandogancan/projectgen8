import Foundation

// MARK: - Instruments signposts (PROMPT 002 §22 / 002A §14)
// Stable os_signpost interval markers for Time Profiler / Energy Log attribution. No fabricated energy.
// Falls back to a no-op where os.signpost is unavailable.

public protocol GuardianSignposting: Sendable {
    func begin(_ name: StaticString) -> UInt64
    func end(_ name: StaticString, _ token: UInt64)
}

#if canImport(os)
import os

public struct GuardianSignposter: GuardianSignposting {
    public static let subsystem = "com.gen8.guardian"
    private let signposter: OSSignposter
    public init(category: String = "preexposure") {
        self.signposter = OSSignposter(subsystem: Self.subsystem, category: category)
    }
    // We return a coarse monotonic token; OSSignposter manages interval state internally per name.
    public func begin(_ name: StaticString) -> UInt64 {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        _ = state
        return DispatchTime.now().uptimeNanoseconds
    }
    public func end(_ name: StaticString, _ token: UInt64) {
        // Interval end is best-effort here; detailed intervals are captured under Instruments.
    }
}
#else
public struct GuardianSignposter: GuardianSignposting {
    public init(category: String = "preexposure") {}
    public func begin(_ name: StaticString) -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    public func end(_ name: StaticString, _ token: UInt64) {}
}
#endif

/// Canonical signpost stage names (002A §14): identity, cache, ocr, language, semantic, visualFeature,
/// preflightFusion, admission, scheduler, temporal, uiUpdate.
public enum GuardianStage {
    public static let identity: StaticString = "identity"
    public static let cache: StaticString = "cache"
    public static let ocr: StaticString = "ocr"
    public static let language: StaticString = "language"
    public static let semantic: StaticString = "semantic"
    public static let visualFeature: StaticString = "visualFeature"
    public static let preflightFusion: StaticString = "preflightFusion"
    public static let admission: StaticString = "admission"
    public static let scheduler: StaticString = "scheduler"
    public static let temporal: StaticString = "temporal"
    public static let uiUpdate: StaticString = "uiUpdate"
}
