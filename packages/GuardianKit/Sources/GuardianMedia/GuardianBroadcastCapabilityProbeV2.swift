//
//  GuardianBroadcastCapabilityProbeV2.swift — §F: transition-correlation capability probe (honest redesign).
//
//  WHY V2 (mandate F): V1 upgraded to PRESENT_AND_UPDATES the moment the application-info DIGEST changed even once.
//  That is too weak: a digest change alone does NOT prove the attachment tracks the REAL foreground app. Two distinct
//  defects it cannot tell apart —
//    • a value that changes for reasons unrelated to a foreground switch (noise / re-annotation), and
//    • a value that is PRESENT but STALE (never reflects the switch we actually performed).
//  V2 therefore does NOT trust mere data presence or mere change. It scores TEMPORAL AGREEMENT against a PRE-DEFINED
//  transition script (the device operator performs a known A→B→A foreground sequence): the probe only reaches
//  PRESENT_AND_UPDATES when the observed source transitions MATCH the scripted transitions IN ORDER and IN TIME.
//
//  TWO SOURCES, SEPARATED (mandate F): the app-identity can arrive via TWO distinct channels —
//    (1) the broadcastAnnotated(withApplicationInfo:) CALLBACK the host app pushes, and
//    (2) a per-sample CMSampleBuffer ATTACHMENT key.
//  They are NOT the same guarantee (a key's mere presence ≠ a fresh per-frame foreground identity). V2 keeps the two
//  source streams separate and scores each independently, because one can be live while the other is stale/absent.
//
//  PRIVACY (mandate F): FNV-1a is NOT described as "anonymization / irreversible" (it is neither). We keep ONLY a
//  SESSION-KEYED comparison digest (salted with a per-session random key, discarded at session end) so two samples
//  can be told same/different WITHOUT retaining any cross-session identity, and — where possible — we keep only the
//  TRANSITION-AGREEMENT statistic, not the identities themselves. No raw bundle id is ever retained or logged.
//
//  No private API. No behaviour change: V2 is a MEASUREMENT instrument. Auto-idle stays FEATURE_UNAVAILABLE off a
//  real device; the probe never flips a product behaviour — it only tells a later device run whether it COULD.
//
import Foundation

/// The channel an app-identity observation arrived on. Kept separate because they are different guarantees.
public enum GuardianProbeSourceV2: String, Sendable, Equatable, Codable {
    case annotationCallback = "ANNOTATION_CALLBACK"   // broadcastAnnotated(withApplicationInfo:) host push
    case sampleAttachment   = "SAMPLE_ATTACHMENT"     // per-CMSampleBuffer attachment key
}

/// One step of the PRE-DEFINED transition script the device operator performs (e.g. foreground app A, then B, then A).
/// The script carries only OPAQUE labels (A/B/A) — never real bundle ids — so the expectation itself retains no identity.
public struct GuardianProbeScriptStepV2: Sendable, Equatable {
    /// Opaque label for the expected foreground app at this step ("A", "B", …). Mapped to a session-keyed digest.
    public let label: String
    public init(label: String) { self.label = label }
}

/// The transition-correlation accumulator for ONE source channel. Fed the session-keyed digest of each observation;
/// it detects TRANSITIONS (digest changed vs the previous observation) and scores them against the scripted
/// transitions in order. Retains only: the current digest (to detect the next transition), a bounded count of
/// observed transitions, and how many agreed with the script. No identity, no history of values.
public struct GuardianProbeSourceAccumulatorV2: Sendable, Equatable {
    public private(set) var observations = 0
    /// Observations that actually CARRIED an identity (absent-observations are excluded). A source that only ever
    /// reported ABSENT has `identityObservations == 0` → FEATURE_UNAVAILABLE, never "present".
    public private(set) var identityObservations = 0
    public private(set) var observedTransitions = 0
    /// Scripted transitions matched IN ORDER: the next expected transition's "to" digest equalled the observed one.
    public private(set) var scriptedTransitionsMatched = 0
    private var lastDigest: UInt64? = nil

