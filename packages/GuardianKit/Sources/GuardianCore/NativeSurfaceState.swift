import Foundation

// MARK: - Native surface state + Live Activity update budget (PROMPT 007 §5,§6,§24)
// Control Center + Dynamic Island carry a MINIMAL, privacy-safe state — never raw Shield rule text.
// The real WidgetKit/ActivityKit targets are device-gated; this is the headless-testable logic they consume.

/// 007 §24 — the only states allowed on a native surface (lock-safe; no sensitive detail, no rule text).
public enum NativeSurfaceState: String, Sendable, Codable {
    case guardianOn = "GUARDIAN_ON", caution = "CAUTION", shieldMatch = "SHIELD_MATCH", unknown = "UNKNOWN", off = "OFF"

    /// Map a per-content glyph family to a privacy-safe surface state. Never leaks content character as "safe".
    public static func from(glyph: GlyphFamily, guardianEnabled: Bool) -> NativeSurfaceState {
        guard guardianEnabled else { return .off }
        switch glyph {
        case .strongProtection, .shieldMatch: return .shieldMatch
        case .caution: return .caution
        case .unknown, .analyzing: return .unknown
        default: return .guardianOn            // positive/neutral content → just "on", never a content label on the surface
        }
    }
    /// Short, non-sensitive label safe to show on a locked device.
    public var lockSafeLabel: String {
        switch self {
        case .guardianOn: return "Guardian on"
        case .caution: return "Caution"
        case .shieldMatch: return "Shield match"
        case .unknown: return "Unknown"
        case .off: return "Off"
        }
    }
}

/// 007 §6 — Live Activity update budget. Only stabilized, meaningful transitions reach the OS; safety may bypass debounce.
public final class LiveActivityUpdatePolicy: @unchecked Sendable {
    public struct Counters: Sendable, Equatable {
        public var requested = 0, accepted = 0, suppressed = 0, staleRejected = 0, outOfOrderRejected = 0
    }
    private let lock = NSLock()
    private var counters = Counters()
    private var lastState: NativeSurfaceState?
    private var lastContentID: String?
    private var lastAcceptedNanos: UInt64 = 0
    private var lastSequence: UInt64 = 0
    private let debounceNanos: UInt64
    public init(debounceNanos: UInt64 = 2_000_000_000) { self.debounceNanos = debounceNanos }   // 2s default

    public enum Decision: Sendable, Equatable { case accepted, suppressedNoChange, suppressedDebounce, rejectedStale, rejectedOutOfOrder }

    /// Returns whether to push this update to the OS. Safety escalation (caution/shieldMatch) bypasses debounce.
    public func consider(contentID: String, sequence: UInt64, state: NativeSurfaceState, nowNanos: UInt64, isSafetyEscalation: Bool) -> Decision {
        lock.lock(); defer { lock.unlock() }
        counters.requested += 1
        // Content switch resets ordering; a new content's first stabilized update is allowed.
        if contentID != lastContentID { lastContentID = contentID; lastSequence = 0; lastState = nil }
        if sequence < lastSequence { counters.outOfOrderRejected += 1; return .rejectedOutOfOrder }
        if state == lastState && !isSafetyEscalation { counters.suppressed += 1; return .suppressedNoChange }
        let elapsed = nowNanos >= lastAcceptedNanos ? nowNanos - lastAcceptedNanos : 0
        if !isSafetyEscalation && lastState != nil && elapsed < debounceNanos { counters.suppressed += 1; return .suppressedDebounce }
        lastState = state; lastSequence = sequence; lastAcceptedNanos = nowNanos; counters.accepted += 1
        return .accepted
    }

    public func noteStaleRejected() { lock.lock(); counters.staleRejected += 1; lock.unlock() }
    public func snapshot() -> Counters { lock.lock(); defer { lock.unlock() }; return counters }
}
