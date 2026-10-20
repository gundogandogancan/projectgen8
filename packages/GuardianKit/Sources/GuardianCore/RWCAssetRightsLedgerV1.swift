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
}

public enum RWCAssetRightsLedgerV1 {
    public static let version = "rwc-asset-rights-ledger-v1"
    public static let eligibleSourceClasses: [RWCSourceClassV1] = [.projectOwnedReal, .licensedRightsClear]

    /// FAIL-CLOSED eligibility for a given use ("training"/"evaluation"). Throws the FIRST violation.
    public static func requireEligible(_ r: RWCAssetRightsRecordV1, use: String) throws {
        if let e = RWCAssetIdentityV1.validateAssetID(r.assetID) { throw RWCRightsErrorV1.invalidAssetID(e) }
        guard r.sourceClass.eligible else { throw RWCRightsErrorV1.ineligibleSourceClass(r.sourceClass) }
        guard !r.licenseEvidence.trimmingCharacters(in: .whitespaces).isEmpty else { throw RWCRightsErrorV1.missingLicenseEvidence }
        guard !r.rightsHolder.trimmingCharacters(in: .whitespaces).isEmpty else { throw RWCRightsErrorV1.missingRightsHolder }
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
