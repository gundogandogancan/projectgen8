import Foundation

// MARK: - Automatic Guardian Runtime (PROMPT 008A §6,§7,§8,§9,§23,§26)
// Canonical: ZERO-TOUCH WHERE PERMITTED, ONE-TAP PER SESSION WHERE REQUIRED, NEVER HIDDEN CAPTURE.
// Within an authorized session, app/content transitions are AUTOMATIC (Gen8 is never reopened). The session START
// obeys the OS consent boundary (iOS ReplayKit = system picker, one tap per session). No private API / accessibility abuse.

/// §7 automation truth table — what each platform's OFFICIAL capture path allows. iOS cannot be ZERO_TOUCH cross-app.
public enum ObservationAutomation: String, Sendable, Codable {
    case zeroTouchContinuous = "ZERO_TOUCH_CONTINUOUS"
    case autoResumePermitted = "AUTO_RESUME_PERMITTED"
    case oneTapPerSessionRequired = "ONE_TAP_PER_SESSION_REQUIRED"
    case systemPickerRequired = "SYSTEM_PICKER_REQUIRED"
    case foregroundOnly = "FOREGROUND_ONLY"
    case backgroundLimited = "BACKGROUND_LIMITED"
    case unavailable = "UNAVAILABLE"
}

public struct PlatformObservationCapability: Sendable, Codable, Equatable {
    public var platform: String
    public var sessionStart: ObservationAutomation        // how a session must START
    public var withinSessionAppSwitchAutomatic: Bool      // once active, do app/content changes auto-flow?
    public var autoResumeAfterInterruption: ObservationAutomation
    public var appContextOfficiallyExposed: Bool          // does the OS expose foreground app/window identity to us?
    public var backgroundExecution: ObservationAutomation
    public var notes: String
}

public struct PlatformCapabilityRegistry: Sendable {
    public init() {}
    public func capability(platform: String) -> PlatformObservationCapability {
        switch platform.lowercased() {
        case "ios", "ipados":
            // Truth: cross-app capture is the ReplayKit system broadcast — user taps Start (per session). Within the
            // active broadcast, app/content transitions flow automatically. OS can terminate → one-tap restart. No
            // official foreground-app identity is exposed to a third party. Background cross-app capture is not allowed.
            return .init(platform: "iOS", sessionStart: .systemPickerRequired, withinSessionAppSwitchAutomatic: true,
                         autoResumeAfterInterruption: .oneTapPerSessionRequired, appContextOfficiallyExposed: false,
                         backgroundExecution: .backgroundLimited,
                         notes: "ReplayKit system broadcast; one-tap per session; never hidden; no cross-app bundle id exposed")
        case "macos":
            return .init(platform: "macOS", sessionStart: .oneTapPerSessionRequired, withinSessionAppSwitchAutomatic: true,
                         autoResumeAfterInterruption: .autoResumePermitted, appContextOfficiallyExposed: true,
                         backgroundExecution: .backgroundLimited, notes: "ScreenCaptureKit; permission persists; window/app identity exposed")
        case "android":
            return .init(platform: "Android", sessionStart: .oneTapPerSessionRequired, withinSessionAppSwitchAutomatic: true,
                         autoResumeAfterInterruption: .oneTapPerSessionRequired, appContextOfficiallyExposed: false,
                         backgroundExecution: .backgroundLimited, notes: "MediaProjection consent per session (planned adapter)")
        default:
            return .init(platform: platform, sessionStart: .unavailable, withinSessionAppSwitchAutomatic: false,
                         autoResumeAfterInterruption: .unavailable, appContextOfficiallyExposed: false,
                         backgroundExecution: .unavailable, notes: "no verified official adapter")
        }
    }
}

/// §8 observation session state machine. Persists only safe session metadata — NEVER captured content.
public enum ObservationSessionState: String, Sendable, Codable {
    case off = "OFF", permissionRequired = "PERMISSION_REQUIRED", ready = "READY", starting = "STARTING"
    case active = "ACTIVE", interrupted = "INTERRUPTED", recoverable = "RECOVERABLE", restartRequired = "RESTART_REQUIRED"
    case unavailable = "UNAVAILABLE", error = "ERROR"
    /// A surface may claim "Guardian is observing" ONLY in .active.
    public var isObserving: Bool { self == .active }
}

public enum SessionEvent: Sendable { case guardianOn, guardianOff, permissionGranted, userStarted, osConfirmedActive,
    osInterrupted, osTerminated, recovered, platformUnavailable, errored }

