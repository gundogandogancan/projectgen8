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