    public init() {}

    /// Feed one session-keyed digest for this source, along with the expected NEXT scripted transition's target
    /// digest (nil when the script is exhausted). `carriesIdentity` is false for an ABSENT observation (the key was
    /// missing this sample). Returns whether this observation completed a scripted transition.
    @discardableResult
    public mutating func observe(sessionKeyedDigest d: UInt64, expectedNextDigest: UInt64?,
                                 carriesIdentity: Bool = true) -> Bool {
        observations += 1
        if carriesIdentity { identityObservations += 1 }
        defer { lastDigest = d }
        guard let last = lastDigest, last != d else { return false }  // a real change vs the previous observation
        // A transition INTO or OUT OF absence is not a foreground-identity transition we can score; only count a
        // transition when the new observation actually carries an identity.
        guard carriesIdentity else { return false }
        observedTransitions += 1
        if let expected = expectedNextDigest, d == expected {
            scriptedTransitionsMatched += 1
            return true
        }
        return false
    }
}

/// The honest V2 verdict. PRESENT_AND_UPDATES requires scripted TEMPORAL AGREEMENT on at least one source — never
/// mere presence or mere change. Reachable ONLY from a real device run that performed the script.
public enum GuardianBroadcastCapabilityVerdictV2: String, Sendable, Equatable {
    case featureUnavailable = "FEATURE_UNAVAILABLE"              // no source ever carried identity
    case presentStaleOrFixed = "PRESENT_STALE_OR_FIXED"         // identity present but it NEVER changed (fixed/stale)
    case presentChangesUnscripted = "PRESENT_CHANGES_UNSCRIPTED"// it changed, but NOT in agreement with the script
    case presentAndUpdates = "PRESENT_AND_UPDATES"              // changed in TEMPORAL AGREEMENT with the A→B→A script
}

/// The V2 probe. One instance per broadcast session. Holds the per-session random KEY (so digests are comparable
/// within the session but carry no cross-session identity), the scripted transitions, and a separate accumulator per
/// source channel. It changes NO behaviour; default verdict is FEATURE_UNAVAILABLE until a device run proves agreement.
public struct GuardianBroadcastCapabilityProbeV2: Sendable {
    public static let version = "broadcast-capability-probe-v2"

    /// A per-session random key. Mixed into every digest so the SAME bundle id yields a DIFFERENT digest in a
    /// different session — session-keyed comparison without retaining a reversible/stable identity (mandate F).
    private let sessionKey: UInt64
    /// The expected transitions as session-keyed target digests (derived once from the opaque script + the key).
    private let scriptedTargetDigests: [UInt64]
    private var scriptCursor = 0

    public private(set) var callback = GuardianProbeSourceAccumulatorV2()
    public private(set) var attachment = GuardianProbeSourceAccumulatorV2()

    public init(script: [GuardianProbeScriptStepV2], sessionKey: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) {
        self.sessionKey = sessionKey
        // Derive the expected TRANSITION targets: each step after the first is a transition TO that step's label.
        var targets: [UInt64] = []
        for i in 1..<max(script.count, 1) where i < script.count {
            targets.append(Self.sessionKeyedDigest(of: script[i].label, key: sessionKey))
        }
        self.scriptedTargetDigests = targets
    }

    /// The canonical A→B→A script (the simplest design that distinguishes a live source from a fixed/stale one: it
    /// requires a change AWAY from A and a change BACK to A, in order — a stuck value matches neither transition).
    public static let defaultScript = [GuardianProbeScriptStepV2(label: "A"),
                                       GuardianProbeScriptStepV2(label: "B"),
                                       GuardianProbeScriptStepV2(label: "A")]

