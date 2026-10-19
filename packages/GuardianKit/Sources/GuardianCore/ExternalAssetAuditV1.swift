import Foundation

// MARK: - P009B §19 — external model/asset license-provenance audit. LAW: unclear license or provenance
// → DO NOT INTEGRATE. Every non-Apple-system intelligence asset MUST have a record here BEFORE integration.

public enum AssetLicenseClassV1: String, Sendable, Codable {
    case appleSystemFramework = "APPLE_SYSTEM_FRAMEWORK"     // OS-provided; licensed via OS
    case projectAuthored = "PROJECT_AUTHORED"                // written in this repo; rights-clear by construction
    case permissiveVerified = "PERMISSIVE_VERIFIED"          // MIT/Apache-2.0/BSD verified at source
    case unclearDoNotIntegrate = "UNCLEAR_DO_NOT_INTEGRATE"  // §19: never ships
}

public struct ExternalIntelligenceAssetAuditV1: Sendable, Codable {
    public let assetName: String
    public let provider: String
    public let licenseClass: AssetLicenseClassV1
    public let licenseEvidence: String            // where the license was verified (URL/file), or why unclear
    public let provenance: String                 // who built it, from what data (as declared)
    public let integrationApproved: Bool          // false whenever licenseClass == .unclearDoNotIntegrate
    public let auditedAtISO8601: String
    public init(assetName: String, provider: String, licenseClass: AssetLicenseClassV1,
                licenseEvidence: String, provenance: String, auditedAtISO8601: String) {
        self.assetName = assetName; self.provider = provider; self.licenseClass = licenseClass
        self.licenseEvidence = licenseEvidence; self.provenance = provenance
        self.integrationApproved = licenseClass != .unclearDoNotIntegrate
        self.auditedAtISO8601 = auditedAtISO8601
    }
}

/// P009B outcome: ZERO new external model assets were integrated. The mesh reuses Apple system
/// frameworks (already provider-wrapped in P002–P006) + project-authored lexicons/heuristics only.
public enum P009BAssetAuditLedgerV1 {
    public static let records: [ExternalIntelligenceAssetAuditV1] = [
        .init(assetName: "Vision.framework classification/OCR", provider: "Apple (OS)",
              licenseClass: .appleSystemFramework, licenseEvidence: "iOS SDK — OS-licensed system framework",
              provenance: "Apple on-device models; accessed only via GuardianIntelligence providers",
              auditedAtISO8601: "2026-10-19"),
        .init(assetName: "SoundAnalysis.framework", provider: "Apple (OS)",
              licenseClass: .appleSystemFramework, licenseEvidence: "iOS SDK — OS-licensed system framework",
              provenance: "Apple on-device sound classifier; accessed only via GuardianMedia providers",
              auditedAtISO8601: "2026-10-19"),
        .init(assetName: "Speech.framework (SFSpeechRecognizer on-device)", provider: "Apple (OS)",
              licenseClass: .appleSystemFramework, licenseEvidence: "iOS SDK — OS-licensed system framework",
              provenance: "Apple on-device recognizer; honest-UNAVAILABLE when not granted/on-device",
              auditedAtISO8601: "2026-10-19"),
        .init(assetName: "NaturalLanguage.framework", provider: "Apple (OS)",
              licenseClass: .appleSystemFramework, licenseEvidence: "iOS SDK — OS-licensed system framework",
              provenance: "Apple language ID/embedding; accessed via NLTextSignalProvider",
              auditedAtISO8601: "2026-10-19"),
        .init(assetName: "Lexicons (TR+EN topical/manipulation)", provider: "Gen8 project",
              licenseClass: .projectAuthored, licenseEvidence: "authored in repo (Lexicons.swift, P003)",
              provenance: "hand-written in this repository; no scraped corpora",
              auditedAtISO8601: "2026-10-19"),
        .init(assetName: "P009B corpus scenarios", provider: "Gen8 project",
              licenseClass: .projectAuthored, licenseEvidence: "authored in repo (P009BCorpusV1.swift)",
              provenance: "project-authored derived-input bundles; no third-party media",
              auditedAtISO8601: "2026-10-19"),
    ]
    /// §19 gate used by tests: nothing unclear may ever be approved.
    public static var allIntegrationsLawful: Bool {
        records.allSatisfy { $0.integrationApproved && $0.licenseClass != .unclearDoNotIntegrate }
    }
}

// MARK: - R1 §10 — external asset audit V2: full governance record. For Apple OS frameworks the
// sentinel `NOT_APPLICABLE_OS_FRAMEWORK` is used where a field does not apply; unmeasured runtime
// characteristics are `NOT_MEASURED`. Licenses/provenance are NEVER invented.

public struct ExternalIntelligenceAssetAuditV2: Sendable, Codable {
    public static let notApplicableOS = "NOT_APPLICABLE_OS_FRAMEWORK"
    public static let notMeasured = "NOT_MEASURED"
    public let assetName: String
    public let exactVersionOrOSManaged: String
    public let provider: String
    public let codeLicense: String
    public let weightsLicense: String
    public let commercialUse: String
    public let redistribution: String
    public let trainingDataProvenance: String
    public let restrictions: String
    public let assetSizeBytes: String                 // number or sentinel
    public let installedSizeBytes: String
    public let warmMemory: String
    public let measuredLatency: String
    public let languages: [String]
    public let safetyLimitations: String
    public let privacyBehavior: String
    public let offlineSupport: Bool
    public let osDeviceSupport: String
    public let fallback: String
    public let checksumOrSignature: String
    public let verificationSource: String
    public let auditDateISO8601: String
    public let licenseClass: AssetLicenseClassV1
    public var integrationApproved: Bool { licenseClass != .unclearDoNotIntegrate }
}

