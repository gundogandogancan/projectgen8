import Foundation

// MARK: - RWC-PRE-01 — ASSET RIGHTS LEDGER (governance only; ZERO assets acquired).
//
// LAW (frozen pre-acquisition):
//  - Eligible source classes are EXACTLY PROJECT_OWNED_REAL and LICENSED_RIGHTS_CLEAR. Everything else
//    (scraped, public-visibility-assumed, private-account captures, user-private content,
//    unknown-license media) is REFUSED/INELIGIBLE — "publicly visible == free to train" is forbidden logic.
//  - Eligibility is FAIL-CLOSED: any missing/unknown/invalid field makes the asset ineligible.
//  - Revocation: a revoked asset is INELIGIBLE for all future fitting/evaluation; derived artifacts
//    are governed by recorded derivative-rights terms; the audit trail (opaque IDs + hashes + decisions)
//    is retained, prohibited raw content is not.
//  - Lifecycle: acquire -> verify rights -> hash -> register -> eligibility -> split assignment (later)
//    -> use -> revoke/delete/expire.
//  - Privacy: diagnostics carry opaque asset IDs + reason codes ONLY; sourceReference/licenseEvidence
//    are opaque pointers to secure external storage, never raw paths/URLs with content semantics.

public enum RWCSourceClassV1: String, Sendable, Codable, CaseIterable {
    case projectOwnedReal = "PROJECT_OWNED_REAL"
    case licensedRightsClear = "LICENSED_RIGHTS_CLEAR"
    case refusedScraped = "REFUSED_SCRAPED"
    case refusedPrivateCapture = "REFUSED_PRIVATE_CAPTURE"
    case refusedUserPrivate = "REFUSED_USER_PRIVATE"
    case refusedUnknownLicense = "REFUSED_UNKNOWN_LICENSE"
    public var eligible: Bool { self == .projectOwnedReal || self == .licensedRightsClear }
}

public enum RWCRevocationStateV1: String, Sendable, Codable { case active = "ACTIVE", revoked = "REVOKED", expired = "EXPIRED" }

public struct RWCAssetRightsRecordV1: Sendable, Codable, Equatable {
    public let assetID: String                 // RWCAssetIdentityV1 grammar — opaque, non-semantic
    public let sourceClass: RWCSourceClassV1
    public let sourceReference: String         // opaque pointer (secure external storage), never content
    public let owner: String
    public let rightsHolder: String
    public let licenseType: String
    public let licenseEvidence: String         // opaque pointer to evidence; never a secret/credential
    public let allowedUse: [String]
    public let prohibitedUse: [String]
    public let trainingAllowed: Bool
    public let evaluationAllowed: Bool
    public let derivativeRights: String
    public let redistributionAllowed: Bool
    public let language: String
    public let contentType: String
    public let modality: String
    public let acquisitionDate: String         // ISO-8601; recorded at registration
    public let expiryDate: String?             // nil = no expiry
    public let revocationState: RWCRevocationStateV1
    public let revocationDate: String?
    public let contentHash: String             // SHA-256 hex, 64 chars
    public let provenanceChain: [String]       // opaque provenance step IDs
    public let consentBasis: String?           // where applicable
    public let jurisdictionNotes: String?
    public let notes: String?
    public init(assetID: String, sourceClass: RWCSourceClassV1, sourceReference: String, owner: String,
                rightsHolder: String, licenseType: String, licenseEvidence: String, allowedUse: [String],
                prohibitedUse: [String], trainingAllowed: Bool, evaluationAllowed: Bool, derivativeRights: String,
                redistributionAllowed: Bool, language: String, contentType: String, modality: String,
                acquisitionDate: String, expiryDate: String?, revocationState: RWCRevocationStateV1,
                revocationDate: String?, contentHash: String, provenanceChain: [String],
                consentBasis: String? = nil, jurisdictionNotes: String? = nil, notes: String? = nil) {
        self.assetID = assetID; self.sourceClass = sourceClass; self.sourceReference = sourceReference
        self.owner = owner; self.rightsHolder = rightsHolder; self.licenseType = licenseType
        self.licenseEvidence = licenseEvidence; self.allowedUse = allowedUse; self.prohibitedUse = prohibitedUse
        self.trainingAllowed = trainingAllowed; self.evaluationAllowed = evaluationAllowed
        self.derivativeRights = derivativeRights; self.redistributionAllowed = redistributionAllowed
        self.language = language; self.contentType = contentType; self.modality = modality
        self.acquisitionDate = acquisitionDate; self.expiryDate = expiryDate
        self.revocationState = revocationState; self.revocationDate = revocationDate
        self.contentHash = contentHash; self.provenanceChain = provenanceChain
        self.consentBasis = consentBasis; self.jurisdictionNotes = jurisdictionNotes; self.notes = notes
    }
}

