//
//  FamilyProfileSharedStoreV1.swift — R5 §2 (P0-1): the SHARED FAMILY PROFILE STORE.
//
//  WHY: the frozen family engine (GuardianCore `ChildAgePolicyEngineV1` + `GuardianEnteredChildProfileV1` +
//  `ParentPreferencePolicyV1` + `JurisdictionAgeBandRegistryV1`) is real and tested, but until R5 NOTHING on the
//  product path could feed it: there was no durable, app↔extension-shared parent/child profile. This store is that
//  missing link — the SAME pattern as `PersonalShieldSharedStoreV1` (App Group container + a monotonic revision
//  counter in the shared suite) and the SAME crash-safety discipline as `LocalLearningStoreV1` (atomic writes,
//  write-ahead intent, file protection, backup exclusion, corrupt → recovered + SURFACED, never silent).
//
//  LAWS (mandate §2 — binding):
//   • Age is PARENT-ENTERED ONLY. There is structurally no face/photo/behavior input anywhere near this type.
//   • The parent declaration is a DECLARATION ("beyan") — NEVER presented as verified identity/guardianship.
//   • Minimal data: policy mode, entered age, declaration flag, region, stricter-only preferences, revisions,
//     timestamps. NO full name, NO photo, NO birthdate, NO contact data — the struct cannot even hold them.
//   • Parent preferences are STRICTER-ONLY (they map onto `ParentPreferencePolicyV1`, which can only tighten).
//   • App Group read failure → HONEST state (MISSING / STALE), never stale-as-fresh.
//   • A profile/policy change bumps the shared revision → the extension invalidates its current decision.
//
//  Lives in GuardianMedia (GuardianCore frozen); dual-compiled into the app + extension (pbxproj FF pattern).
//
import Foundation
import GuardianCore

// MARK: - §2 — the family policy mode (the ACTIVE protection posture, chosen by the parent/owner).

public enum FamilyPolicyModeV1: String, Sendable, Equatable, Codable, CaseIterable {
    case adult = "ADULT"     // no child/teen overlay — personal shield + general wellbeing only (unchanged behavior)
    case teen  = "TEEN"      // 13–17 developmental overlay (TeenBandFailClosedPolicy applies inside the engine)
    case child = "CHILD"     // under-13 overlay — the strictest floor (H1 fail-closed law applies inside the engine)

    /// Short honest Turkish label for the product UI.
    public var turkishLabel: String {
        switch self {
        case .adult: return "Yetişkin"
        case .teen:  return "Ergen (13–17)"
        case .child: return "Çocuk (<13)"
        }
    }
}

// MARK: - §2 — the honest profile STATE (what the reader may claim about the stored profile).

public enum FamilyProfileStateV1: String, Sendable, Equatable, Codable {
    case valid = "VALID"              // decodable, revision-consistent, supported jurisdiction
    case missing = "MISSING"          // no profile stored (or the shared container is unreadable → honest MISSING)
    case stale = "STALE"              // the shared revision counter is AHEAD of the file we can read — never fresh
    case corrupt = "CORRUPT"          // stored bytes did not decode — recovered to no-profile, SURFACED (never silent)
    case unsupported = "UNSUPPORTED"  // decodable but the jurisdiction is not in the versioned registry → fail closed
}

// MARK: - §2 — the profile record (MINIMAL by construction).

