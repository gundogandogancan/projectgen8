// AUDIT19 R6 ORDINARY-CONSUMER PROOF (A19-F2) — ordinary `import` (NO @testable).
import Foundation
import GuardianCore

// POSITIVE STRUCTURAL PROOF: the only public production entry fails closed; there is no public mint.
let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
do {
    _ = try RWCReviewerTrustRootLoaderV2.loadProduction(repoRoot: repoRoot)
    fatalError("A19-F2 REGRESSION: ordinary consumer obtained a production trust root")
} catch let e as RWCReviewerTrustErrorV2 where e == .noOperationalRoot {
    print("A19-F2 ORDINARY CONSUMER: production trust root UNREACHABLE (loadProduction → .noOperationalRoot)")
} catch {
    print("A19-F2 ORDINARY CONSUMER: production trust root UNREACHABLE (threw \(error))")
}

// NEGATIVE PROOFS (kept commented — uncommenting MUST fail to compile for an ordinary consumer):
//
//   // 1. No public mint surface exists on the R6 loader:
//   _ = try RWCReviewerTrustRootLoaderV2.mint(fromJSON: Data())            // 'mint' is internal
//   // 2. The synthetic factory is internal:
//   _ = RWCReviewerTrustRootLoaderV2.makeSyntheticTestRoot()               // internal → unresolved
//   // 3. The onboarding capability cannot be constructed:
//   _ = RWCReviewerRootOnboardingCapabilityV1(onboardingRecordID: "x")     // init is internal
//
// The verified-root type RWCVerifiedReviewerTrustRootV2 has a fileprivate init, so an ordinary
// consumer cannot fabricate one directly either. A19-F2 is closed structurally, not by comment.