public enum P009BAssetAuditLedgerV2 {
    static func appleFramework(_ name: String, languages: [String], safety: String, fallback: String) -> ExternalIntelligenceAssetAuditV2 {
        let na = ExternalIntelligenceAssetAuditV2.notApplicableOS
        return ExternalIntelligenceAssetAuditV2(
            assetName: name, exactVersionOrOSManaged: "OS-managed (iOS 26.x / macOS 26.x SDK)", provider: "Apple (OS)",
            codeLicense: "Apple SDK / OS EULA", weightsLicense: na, commercialUse: "permitted per Apple Developer Program License Agreement",
            redistribution: na + " (ships with the OS, never redistributed by Gen8)",
            trainingDataProvenance: na + " (Apple does not publish per-model training data; nothing is claimed)",
            restrictions: "on-device API use only; no model extraction", assetSizeBytes: na, installedSizeBytes: "0 (OS-provided)",
            warmMemory: ExternalIntelligenceAssetAuditV2.notMeasured, measuredLatency: ExternalIntelligenceAssetAuditV2.notMeasured,
            languages: languages, safetyLimitations: safety,
            privacyBehavior: "on-device inference; Gen8 passes derived results only, never persists raw media",
            offlineSupport: true, osDeviceSupport: "iOS 17+/macOS 14+ (deployed: iOS 26.x)",
            fallback: fallback, checksumOrSignature: na + " (OS code-signing chain)",
            verificationSource: "Apple SDK headers + Apple Developer documentation (verified at implementation time)",
            auditDateISO8601: "2026-10-19", licenseClass: .appleSystemFramework)
    }
    static func projectAsset(_ name: String, file: String, languages: [String], size: String) -> ExternalIntelligenceAssetAuditV2 {
        ExternalIntelligenceAssetAuditV2(
            assetName: name, exactVersionOrOSManaged: "repo HEAD (versioned in git)", provider: "Gen8 project",
            codeLicense: "project-internal (proprietary)", weightsLicense: "no weights — hand-authored data",
            commercialUse: "owned by the project", redistribution: "not redistributed",
            trainingDataProvenance: "hand-written in this repository (\(file)); no scraped corpora, no third-party text",
            restrictions: "none beyond project license", assetSizeBytes: size, installedSizeBytes: size,
            warmMemory: "negligible (static Swift constants)", measuredLatency: "lexicon scan measured in route latency samples",
            languages: languages, safetyLimitations: "lexical only; uncalibrated; no visual safety capability",
            privacyBehavior: "static word lists; no user data", offlineSupport: true,
            osDeviceSupport: "all Gen8 targets", fallback: "absence → honest UNAVAILABLE evidence",
            checksumOrSignature: "git object hash (repo history)", verificationSource: "source file in repo",
            auditDateISO8601: "2026-10-19", licenseClass: .projectAuthored)
    }
    public static let records: [ExternalIntelligenceAssetAuditV2] = [
        appleFramework("Vision.framework (VNRecognizeTextRequest / VNClassifyImageRequest / feature print)",
                       languages: ["multi (OCR)", "label taxonomy: en"],
                       safety: "generic taxonomy — NOT a safety classifier; H1 dimensions remain UNAVAILABLE",
                       fallback: "no result → nil field → honest UNAVAILABLE evidence"),
        appleFramework("SoundAnalysis.framework (SNClassifySoundRequest v1)",
                       languages: ["n/a"], safety: "generic sound classes — no violence/distress classifier claim",
                       fallback: "no result → nil soundEvents → UNAVAILABLE"),
        appleFramework("Speech.framework (SFSpeechRecognizer, on-device)",
                       languages: ["tr", "en", "others OS-dependent"],
                       safety: "transcription only; authorization-gated; unavailable → honest UNAVAILABLE",
                       fallback: "speechAvailable=false path"),
        appleFramework("NaturalLanguage.framework (NLLanguageRecognizer / embeddings)",
                       languages: ["multi"], safety: "language id only — no content judgment",
                       fallback: "unknown → und → UNSUPPORTED_LANGUAGE abstention"),
        projectAsset("Lexicons TR+EN (P003 lexicon-v1)", file: "Sources/GuardianCore/Lexicons.swift",
                     languages: ["tr", "en"], size: "~6 KB source"),
        projectAsset("P009B corpus V1 (frozen audit evidence) + V2 (split-independent)",
                     file: "Sources/GuardianCore/P009BCorpusV1.swift + P009BCorpusV2.swift",
                     languages: ["tr", "en"], size: "~40 KB source"),
    ]
    public static var allIntegrationsLawful: Bool {
        !records.isEmpty && records.allSatisfy { $0.integrationApproved && $0.licenseClass != .unclearDoNotIntegrate }
    }
}
