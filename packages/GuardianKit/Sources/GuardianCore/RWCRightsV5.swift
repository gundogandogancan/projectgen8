import Foundation
import CryptoKit

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// RWC RIGHTS REVIEW TRUST-ROOT ARCHITECTURE V3 (R5; AUDIT18 remediation).
//
// Supersedes BY RECORD (not mutation) the V2 review surface in RWCRightsV4.swift, whose
// caller-SUPPLIED reviewer registry (A18-F1 pin) and unenforced reviewer.scope (A18-F2 pin) remain
// byte-frozen SUPERSEDED_ENGINEERING_HISTORY — never a lawful real-world path in R5.
//
// SECURITY PRINCIPLE (A18-F1 root cause): SIGNATURE AUTHENTICITY ≠ TRUST AUTHORITY. V4 proved that
// a review was signed by SOME key in SOME registry the caller handed in — but the caller could
// mint its own registry and enroll its own key, so "an authorized reviewer approved this" collapsed
// to "the caller approved this". R5 installs a GOVERNED CHAIN OF TRUST that the caller cannot forge
// at any link:
//
//   GOVERNED ROOT  →  ROOT-SIGNED REGISTRY DOCUMENT  →  REVIEWER  →  SIGNED REVIEW  →  VERIFIED
//   GRANT V3  →  PRE-ACQUISITION AUTHORIZATION V2  →  RUNNER V3.
//
//   • The ROOT is an Ed25519 public key with a governance record (rwc-root-*). Its ONLY production
//     instance lives at docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json — which does NOT exist in
//     R5; RWCReviewerTrustRootLoaderV1.loadProduction FAILS CLOSED with .noOperationalRoot. Private
//     key material is NEVER committed. Tests use an EXPLICITLY SYNTHETIC in-memory factory.
//   • A reviewer REGISTRY is an immutable DOCUMENT SIGNED BY THE ROOT (not a caller mutable dict).
//     The only way to obtain an RWCVerifiedReviewerRegistryV1 is through the verifier, which checks
//     the ROOT signature over canonical length-prefixed bytes, monotone revision + rollback binding
//     to the previous document digest, per-entry grammar, and refuses duplicate reviewer IDs.
//   • A VERIFIED GRANT V3 exists ONLY when the signed review verifies against a reviewer looked up
//     in the VERIFIED registry (never a caller dict) AND that reviewer's scope == .corpus (A18-F2).
//
// The verified-registry and verified-grant-V3 types have fileprivate inits: possession is proof.
// There is deliberately NO enroll/mutate API on the verified registry (A18-F1: no silent identity
// overwrite; rotation is a NEW signed document, historically visible).
//
// SOURCE MANIFEST CANONICALITY (A18-F10): RWCSourceManifestLawV2 THROWS on duplicate/empty/invalid
// source lists so a caller cannot smuggle an empty or degenerate manifest past membership.
//
// ZERO-DATA: synthetic fixtures only; no production root, no real reviewer, no real grant/media.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

// MARK: - Trust-root typed errors (R5)

public enum RWCReviewerTrustErrorV1: Error, Equatable, Sendable {
    case noOperationalRoot                       // production root file absent — FAIL CLOSED
    case rootMalformed(String)
    case rootNotActive(status: String)
    case malformedRootID
    case malformedRootKey
    // registry document
    case registryMalformed(String)
    case registryRootMismatch
    case registryVersionUnsupported
    case registrySignatureInvalid
    case registryRevisionNotMonotonic(expected: Int, found: Int)
    case registryPreviousDigestMismatch
    case malformedReviewerID
    case malformedReviewerKey
    case duplicateReviewerInDocument(reviewerID: String)
    case malformedReviewerScope(String)
    case malformedReviewerStatus(String)
}

public enum RWCRightsAuthorityErrorV3: Error, Equatable, Sendable {
    case reviewerNotInVerifiedRegistry
    case reviewerNotActive(status: String)
    case reviewerRoleUnauthorized
    case reviewerScopeUnauthorized(scope: String)   // A18-F2
    case reviewerOutsideValidity
    case malformedPublicKey
    case signatureInvalid
    case payloadFieldMismatch(field: String)
    case decisionNotApproved
    case malformedReviewerID
}

// MARK: - Reviewer scope (A18-F2)

