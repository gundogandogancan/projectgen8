// swift-tools-version:5.9
// AUDIT19 R6 ORDINARY-CONSUMER PROOF (A19-F2). A SEPARATE SwiftPM package that imports GuardianCore
// as an ORDINARY external consumer — NO @testable — to prove structurally that such a consumer:
//   • cannot mint a verified production reviewer trust root (RWCReviewerTrustRootLoaderV2 exposes NO
//     public mint; loadProduction fails closed with .noOperationalRoot),
//   • cannot reach the internal synthetic factory makeSyntheticTestRoot (internal → not visible),
//   • cannot construct the onboarding capability (internal init).
//
// USAGE (run by the MAIN SESSION or AUDIT20, not by the sandboxed builder):
//   cd docs/audit/audit19_tools/a19consumer_r6
//   edit Package.swift `path:` below to the absolute path of packages/GuardianKit, then
//   `swift run a19consumer_r6`  → prints "A19-F2 ORDINARY CONSUMER: production trust root UNREACHABLE".
// A compile failure if the negative-proof lines (commented) are uncommented is ALSO part of the
// evidence: @testable-only / internal symbols do not resolve for an ordinary consumer.
import PackageDescription

let package = Package(
    name: "a19consumer_r6",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Relative path from docs/audit/audit19_tools/a19consumer_r6 to packages/GuardianKit.
        .package(path: "../../../../packages/GuardianKit")
    ],
    targets: [
        .executableTarget(
            name: "a19consumer_r6",
            dependencies: [.product(name: "GuardianCore", package: "GuardianKit")]
        )
    ]
)
