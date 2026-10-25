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

/// §F — the transition-correlation accumulator for ONE source channel, redesigned to fix the DIGEST-DOMAIN MISMATCH.
///
/// THE BUG V2 originally had: it compared each OBSERVED digest (a digest of the real foreground app's identity VALUE)
/// against a PRE-COMPUTED digest of the opaque script LABEL ("A"/"B"). Those live in DIFFERENT domains — the digest of
/// the string "A" is not the digest of the real bundle id that happens to be foregrounded at script step A — so even a
/// perfectly-tracking source could NEVER reach PRESENT_AND_UPDATES (and a test only "passed" by feeding the literal
/// label as the value, which never happens on a device).
///
/// THE FIX: the script label ↔ real identity mapping is established AT RUNTIME, in the device experiment, by the
/// OPERATOR: at each observation the operator asserts WHICH scripted step is foregrounded right now (the schedule).
/// The accumulator LEARNS the observed digest the first time it sees each asserted label, then scores a transition as
/// SCRIPTED-AGREEING when the step advances in scripted order (A→B→A) AND the observed digest for the now-asserted
/// label is CONSISTENT with what this source showed for that label before. This compares observed-vs-observed (one
/// domain), never observed-vs-label-digest. A fixed/stale source learns one digest and never changes →
/// PRESENT_STALE_OR_FIXED; a source whose digest for a RE-asserted label differs → PRESENT_CHANGES_UNSCRIPTED.
public struct GuardianProbeSourceAccumulatorV2: Sendable, Equatable {
    public private(set) var observations = 0
    /// Observations that actually CARRIED an identity (absent-observations are excluded). A source that only ever
    /// reported ABSENT has `identityObservations == 0` → FEATURE_UNAVAILABLE, never "present".
    public private(set) var identityObservations = 0
    /// Distinct foreground transitions actually observed (the observed digest changed vs the previous observation).
    public private(set) var observedTransitions = 0
    /// Scripted-step transitions that AGREED: the step advanced in scripted order AND the new step's observed digest
    /// was consistent with this source's learned binding. The ONLY path to PRESENT_AND_UPDATES.
    public private(set) var scriptedTransitionsMatched = 0
    /// A step re-assertion whose observed digest CONTRADICTED the digest learned for that label (present + changing,
    /// but NOT tracking the real foreground consistently) → a PRESENT_CHANGES_UNSCRIPTED signal.
    public private(set) var contradictions = 0
    private var lastDigest: UInt64? = nil
    private var lastStepIndex: Int? = nil
    /// LEARNED per-step-label observed digest (the runtime label↔identity binding). The SAME label asserted at two
    /// schedule positions (A at step 0 and step 2) is required to show the SAME digest to agree.
    private var learnedDigestByLabel: [String: UInt64] = [:]

    public init() {}

