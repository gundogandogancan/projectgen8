import Foundation

// MARK: - Guardian Activation State (PROMPT 006 §3) — single source of truth, atomic, relaunch-safe.
// Toggles product policy/runtime state. Does NOT grant cross-app capture iOS doesn't provide.

public enum GuardianActivation: String, Sendable, Codable {
    case enabled, paused, disabled
    case temporarilySuspendedBySystem
    case restrictedByCapability
    case restrictedByPolicy

    /// Whether the runtime should perform new Guardian work.
    public var runtimeActive: Bool { self == .enabled }
    /// Honest surface: never imply "Protected" when the runtime can't operate.
    public var canClaimProtection: Bool { self == .enabled }
}

/// Atomic holder shared between app + WidgetKit control. Persists via an injected store (App Group on device).
public protocol ActivationStore: Sendable {
    func read() -> GuardianActivation?
    func write(_ state: GuardianActivation)
}

/// In-memory store (tests) — a real App Group / UserDefaults(suiteName:) store plugs in on device.
public final class InMemoryActivationStore: ActivationStore, @unchecked Sendable {
    private let lock = NSLock(); private var state: GuardianActivation?
    public init(_ initial: GuardianActivation? = nil) { self.state = initial }
    public func read() -> GuardianActivation? { lock.lock(); defer { lock.unlock() }; return state }
    public func write(_ s: GuardianActivation) { lock.lock(); state = s; lock.unlock() }
}

public final class GuardianActivationController: @unchecked Sendable {
    private let lock = NSLock()
    private let store: ActivationStore
    private var cancelHandlers: [@Sendable () -> Void] = []
    public init(store: ActivationStore) { self.store = store }

    public var state: GuardianActivation { lock.lock(); defer { lock.unlock() }; return store.read() ?? .enabled }

    /// Set state atomically. Turning OFF (disabled/paused) fires cancel handlers (stop new work promptly).
    public func set(_ new: GuardianActivation) {
        lock.lock()
        let old = store.read() ?? .enabled
        store.write(new)
        let shouldCancel = old.runtimeActive && !new.runtimeActive
        let handlers = cancelHandlers
        lock.unlock()
        if shouldCancel { handlers.forEach { $0() } }
    }

    public func onDeactivate(_ handler: @escaping @Sendable () -> Void) {
        lock.lock(); cancelHandlers.append(handler); lock.unlock()
    }

    /// Relaunch-safe: state is whatever the shared store holds (default enabled).
    public var runtimeActive: Bool { state.runtimeActive }
}