public struct FamilyProfileV1: Sendable, Equatable, Codable {
    public static let schemaVersion = 1
    public var schema: Int
    /// Opaque profile id (UUID string) — identifies the ACTIVE profile record, carries no personal data.
    public let profileID: String
    public var mode: FamilyPolicyModeV1
    /// Parent-ENTERED age in years (nil for adult mode). NEVER inferred; the only source is the parent's numeric entry.
    public var parentEnteredAgeYears: Int?
    /// The parent's DECLARATION that they are the responsible guardian. A declaration, NOT a verified identity —
    /// every consumer must present it as "beyan" (the engine separately requires it to produce any child decision).
    public var parentDeclaration: Bool
    /// Supported policy region code — must come from `JurisdictionAgeBandRegistryV1.supportedJurisdictions`.
    public var jurisdictionCode: String
    // --- STRICTER-ONLY parent preferences (map 1:1 onto the frozen ParentPreferencePolicyV1 — tighten only) ---
    public var extraCautionFearThreat: Bool
    public var extraCautionManipulation: Bool
    public var blockSensitiveNews: Bool
    /// Monotonic profile/policy revision EMBEDDED in the record (mirrors the shared suite counter at write time).
    public var profileRevision: UInt64
    public let createdEpoch: Double
    public var modifiedEpoch: Double

    public init(profileID: String = UUID().uuidString, mode: FamilyPolicyModeV1,
                parentEnteredAgeYears: Int?, parentDeclaration: Bool, jurisdictionCode: String,
                extraCautionFearThreat: Bool = false, extraCautionManipulation: Bool = false,
                blockSensitiveNews: Bool = false, profileRevision: UInt64 = 0,
                createdEpoch: Double, modifiedEpoch: Double) {
        self.schema = Self.schemaVersion
        self.profileID = profileID; self.mode = mode
        self.parentEnteredAgeYears = parentEnteredAgeYears
        self.parentDeclaration = parentDeclaration
        self.jurisdictionCode = jurisdictionCode
        self.extraCautionFearThreat = extraCautionFearThreat
        self.extraCautionManipulation = extraCautionManipulation
        self.blockSensitiveNews = blockSensitiveNews
        self.profileRevision = profileRevision
        self.createdEpoch = createdEpoch; self.modifiedEpoch = modifiedEpoch
    }

    /// The frozen engine's profile input. HONESTY: when the age was never entered we pass `enteredByGuardian: false`
    /// with a sentinel age so the frozen engine FAILS CLOSED itself (`ageSourceMissing` → AGE_UNKNOWN_REVIEW) — the
    /// bridge never fabricates an attested age. When the declaration is off, same law: no attestation, no decision.
    public var guardianEnteredProfile: GuardianEnteredChildProfileV1 {
        GuardianEnteredChildProfileV1(ageYears: parentEnteredAgeYears ?? -1,
                                      jurisdictionCode: jurisdictionCode,
                                      enteredByGuardian: parentDeclaration && parentEnteredAgeYears != nil)
    }

    /// The frozen STRICTER-ONLY preference overlay. There is no loosening field to map — by construction.
    public var parentPreferencePolicy: ParentPreferencePolicyV1 {
        var dims: Set<SafetyDimensionV1> = []
        if extraCautionFearThreat { dims.insert(.fearThreat) }
        if extraCautionManipulation { dims.insert(.manipulationAttention) }
        return ParentPreferencePolicyV1(extraCautionDimensions: dims, blockSensitiveNews: blockSensitiveNews)
    }
}

// MARK: - §2 — load result (profile + honest state + storage facts).

public struct FamilyProfileLoadResultV1: Sendable {
    public let profile: FamilyProfileV1?
    public let state: FamilyProfileStateV1
    /// The LIVE shared revision counter at load time (0 when the suite is unavailable — honest degraded).
    public let liveRevision: UInt64
    public let sharedContainerActive: Bool
    public let corruptRecovered: Bool
    public let fileProtectionComplete: Bool
    public let excludedFromBackup: Bool
}

// MARK: - §2 — store location (same resolve pattern as PersonalShieldStoreLocationV1; honest DEGRADED fallback).

public enum FamilyProfileStoreLocationV1 {
    public static let appGroupID = "group.com.gen8.guardian.dev"
    public static let subdirectory = "Gen8/family"
    /// Resolve the storage directory. App Group container when provisioned; Application Support fallback otherwise
    /// (DEGRADED: app and extension then see DIFFERENT directories — the reader honestly reports MISSING, never a
    /// stale profile presented as fresh).
    public static func resolve(appGroupID: String = appGroupID) -> (directory: URL, sharedContainerActive: Bool) {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return (container.appendingPathComponent(subdirectory), true)
        }
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return (appSupport.appendingPathComponent(subdirectory), false)
    }
}