/// The security domain a reviewer is authorized to act in. Only `.corpus` may approve a corpus
/// rights grant; any other scope is a typed refusal in RWCRightsReviewAuthorityV3.verify.
public enum RWCReviewerScopeV1: String, Equatable, Sendable, CaseIterable {
    case corpus = "rwc-corpus"
    case annotation = "rwc-annotation"
    case governance = "rwc-governance"
}

// MARK: - Governed reviewer trust root (A18-F1, §12-§13)

/// The governed ROOT of reviewer trust. PUBLIC key only; the private key is NEVER in the repo/app.
/// rootID grammar: rwc-root-[a-z0-9-]{4,64} (>=1 alphanumeric). Ed25519 only.
public struct RWCReviewerTrustRootV1: Equatable, Sendable {
    public enum Status: String, Sendable, Equatable { case active = "ACTIVE", retired = "RETIRED" }
    public static let algorithm = "ed25519"
    /// The ONLY canonical production instance path. In R5 this file MUST NOT EXIST (fail closed).
    public static let canonicalInstancePath = "docs/operations/rwc/RWC_REVIEWER_TRUST_ROOT.json"

    public let rootID: String
    public let publicKeyRawHex: String      // Ed25519 raw representation, lowercase hex (64 chars)
    public let algorithm: String            // must equal "ed25519"
    public let activationDate: RWCDateV3
    public let status: Status
    public let governanceRecordID: String

    public init(rootID: String, publicKeyRawHex: String, algorithm: String,
                activationDate: RWCDateV3, status: Status, governanceRecordID: String) {
        self.rootID = rootID; self.publicKeyRawHex = publicKeyRawHex; self.algorithm = algorithm
        self.activationDate = activationDate; self.status = status
        self.governanceRecordID = governanceRecordID
    }
}

/// UNFORGEABLE verified trust root — fileprivate init. Minted ONLY by the production loader (a real
/// governed file, absent in R5) or by the clearly-named synthetic test factory. Possession proves
/// "this Ed25519 public key is the governed, ACTIVE reviewer trust root".
public struct RWCVerifiedReviewerTrustRootV1: Sendable {
    public let rootID: String
    public let publicKey: Curve25519.Signing.PublicKey
    public let publicKeyRawHex: String
    public let governanceRecordID: String
    fileprivate init(rootID: String, publicKey: Curve25519.Signing.PublicKey,
                     publicKeyRawHex: String, governanceRecordID: String) {
        self.rootID = rootID; self.publicKey = publicKey
        self.publicKeyRawHex = publicKeyRawHex; self.governanceRecordID = governanceRecordID
    }
}

enum RWCTrustHex {
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
            data.append(b); idx = next
        }
        return data
    }
}

public enum RWCReviewerTrustRootLoaderV1 {
    public static let version = "rwc-reviewer-trust-root-loader-v1"

    /// PRODUCTION loader: FAILS CLOSED. Reads the canonical governed file (JSON); in R5 the file is
    /// absent → .noOperationalRoot. No synthetic fallback exists on this path (that is the whole
    /// point of A18-F1): there is NO way to obtain a trust root in production until a governed
    /// onboarding artifact exists (RWC-REVIEWER-ROOT-ONBOARDING blocker).
    // R7 A20-F2: demoted `public → package` (lawful freeze supersession; declared in
    // docs/audit/AUDIT20_R7_INVERSION_LOCK.md). Sealed from external SwiftPM consumers; in-package
    // historical probes (AUDIT19/R5 tests) keep compiling (`package` is package-wide).
    package static func loadProduction(repoRoot: URL) throws -> RWCVerifiedReviewerTrustRootV1 {
        let url = repoRoot.appendingPathComponent(RWCReviewerTrustRootV1.canonicalInstancePath)
        guard let data = try? Data(contentsOf: url) else {
            throw RWCReviewerTrustErrorV1.noOperationalRoot
        }
        return try mint(fromJSON: data)
    }

