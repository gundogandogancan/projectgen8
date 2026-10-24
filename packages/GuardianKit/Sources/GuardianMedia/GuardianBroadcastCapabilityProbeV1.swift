//
//  GuardianBroadcastCapabilityProbeV1.swift — §5.2 SMALL, HONEST capability probe for ReplayKit app-identity.
//
//  THE QUESTION (mandate §5.2): can a ReplayKit Broadcast Upload Extension reliably learn the FOREGROUND app whose
//  frames it is receiving — via the DOCUMENTED attachment key RPVideoSampleOrientationKey-adjacent application-info,
//  i.e. the RPApplicationInfoBundleIdentifierKey carried on the CMSampleBuffer / supplied to
//  broadcastAnnotated(withApplicationInfo:) — and does it UPDATE when the user switches foreground apps, on which
//  iOS versions, under which entitlement? If YES and reliable, source-aware auto-idle (§5) could be enabled. If NOT
//  reliable, app-based auto-idle MUST stay FEATURE_UNAVAILABLE and we ship the user-controlled switch instead.
//
//  WHAT THIS MODULE DOES — and does NOT do:
//   • It READS only DOCUMENTED, public CMSampleBuffer attachment keys and records PRESENCE/ABSENCE + a privacy-safe
//     digest (never the bundle id string itself in release logs — a bundle id is app-private telemetry). It is a
//     measurement instrument, not a feature: it makes NO decisions and changes NO behaviour.
//   • It NEVER uses a private API and NEVER issues a hidden foreground query (rule 19; §5.2). The ONLY source is the
//     attachment the OS itself put on the buffer.
//   • The simulator cannot prove device broadcast behaviour → on the simulator / absent a real device broadcast the
//     verdict is DEVICE_UNVERIFIED and the capability DEFAULTS to FEATURE_UNAVAILABLE (auto-idle stays off).
//
//  Wire it into SampleHandler behind the SAME EvidenceBuildPolicyV1 gate as the other high-volume evidence (so it is
//  structurally OFF in release and only runs in an explicit evidence/DEBUG build). Lives in GuardianMedia, dual-
//  compiled into the broadcast extension.
//
import Foundation
#if canImport(CoreMedia)
import CoreMedia
#endif
#if canImport(ReplayKit)
import ReplayKit
#endif

/// One probe observation for a single buffer: which documented attachment keys were present, and a stable,
/// privacy-safe digest of the application-info value (so repeated SAME-app buffers can be told apart from a CHANGE
/// without ever logging the raw bundle id). NO raw frames; derived scalars only.
public struct GuardianBroadcastCapabilityProbeSampleV1: Sendable, Equatable {
    /// Was ANY attachments dictionary present on the buffer at all?
    public let hadAttachments: Bool
    /// Was the documented ReplayKit application-info key present (bundle id of the foreground app)?
    public let hadApplicationInfoKey: Bool
    /// A privacy-safe digest of the application-info value (0 when absent). Lets us DETECT a foreground change
    /// (digest changed between buffers) without ever retaining the app-private bundle id string itself.
    public let applicationInfoDigest: UInt64

    public init(hadAttachments: Bool, hadApplicationInfoKey: Bool, applicationInfoDigest: UInt64) {
        self.hadAttachments = hadAttachments
        self.hadApplicationInfoKey = hadApplicationInfoKey
        self.applicationInfoDigest = applicationInfoDigest
    }
}

/// The accumulated verdict after observing N buffers over a real device broadcast. Honest by construction: it never
/// claims the capability works unless the key was actually PRESENT and actually CHANGED across a foreground switch.
public enum GuardianBroadcastCapabilityVerdictV1: String, Sendable, Equatable {
    /// We never saw the application-info key present on any buffer → the capability is not available to us here.
    case featureUnavailable = "FEATURE_UNAVAILABLE"
    /// The key was present but we have NOT yet confirmed it UPDATES on a real foreground change → needs a device run.
    case presentUnverified = "PRESENT_DEVICE_UNVERIFIED"
    /// The key was present AND its digest changed (a foreground app switch was reflected) → the signal is live.
    /// This verdict is only EVER reachable from a real device broadcast; the simulator cannot produce it.
    case presentAndUpdates = "PRESENT_AND_UPDATES"
}

/// A small accumulator. Feed it the documented attachments of each buffer; it tracks presence + change and yields an
/// HONEST verdict. Keep one instance per broadcast session.
public struct GuardianBroadcastCapabilityProbeV1: Sendable {
    public static let version = "broadcast-capability-probe-v1"