// MARK: - §2 — the store. Writer = app; reader = extension. Crash-safe: write-ahead intent + atomic file write +
// self-healing recovery on load (a crash between the file write and the revision bump is repaired, never half-state).

public final class FamilyProfileSharedStoreV1: @unchecked Sendable {
    public static let fileName = "family-profile-v1.json"
    public static let intentFileName = "family-profile-intent-v1.json"
    /// App Group key holding the monotonic FAMILY revision (distinct from the personal-shield revision key — the
    /// two policies are independent: a family change must never disturb the personal shield, and vice versa).
    public static let familyRevisionKey = "guardian.family.profile.revision.v1"

    private let fileURL: URL
    private let intentURL: URL
    private let suite: UserDefaults?
    private let fm = FileManager.default
    private let lock = NSLock()
    public let sharedContainerActive: Bool

    /// Write-ahead intent: records the revision a save is ABOUT to publish, so a crash between the atomic file
    /// write and the suite revision bump is detectable and repairable on the next load (self-heal, never silent).
    private struct SaveIntentV1: Codable { let targetRevision: UInt64; let epoch: Double }

    public init(appGroupID: String = FamilyProfileStoreLocationV1.appGroupID) {
        let (dir, shared) = FamilyProfileStoreLocationV1.resolve(appGroupID: appGroupID)
        self.sharedContainerActive = shared
        self.suite = UserDefaults(suiteName: appGroupID)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(Self.fileName)
        self.intentURL = dir.appendingPathComponent(Self.intentFileName)
    }

    /// Test / injection initializer — explicit directory + suite (no entitlement needed).
    public init(directory: URL, suite: UserDefaults?, sharedContainerActive: Bool = false) {
        self.sharedContainerActive = sharedContainerActive
        self.suite = suite
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent(Self.fileName)
        self.intentURL = directory.appendingPathComponent(Self.intentFileName)
    }

    // MARK: Revision counter (monotonic; shared across processes via the App Group suite)

    public var familyRevision: UInt64 {
        guard let suite else { return 0 }
        return UInt64(bitPattern: suite.object(forKey: Self.familyRevisionKey) as? Int64 ?? 0)
    }

    @discardableResult
    private func publishRevision(_ value: UInt64) -> UInt64 {
        suite?.set(Int64(bitPattern: value), forKey: Self.familyRevisionKey)
        return value
    }

    // MARK: Writer side (app)

    /// Persist the profile and bump the shared revision so any in-flight decision made under the old profile is
    /// stale. CRASH-SAFE SEQUENCE: (1) write-ahead intent (target revision), (2) atomic profile write with the
    /// target revision EMBEDDED, (3) publish the suite revision, (4) clear the intent. A crash after (2) leaves the
    /// file AHEAD of the suite — `load()` detects the intent and self-heals by finishing step (3). A crash before
    /// (2) leaves the old profile fully intact (atomicity). Returns the new revision, or nil on a write failure
    /// (the caller must NOT claim the profile was saved).
    @discardableResult
    public func save(_ profile: FamilyProfileV1) -> UInt64? {
        lock.lock(); defer { lock.unlock() }
        let target = familyRevision &+ 1
        var stamped = profile
        stamped.profileRevision = target
        stamped.modifiedEpoch = Date().timeIntervalSince1970
        guard let intentData = try? JSONEncoder().encode(SaveIntentV1(targetRevision: target,
                                                                      epoch: stamped.modifiedEpoch)),
              let data = try? JSONEncoder().encode(stamped) else { return nil }
        do {
            try intentData.write(to: intentURL, options: [.atomic])
            try data.write(to: fileURL, options: [.atomic])
        } catch { try? fm.removeItem(at: intentURL); return nil }
        applyFileProtection(fileURL); applyExcludedFromBackup(fileURL)
        applyFileProtection(intentURL)
        publishRevision(target)
        try? fm.removeItem(at: intentURL)
        return target
    }