    /// Observe one raw identity VALUE on a given source. The raw value is digested with the session key immediately
    /// and NEVER retained. Advances the script cursor when the observation completes the next scripted transition.
    public mutating func observe(rawIdentity value: String, source: GuardianProbeSourceV2) {
        let d = Self.sessionKeyedDigest(of: value, key: sessionKey)
        let expected = scriptCursor < scriptedTargetDigests.count ? scriptedTargetDigests[scriptCursor] : nil
        let matched: Bool
        switch source {
        case .annotationCallback: matched = callback.observe(sessionKeyedDigest: d, expectedNextDigest: expected)
        case .sampleAttachment:   matched = attachment.observe(sessionKeyedDigest: d, expectedNextDigest: expected)
        }
        if matched { scriptCursor += 1 }
    }

    /// Observe the ABSENCE of identity on a source this sample (e.g. the attachment key was missing). Recorded as an
    /// observation with no change, so a source that only intermittently carries identity is scored honestly.
    public mutating func observeAbsent(source: GuardianProbeSourceV2) {
        // An absent value cannot complete a transition; feed a sentinel that never equals a scripted target.
        let sentinel = Self.sessionKeyedDigest(of: "\u{0}ABSENT", key: sessionKey)
        switch source {
        case .annotationCallback: _ = callback.observe(sessionKeyedDigest: sentinel, expectedNextDigest: nil, carriesIdentity: false)
        case .sampleAttachment:   _ = attachment.observe(sessionKeyedDigest: sentinel, expectedNextDigest: nil, carriesIdentity: false)
        }
    }

    /// Per-source verdict (mandate F: the two channels are scored independently).
    public func verdict(for source: GuardianProbeSourceV2) -> GuardianBroadcastCapabilityVerdictV2 {
        let acc = source == .annotationCallback ? callback : attachment
        if acc.identityObservations == 0 { return .featureUnavailable }   // never saw an identity on this channel
        if acc.observedTransitions == 0 { return .presentStaleOrFixed }
        // Require ALL scripted transitions to have matched in order to claim temporal agreement (A→B AND B→A).
        return acc.scriptedTransitionsMatched >= scriptedTargetDigests.count && !scriptedTargetDigests.isEmpty
            ? .presentAndUpdates
            : .presentChangesUnscripted
    }

    /// The overall verdict — the BEST of the two sources (either channel proving agreement suffices to say the
    /// capability exists on SOME channel), but never better than what a source actually demonstrated.
    public var verdict: GuardianBroadcastCapabilityVerdictV2 {
        let order: [GuardianBroadcastCapabilityVerdictV2] = [.featureUnavailable, .presentStaleOrFixed,
                                                             .presentChangesUnscripted, .presentAndUpdates]
        let c = verdict(for: .annotationCallback), a = verdict(for: .sampleAttachment)
        return (order.firstIndex(of: c)! >= order.firstIndex(of: a)!) ? c : a
    }

    /// A one-line, privacy-safe summary (statistics only — NEVER a bundle id, NEVER a retained identity).
    public var summary: String {
        "probe=\(Self.version) cb[obs=\(callback.observations) tr=\(callback.observedTransitions) scripted=\(callback.scriptedTransitionsMatched) v=\(verdict(for: .annotationCallback).rawValue)] att[obs=\(attachment.observations) tr=\(attachment.observedTransitions) scripted=\(attachment.scriptedTransitionsMatched) v=\(verdict(for: .sampleAttachment).rawValue)] overall=\(verdict.rawValue)"
    }

    /// A SESSION-KEYED comparison digest. FNV-1a mixed with the per-session key — this is a COMPARISON token, NOT an
    /// anonymization primitive (it is not described as irreversible; the point is only same/different WITHIN a
    /// session). Different session key ⇒ different digest for the same input ⇒ no cross-session identity retained.
    public static func sessionKeyedDigest(of s: String, key: UInt64) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325 ^ key
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h &* (key | 1)
    }
}