    /// Mint a verified root from the canonical governed JSON bytes. Structural + ACTIVE + grammar
    /// + key-parse laws. Shared by the production loader and (indirectly) tests that write a file.
    package static func mint(fromJSON data: Data) throws -> RWCVerifiedReviewerTrustRootV1 {   // R7 A20-F2: public → package
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RWCReviewerTrustErrorV1.rootMalformed("not strict JSON")
        }
        func str(_ k: String) throws -> String {
            guard let v = o[k] as? String, !v.isEmpty else {
                throw RWCReviewerTrustErrorV1.rootMalformed("missing \(k)")
            }
            return v
        }
        let rootID = try str("root_id")
        let keyHex = try str("public_key_raw_hex")
        let algorithm = try str("algorithm")
        let governanceRecordID = try str("governance_record_id")
        let statusRaw = try str("status")
        _ = try RWCDateV3.parse(try str("activation_date"), field: "activation_date")
        guard RWCRightsReviewAuthorityV1.isToken(rootID, prefix: "rwc-root-") else {
            throw RWCReviewerTrustErrorV1.malformedRootID
        }
        guard algorithm == RWCReviewerTrustRootV1.algorithm else {
            throw RWCReviewerTrustErrorV1.rootMalformed("algorithm")
        }
        guard statusRaw == RWCReviewerTrustRootV1.Status.active.rawValue else {
            throw RWCReviewerTrustErrorV1.rootNotActive(status: statusRaw)
        }
        guard RWCTrustHex.isHex(keyHex, length: 64), let keyData = RWCTrustHex.hexToData(keyHex),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw RWCReviewerTrustErrorV1.malformedRootKey
        }
        return RWCVerifiedReviewerTrustRootV1(rootID: rootID, publicKey: pub,
                                              publicKeyRawHex: keyHex,
                                              governanceRecordID: governanceRecordID)
    }

    /// TEST-ONLY synthetic factory — ACCESS-CONTROLLED, not comment-controlled (Fable review gate,
    /// R5 §53/§84): `internal`, so ONLY @testable imports (the test target) can reach it; a normal
    /// production consumer of GuardianCore CANNOT mint a trust-root proof from thin air. It returns
    /// BOTH the verified-root proof AND its ephemeral private key (never persisted; no file side
    /// effect). The ONLY production mint path remains loadProduction (fail-closed).
    internal static func makeSyntheticTestRoot(
        rootID: String = "rwc-root-synthetic01",
        governanceRecordID: String = "rwc-gov-synthetic01",
        privateKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey()
    ) -> (root: RWCVerifiedReviewerTrustRootV1, privateKey: Curve25519.Signing.PrivateKey) {
        let keyHex = privateKey.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
        let root = RWCVerifiedReviewerTrustRootV1(rootID: rootID, publicKey: privateKey.publicKey,
                                                  publicKeyRawHex: keyHex,
                                                  governanceRecordID: governanceRecordID)
        return (root, privateKey)
    }
}

// MARK: - Root-signed immutable reviewer registry document (A18-F1, §14-§18)

/// One reviewer entry inside a signed registry document. scope carries RWCReviewerScopeV1 raw.
public struct RWCReviewerRegistryEntryV1: Equatable, Sendable {
    public let reviewerID: String          // rwc-reviewer-[a-z0-9-]{4,64}
    public let publicKeyRawHex: String     // Ed25519 raw, lowercase hex (64)
    public let status: String              // "ACTIVE" | "REVOKED" | "SUSPENDED"
    public let role: String                // "RIGHTS_REVIEW" for corpus grant approval
    public let scope: String               // RWCReviewerScopeV1 raw value
    public let validFrom: RWCDateV3
    public let validUntil: RWCDateV3?
    public let revision: Int               // this entry's revision within the reviewer's history

    public init(reviewerID: String, publicKeyRawHex: String, status: String, role: String,
                scope: String, validFrom: RWCDateV3, validUntil: RWCDateV3?, revision: Int) {
        self.reviewerID = reviewerID; self.publicKeyRawHex = publicKeyRawHex; self.status = status
        self.role = role; self.scope = scope; self.validFrom = validFrom
        self.validUntil = validUntil; self.revision = revision
    }
}

/// An IMMUTABLE reviewer registry DOCUMENT signed by the governed root. Canonical bytes are
/// LENGTH-PREFIXED (matching the RWCRightsV4 LP style): version, registryRevision, rootID,
/// createdAt, previousRegistryDigest, reviewerCount, then each entry field-by-field. The document
/// digest and the root signature are both over the PAYLOAD bytes (signature is NOT part of the
/// digest input — the digest identifies the payload a later document chains onto).
public struct RWCReviewerRegistryDocumentV2: Sendable {
    public static let schemaVersion = "rwc-reviewer-registry-document-v2"
    public static let requiredRole = "RIGHTS_REVIEW"
    /// The canonical previousRegistryDigest for the genesis document (revision 1).
    public static let genesisPreviousDigest =
        SHA256.hash(data: Data("GEN8-RWC-REVIEWER-REGISTRY-V2-GENESIS".utf8))
            .map { String(format: "%02x", $0) }.joined()

