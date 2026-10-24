// AUDIT20 → R7 ORDINARY-CONSUMER PROOF — RWCAcquisition sealing.
//
// STRUCTURAL FACT (strongest form): RWCAcquisition is NOT a PRODUCT of the GuardianKit package (only
// GuardianCore, GuardianIntelligence, GuardianMedia are products — see packages/GuardianKit/Package.swift).
// Therefore an external SwiftPM consumer CANNOT import RWCAcquisition AT ALL — the legacy
// RWCCorpusAcquisitionRunnerV3.reconcileV3 backdoor and the RWCCorpusAcquisitionRunnerV5 coordinator are
// doubly sealed: (1) RWCAcquisition is not exported as a product, and (2) reconcileV3 is additionally
// demoted `public → package` so even a sibling in-package target that is not a test cannot name it
// outside the package.
//
// This executable therefore imports ONLY GuardianCore and documents the double seal. Uncommenting the
// import line MUST fail `swift build` ("no such module 'RWCAcquisition'") for an external consumer.
import Foundation
import GuardianCore

print("R7 ORDINARY CONSUMER (acq): RWCAcquisition is not a package product — the reconcileV3 backdoor and the RunnerV5 coordinator are UNREACHABLE to any external consumer")

// NEGATIVE PROOF (kept COMMENTED — uncommenting MUST fail `swift build`):
//   import RWCAcquisition        // ERROR: no such module 'RWCAcquisition' (not a product of GuardianKit)
//   let r = RWCCorpusAcquisitionRunnerV3(quarantineRoot: URL(fileURLWithPath: "/tmp"))
//   _ = try r.reconcileV3(rightsStore: s, corpusStore: c, receiptStore: rc)   // + `package` sealed
