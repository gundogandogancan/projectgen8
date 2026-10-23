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
        // R3 (A16-F22): REAL corpus-entry/acquisition authority OUTSIDE the test target.
        // Offline tooling library (git-object verification, quarantine transaction law); macOS-only
        // bodies are #if os(macOS)-guarded; never part of the consumer app products.
        .target(name: "RWCAcquisition", dependencies: ["GuardianCore"]),
        .testTarget(name: "GuardianCoreTests", dependencies: ["GuardianCore", "RWCAcquisition"]),
        .testTarget(name: "GuardianIntelligenceTests", dependencies: ["GuardianIntelligence", "GuardianCore"]),
        .testTarget(name: "GuardianMediaTests", dependencies: ["GuardianMedia", "GuardianIntelligence", "GuardianCore"])
    ]
)