    public let registryVersion: String
    public let registryRevision: Int       // >= 1
    public let rootID: String
    public let createdAt: RWCDateV3
    public let previousRegistryDigest: String
    public let reviewers: [RWCReviewerRegistryEntryV1]
    public let signatureHex: String        // Ed25519 by the ROOT over canonicalPayloadBytes

    public init(registryVersion: String, registryRevision: Int, rootID: String, createdAt: RWCDateV3,
                previousRegistryDigest: String, reviewers: [RWCReviewerRegistryEntryV1],
                signatureHex: String) {
        self.registryVersion = registryVersion; self.registryRevision = registryRevision
        self.rootID = rootID; self.createdAt = createdAt
        self.previousRegistryDigest = previousRegistryDigest; self.reviewers = reviewers
        self.signatureHex = signatureHex
    }

    /// Deterministic canonical LP encoding of the signed PAYLOAD (everything but the signature).
    public var canonicalPayloadBytes: Data {
        var out = Data()
        func lp(_ s: String) {
            let bytes = Data(s.utf8)
            var len = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
            out.append(bytes)
        }
        func u32(_ n: Int) {
            var v = UInt32(n).bigEndian
            withUnsafeBytes(of: &v) { out.append(contentsOf: $0) }
        }
        lp(Self.schemaVersion)
        lp(String(registryRevision))
        lp(rootID)
        lp(createdAt.isoString)
        lp(previousRegistryDigest)
        u32(reviewers.count)
        for e in reviewers {
            lp(e.reviewerID); lp(e.publicKeyRawHex); lp(e.status); lp(e.role); lp(e.scope)
            lp(e.validFrom.isoString); lp(e.validUntil?.isoString ?? "NONE"); lp(String(e.revision))
        }
        return out
    }

    /// The document identity digest — SHA-256 over the payload bytes (what a later document chains
    /// onto via previousRegistryDigest). NOT a function of the signature.
    public var documentDigest: String {
        SHA256.hash(data: canonicalPayloadBytes).map { String(format: "%02x", $0) }.joined()
    }
}

/// UNFORGEABLE verified reviewer registry — fileprivate init; the ONLY mint path is
/// RWCReviewerRegistryVerifierV1.verify (root-signature + chain laws). Immutable reviewer lookup;
/// NO enroll/mutate API (A18-F1: rotation is a NEW signed document, not an in-place overwrite).
public struct RWCVerifiedReviewerRegistryV1: Sendable {
    public let rootID: String
    public let registryRevision: Int
    public let documentDigest: String
    private let reviewers: [String: RWCReviewerRegistryEntryV1]

    fileprivate init(rootID: String, registryRevision: Int, documentDigest: String,
                     reviewers: [String: RWCReviewerRegistryEntryV1]) {
        self.rootID = rootID; self.registryRevision = registryRevision
        self.documentDigest = documentDigest; self.reviewers = reviewers
    }

    public func reviewer(_ id: String) -> RWCReviewerRegistryEntryV1? { reviewers[id] }
    public var reviewerCount: Int { reviewers.count }
}

public enum RWCReviewerRegistryVerifierV1 {
    public static let version = "rwc-reviewer-registry-verifier-v1"