public enum RWCRightsErrorV1: Error, Equatable {
    case invalidAssetID(RWCAssetIdentityErrorV1)
    case ineligibleSourceClass(RWCSourceClassV1)
    case missingLicenseEvidence
    case missingRightsHolder
    case revoked
    case expired
    case useNotAllowed(use: String)            // "training" | "evaluation"
    case invalidContentHash
    case emptyProvenance
    // ── PRE-14 R1 (A14-F1/F2/F3/F4) ──
    case missingOwner
    case malformedDate(field: String)                       // strict yyyy-MM-dd only
    case dateOrderViolation(rule: String)                   // expiry>=acquisition, revocation>=acquisition
    case useConsistencyViolation(reason: String)            // ONE authoritative use truth (A14-F2)
    case duplicateProvenance
    case invalidEvidencePointer(field: String)              // opaque-pointer grammar (store law)
    case acquisitionInFuture                                // asOf law (store)
    case assetUnknown
    case duplicateRegistration
    case resurrectionRefused                                // same assetID after revocation (A14-F4)
    case reauthorizationRequiresNewEvidence
}

/// R1 (A14-F2): the ONLY uses eligibility can ever answer for. Typed — unknown strings never map here.
public enum RWCUseV1: String, CaseIterable, Sendable { case training, evaluation }

public enum RWCAssetRightsLedgerV1 {
    public static let version = "rwc-asset-rights-ledger-v1"
    public static let eligibleSourceClasses: [RWCSourceClassV1] = [.projectOwnedReal, .licensedRightsClear]

