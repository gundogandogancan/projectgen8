// AUDIT20 → R7 ORDINARY-CONSUMER PROOF (A20-F1 / A20-F2) — ordinary `import` (NO @testable).
// Proves an external SwiftPM consumer of the GuardianCore PRODUCT cannot reach the sealed R7 surfaces.
import Foundation
import GuardianCore

// POSITIVE STRUCTURAL PROOF (carried A19-F2): the only public production trust-root entry fails closed.
let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
do {
    _ = try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: repoRoot)
    fatalError("A19-F2 REGRESSION: ordinary consumer obtained a production trust root")
} catch {
    print("R7 ORDINARY CONSUMER: production trust root UNREACHABLE (loadProduction fail-closed)")
}
print("R7 ORDINARY CONSUMER: legacy V1/V3 mint/register + scalar authorize + authority token are UNREACHABLE (package-sealed)")

// NEGATIVE PROOFS (kept COMMENTED — uncommenting ANY line MUST fail `swift build` for an ordinary
// consumer, because each symbol is now `package`/`internal`/`fileprivate`, invisible outside the
// GuardianKit package). These are the A20-F1 / A20-F2 seal evidence.
//
// A20-F2 — legacy signature-free root self-mint (RWCRightsV5.swift):
//   _ = try RWCReviewerTrustRootLoaderV1.mint(fromJSON: Data())                 // `package` → unresolved
//   _ = try RWCReviewerTrustRootLoaderV1.loadProduction(repoRoot: repoRoot)     // `package` → unresolved
//   _ = try RWCReviewerRegistryVerifierV1.verify(document: someDoc,             // `package` → unresolved
//                                                 trustRoot: someRoot, previousVerified: nil)
//
// A20-F2 — legacy no-crypto V1 grant mint + V3 register (RWCRightsV3.swift):
//   _ = try RWCRightsReviewAuthorityV1.verify(grant: someGrant,                 // `package` → unresolved
//                                             reviewRecord: someReview)
//   try someStoreV3.register(someRecord, verifiedGrant: someV1Grant,            // `package` → unresolved
//                            clock: someClock)
//
// A20-F1 — scalar PRE-14-PASS bypass writer (RWCRightsV6Store.swift):
//   _ = try someStoreV4.authorizeAcquisition(sessionID: "s", assetID: "a",      // `package` → unresolved
//            contentHash: "…", intendedUse: .training, sourceReference: "…",
//            verifiedGrant: someV6Grant, candidateCommit: "deadbeef",
//            auditResultBlobSHA256: "ffff…", clock: someClock)
//
// A20-F1 — the authority token an external caller would need to drive the SEALED R7 write cannot be
// constructed (its init is `package`):
//   _ = RWCAcquisitionAuthorityTokenV1(candidateCommit: "…", /* … */)           // `package` init → unresolved
//
// With every line above commented, `swift build` SUCCEEDS and this executable prints the fail-closed
// lines. Uncomment any one → the build FAILS. The seal is structural, not a comment.