    /// The DOCUMENTED ReplayKit attachment key name for the foreground application's bundle id. Referenced as a
    /// STRING so this module compiles on platforms/SDKs where the ReplayKit symbol is unavailable (it is read off
    /// the attachments dictionary by key, exactly as documented) — never a private/undocumented key.
    public static let applicationInfoKeyName = "RPApplicationInfoBundleIdentifierKey"

    public private(set) var samplesObserved = 0
    public private(set) var samplesWithKey = 0
    public private(set) var distinctDigests: Set<UInt64> = []
    private var lastDigest: UInt64? = nil
    public private(set) var digestChanges = 0

    public init() {}

    /// Record one probe sample. Pure + testable (no CoreMedia needed): callers that have a real CMSampleBuffer use
    /// `probe(_:)` below to extract the sample first.
    public mutating func record(_ s: GuardianBroadcastCapabilityProbeSampleV1) {
        samplesObserved += 1
        guard s.hadApplicationInfoKey else { return }
        samplesWithKey += 1
        distinctDigests.insert(s.applicationInfoDigest)
        if let last = lastDigest, last != s.applicationInfoDigest { digestChanges += 1 }
        lastDigest = s.applicationInfoDigest
    }

    /// The HONEST verdict given what we have actually observed. DEVICE_UNVERIFIED is the ceiling off-device: the
    /// `presentAndUpdates` verdict requires a real foreground change, which only a device broadcast can produce.
    public var verdict: GuardianBroadcastCapabilityVerdictV1 {
        if samplesWithKey == 0 { return .featureUnavailable }
        return digestChanges > 0 ? .presentAndUpdates : .presentUnverified
    }

    /// A one-line, privacy-safe summary for the evidence log (NEVER the bundle id string).
    public var summary: String {
        "probe=\(Self.version) samples=\(samplesObserved) withKey=\(samplesWithKey) distinct=\(distinctDigests.count) changes=\(digestChanges) verdict=\(verdict.rawValue)"
    }

#if canImport(CoreMedia)
    /// Extract a probe sample from a REAL CMSampleBuffer by reading only DOCUMENTED attachments. Returns a sample
    /// with presence flags + a privacy-safe digest; never retains or logs the raw bundle id. Call behind the
    /// EvidenceBuildPolicyV1 gate in SampleHandler.
    public static func sample(from buffer: CMSampleBuffer) -> GuardianBroadcastCapabilityProbeSampleV1 {
        guard let raw = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[CFString: Any]],
              let first = raw.first else {
            return .init(hadAttachments: false, hadApplicationInfoKey: false, applicationInfoDigest: 0)
        }
        // Read the DOCUMENTED application-info key by name (string key off the attachments dict).
        let key = applicationInfoKeyName as CFString
        if let value = first[key] {
            let digest = privacySafeDigest(of: "\(value)")
            return .init(hadAttachments: true, hadApplicationInfoKey: true, applicationInfoDigest: digest)
        }
        return .init(hadAttachments: true, hadApplicationInfoKey: false, applicationInfoDigest: 0)
    }

    /// Convenience: extract + record in one call from a real buffer.
    public mutating func probe(_ buffer: CMSampleBuffer) {
        record(Self.sample(from: buffer))
    }
#endif

    /// A stable, non-reversible digest (FNV-1a) of the app-private value. We keep the DIGEST, never the string, so a
    /// foreground change is detectable without the bundle id ever entering our logs/state.
    public static func privacySafeDigest(of s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }
}

/// The DEVICE probe PLAN (§5.2) — documented so the capability can be verified on a real device later without
/// guessing. This is produced by the extension as FEATURE_UNAVAILABLE by default until a device run upgrades it.
public enum GuardianBroadcastCapabilityProbePlanV1 {
    public static let steps: [String] = [
        "1. Build GuardianBroadcastExtension with GEN8_EVIDENCE_BUILD so the probe runs (structurally off in release).",
        "2. On a REAL device, start the system broadcast from app A (e.g. a social feed), let ~60 buffers flow.",
        "3. Switch the foreground to app B WITHOUT stopping the broadcast; let ~60 more buffers flow.",
        "4. Pull gen8_crossapp_proof.log; read CAPABILITY_PROBE lines: did withKey>0 ever? did changes>0 after the switch?",
        "5. Repeat across iOS 17 / 18 / 26 and with/without the app-info annotation entitlement; record each verdict.",
        "6. ONLY if verdict==PRESENT_AND_UPDATES reliably on all targeted iOS versions → consider enabling app-based",
        "   auto-idle. Until then auto-idle stays FEATURE_UNAVAILABLE and the user-controlled ACTIVE/IDLE switch ships."
    ]
    /// The default device-unverified capability until a real device run proves otherwise.
    public static let defaultVerdict = GuardianBroadcastCapabilityVerdictV1.featureUnavailable
}