    /// FAIL-CLOSED eligibility for a given use ("training"/"evaluation"). Throws the FIRST violation.
    public static func requireEligible(_ r: RWCAssetRightsRecordV1, use: String) throws {
        if let e = RWCAssetIdentityV1.validateAssetID(r.assetID) { throw RWCRightsErrorV1.invalidAssetID(e) }
        guard r.sourceClass.eligible else { throw RWCRightsErrorV1.ineligibleSourceClass(r.sourceClass) }
        guard !r.licenseEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RWCRightsErrorV1.missingLicenseEvidence }
        guard !r.rightsHolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RWCRightsErrorV1.missingRightsHolder }
        guard r.revocationState == .active else {
            throw r.revocationState == .revoked ? RWCRightsErrorV1.revoked : RWCRightsErrorV1.expired
        }
        switch use {
        case "training": guard r.trainingAllowed else { throw RWCRightsErrorV1.useNotAllowed(use: use) }
        case "evaluation": guard r.evaluationAllowed else { throw RWCRightsErrorV1.useNotAllowed(use: use) }
        default: throw RWCRightsErrorV1.useNotAllowed(use: use)   // unknown use NEVER passes (fail closed)
        }
        guard r.contentHash.count == 64, r.contentHash.allSatisfy({ $0.isHexDigit }) else {
            throw RWCRightsErrorV1.invalidContentHash
        }
        guard !r.provenanceChain.isEmpty else { throw RWCRightsErrorV1.emptyProvenance }
        // ── R1 appended laws (A14-F1/F2/F3) — record-internal, deterministic, no hidden clock ──
        guard !r.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RWCRightsErrorV1.missingOwner }
        guard isStrictISODate(r.acquisitionDate) else { throw RWCRightsErrorV1.malformedDate(field: "acquisitionDate") }
        if let e = r.expiryDate {
            guard isStrictISODate(e) else { throw RWCRightsErrorV1.malformedDate(field: "expiryDate") }
            // cross-field law (lexicographic compare is exact for zero-padded ISO dates)
            guard e >= r.acquisitionDate else { throw RWCRightsErrorV1.dateOrderViolation(rule: "expiry >= acquisition") }
        }
        if let rd = r.revocationDate {
            guard isStrictISODate(rd) else { throw RWCRightsErrorV1.malformedDate(field: "revocationDate") }
            guard rd >= r.acquisitionDate else { throw RWCRightsErrorV1.dateOrderViolation(rule: "revocation >= acquisition") }
        }
        try requireUseConsistency(r)
        // canonical hash law: lowercase hex ONLY — case-variant aliases of one digest are refused, never normalized
        guard r.contentHash.allSatisfy({ ("0"..."9").contains(String($0)) || ("a"..."f").contains(String($0)) }) else {
            throw RWCRightsErrorV1.invalidContentHash
        }
        guard Set(r.provenanceChain).count == r.provenanceChain.count else { throw RWCRightsErrorV1.duplicateProvenance }
    }

    /// R1 (A14-F1): strict `yyyy-MM-dd` — the ONLY accepted date shape (deterministic; no Date()/locale).
    static func isStrictISODate(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let m = Int(parts[1]), let d = Int(parts[2]), (1...12).contains(m), (1...31).contains(d)
        else { return false }
        return true
    }

    /// R1 (A14-F2): ONE authoritative use truth. For each known use: boolean TRUE requires membership in
    /// allowedUse AND absence from prohibitedUse (case-insensitively); boolean FALSE forbids allowedUse
    /// membership. allowedUse may contain ONLY known lowercase use tokens. prohibitedUse may carry other
    /// rights terms (e.g. "redistribution") but never a known use that a boolean grants. Contradictions
    /// are typed refusals — records are never silently repaired.
    static func requireUseConsistency(_ r: RWCAssetRightsRecordV1) throws {
        let known = Set(RWCUseV1.allCases.map(\.rawValue))
        for a in r.allowedUse where !known.contains(a) {
            throw RWCRightsErrorV1.useConsistencyViolation(reason: "allowedUse contains unknown use token")
        }
        let allowed = Set(r.allowedUse)
        let prohibitedLowered = Set(r.prohibitedUse.map { $0.lowercased() })
        for use in RWCUseV1.allCases {
            let granted = (use == .training) ? r.trainingAllowed : r.evaluationAllowed
            if granted {
                guard allowed.contains(use.rawValue) else {
                    throw RWCRightsErrorV1.useConsistencyViolation(reason: "\(use.rawValue) granted by flag but absent from allowedUse")
                }
                guard !prohibitedLowered.contains(use.rawValue) else {
                    throw RWCRightsErrorV1.useConsistencyViolation(reason: "\(use.rawValue) granted but present in prohibitedUse")
                }
            } else {
                guard !allowed.contains(use.rawValue) else {
                    throw RWCRightsErrorV1.useConsistencyViolation(reason: "\(use.rawValue) in allowedUse but flag is false")
                }
            }
        }
    }

    /// R1 (A14-F3): OPAQUE POINTER GRAMMAR (store law) — licenseEvidence must be `rwc-rights-ref-` +
    /// [a-z0-9-]{4,64}; sourceReference `rwc-source-ref-` + same token grammar. Raw URLs, filesystem
    /// paths and semantic titles are typed refusals; nothing is normalized.
    static func requireOpaquePointers(_ r: RWCAssetRightsRecordV1) throws {
        func token(_ s: String, prefix: String) -> Bool {
            guard s.hasPrefix(prefix) else { return false }
            let t = s.dropFirst(prefix.count)
            return (4...64).contains(t.count) && t.allSatisfy { ($0.isASCII && ($0.isLowercase || $0.isNumber)) || $0 == "-" }
        }
        guard token(r.licenseEvidence, prefix: "rwc-rights-ref-") else {
            throw RWCRightsErrorV1.invalidEvidencePointer(field: "licenseEvidence")
        }
        guard token(r.sourceReference, prefix: "rwc-source-ref-") else {
            throw RWCRightsErrorV1.invalidEvidencePointer(field: "sourceReference")
        }
    }

    /// Revocation law: revoke is monotone (no un-revoke path exists in this API — resurrection would
    /// require a new registration + new rights evidence, by design).
    public static func revoked(_ r: RWCAssetRightsRecordV1, onDate date: String) -> RWCAssetRightsRecordV1 {
        RWCAssetRightsRecordV1(assetID: r.assetID, sourceClass: r.sourceClass, sourceReference: r.sourceReference,
                               owner: r.owner, rightsHolder: r.rightsHolder, licenseType: r.licenseType,
                               licenseEvidence: r.licenseEvidence, allowedUse: r.allowedUse,
                               prohibitedUse: r.prohibitedUse, trainingAllowed: false, evaluationAllowed: false,
                               derivativeRights: r.derivativeRights, redistributionAllowed: false,
                               language: r.language, contentType: r.contentType, modality: r.modality,
                               acquisitionDate: r.acquisitionDate, expiryDate: r.expiryDate,
                               revocationState: .revoked, revocationDate: date, contentHash: r.contentHash,
                               provenanceChain: r.provenanceChain + ["revocation-recorded"],
                               consentBasis: r.consentBasis, jurisdictionNotes: r.jurisdictionNotes, notes: r.notes)
    }
}