    /// THE registry authority boundary. A caller-authored dictionary can NEVER reach this type:
    /// the only input is a root-signed DOCUMENT and a VERIFIED trust root proof.
    ///
    /// Monotonic revision / rollback law (A18-F18): if `previousVerified` is supplied, the new
    /// document's revision must be exactly previous+1 and its previousRegistryDigest must equal the
    /// previous document's digest (prevents replaying an older, more-permissive registry).
    package static func verify(document d: RWCReviewerRegistryDocumentV2,   // R7 A20-F2: public → package
                               trustRoot: RWCVerifiedReviewerTrustRootV1,
                               previousVerified: RWCVerifiedReviewerRegistryV1? = nil)
        throws -> RWCVerifiedReviewerRegistryV1 {
        guard d.registryVersion == RWCReviewerRegistryDocumentV2.schemaVersion else {
            throw RWCReviewerTrustErrorV1.registryVersionUnsupported
        }
        guard d.rootID == trustRoot.rootID else { throw RWCReviewerTrustErrorV1.registryRootMismatch }
        guard d.registryRevision >= 1 else {
            throw RWCReviewerTrustErrorV1.registryMalformed("revision < 1")
        }
        // ROOT signature over the canonical payload (A18-F1: authority is the governed root).
        guard let sig = RWCTrustHex.hexToData(d.signatureHex), sig.count == 64,
              trustRoot.publicKey.isValidSignature(sig, for: d.canonicalPayloadBytes) else {
            throw RWCReviewerTrustErrorV1.registrySignatureInvalid
        }
        // chain / rollback law
        if let prev = previousVerified {
            guard d.registryRevision == prev.registryRevision + 1 else {
                throw RWCReviewerTrustErrorV1.registryRevisionNotMonotonic(
                    expected: prev.registryRevision + 1, found: d.registryRevision)
            }
            guard d.previousRegistryDigest == prev.documentDigest else {
                throw RWCReviewerTrustErrorV1.registryPreviousDigestMismatch
            }
        } else {
            // genesis document must carry the genesis constant for revision 1
            if d.registryRevision == 1 {
                guard d.previousRegistryDigest == RWCReviewerRegistryDocumentV2.genesisPreviousDigest else {
                    throw RWCReviewerTrustErrorV1.registryPreviousDigestMismatch
                }
            }
        }
        // per-entry grammar + duplicate-ID-within-document refusal (A18-F1: no silent overwrite)
        var lookup: [String: RWCReviewerRegistryEntryV1] = [:]
        for e in d.reviewers {
            guard RWCRightsReviewAuthorityV1.isToken(e.reviewerID, prefix: "rwc-reviewer-") else {
                throw RWCReviewerTrustErrorV1.malformedReviewerID
            }
            guard RWCTrustHex.isHex(e.publicKeyRawHex, length: 64),
                  RWCTrustHex.hexToData(e.publicKeyRawHex) != nil else {
                throw RWCReviewerTrustErrorV1.malformedReviewerKey
            }
            guard ["ACTIVE", "REVOKED", "SUSPENDED"].contains(e.status) else {
                throw RWCReviewerTrustErrorV1.malformedReviewerStatus(e.status)
            }
            guard RWCReviewerScopeV1(rawValue: e.scope) != nil else {
                throw RWCReviewerTrustErrorV1.malformedReviewerScope(e.scope)
            }
            guard e.revision >= 1 else {
                throw RWCReviewerTrustErrorV1.registryMalformed("entry revision < 1")
            }
            if let exp = e.validUntil {
                guard exp >= e.validFrom else {
                    throw RWCReviewerTrustErrorV1.registryMalformed("validUntil < validFrom")
                }
            }
            guard lookup[e.reviewerID] == nil else {
                throw RWCReviewerTrustErrorV1.duplicateReviewerInDocument(reviewerID: e.reviewerID)
            }
            lookup[e.reviewerID] = e
        }
        return RWCVerifiedReviewerRegistryV1(rootID: d.rootID, registryRevision: d.registryRevision,
                                             documentDigest: d.documentDigest, reviewers: lookup)
    }
}

// MARK: - Source manifest canonicality law V2 (A18-F10, §47-§48)

/// Supersedes the V1 digest helper for the AUTHORING path: duplicate, empty or
/// invalid-grammar source lists THROW rather than silently producing a degenerate digest. For a
/// valid, duplicate-free list the sorted LP encoding is IDENTICAL to RWCSourceAuthorizationV1's
/// manifestDigest, so historical valid digests are byte-stable.
public enum RWCSourceManifestLawV2 {
    public enum ErrorV1: Error, Equatable, Sendable {
        case emptyManifest
        case duplicateSourceReference(String)
        case invalidSourceReference(String)
    }

    public static func canonicalManifestDigest(sources: [String]) throws -> String {
        guard !sources.isEmpty else { throw ErrorV1.emptyManifest }
        var seen = Set<String>()
        for s in sources {
            guard RWCRightsReviewAuthorityV1.isToken(s, prefix: "rwc-source-ref-") else {
                throw ErrorV1.invalidSourceReference(s)
            }
            guard seen.insert(s).inserted else { throw ErrorV1.duplicateSourceReference(s) }
        }
        // identical sorted LP encoding to the V1 helper for valid inputs (byte-stable history).
        return RWCSourceAuthorizationV1.manifestDigest(ofSources: sources)
    }
}

