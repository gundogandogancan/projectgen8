// swift-tools-version:5.9
// GuardianKit — platform-independent Guardian core + Apple-native intelligence + media adapters for Gen8.
// GuardianCore: pure domain/application logic (no SwiftUI/UIKit/AVFoundation) — fully testable headless.
// GuardianIntelligence: REAL Apple-native providers (CryptoKit, NaturalLanguage, Vision).
// GuardianMedia: REAL AVFoundation media ingestion/decode (platform/media layer) — AVFoundation stays OUT of core.
import PackageDescription

let package = Package(
    name: "GuardianKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "GuardianCore", targets: ["GuardianCore"]),
        .library(name: "GuardianIntelligence", targets: ["GuardianIntelligence"]),
        .library(name: "GuardianMedia", targets: ["GuardianMedia"])
    ],
    targets: [
        .target(name: "GuardianCore"),
        .target(name: "GuardianIntelligence", dependencies: ["GuardianCore"]),
        .target(name: "GuardianMedia", dependencies: ["GuardianCore", "GuardianIntelligence"]),
        .testTarget(name: "GuardianCoreTests", dependencies: ["GuardianCore"]),
        .testTarget(name: "GuardianIntelligenceTests", dependencies: ["GuardianIntelligence", "GuardianCore"]),
        .testTarget(name: "GuardianMediaTests", dependencies: ["GuardianMedia", "GuardianIntelligence", "GuardianCore"])
    ]
)