// MARK: - R1 (A14-F4) — APPEND-ONLY RIGHTS LEDGER STORE: the CANONICAL eligibility authority.
//
// LAW: eligibility for use consults LEDGER STATE, never a caller-constructed ACTIVE value. The event
// log is append-only with a chained digest; revocation is a tombstone for that (assetID, evidence)
// pair FOREVER — re-registration with the same or any previously-seen evidence identity is
// resurrectionRefused. Legitimate relicensing exists ONLY as an explicit `reauthorize` event carrying
// a NEW evidence identity (auditable transition; nothing is silently cleared). asOf is injectable —
// no hidden Date() anywhere (deterministic tests). Zero real records exist (prereg zero-data law).

public final class RWCAssetRightsLedgerStoreV1 {
    public static let version = "rwc-rights-ledger-store-v1"
    public struct EventV1: Equatable, Sendable {
        public let seq: Int
        public let assetID: String
        public let kind: String          // registered | revoked | reauthorized
        public let evidenceID: String
        public let date: String
        public let chainDigest: String   // digest(prev.chainDigest + fields) — append-only witness
    }
    private var states: [String: RWCAssetRightsRecordV1] = [:]
    private var seenEvidence: [String: Set<String>] = [:]     // assetID -> every evidence identity ever
    private var tombstoned: Set<String> = []                  // assetIDs with a revocation tombstone
    public private(set) var events: [EventV1] = []
    public init() {}

    private func append(_ kind: String, _ assetID: String, _ evidenceID: String, _ date: String) {
        let prev = events.last?.chainDigest ?? "rwc-ledger-genesis"
        var hasher = Hasher()                                  // deterministic within a process run;
        hasher.combine(prev); hasher.combine(kind)             // the durable artifact law uses SHA-256
        hasher.combine(assetID); hasher.combine(evidenceID); hasher.combine(date)
        let digest = String(format: "%016x", UInt64(bitPattern: Int64(hasher.finalize())))
        events.append(EventV1(seq: events.count, assetID: assetID, kind: kind,
                              evidenceID: evidenceID, date: date, chainDigest: digest))
    }

    /// Register a NEW asset. Full record validation + opaque-pointer grammar + asOf laws.
    public func register(_ r: RWCAssetRightsRecordV1, asOf: String) throws {
        try RWCAssetRightsLedgerV1.requireEligible(r, use: "evaluation")   // record-shape laws (fail closed)
        try RWCAssetRightsLedgerV1.requireOpaquePointers(r)
        guard RWCAssetRightsLedgerV1.isStrictISODate(asOf) else { throw RWCRightsErrorV1.malformedDate(field: "asOf") }
        guard r.acquisitionDate <= asOf else { throw RWCRightsErrorV1.acquisitionInFuture }
        guard !tombstoned.contains(r.assetID) else { throw RWCRightsErrorV1.resurrectionRefused }
        guard states[r.assetID] == nil else { throw RWCRightsErrorV1.duplicateRegistration }
        guard !(seenEvidence[r.assetID]?.contains(r.licenseEvidence) ?? false) else {
            throw RWCRightsErrorV1.resurrectionRefused
        }
        states[r.assetID] = r
        seenEvidence[r.assetID, default: []].insert(r.licenseEvidence)
        append("registered", r.assetID, r.licenseEvidence, asOf)
    }