    /// Delete the profile. The revision STILL bumps — deletion is a policy change: the extension must invalidate
    /// its current decision and re-read (it will then see honest MISSING, i.e. adult-equivalent default posture).
    @discardableResult
    public func delete() -> Bool {
        lock.lock(); defer { lock.unlock() }
        try? fm.removeItem(at: intentURL)
        if fm.fileExists(atPath: fileURL.path) {
            do { try fm.removeItem(at: fileURL) } catch { return false }
        }
        publishRevision(familyRevision &+ 1)
        return true
    }

    // MARK: Reader side (extension + app display)

    /// Load with HONEST state derivation. Never stale-as-fresh: when the shared revision counter is AHEAD of the
    /// decodable file we report STALE. A decode failure is CORRUPT (recovered to no-profile + surfaced). An absent
    /// file is MISSING. An out-of-registry jurisdiction is UNSUPPORTED (fail closed upstream).
    public func load() -> FamilyProfileLoadResultV1 {
        lock.lock(); defer { lock.unlock() }
        // Self-heal: a crash between the file write and the revision publish left a live intent whose target the
        // file already carries. Finish the publish so the two views converge; then clear the intent.
        if let intentData = try? Data(contentsOf: intentURL),
           let intent = try? JSONDecoder().decode(SaveIntentV1.self, from: intentData) {
            if let data = try? Data(contentsOf: fileURL),
               let p = try? JSONDecoder().decode(FamilyProfileV1.self, from: data),
               p.profileRevision == intent.targetRevision, familyRevision < intent.targetRevision {
                publishRevision(intent.targetRevision)   // the file write landed before the crash — finish the publish
            }
            try? fm.removeItem(at: intentURL)
        }
        let live = familyRevision
        guard fm.fileExists(atPath: fileURL.path) else {
            return FamilyProfileLoadResultV1(profile: nil, state: .missing, liveRevision: live,
                                             sharedContainerActive: sharedContainerActive, corruptRecovered: false,
                                             fileProtectionComplete: false, excludedFromBackup: false)
        }
        guard let data = try? Data(contentsOf: fileURL),
              let profile = try? JSONDecoder().decode(FamilyProfileV1.self, from: data) else {
            // Corrupt/incompatible ⇒ recovered to no-profile, SURFACED as CORRUPT (never a crash, never silent).
            return FamilyProfileLoadResultV1(profile: nil, state: .corrupt, liveRevision: live,
                                             sharedContainerActive: sharedContainerActive, corruptRecovered: true,
                                             fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
        }
        let state: FamilyProfileStateV1
        if suite != nil, live > profile.profileRevision {
            state = .stale   // a writer advanced the policy past what we can read — NEVER fresh
        } else if !JurisdictionAgeBandRegistryV1.supportedJurisdictions.contains(profile.jurisdictionCode) {
            state = .unsupported
        } else {
            state = .valid
        }
        return FamilyProfileLoadResultV1(profile: profile, state: state, liveRevision: live,
                                         sharedContainerActive: sharedContainerActive, corruptRecovered: false,
                                         fileProtectionComplete: protectionIsComplete(), excludedFromBackup: isExcluded())
    }

    // MARK: File protection + backup exclusion (same discipline as LocalLearningStoreV1)

    private func applyFileProtection(_ url: URL) {
        #if canImport(UIKit)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
    private func applyExcludedFromBackup(_ url: URL) {
        var u = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? u.setResourceValues(values)
    }
    private func protectionIsComplete() -> Bool {
        #if canImport(UIKit)
        let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.protectionKey] as? FileProtectionType) == .complete
        #else
        return false
        #endif
    }
    private func isExcluded() -> Bool {
        (try? fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup ?? false
    }
}
