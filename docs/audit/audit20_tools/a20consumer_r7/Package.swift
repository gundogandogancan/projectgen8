// swift-tools-version:5.9
// AUDIT20 → R7 ORDINARY-CONSUMER PROOF (A20-F1 / A20-F2). A SEPARATE SwiftPM package that imports
// GuardianCore and RWCAcquisition as an ORDINARY external consumer — NO @testable — to prove
// structurally that such a consumer cannot:
//   • reach the sealed legacy V1/V3 mint/register/reconcile surfaces (now `package`),
//   • reach the scalar authorizeAcquisition writer on store V4 (now `package`),
//   • construct an RWCAcquisitionAuthorityTokenV1 (its init is `package`),
//   • mint a verified production trust root (carried A19-F2 closure).
//
// USAGE (run by the MAIN SESSION or AUDIT21, not by the sandboxed builder):
//   cd docs/audit/audit20_tools/a20consumer_r7
//   `swift build`  with the negative-proof lines COMMENTED → SUCCEEDS; the positive runtime check
//   (a20consumer_r7_core) prints the fail-closed line.
//   Uncomment ANY negative-proof line → `swift build` MUST FAIL (the symbol does not resolve for an
//   ordinary consumer). That compile failure IS the A20-F1/F2 seal evidence.
import PackageDescription

let package = Package(
    name: "a20consumer_r7",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Relative path from docs/audit/audit20_tools/a20consumer_r7 to packages/GuardianKit.
        .package(path: "../../../../packages/GuardianKit")
    ],
    targets: [
        .executableTarget(
            name: "a20consumer_r7_core",
            dependencies: [.product(name: "GuardianCore", package: "GuardianKit")]
        ),
        .executableTarget(
            name: "a20consumer_r7_acq",
            dependencies: [
                .product(name: "GuardianCore", package: "GuardianKit")
            ]
        )
    ]
)