// MARK: - Review authority V3 (A18-F1/F2): verified registry + scope enforcement

/// UNFORGEABLE verified grant V3 — fileprivate init; the ONLY mint path is
/// RWCRightsReviewAuthorityV3.verify (signature + VERIFIED-registry authority + scope == .corpus).
/// Carries the same bound fields as V2 (grant + reviewRecordID + reviewerID + sourceAuthorization).
public struct RWCVerifiedRightsGrantV3: Sendable {
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

public enum RWCRightsReviewAuthorityV3 {
    public static let version = "rwc-rights-review-authority-v3"

    /// THE V3 authority boundary. ALL V2 checks PLUS: the reviewer is looked up in the VERIFIED
    /// registry (a root-signed document proof — never a caller dict), and the reviewer's scope MUST
    /// be `.corpus` (A18-F2) or the mint is refused with reviewerScopeUnauthorized.
    public static func verify(signedReview r: RWCSignedRightsReviewV1,
                              grant: RWCLegalGrantIdentityV1,
                              verifiedRegistry: RWCVerifiedReviewerRegistryV1)
        throws -> RWCVerifiedRightsGrantV3 {
        try RWCRightsReviewAuthorityV1.validateGrant(grant)   // structural grammar reuse (CLEAN law)
        guard RWCRightsReviewAuthorityV1.isToken(r.reviewerID, prefix: "rwc-reviewer-") else {
            throw RWCRightsAuthorityErrorV3.malformedReviewerID
        }
        // 1. reviewer AUTHORITY looked up in the VERIFIED registry (A18-F1: NOT a caller dict).
        guard let reviewer = verifiedRegistry.reviewer(r.reviewerID) else {
            throw RWCRightsAuthorityErrorV3.reviewerNotInVerifiedRegistry
        }
        guard reviewer.status == "ACTIVE" else {
            throw RWCRightsAuthorityErrorV3.reviewerNotActive(status: reviewer.status)
        }
        guard reviewer.role == RWCReviewerRegistryDocumentV2.requiredRole else {
            throw RWCRightsAuthorityErrorV3.reviewerRoleUnauthorized
        }
        // A18-F2: the reviewer's governed SCOPE must authorize corpus rights review.
        guard reviewer.scope == RWCReviewerScopeV1.corpus.rawValue else {
            throw RWCRightsAuthorityErrorV3.reviewerScopeUnauthorized(scope: reviewer.scope)
        }
        guard r.reviewDate >= reviewer.validFrom,
              reviewer.validUntil.map({ r.reviewDate <= $0 }) ?? true else {
            throw RWCRightsAuthorityErrorV3.reviewerOutsideValidity
        }
        // 2. SIGNATURE over the canonical payload with the registered reviewer key.
        guard RWCTrustHex.isHex(reviewer.publicKeyRawHex, length: 64),
              let keyData = RWCTrustHex.hexToData(reviewer.publicKeyRawHex),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
            throw RWCRightsAuthorityErrorV3.malformedPublicKey
        }
        guard let signature = RWCTrustHex.hexToData(r.signatureHex), signature.count == 64,
              publicKey.isValidSignature(signature, for: r.canonicalPayloadBytes) else {
            throw RWCRightsAuthorityErrorV3.signatureInvalid
        }
        // 3. payload binds EXACTLY this grant (same field-law as V2).
        guard r.decision == "APPROVED" else { throw RWCRightsAuthorityErrorV3.decisionNotApproved }
        for (field, a, b) in [("grantID", r.grantID, grant.grantID),
                              ("evidenceDigest", r.evidenceDigest, grant.evidenceDigest),
                              ("rightsHolder", r.rightsHolder, grant.rightsHolder),
                              ("reviewRecordID", r.reviewRecordID, grant.reviewRecordID),
                              ("effectiveDate", r.effectiveDate.isoString, grant.effectiveDate.isoString),
                              ("expiryDate", r.expiryDate?.isoString ?? "NONE",
                               grant.expiryDate?.isoString ?? "NONE")] where a != b {
            throw RWCRightsAuthorityErrorV3.payloadFieldMismatch(field: field)
        }
        guard r.grantRevision == grant.grantRevision else {
            throw RWCRightsAuthorityErrorV3.payloadFieldMismatch(field: "grantRevision")
        }
        guard r.allowedUse == grant.allowedUse, r.prohibitedUse == grant.prohibitedUse else {
            throw RWCRightsAuthorityErrorV3.payloadFieldMismatch(field: "use lists")
        }
        return RWCVerifiedRightsGrantV3(grant: grant, reviewRecordID: r.reviewRecordID,
                                        reviewerID: r.reviewerID,
                                        sourceAuthorization: r.sourceAuthorization)
    }
}