    /// Revoke: tombstone the asset. Monotone — there is no un-revoke.
    public func revoke(assetID: String, onDate date: String) throws {
        guard let current = states[assetID] else { throw RWCRightsErrorV1.assetUnknown }
        guard RWCAssetRightsLedgerV1.isStrictISODate(date) else { throw RWCRightsErrorV1.malformedDate(field: "revocationDate") }
        states[assetID] = RWCAssetRightsLedgerV1.revoked(current, onDate: date)
        tombstoned.insert(assetID)
        append("revoked", assetID, current.licenseEvidence, date)
    }

    /// Relicensing: ONLY lawful path after revocation — an explicit event with a NEW evidence identity.
    public func reauthorize(_ r: RWCAssetRightsRecordV1, asOf: String) throws {
        guard tombstoned.contains(r.assetID) else { throw RWCRightsErrorV1.assetUnknown }
        guard !(seenEvidence[r.assetID]?.contains(r.licenseEvidence) ?? false) else {
            throw RWCRightsErrorV1.reauthorizationRequiresNewEvidence
        }
        try RWCAssetRightsLedgerV1.requireEligible(r, use: "evaluation")
        try RWCAssetRightsLedgerV1.requireOpaquePointers(r)
        guard RWCAssetRightsLedgerV1.isStrictISODate(asOf), r.acquisitionDate <= asOf else {
            throw RWCRightsErrorV1.acquisitionInFuture
        }
        states[r.assetID] = r
        tombstoned.remove(r.assetID)                     // auditable transition, never a silent clear
        seenEvidence[r.assetID, default: []].insert(r.licenseEvidence)
        append("reauthorized", r.assetID, r.licenseEvidence, asOf)
    }

    /// CANONICAL eligibility: ledger state + asOf expiry law (valid THROUGH the expiry date).
    public func requireEligible(assetID: String, use: RWCUseV1, asOf: String) throws {
        guard RWCAssetRightsLedgerV1.isStrictISODate(asOf) else { throw RWCRightsErrorV1.malformedDate(field: "asOf") }
        guard let r = states[assetID] else { throw RWCRightsErrorV1.assetUnknown }
        try RWCAssetRightsLedgerV1.requireEligible(r, use: use.rawValue)
        guard r.acquisitionDate <= asOf else { throw RWCRightsErrorV1.acquisitionInFuture }
        if let e = r.expiryDate { guard asOf <= e else { throw RWCRightsErrorV1.expired } }
    }
}

// MARK: - R1 (A14-F15) — PROTECTIVE ANNOTATION LAW for RWC labels.
// The legacy engineering type (CalibrationAnnotationV1, .rounded() midpoint) is deliberately UNCHANGED
// (AUDIT pins + engineering metrics depend on it; engineering-scoped forever). RWC labels use THIS law:
// a disagreement that crosses the protection boundary ({0,1} vs {2,3,4}) can NEVER be resolved by
// arithmetic — it REQUIRES adjudication; same-class disagreements resolve to the MORE PROTECTIVE
// (lower) value. A/B originals are always preserved (third-layer law, PRE-07).
public enum RWCAnnotationLawV1 {
    public static let version = "rwc-annotation-law-v1"
    public enum ResolutionV1: Equatable, Sendable {
        case label(Int)
        case adjudicationRequired
    }
    public static func protectiveClass(_ label: Int) -> Int { label <= 1 ? 0 : 1 }
    public static func finalLabel(a: Int, b: Int, adjudicated: Int?) -> ResolutionV1 {
        if let adj = adjudicated { return .label(adj) }
        if a == b { return .label(a) }
        if protectiveClass(a) != protectiveClass(b) { return .adjudicationRequired }
        return .label(min(a, b))                              // more-protective value, deterministic
    }
}