    /// Feed one observation for this source. `digest` is the session-keyed digest of the observed identity value (or a
    /// sentinel for absence). `assertedStepIndex`/`assertedLabel` is the scripted step the OPERATOR asserts is
    /// foregrounded RIGHT NOW (nil when the operator is between steps). `carriesIdentity` is false for an ABSENT
    /// observation. Returns whether this observation completed a scripted-order transition.
    @discardableResult
    public mutating func observe(sessionKeyedDigest digest: UInt64, assertedStepIndex: Int?, assertedLabel: String?,
                                 carriesIdentity: Bool = true) -> Bool {
        observations += 1
        if carriesIdentity { identityObservations += 1 }
        defer { if carriesIdentity { lastDigest = digest; if let s = assertedStepIndex { lastStepIndex = s } } }
        guard carriesIdentity else { return false }   // absence cannot complete a foreground transition
        if let last = lastDigest, last != digest { observedTransitions += 1 }   // a real foreground change
        // Scoring requires the operator's runtime assertion of which scripted step this is; without it we can only
        // count presence/transitions (an unscripted free-run), never claim scripted agreement.
        guard let step = assertedStepIndex, let label = assertedLabel else { return false }
        // LEARN or VERIFY the label↔identity binding (observed-vs-observed, same domain — the mismatch fix).
        if let learned = learnedDigestByLabel[label] {
            if learned != digest { contradictions += 1; return false }   // same label, different identity → inconsistent
        } else {
            learnedDigestByLabel[label] = digest   // first sighting of this label binds it to the observed digest
        }
        // A scripted-order transition completes when we ADVANCE to the next step (index increased by exactly one vs
        // the last asserted step) and the digest is consistent with that step (checked above). The first asserted
        // step only establishes the baseline (no transition yet).
        if let prevStep = lastStepIndex, step == prevStep + 1 {
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
    /// The scripted step LABELS (opaque A/B/A). The operator asserts WHICH of these is foregrounded at observe time;
    /// the label↔identity binding is learned at runtime (no pre-computed label digests — the digest-domain fix).
    private let scriptLabels: [String]
    /// Expected scripted TRANSITIONS to reach agreement = steps − 1 (A→B and B→A for the default script).
    private var expectedTransitions: Int { max(0, scriptLabels.count - 1) }

    public private(set) var callback = GuardianProbeSourceAccumulatorV2()
    public private(set) var attachment = GuardianProbeSourceAccumulatorV2()

    public init(script: [GuardianProbeScriptStepV2], sessionKey: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) {
        self.sessionKey = sessionKey
        self.scriptLabels = script.map { $0.label }
    }

    /// The canonical A→B→A script (the simplest design that distinguishes a live source from a fixed/stale one: it
    /// requires a change AWAY from A and a change BACK to A, in order — a stuck value matches neither transition).
    public static let defaultScript = [GuardianProbeScriptStepV2(label: "A"),
                                       GuardianProbeScriptStepV2(label: "B"),
                                       GuardianProbeScriptStepV2(label: "A")]

    /// §F — observe one raw identity VALUE on a source, WITH the scripted step the operator asserts is foregrounded
    /// right now (`assertedStepIndex`, nil when the operator is between steps). The raw value is digested with the
    /// session key immediately and NEVER retained; the asserted step provides the runtime label↔identity binding so
    /// agreement is scored observed-vs-observed (fixing the digest-domain mismatch). In the device experiment the
    /// operator drives `assertedStepIndex` from the schedule (0 for the first A, 1 for B, 2 for the return A).
    public mutating func observe(rawIdentity value: String, source: GuardianProbeSourceV2, assertedStepIndex: Int?) {
        let d = Self.sessionKeyedDigest(of: value, key: sessionKey)
        let label = assertedStepIndex.flatMap { scriptLabels.indices.contains($0) ? scriptLabels[$0] : nil }
        switch source {
        case .annotationCallback: _ = callback.observe(sessionKeyedDigest: d, assertedStepIndex: assertedStepIndex, assertedLabel: label)
        case .sampleAttachment:   _ = attachment.observe(sessionKeyedDigest: d, assertedStepIndex: assertedStepIndex, assertedLabel: label)
        }
    }

    /// Observe the ABSENCE of identity on a source this sample (e.g. the attachment key was missing). Recorded as an
    /// observation with no change, so a source that only intermittently carries identity is scored honestly.
    public mutating func observeAbsent(source: GuardianProbeSourceV2) {
        let sentinel = Self.sessionKeyedDigest(of: "\u{0}ABSENT", key: sessionKey)
        switch source {
        case .annotationCallback: _ = callback.observe(sessionKeyedDigest: sentinel, assertedStepIndex: nil, assertedLabel: nil, carriesIdentity: false)
        case .sampleAttachment:   _ = attachment.observe(sessionKeyedDigest: sentinel, assertedStepIndex: nil, assertedLabel: nil, carriesIdentity: false)
        }
    }

    /// Per-source verdict (mandate F: the two channels are scored independently).
    public func verdict(for source: GuardianProbeSourceV2) -> GuardianBroadcastCapabilityVerdictV2 {
        let acc = source == .annotationCallback ? callback : attachment
        if acc.identityObservations == 0 { return .featureUnavailable }   // never saw an identity on this channel
        if acc.observedTransitions == 0 { return .presentStaleOrFixed }
        // Require ALL scripted transitions to have matched in scripted order, with NO contradictions, to claim
        // temporal agreement (A→B AND B→A, each digest consistent with its learned binding).
        return acc.scriptedTransitionsMatched >= expectedTransitions && expectedTransitions > 0 && acc.contradictions == 0
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
        "probe=\(Self.version) cb[obs=\(callback.observations) tr=\(callback.observedTransitions) scripted=\(callback.scriptedTransitionsMatched) contra=\(callback.contradictions) v=\(verdict(for: .annotationCallback).rawValue)] att[obs=\(attachment.observations) tr=\(attachment.observedTransitions) scripted=\(attachment.scriptedTransitionsMatched) contra=\(attachment.contradictions) v=\(verdict(for: .sampleAttachment).rawValue)] overall=\(verdict.rawValue)"
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