// MARK: - Pre-acquisition authorization V2 (A18-F10; §47-§48)

/// UNFORGEABLE pre-acquisition proof V2 — fileprivate init; minted ONLY by
/// RWCPreAcquisitionEvaluatorV2 after ALL pre-fetch checks against a V3 grant. Same bound fields as
/// V1 (no TOCTOU substitution); the only behavioral delta is V3-grant input + the V2 manifest law.
public struct RWCPreAcquisitionAuthorizationV2: Sendable {
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
    fileprivate init(request: RWCAcquisitionRequestV1, grant: RWCVerifiedRightsGrantV3,
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

public enum RWCPreAcquisitionEvaluatorV2 {
    public static let version = "rwc-preacquisition-evaluator-v2"

    /// Same pre-fetch laws as V1 (copied from RWCRightsV4.swift) but takes a V3 grant and uses
    /// RWCSourceManifestLawV2 for SOURCE_MANIFEST membership — an empty/duplicate/invalid manifest
    /// becomes a TYPED refusal BEFORE any byte moves (A18-F10). The single transactionDate is bound
    /// here by the caller (runner consults the clock exactly once, stage 0).
    public static func authorize(request: RWCAcquisitionRequestV1,
                                 verifiedGrant: RWCVerifiedRightsGrantV3,
                                 transactionDate: RWCDateV3) throws -> RWCPreAcquisitionAuthorizationV2 {
        let g = verifiedGrant.grant
        // asset identity
        if let e = RWCAssetIdentityV1.validateAssetID(request.assetID) {
            throw RWCRightsErrorV3.invalidAssetID("\(e)")
        }
        // session grammar (A17-F6 carried)
        try RWCAcquisitionSessionIDV1.validate(request.sessionID)
        // source class eligibility (A17-F2 carried)
        guard request.sourceClass.eligible else {
            throw RWCRightsAuthorityErrorV2.ineligibleSourceClass(request.sourceClass)
        }
        // source reference grammar + grant SOURCE BINDING with V2 manifest canonicality (A18-F10).
        guard RWCRightsReviewAuthorityV1.isToken(request.sourceReference, prefix: "rwc-source-ref-") else {
            throw RWCRightsErrorV3.invalidPointer(field: "sourceReference")
        }
        guard try sourceCovered(verifiedGrant.sourceAuthorization, request: request) else {
            throw RWCRightsAuthorityErrorV2.sourceNotAuthorized
        }
        // INTENDED USE law (A17-F5 carried): declared, allowed, not prohibited; empty = nothing.
        guard !g.allowedUse.isEmpty else { throw RWCRightsAuthorityErrorV2.allowedUseEmpty }
        let useToken = request.intendedUse == .training ? "training" : "evaluation"
        guard g.allowedUse.contains(useToken), !g.prohibitedUse.contains(useToken) else {
            throw RWCRightsAuthorityErrorV2.intendedUseNotAllowed(use: useToken)
        }
        // grant temporal validity at the SINGLE transaction date (A17-F2/F9 carried)
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
        return RWCPreAcquisitionAuthorizationV2(request: request, grant: verifiedGrant,
                                                transactionDate: transactionDate)
    }

    /// Membership law under RWCSourceManifestLawV2: a SOURCE_MANIFEST grant requires a non-empty,
    /// duplicate-free, grammar-valid manifest whose canonical digest equals the signed digest AND
    /// contains the requested source. An exact-source grant is unchanged from V1.
    static func sourceCovered(_ authorization: RWCSourceAuthorizationV1,
                              request: RWCAcquisitionRequestV1) throws -> Bool {
        switch authorization {
        case .exactSource(let s):
            return s == request.sourceReference
        case .sourceManifest(let digest):
            guard let sources = request.manifestSources else { return false }
            // A18-F10: empty/duplicate/invalid manifest → typed refusal pre-fetch.
            let canonical = try RWCSourceManifestLawV2.canonicalManifestDigest(sources: sources)
            guard canonical == digest else { return false }
            return sources.contains(request.sourceReference)
        }
    }
}
