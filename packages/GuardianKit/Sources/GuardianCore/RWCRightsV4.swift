import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC RIGHTS REVIEW AUTHORITY V2 + PRE-ACQUISITION AUTHORIZATION (R4; AUDIT17 remediation).
//
// Supersedes BY RECORD (not mutation) the V3 review surface, whose caller-forgeable
// RWCRightsReviewAuthorityV1.verify (A17-F1 pin) remains byte-frozen negative evidence and is
// SUPERSEDED_ENGINEERING_HISTORY — never a lawful real-world path.
//
// AUTHORITY MODEL (A17-F1):
//   REVIEW DATA (anyone may construct a request) is separated from REVIEW AUTHORITY (only an
//   AUTHORIZED REVIEWER can produce it). A verified grant V2 exists ONLY when:
//     1. an Ed25519 SIGNATURE over the canonical review payload verifies, AND
//     2. the signing reviewer is in the AUTHORIZED REVIEWER REGISTRY: ACTIVE, role-authorized,
//        within validity window, not revoked, with the exact registered public key, AND
//     3. the signed payload binds EXACTLY the grant identity, evidence digest, rights holder,
//        SOURCE AUTHORIZATION (A17-F10), allowed/prohibited uses, dates and decision APPROVED.
//   A caller-authored "APPROVED" string without a valid authorized signature can NEVER mint.
//   LEGAL VOCABULARY (carried §46): this proves "an authorized reviewer, per the governed review
//   process, approved this specific grant/evidence/scope record" — never abstract legal validity.
//   KEY LAW: private keys are NEVER stored in the repo/app; tests use explicitly synthetic
//   in-memory keys; the production registry starts EMPTY (fail-closed) until real operational
//   reviewer onboarding.
//
// SOURCE BINDING (A17-F10): the signed payload carries RWCSourceAuthorizationV1 —
//   EXACT_SOURCE (one opaque sourceReference) or SOURCE_MANIFEST (digest of a canonical
//   authorized-source list; membership verified). A grant can never cover a caller-chosen source.
//
// PRE-ACQUISITION AUTHORIZATION (A17-F2/F5/F8):
//   RWCPreAcquisitionAuthorizationV1 is a PROOF TYPE (fileprivate init) minted only by
//   RWCPreAcquisitionEvaluatorV1 after ALL pre-fetch checks pass: corpus-entry proof is the
//   caller's type-gate; verified signed grant; grant effective/non-expired at the single
//   transaction date; eligible source class; source bound to the grant's source authorization;
//   INTENDED USE declared and allowed (empty allowedUse authorizes nothing); owner/asset/session
//   grammar; provenance preconditions. NO content hash exists yet — the hash is computed AFTER
//   authorized quarantine acquisition (hash-after-fetch law; optional trusted checksum only).
//   The proof binds the EXACT request (no TOCTOU substitution).
//
// SESSION LAW (A17-F6): RWCAcquisitionSessionIDV1 grammar rwc-acq-[a-z0-9]{16,64} — no path
//   characters representable; duplicate sessions are refused at reservation (runner V2).
// SINGLE TRANSACTION DATE (A17-F9): the evaluator binds ONE transactionDate; every later stage
//   (rights commit, receipt, logs) must use it; the clock is never consulted twice.
// ZERO-DATA: synthetic fixtures only; no real reviewer, no real grant, no real media.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

public enum RWCRightsAuthorityErrorV2: Error, Equatable, Sendable {
    case malformedReviewerID
    case unknownReviewer
    case reviewerNotActive(status: String)
    case reviewerRoleUnauthorized
    case reviewerOutsideValidity
    case malformedPublicKey
    case signatureInvalid
    case payloadFieldMismatch(field: String)
    case decisionNotApproved
    case reviewDateOutsideReviewerValidity
    case malformedSourceAuthorization
    case sourceNotAuthorized
    case intendedUseNotAllowed(use: String)
    case allowedUseEmpty
    case malformedSessionID
    case grantNotEffective
    case grantExpired
    case ineligibleSourceClass(RWCSourceClassV1)
    case recordPreconditionFailed(reason: String)
}

// MARK: - Source authorization (A17-F10)

