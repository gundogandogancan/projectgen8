import XCTest
import Foundation
import CryptoKit
@testable import GuardianCore
#if os(macOS)
import RWCAcquisition
#endif

// ═══════════════════════════════════════════════════════════════════════════════════════════════
// AUDIT18_RWC_PRE14_R4_REAUDIT — part 2 of 4: rights review authority V2 adversarial battery
// (reviewer registry root of trust, scope, revocation/validity matrix, signature
// canonicalization, replay, source authorization, pre-acquisition evaluator laws).
// Probes pinning defective behavior are marked "AUDIT18 FINDING <id>: pins defective behavior".
// All keys are synthetic in-memory fixtures; no real reviewer identity exists or is created.
// ═══════════════════════════════════════════════════════════════════════════════════════════════

#if os(macOS)

final class AUDIT18_RightsAuthorityProbes: XCTestCase {

    private func expectAuth(_ expected: RWCRightsAuthorityErrorV2, _ body: () throws -> Void,
                            _ label: String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), label, file: file, line: line) { e in
            XCTAssertEqual(e as? RWCRightsAuthorityErrorV2, expected, label, file: file, line: line)
        }
    }

    // MARK: §5/§6 AUDIT18 FINDING A18-F1 — self-enrolled caller registry mints real authority

    func test_A18_10_FINDING_A18F1_SelfEnrolledRegistry_MintsVerifiedGrant() throws {
        // AUDIT18 FINDING A18-F1: pins defective behavior.
        // There is NO authoritative reviewer-registry root of trust. An ORDINARY CALLER:
        //   1. generates its own Ed25519 key pair,
        //   2. constructs its own RWCAuthorizedReviewerV1 (ACTIVE / RIGHTS_REVIEW / rwc-corpus),
        //   3. enrolls itself into a caller-created RWCAuthorizedReviewerRegistryV1 (public init
        //      + public enroll),
        //   4. signs an arbitrary APPROVED review,
        //   5. calls RWCRightsReviewAuthorityV2.verify(...) passing its OWN registry —
        // and receives a minted RWCVerifiedRightsGrantV2. The attacker became their own
        // root-of-trust/CA; rights review authority is still caller-forgeable end to end.
        let attackerKey = Curve25519.Signing.PrivateKey()                       // 1
        let selfReviewer = A18.reviewer(id: "rwc-reviewer-a18evil01", key: attackerKey)   // 2+3
        let ownRegistry = A18.registry([selfReviewer])                          // 3
        let g = A18.grant(id: "rwc-grant-a18evil01", digestSeed: "a18-evil",
                          review: "rwc-review-a18evil01")
        let review = try A18.signedReview(for: g, source: A18.exactSource,
                                          reviewerID: "rwc-reviewer-a18evil01",
                                          key: attackerKey)                     // 4
        let minted = try RWCRightsReviewAuthorityV2.verify(signedReview: review, grant: g,
                                                           registry: ownRegistry)   // 5
        XCTAssertEqual(minted.reviewerID, "rwc-reviewer-a18evil01",
                       "A18-F1: a self-enrolled caller registry minted RWCVerifiedRightsGrantV2")
        XCTAssertEqual(minted.grant.grantID, g.grantID)
        // the same forged authority flows into a minted PRE-ACQUISITION proof too
        let preauth = try RWCPreAcquisitionEvaluatorV1.authorize(
            request: A18.request(), verifiedGrant: minted, transactionDate: A18.d("2026-10-01"))
        XCTAssertEqual(preauth.reviewerID, "rwc-reviewer-a18evil01",
                       "A18-F1: forged review authority reaches the pre-acquisition proof")
    }

    // MARK: §7 AUDIT18 FINDING A18-F1 (evidence) — enroll() silently replaces an existing reviewer

    func test_A18_11_FINDING_A18F1_Enroll_Overwrites_Key_Role_Status_Validity() throws {
        // AUDIT18 FINDING A18-F1: pins defective behavior (registry replacement semantics).
        // enroll(_:) is a plain dictionary assignment: the SAME reviewer ID can be re-enrolled
        // with a different key / role / status / validity window — no independently authorized
        // key-rotation event exists anywhere in the surface.
        let keyA = Curve25519.Signing.PrivateKey()
        let keyB = Curve25519.Signing.PrivateKey()
        var reg = RWCAuthorizedReviewerRegistryV1()
        reg.enroll(A18.reviewer(id: "rwc-reviewer-a18rot01", key: keyA, status: .revoked,
                                role: "OTHER_ROLE", validFrom: "2026-06-01", validUntil: "2026-07-01"))
        // attacker replaces key+role+status+validity in one unauthorized call
        reg.enroll(A18.reviewer(id: "rwc-reviewer-a18rot01", key: keyB, status: .active,
                                role: "RIGHTS_REVIEW", validFrom: "2026-01-01",
                                validUntil: "2027-12-31"))
        XCTAssertEqual(reg.count, 1, "same ID: entry replaced, not rejected")
        XCTAssertEqual(reg.reviewer("rwc-reviewer-a18rot01")?.publicKeyRawHex,
                       A18.hex(keyB.publicKey.rawRepresentation),
                       "A18-F1: key substitution without any rotation authority")
        let g = A18.grant(id: "rwc-grant-a18rot001", digestSeed: "a18-rot",
                          review: "rwc-review-a18rot01")
        let review = try A18.signedReview(for: g, source: A18.exactSource,
                                          reviewerID: "rwc-reviewer-a18rot01", key: keyB)
        XCTAssertNoThrow(try RWCRightsReviewAuthorityV2.verify(signedReview: review, grant: g,
                                                               registry: reg),
                         "A18-F1: replaced key B mints; original revoked identity A is erased")
        // key A no longer verifies (its history is silently gone)
        let reviewA = try A18.signedReview(for: g, source: A18.exactSource,
                                           reviewerID: "rwc-reviewer-a18rot01", key: keyA)
        expectAuth(.signatureInvalid, {
            _ = try RWCRightsReviewAuthorityV2.verify(signedReview: reviewA, grant: g, registry: reg)
        }, "old key refused after silent replacement")
    }

    // MARK: §8 AUDIT18 FINDING A18-F2 — reviewer.scope is NEVER checked by verify()

    func test_A18_12_FINDING_A18F2_WrongScope_Reviewer_Mints() throws {
        // AUDIT18 FINDING A18-F2: pins defective behavior.
        // RWCAuthorizedReviewerV1 declares `scope` as a registry security field (e.g. rwc-corpus),
        // and the R4 change ledger claims a "wrong-scope" refusal was matrix-tested — but
        // RWCRightsReviewAuthorityV2.verify checks ONLY status/role/validity/key: a reviewer
        // scoped to a DIFFERENT program mints an RWC grant.
        let key = Curve25519.Signing.PrivateKey()
        let foreignScope = A18.reviewer(id: "rwc-reviewer-a18scope1", key: key,
                                        scope: "some-other-program")
        let reg = A18.registry([foreignScope])
        let g = A18.grant(id: "rwc-grant-a18scp001", digestSeed: "a18-scp",
                          review: "rwc-review-a18scp01")
        let review = try A18.signedReview(for: g, source: A18.exactSource,
                                          reviewerID: "rwc-reviewer-a18scope1", key: key)
        let minted = try RWCRightsReviewAuthorityV2.verify(signedReview: review, grant: g,
                                                           registry: reg)
        XCTAssertEqual(minted.reviewerID, "rwc-reviewer-a18scope1",
                       "A18-F2: scope 'some-other-program' reviewer minted an rwc-corpus grant")
    }

    // MARK: §9 reviewer validity / revocation matrix (all must refuse)

    func test_A18_13_Reviewer_Validity_Revocation_Matrix() throws {
        let key = Curve25519.Signing.PrivateKey()
        let otherKey = Curve25519.Signing.PrivateKey()
        let g = A18.grant()
        let id = "rwc-reviewer-a18rev01"
        func verify(_ reg: RWCAuthorizedReviewerRegistryV1,
                    review: RWCSignedRightsReviewV1? = nil) throws {
            _ = try RWCRightsReviewAuthorityV2.verify(
                signedReview: review ?? A18.signedReview(for: g, source: A18.exactSource, key: key),
                grant: g, registry: reg)
        }
        // unknown reviewer (empty registry — production fail-closed state)
        expectAuth(.unknownReviewer, { try verify(RWCAuthorizedReviewerRegistryV1()) },
                   "empty registry refuses")
        // revoked
        expectAuth(.reviewerNotActive(status: "REVOKED"), {
            try verify(A18.registry([A18.reviewer(id: id, key: key, status: .revoked)]))
        }, "revoked reviewer")
        // suspended
        expectAuth(.reviewerNotActive(status: "SUSPENDED"), {
            try verify(A18.registry([A18.reviewer(id: id, key: key, status: .suspended)]))
        }, "suspended reviewer")
        // review date BEFORE validFrom
        expectAuth(.reviewDateOutsideReviewerValidity, {
            try verify(A18.registry([A18.reviewer(id: id, key: key, validFrom: "2026-09-01")]))
        }, "before validFrom (reviewDate 2026-08-15)")
        // review date AFTER validUntil
        expectAuth(.reviewDateOutsideReviewerValidity, {
            try verify(A18.registry([A18.reviewer(id: id, key: key, validFrom: "2026-01-01",
                                                  validUntil: "2026-08-01")]))
        }, "after validUntil")
        // wrong role
        expectAuth(.reviewerRoleUnauthorized, {
            try verify(A18.registry([A18.reviewer(id: id, key: key, role: "ANNOTATION")]))
        }, "wrong role")
        // wrong public key registered (signature by the real key no longer matches)
        expectAuth(.signatureInvalid, {
            try verify(A18.registry([A18.reviewer(id: id, key: otherKey)]))
        }, "wrong registered key")
        // malformed public keys: wrong length, uppercase hex, non-hex
        for bad in [String(repeating: "ab", count: 31),
                    String(repeating: "AB", count: 32),
                    String(repeating: "zz", count: 32)] {
            expectAuth(.malformedPublicKey, {
                try verify(A18.registry([A18.reviewer(id: id, key: key, pubHexOverride: bad)]))
            }, "malformed key \(bad.prefix(8))")
        }
        // malformed reviewer ID grammar
        expectAuth(.malformedReviewerID, {
            let review = try A18.signedReview(for: g, source: A18.exactSource,
                                              reviewerID: "evil", key: key)
            _ = try RWCRightsReviewAuthorityV2.verify(signedReview: review, grant: g,
                                                      registry: A18.registry([A18.reviewer(key: key)]))
        }, "malformed reviewer ID")
        // decision != APPROVED (signed REJECTED cannot mint)
        expectAuth(.decisionNotApproved, {
            let review = try A18.signedReview(for: g, source: A18.exactSource,
                                              decision: "REJECTED", key: key)
            _ = try RWCRightsReviewAuthorityV2.verify(signedReview: review, grant: g,
                                                      registry: A18.registry([A18.reviewer(key: key)]))
        }, "signed REJECTED refused")
        // lawful mint sanity (synthetic)
        XCTAssertNoThrow(try verify(A18.registry([A18.reviewer(id: id, key: key)])))
    }

    // MARK: §10 signed-review canonicalization — any semantic mutation invalidates the signature

    func test_A18_14_Signature_Canonicalization_MutationBattery() throws {
        let key = Curve25519.Signing.PrivateKey()
        let g = A18.grant()
        let reg = A18.registry([A18.reviewer(key: key)])
        let signed = try A18.signedReview(for: g, source: A18.exactSource, key: key)
        XCTAssertNoThrow(try RWCRightsReviewAuthorityV2.verify(signedReview: signed, grant: g,
                                                               registry: reg))
        func mutated(reviewRecordID: String? = nil, grantID: String? = nil, rev: Int? = nil,
                     evidence: String? = nil, holder: String? = nil,
                     source: RWCSourceAuthorizationV1? = nil, allowed: [String]? = nil,
                     prohibited: [String]? = nil, effective: RWCDateV3? = nil,
                     expiry: RWCDateV3?? = nil, decision: String? = nil,
                     reviewDate: RWCDateV3? = nil) -> RWCSignedRightsReviewV1 {
            RWCSignedRightsReviewV1(
                reviewRecordID: reviewRecordID ?? signed.reviewRecordID,
                reviewerID: signed.reviewerID,
                grantID: grantID ?? signed.grantID,
                grantRevision: rev ?? signed.grantRevision,
                evidenceDigest: evidence ?? signed.evidenceDigest,
                rightsHolder: holder ?? signed.rightsHolder,
                sourceAuthorization: source ?? signed.sourceAuthorization,
                allowedUse: allowed ?? signed.allowedUse,
                prohibitedUse: prohibited ?? signed.prohibitedUse,
                effectiveDate: effective ?? signed.effectiveDate,
                expiryDate: expiry ?? signed.expiryDate,
                decision: decision ?? signed.decision,
                reviewDate: reviewDate ?? signed.reviewDate,
                signatureHex: signed.signatureHex)   // OLD signature kept — replay of stale bytes
        }
        let attacks: [(String, RWCSignedRightsReviewV1)] = [
            ("grantID", mutated(grantID: "rwc-grant-a18other01")),
            ("grantRevision", mutated(rev: 2)),
            ("evidenceDigest", mutated(evidence: A18.shaHex("other-evidence"))),
            ("rightsHolder", mutated(holder: "licensor-evil")),
            ("sourceAuthorization", mutated(source: .exactSource("rwc-source-ref-a18evil1"))),
            ("allowedUse reorder", mutated(allowed: ["evaluation", "training"])),
            ("allowedUse broaden", mutated(allowed: ["training", "evaluation", "training2"])),
            ("prohibitedUse drop", mutated(prohibited: ["training"])),
            ("effectiveDate", mutated(effective: A18.d("2025-01-01"))),
            ("expiryDate", mutated(expiry: .some(A18.d("2099-12-31")))),
            ("decision case", mutated(decision: "approved")),
            ("reviewDate", mutated(reviewDate: A18.d("2026-08-16"))),
            ("reviewRecordID", mutated(reviewRecordID: "rwc-review-a18other1")),
        ]
        for (label, r) in attacks {
            XCTAssertThrowsError(try RWCRightsReviewAuthorityV2.verify(signedReview: r, grant: g,
                                                                       registry: reg),
                                 "mutation must not verify: \(label)") { e in
                guard let err = e as? RWCRightsAuthorityErrorV2 else {
                    return XCTFail("\(label): non-typed \(e)")
                }
                switch err {
                case .signatureInvalid, .payloadFieldMismatch, .decisionNotApproved: break
                default: XCTFail("\(label): unexpected \(err)")
                }
            }
        }
        // signature bytes tampered directly
        var sig = signed.signatureHex
        sig = (sig.first == "0" ? "1" : "0") + sig.dropFirst()
        let tampered = RWCSignedRightsReviewV1(
            reviewRecordID: signed.reviewRecordID, reviewerID: signed.reviewerID,
            grantID: signed.grantID, grantRevision: signed.grantRevision,
            evidenceDigest: signed.evidenceDigest, rightsHolder: signed.rightsHolder,
            sourceAuthorization: signed.sourceAuthorization, allowedUse: signed.allowedUse,
            prohibitedUse: signed.prohibitedUse, effectiveDate: signed.effectiveDate,
            expiryDate: signed.expiryDate, decision: signed.decision,
            reviewDate: signed.reviewDate, signatureHex: sig)
        expectAuth(.signatureInvalid, {
            _ = try RWCRightsReviewAuthorityV2.verify(signedReview: tampered, grant: g, registry: reg)
        }, "tampered signature")
        // signed payload for grant A presented against grant B (field cross-binding)
        let gB = A18.grant(id: "rwc-grant-a18bbbb01", digestSeed: "a18-bbb",
                           review: "rwc-review-a18bbb01")
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV2.verify(signedReview: signed, grant: gB,
                                                                   registry: reg)) { e in
            guard let err = e as? RWCRightsAuthorityErrorV2,
                  case .payloadFieldMismatch = err else { return XCTFail("\(e)") }
        }
    }

    // MARK: §11 replay — CURRENT registry/grant state governs later verification

    func test_A18_15_Replay_CurrentState_Matrix() throws {
        let key = Curve25519.Signing.PrivateKey()
        let g = A18.grant()
        let signed = try A18.signedReview(for: g, source: A18.exactSource, key: key)
        // valid today
        let active = A18.registry([A18.reviewer(key: key)])
        let minted = try RWCRightsReviewAuthorityV2.verify(signedReview: signed, grant: g,
                                                           registry: active)
        // replay AFTER reviewer revocation: refused when the CURRENT registry is consulted
        let revoked = A18.registry([A18.reviewer(key: key, status: .revoked)])
        expectAuth(.reviewerNotActive(status: "REVOKED"), {
            _ = try RWCRightsReviewAuthorityV2.verify(signedReview: signed, grant: g,
                                                      registry: revoked)
        }, "replay after reviewer revocation")
        // replay for a LATER grant revision: refused (payload binds revision 1)
        let g2 = A18.grant(rev: 2)
        XCTAssertThrowsError(try RWCRightsReviewAuthorityV2.verify(signedReview: signed, grant: g2,
                                                                   registry: active))
        // replay after grant EXPIRY at the acquisition boundary: evaluator refuses
        expectAuth(.grantExpired, {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(), verifiedGrant: minted,
                transactionDate: A18.d("2027-09-01"))   // past 2027-08-01 expiry
        }, "expired grant at transaction date")
        // replay before effectiveness: refused
        expectAuth(.grantNotEffective, {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(), verifiedGrant: minted,
                transactionDate: A18.d("2026-07-01"))
        }, "not-yet-effective grant")
        // NOTE (A18-F1 dependency, recorded): freshness is only as strong as the registry the
        // CALLER chooses to pass — there is no authoritative registry instance to consult.
    }

    // MARK: §12/§13 source authorization — exact + manifest + duplicate law

    func test_A18_16_SourceAuthorization_Exact_Manifest_Duplicates() throws {
        let key = Curve25519.Signing.PrivateKey()
        let reg = A18.registry([A18.reviewer(key: key)])
        // EXACT_SOURCE: covers only the reviewed reference
        let gE = A18.grant()
        let mintedE = try RWCRightsReviewAuthorityV2.verify(
            signedReview: try A18.signedReview(for: gE, source: A18.exactSource, key: key),
            grant: gE, registry: reg)
        expectAuth(.sourceNotAuthorized, {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(source: "rwc-source-ref-a18wrong1"),
                verifiedGrant: mintedE, transactionDate: A18.d("2026-10-01"))
        }, "wrong exact source")
        // SOURCE_MANIFEST: digest-bound membership
        let s1 = "rwc-source-ref-a18s0001", s2 = "rwc-source-ref-a18s0002"
        let digest = RWCSourceAuthorizationV1.manifestDigest(ofSources: [s1, s2])
        let gM = A18.grant(id: "rwc-grant-a18man001", digestSeed: "a18-man",
                           review: "rwc-review-a18man01")
        let mintedM = try RWCRightsReviewAuthorityV2.verify(
            signedReview: try A18.signedReview(for: gM, source: .sourceManifest(digest: digest),
                                               key: key),
            grant: gM, registry: reg)
        func attempt(_ sources: [String]?, _ source: String = "rwc-source-ref-a18s0001") throws {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(source: source, manifestSources: sources),
                verifiedGrant: mintedM, transactionDate: A18.d("2026-10-01"))
        }
        XCTAssertNoThrow(try attempt([s1, s2]), "lawful member")
        XCTAssertNoThrow(try attempt([s2, s1]), "reorder canonicalized (sorted digest)")
        expectAuth(.sourceNotAuthorized, { try attempt(nil) }, "missing manifest list")
        expectAuth(.sourceNotAuthorized, { try attempt([s1]) }, "removed source changes digest")
        expectAuth(.sourceNotAuthorized, { try attempt([s1, s2, "rwc-source-ref-a18s0003"]) },
                   "extra source changes digest")
        expectAuth(.sourceNotAuthorized, { try attempt([s1, s1, s2]) },
                   "duplicated entry changes digest (cannot smuggle membership)")
        expectAuth(.sourceNotAuthorized, { try attempt([s1, s2], "rwc-source-ref-a18s0003") },
                   "non-member source refused")
        // AUDIT18 FINDING A18-F10 (LOW): pins defective behavior — duplicates have NO explicit
        // law: a manifest signed over [s1, s1, s2] is a DIFFERENT canonical digest than [s1, s2]
        // yet mints normally and covers s1; canonicalization does not reject meaningless
        // duplicates, so two semantically identical reviewed lists have distinct identities.
        let dupDigest = RWCSourceAuthorizationV1.manifestDigest(ofSources: [s1, s1, s2])
        XCTAssertNotEqual(dupDigest, digest, "duplicate list yields a distinct digest")
        let gD = A18.grant(id: "rwc-grant-a18dup001", digestSeed: "a18-dup",
                           review: "rwc-review-a18dup01")
        let mintedD = try RWCRightsReviewAuthorityV2.verify(
            signedReview: try A18.signedReview(for: gD, source: .sourceManifest(digest: dupDigest),
                                               key: key),
            grant: gD, registry: reg)
        XCTAssertNoThrow(try RWCPreAcquisitionEvaluatorV1.authorize(
            request: A18.request(source: s1, manifestSources: [s1, s1, s2]),
            verifiedGrant: mintedD, transactionDate: A18.d("2026-10-01")),
            "A18-F10: duplicate-bearing manifest mints and covers membership")
    }

    // MARK: §14/§19 evaluator pre-fetch matrix + session grammar

    func test_A18_17_Evaluator_PreFetch_Use_Class_Session_Matrix() throws {
        let key = Curve25519.Signing.PrivateKey()
        let reg = A18.registry([A18.reviewer(key: key)])
        func minted(_ g: RWCLegalGrantIdentityV1) throws -> RWCVerifiedRightsGrantV2 {
            try RWCRightsReviewAuthorityV2.verify(
                signedReview: try A18.signedReview(for: g, source: A18.exactSource, key: key),
                grant: g, registry: reg)
        }
        let tx = A18.d("2026-10-01")
        // TRAINING request with EVALUATION-only grant
        let evalOnly = A18.grant(id: "rwc-grant-a18eval01", digestSeed: "a18-eval",
                                 allowed: ["evaluation"], review: "rwc-review-a18eval01")
        expectAuth(.intendedUseNotAllowed(use: "training"), {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(use: .training), verifiedGrant: try minted(evalOnly),
                transactionDate: tx)
        }, "training vs evaluation-only")
        // EVALUATION request with TRAINING-only grant
        let trainOnly = A18.grant(id: "rwc-grant-a18trn001", digestSeed: "a18-trn",
                                  allowed: ["training"], review: "rwc-review-a18trn01")
        expectAuth(.intendedUseNotAllowed(use: "evaluation"), {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(use: .evaluation), verifiedGrant: try minted(trainOnly),
                transactionDate: tx)
        }, "evaluation vs training-only")
        // empty allowedUse authorizes NOTHING
        let none = A18.grant(id: "rwc-grant-a18none01", digestSeed: "a18-none",
                             allowed: [], review: "rwc-review-a18none01")
        expectAuth(.allowedUseEmpty, {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(), verifiedGrant: try minted(none), transactionDate: tx)
        }, "empty allowedUse")
        // requested use not in allowedUse (evaluation grant, evaluation prohibited-elsewhere model):
        // a grant allowing only evaluation refuses a training request at the evaluator use-gate.
        let evalForProh = A18.grant(id: "rwc-grant-a18proh01", digestSeed: "a18-proh",
                                    allowed: ["evaluation"], prohibited: ["training"],
                                    review: "rwc-review-a18proh01")
        expectAuth(.intendedUseNotAllowed(use: "training"), {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(use: .training), verifiedGrant: try minted(evalForProh),
                transactionDate: tx)
        }, "prohibited/unlisted use refused at evaluator use-gate")
        // every refused source class
        let lawful = try minted(A18.grant())
        for cls in [RWCSourceClassV1.refusedScraped, .refusedPrivateCapture,
                    .refusedUserPrivate, .refusedUnknownLicense] {
            expectAuth(.ineligibleSourceClass(cls), {
                _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                    request: A18.request(sourceClass: cls), verifiedGrant: lawful,
                    transactionDate: tx)
            }, "refused class \(cls.rawValue)")
        }
        // invalid sourceReference grammar
        XCTAssertThrowsError(try RWCPreAcquisitionEvaluatorV1.authorize(
            request: A18.request(source: "https://evil.example"), verifiedGrant: lawful,
            transactionDate: tx), "raw URL source refused pre-fetch")
        // invalid asset ID
        XCTAssertThrowsError(try RWCPreAcquisitionEvaluatorV1.authorize(
            request: A18.request(assetID: "rwc-asset-BAD!"), verifiedGrant: lawful,
            transactionDate: tx), "invalid asset ID")
        // empty owner
        expectAuth(.recordPreconditionFailed(reason: "owner"), {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(owner: "   "), verifiedGrant: lawful, transactionDate: tx)
        }, "empty owner")
        // malformed trusted checksum
        expectAuth(.recordPreconditionFailed(reason: "trustedExpectedChecksum"), {
            _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                request: A18.request(checksum: "NOT-A-HASH"), verifiedGrant: lawful,
                transactionDate: tx)
        }, "malformed checksum")
        // session grammar battery (A17-F6 closure)
        for bad in ["rwc-acq-../../../escape", "rwc-acq-abc/def0123456789",
                    "rwc-acq-.", "rwc-acq-..", "rwc-acq-abc:def012345678",
                    "rwc-acq-ünïcode0123456789", "rwc-acq-abc\u{0007}def012345678",
                    "rwc-acq-short", "rwc-acq-" + String(repeating: "a", count: 65),
                    "rwc-acq-ABCDEF0123456789", "no-prefix-a18session01", ""] {
            expectAuth(.malformedSessionID, {
                _ = try RWCPreAcquisitionEvaluatorV1.authorize(
                    request: A18.request(session: bad), verifiedGrant: lawful, transactionDate: tx)
            }, "session grammar: \(bad.prefix(24))")
        }
        XCTAssertNoThrow(try RWCAcquisitionSessionIDV1.validate("rwc-acq-a18ok01234567890"),
                         "lawful session grammar (16-char token)")
    }

    // MARK: §16 pre-acquisition proof binds the EXACT request (no TOCTOU substitution)

    func test_A18_18_PreauthProof_ExactBinding_FieldCensus() throws {
        let key = Curve25519.Signing.PrivateKey()
        let reg = A18.registry([A18.reviewer(key: key)])
        let g = A18.grant()
        let minted = try RWCRightsReviewAuthorityV2.verify(
            signedReview: try A18.signedReview(for: g, source: A18.exactSource, key: key),
            grant: g, registry: reg)
        let checksum = A18.shaHex("a18-trusted")
        let req = A18.request(use: .evaluation, checksum: checksum)
        let proof = try RWCPreAcquisitionEvaluatorV1.authorize(request: req, verifiedGrant: minted,
                                                               transactionDate: A18.d("2026-10-02"))
        XCTAssertEqual(proof.assetID, req.assetID)
        XCTAssertEqual(proof.sourceReference, req.sourceReference)
        XCTAssertEqual(proof.intendedUse, .evaluation)
        XCTAssertEqual(proof.sessionID, req.sessionID)
        XCTAssertEqual(proof.grantID, g.grantID)
        XCTAssertEqual(proof.grantRevision, g.grantRevision)
        XCTAssertEqual(proof.reviewRecordID, g.reviewRecordID)
        XCTAssertEqual(proof.reviewerID, "rwc-reviewer-a18rev01")
        XCTAssertEqual(proof.owner, req.owner)
        XCTAssertEqual(proof.sourceClass, .licensedRightsClear)
        XCTAssertEqual(proof.transactionDate, A18.d("2026-10-02"))
        XCTAssertEqual(proof.trustedExpectedChecksum, checksum)
        // census: 12 bound fields; all lets; no mutable surface for substitution
        let labels = Mirror(reflecting: proof).children.compactMap(\.label)
        XCTAssertEqual(labels.count, 12, "proof binds exactly the 12 declared facts")
    }
}

#endif