public final class ObservationSessionManager: @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var state: ObservationSessionState = .off
    private let capability: PlatformObservationCapability
    public init(capability: PlatformObservationCapability) { self.capability = capability }

    /// Explicit transition. Never silently jumps to .active; .active requires OS confirmation.
    @discardableResult
    public func apply(_ e: SessionEvent) -> ObservationSessionState {
        lock.lock(); defer { lock.unlock() }
        switch (state, e) {
        case (_, .platformUnavailable): state = .unavailable
        case (_, .guardianOff): state = .off
        case (_, .errored): state = .error
        case (.off, .guardianOn):
            state = capability.sessionStart == .unavailable ? .unavailable
                  : (capability.sessionStart == .zeroTouchContinuous ? .ready : .permissionRequired)
        case (.permissionRequired, .permissionGranted): state = .ready
        case (.ready, .userStarted): state = .starting
        case (.ready, .guardianOn): state = .ready
        case (.starting, .osConfirmedActive): state = .active
        case (.active, .osInterrupted): state = .interrupted
        case (.interrupted, .recovered): state = .active
        case (.interrupted, .osTerminated):
            // Auto-resume only if the OS permits it; iOS requires a one-tap restart.
            state = capability.autoResumeAfterInterruption == .autoResumePermitted ? .recoverable : .restartRequired
        case (.active, .osTerminated):
            state = capability.autoResumeAfterInterruption == .autoResumePermitted ? .recoverable : .restartRequired
        case (.recoverable, .osConfirmedActive): state = .active
        case (.restartRequired, .userStarted): state = .starting
        default: break
        }
        return state
    }
}

/// §9 app-context resolution. AppContext confidence is SEPARATE from content confidence; no certain visual app-id guess.
public struct AppContext: Sendable, Equatable {
    public enum Identity: Sendable, Equatable { case knownBundleID(String), inferredClass(String), userDeclared(String), unknownApp }
    public let identity: Identity
    public let sourceSurfaceClass: String     // e.g. "short-video-feed", "messaging", "browser", "unknown"
    public let contextConfidence: Double      // 0..1, independent of content confidence
}
public enum AppContextResolver {
    /// Use official identity when exposed; otherwise an inferred class with its OWN confidence — never a certain guess.
    public static func resolve(officialBundleID: String?, userDeclared: String?, inferredClass: (String, Double)?) -> AppContext {
        if let b = officialBundleID, !b.isEmpty { return AppContext(identity: .knownBundleID(b), sourceSurfaceClass: "official", contextConfidence: 1.0) }
        if let u = userDeclared, !u.isEmpty { return AppContext(identity: .userDeclared(u), sourceSurfaceClass: "user-declared", contextConfidence: 0.9) }
        if let (cls, conf) = inferredClass { return AppContext(identity: .inferredClass(cls), sourceSurfaceClass: cls, contextConfidence: min(0.7, conf)) }
        return AppContext(identity: .unknownApp, sourceSurfaceClass: "unknown", contextConfidence: 0.0)
    }
}

/// §23 recovery classification.
public enum RecoveryClass: String, Sendable, Codable { case autoResumable = "AUTO_RESUMABLE", oneTapRestart = "ONE_TAP_RESTART", impossible = "IMPOSSIBLE" }
public enum SessionRecoveryController {
    public static func classify(_ interruption: String, capability: PlatformObservationCapability) -> RecoveryClass {
        switch interruption {
        case "app-switch":                      // within a live broadcast → session continues automatically
            return capability.withinSessionAppSwitchAutomatic ? .autoResumable : .oneTapRestart
        case "lock-unlock", "foreground-background":
            return capability.autoResumeAfterInterruption == .autoResumePermitted ? .autoResumable : .oneTapRestart
        case "os-terminated", "broadcast-stopped":
            return capability.autoResumeAfterInterruption == .autoResumePermitted ? .autoResumable : .oneTapRestart
        case "reboot": return .oneTapRestart
        default: return .oneTapRestart
        }
    }
}

/// §22 automatic-session metrics — minimal manual intervention, never hidden capture.
public struct SessionProofCounters: Sendable, Equatable {
    public var manualActions = 0            // session starts / restarts the user had to tap
    public var autoContentTransitions = 0   // new contents auto-observed without reopening Gen8
    public var interruptions = 0
    public var recoveries = 0
    public init() {}
}

/// §6 top-level runtime. Once ACTIVE, content changes auto-produce observations; Gen8 is never reopened per app.
public final class GuardianRuntimeManager: @unchecked Sendable {
    public let capability: PlatformObservationCapability
    public let session: ObservationSessionManager
    private let lock = NSLock()
    private var counters = SessionProofCounters()
    public init(platform: String, registry: PlatformCapabilityRegistry = PlatformCapabilityRegistry()) {
        self.capability = registry.capability(platform: platform)
        self.session = ObservationSessionManager(capability: capability)
    }
    public func noteManualAction() { lock.lock(); counters.manualActions += 1; lock.unlock() }
    /// Called on each auto-detected NEW content while the session is ACTIVE. Returns true if an observation should run.
    public func onContentChange(newContent: Bool) -> Bool {
        guard session.state.isObserving, newContent else { return false }
        lock.lock(); counters.autoContentTransitions += 1; lock.unlock()
        return true   // auto — no manual Gen8 reopen
    }
    public func noteInterruption() { lock.lock(); counters.interruptions += 1; lock.unlock() }
    public func noteRecovery() { lock.lock(); counters.recoveries += 1; lock.unlock() }
    public func snapshot() -> SessionProofCounters { lock.lock(); defer { lock.unlock() }; return counters }
}