public enum RWCSourceAuthorizationV1: Equatable, Sendable {
    /// One-asset/one-source grant: the EXACT opaque sourceReference is reviewed.
    case exactSource(String)
    /// Multi-asset license: digest of the canonical authorized-source manifest
    /// (SHA-256 over sorted LP-encoded opaque source references).
    case sourceManifest(digest: String)

    public static func manifestDigest(ofSources sources: [String]) -> String {
        var data = Data()
        for s in sources.sorted() {
            let bytes = Data(s.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { data.append(contentsOf: $0) }
            data.append(bytes)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    var canonicalDescriptor: String {
        switch self {
        case .exactSource(let s): return "EXACT_SOURCE:" + s
        case .sourceManifest(let d): return "SOURCE_MANIFEST:" + d
        }
    }

    /// Membership law: requested source must be covered by the reviewed authorization.
    public func covers(sourceReference: String, manifestSources: [String]?) -> Bool {
        switch self {
        case .exactSource(let s):
            return s == sourceReference
        case .sourceManifest(let digest):
            guard let sources = manifestSources,
                  RWCSourceAuthorizationV1.manifestDigest(ofSources: sources) == digest else { return false }
            return sources.contains(sourceReference)
        }
    }
}

// MARK: - Authorized reviewer registry (A17-F1)

public struct RWCAuthorizedReviewerV1: Equatable, Sendable {
    public enum Status: String, Sendable { case active = "ACTIVE", revoked = "REVOKED", suspended = "SUSPENDED" }
    public let reviewerID: String          // rwc-reviewer-[a-z0-9-]{4,64}, >=1 alphanumeric
    public let publicKeyRawHex: String     // Ed25519 raw representation, lowercase hex (64 hex chars)
    public let status: Status
    public let role: String                // must equal "RIGHTS_REVIEW" for grant approval
    public let scope: String               // e.g. "rwc-corpus"
    public let validFrom: RWCDateV3
    public let validUntil: RWCDateV3?
    public init(reviewerID: String, publicKeyRawHex: String, status: Status, role: String,
                scope: String, validFrom: RWCDateV3, validUntil: RWCDateV3?) {
        self.reviewerID = reviewerID; self.publicKeyRawHex = publicKeyRawHex; self.status = status
        self.role = role; self.scope = scope; self.validFrom = validFrom; self.validUntil = validUntil
    }
}

/// Registry of PUBLIC keys only. Production starts EMPTY (fail-closed) until real operational
/// onboarding; tests enroll synthetic keys explicitly.
public struct RWCAuthorizedReviewerRegistryV1: Sendable {
    public static let requiredRole = "RIGHTS_REVIEW"
    private var reviewers: [String: RWCAuthorizedReviewerV1] = [:]
    public init() {}
    public mutating func enroll(_ r: RWCAuthorizedReviewerV1) { reviewers[r.reviewerID] = r }
    public func reviewer(_ id: String) -> RWCAuthorizedReviewerV1? { reviewers[id] }
    public var count: Int { reviewers.count }
}

// MARK: - Signed review (A17-F1): canonical payload + Ed25519 signature

public struct RWCSignedRightsReviewV1: Sendable {
    public static let schemaVersion = "rwc-signed-rights-review-v1"

    public let reviewRecordID: String
    public let reviewerID: String
    public let grantID: String
    public let grantRevision: Int
    public let evidenceDigest: String
    public let rightsHolder: String
    public let sourceAuthorization: RWCSourceAuthorizationV1
    public let allowedUse: [String]
    public let prohibitedUse: [String]
    public let effectiveDate: RWCDateV3
    public let expiryDate: RWCDateV3?
    public let decision: String
    public let reviewDate: RWCDateV3
    public let signatureHex: String        // Ed25519 over canonicalPayloadBytes

    public init(reviewRecordID: String, reviewerID: String, grantID: String, grantRevision: Int,
                evidenceDigest: String, rightsHolder: String,
                sourceAuthorization: RWCSourceAuthorizationV1, allowedUse: [String],
                prohibitedUse: [String], effectiveDate: RWCDateV3, expiryDate: RWCDateV3?,
                decision: String, reviewDate: RWCDateV3, signatureHex: String) {
        self.reviewRecordID = reviewRecordID; self.reviewerID = reviewerID; self.grantID = grantID
        self.grantRevision = grantRevision; self.evidenceDigest = evidenceDigest
        self.rightsHolder = rightsHolder; self.sourceAuthorization = sourceAuthorization
        self.allowedUse = allowedUse; self.prohibitedUse = prohibitedUse
        self.effectiveDate = effectiveDate; self.expiryDate = expiryDate
        self.decision = decision; self.reviewDate = reviewDate; self.signatureHex = signatureHex
    }

    /// Deterministic canonical encoding (length-prefixed; list order preserved as reviewed).
    public var canonicalPayloadBytes: Data {
        var out = Data()
        func lp(_ s: String) {
            let bytes = Data(s.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        lp(Self.schemaVersion)
        lp(reviewRecordID); lp(reviewerID); lp(grantID); lp(String(grantRevision))
        lp(evidenceDigest); lp(rightsHolder); lp(sourceAuthorization.canonicalDescriptor)
        var countA = UInt32(allowedUse.count).bigEndian
        withUnsafeBytes(of: &countA) { out.append(contentsOf: $0) }
        for u in allowedUse { lp(u) }
        var countP = UInt32(prohibitedUse.count).bigEndian
        withUnsafeBytes(of: &countP) { out.append(contentsOf: $0) }
        for u in prohibitedUse { lp(u) }
        lp(effectiveDate.isoString); lp(expiryDate?.isoString ?? "NONE")
        lp(decision); lp(reviewDate.isoString)
        return out
    }
}

/// UNFORGEABLE verified grant V2 — fileprivate init; the ONLY mint path is
/// RWCRightsReviewAuthorityV2.verify (signature + registry authority).
public struct RWCVerifiedRightsGrantV2: Sendable {
    public let grant: RWCLegalGrantIdentityV1
    public let reviewRecordID: String
    public let reviewerID: String
    public let sourceAuthorization: RWCSourceAuthorizationV1
    fileprivate init(grant: RWCLegalGrantIdentityV1, reviewRecordID: String, reviewerID: String,
                     sourceAuthorization: RWCSourceAuthorizationV1) {
        self.grant = grant; self.reviewRecordID = reviewRecordID; self.reviewerID = reviewerID
        self.sourceAuthorization = sourceAuthorization
    }
}

public enum RWCRightsReviewAuthorityV2 {
    public static let version = "rwc-rights-review-authority-v2"

    static func isHex(_ s: String, length: Int) -> Bool {
        s.count == length && s.utf8.allSatisfy { ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66) }
    }

    static func hexToData(_ s: String) -> Data? {
        guard s.count % 2 == 0 else { return nil }
        var data = Data(capacity: s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let next = s.index(idx, offsetBy: 2)
            guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
            data.append(b)
            idx = next
        }
        return data
    }

    /// THE authority boundary. Caller-authored APPROVED without an authorized signature: REFUSED.
    public static func verify(signedReview r: RWCSignedRightsReviewV1,
                              grant: RWCLegalGrantIdentityV1,
                              registry: RWCAuthorizedReviewerRegistryV1) throws -> RWCVerifiedRightsGrantV2 {
        try RWCRightsReviewAuthorityV1.validateGrant(grant)   // structural grammar reuse (CLEAN law)
        guard RWCRightsReviewAuthorityV1.isToken(r.reviewerID, prefix: "rwc-reviewer-") else {
            throw RWCRightsAuthorityErrorV2.malformedReviewerID
        }
        // 1. reviewer AUTHORITY (registry law)
        guard let reviewer = registry.reviewer(r.reviewerID) else {
            throw RWCRightsAuthorityErrorV2.unknownReviewer
        }
        guard reviewer.status == .active else {
            throw RWCRightsAuthorityErrorV2.reviewerNotActive(status: reviewer.status.rawValue)
        }
        guard reviewer.role == RWCAuthorizedReviewerRegistryV1.requiredRole else {
            throw RWCRightsAuthorityErrorV2.reviewerRoleUnauthorized
        }
        guard r.reviewDate >= reviewer.validFrom,
              reviewer.validUntil.map({ r.reviewDate <= $0 }) ?? true else {
            throw RWCRightsAuthorityErrorV2.reviewDateOutsideReviewerValidity
        }
        // 2. SIGNATURE over the canonical payload with the REGISTERED key
        guard isHex(reviewer.publicKeyRawHex, length: 64),
              let keyData = hexToData(reviewer.publicKeyRawHex),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw RWCRightsAuthorityErrorV2.malformedPublicKey
        }
        guard let signature = hexToData(r.signatureHex), signature.count == 64,
              publicKey.isValidSignature(signature, for: r.canonicalPayloadBytes) else {
            throw RWCRightsAuthorityErrorV2.signatureInvalid
        }
        // 3. payload binds EXACTLY this grant
        guard r.decision == "APPROVED" else { throw RWCRightsAuthorityErrorV2.decisionNotApproved }
        for (field, a, b) in [("grantID", r.grantID, grant.grantID),
                              ("evidenceDigest", r.evidenceDigest, grant.evidenceDigest),
                              ("rightsHolder", r.rightsHolder, grant.rightsHolder),
                              ("reviewRecordID", r.reviewRecordID, grant.reviewRecordID),
                              ("effectiveDate", r.effectiveDate.isoString, grant.effectiveDate.isoString),
                              ("expiryDate", r.expiryDate?.isoString ?? "NONE",
                               grant.expiryDate?.isoString ?? "NONE")] where a != b {
            throw RWCRightsAuthorityErrorV2.payloadFieldMismatch(field: field)
        }
        guard r.grantRevision == grant.grantRevision else {
            throw RWCRightsAuthorityErrorV2.payloadFieldMismatch(field: "grantRevision")
        }
        guard r.allowedUse == grant.allowedUse, r.prohibitedUse == grant.prohibitedUse else {
            throw RWCRightsAuthorityErrorV2.payloadFieldMismatch(field: "use lists")
        }
        return RWCVerifiedRightsGrantV2(grant: grant, reviewRecordID: r.reviewRecordID,
                                        reviewerID: r.reviewerID,
                                        sourceAuthorization: r.sourceAuthorization)
    }
}

// MARK: - Session ID law (A17-F6)

public enum RWCAcquisitionSessionIDV1 {
    /// rwc-acq-[a-z0-9]{16,64} — no path separators, dots, whitespace or unicode representable.
    public static func validate(_ s: String) throws {
        guard s.hasPrefix("rwc-acq-") else { throw RWCRightsAuthorityErrorV2.malformedSessionID }
        let t = s.dropFirst("rwc-acq-".count)
        guard (16...64).contains(t.count),
              t.utf8.allSatisfy({ ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) }) else {
            throw RWCRightsAuthorityErrorV2.malformedSessionID
        }
    }
}

// MARK: - Pre-acquisition authorization (A17-F2/F5/F8/F9)

/// The acquisition REQUEST — facts knowable BEFORE any raw media exists. NO content hash.
public struct RWCAcquisitionRequestV1: Sendable {
    public let assetID: String
    public let sourceClass: RWCSourceClassV1
    public let sourceReference: String
    public let owner: String
    public let intendedUse: RWCUseV1
    public let sessionID: String
    /// Only for SOURCE_MANIFEST grants: the canonical authorized source list whose digest the
    /// signed review binds (membership is verified against the digest — not trusted free-form).
    public let manifestSources: [String]?
    /// OPTIONAL trusted source-supplied checksum (lowercase hex SHA-256). Its absence NEVER forces
    /// a pre-download; canonical identity is the hash of the quarantined bytes actually acquired.
    public let trustedExpectedChecksum: String?
    public init(assetID: String, sourceClass: RWCSourceClassV1, sourceReference: String,
                owner: String, intendedUse: RWCUseV1, sessionID: String,
                manifestSources: [String]? = nil, trustedExpectedChecksum: String? = nil) {
        self.assetID = assetID; self.sourceClass = sourceClass; self.sourceReference = sourceReference
        self.owner = owner; self.intendedUse = intendedUse; self.sessionID = sessionID
        self.manifestSources = manifestSources; self.trustedExpectedChecksum = trustedExpectedChecksum
    }
}

/// UNFORGEABLE pre-acquisition proof — fileprivate init; minted ONLY by the evaluator after ALL
/// pre-fetch checks. Binds the EXACT request facts + the single transaction date (no TOCTOU).
public struct RWCPreAcquisitionAuthorizationV1: Sendable {
    public let assetID: String
    public let sourceReference: String
    public let intendedUse: RWCUseV1
    public let sessionID: String
    public let grantID: String
    public let grantRevision: Int
    public let reviewRecordID: String
    public let reviewerID: String
    public let owner: String
    public let sourceClass: RWCSourceClassV1
    public let transactionDate: RWCDateV3
    public let trustedExpectedChecksum: String?
    fileprivate init(request: RWCAcquisitionRequestV1, grant: RWCVerifiedRightsGrantV2,
                     transactionDate: RWCDateV3) {
        self.assetID = request.assetID; self.sourceReference = request.sourceReference
        self.intendedUse = request.intendedUse; self.sessionID = request.sessionID
        self.grantID = grant.grant.grantID; self.grantRevision = grant.grant.grantRevision
        self.reviewRecordID = grant.reviewRecordID; self.reviewerID = grant.reviewerID
        self.owner = request.owner; self.sourceClass = request.sourceClass
        self.transactionDate = transactionDate
        self.trustedExpectedChecksum = request.trustedExpectedChecksum
    }
}

public enum RWCPreAcquisitionEvaluatorV1 {
    public static let version = "rwc-preacquisition-evaluator-v1"

    /// ALL pre-fetch checks (R4 mandate §20). Single transaction date is bound HERE (A17-F9).
    /// The caller's corpus-entry proof is enforced by the RUNNER's type signature (global gate);
    /// this evaluator owns every per-request law. Any failure means NO byte may move.
    public static func authorize(request: RWCAcquisitionRequestV1,
                                 verifiedGrant: RWCVerifiedRightsGrantV2,
                                 transactionDate: RWCDateV3) throws -> RWCPreAcquisitionAuthorizationV1 {
        let g = verifiedGrant.grant
        // asset identity
        if let e = RWCAssetIdentityV1.validateAssetID(request.assetID) {
            throw RWCRightsErrorV3.invalidAssetID("\(e)")
        }
        // session grammar (A17-F6)
        try RWCAcquisitionSessionIDV1.validate(request.sessionID)
        // source class eligibility (A17-F2)
        guard request.sourceClass.eligible else {
            throw RWCRightsAuthorityErrorV2.ineligibleSourceClass(request.sourceClass)
        }
        // source reference grammar + grant SOURCE BINDING (A17-F2/F10)
        guard RWCRightsReviewAuthorityV1.isToken(request.sourceReference, prefix: "rwc-source-ref-") else {
            throw RWCRightsErrorV3.invalidPointer(field: "sourceReference")
        }
        guard verifiedGrant.sourceAuthorization.covers(sourceReference: request.sourceReference,
                                                       manifestSources: request.manifestSources) else {
            throw RWCRightsAuthorityErrorV2.sourceNotAuthorized
        }
        // INTENDED USE law (A17-F5): declared, allowed, not prohibited; empty allowedUse = nothing.
        guard !g.allowedUse.isEmpty else { throw RWCRightsAuthorityErrorV2.allowedUseEmpty }
        let useToken = request.intendedUse == .training ? "training" : "evaluation"
        guard g.allowedUse.contains(useToken), !g.prohibitedUse.contains(useToken) else {
            throw RWCRightsAuthorityErrorV2.intendedUseNotAllowed(use: useToken)
        }
        // grant temporal validity at the SINGLE transaction date (A17-F2/F9)
        guard transactionDate >= g.effectiveDate else { throw RWCRightsAuthorityErrorV2.grantNotEffective }
        if let exp = g.expiryDate, transactionDate > exp { throw RWCRightsAuthorityErrorV2.grantExpired }
        // owner / provenance preconditions
        guard !request.owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RWCRightsAuthorityErrorV2.recordPreconditionFailed(reason: "owner")
        }
        if let checksum = request.trustedExpectedChecksum {
            guard RWCRightsReviewAuthorityV1.isLowercaseHex64(checksum) else {
                throw RWCRightsAuthorityErrorV2.recordPreconditionFailed(reason: "trustedExpectedChecksum")
            }
        }
        return RWCPreAcquisitionAuthorizationV1(request: request, grant: verifiedGrant,
                                                transactionDate: transactionDate)
    }
}
