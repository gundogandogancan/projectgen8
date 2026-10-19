import Foundation

// MARK: - Global Language Capability Registry (PROMPT 006 §12,§13,§14,§15) — architecture is global, certification is per-language.
// NEVER claim "all languages supported". Uncertified language does NOT inherit a certified threshold.

public enum LanguageCertification: String, Sendable, Codable, Comparable {
    case unassessed = "UNASSESSED"
    case basicSignalOnly = "BASIC_SIGNAL_ONLY"
    case labSupported = "LAB_SUPPORTED"
    case calibrated = "CALIBRATED"
    case certified = "CERTIFIED"
    case degraded = "DEGRADED"
    case unsupported = "UNSUPPORTED"
    private var rank: Int {
        switch self { case .unsupported: return 0; case .unassessed: return 1; case .degraded: return 2
        case .basicSignalOnly: return 3; case .labSupported: return 4; case .calibrated: return 5; case .certified: return 6 }
    }
    public static func < (a: LanguageCertification, b: LanguageCertification) -> Bool { a.rank < b.rank }
}

public struct LanguageCapability: Sendable, Codable, Equatable {
    public let locale: String
    public let script: String
    public var languageIDSupported: Bool
    public var ocrSupported: Bool
    public var speechSupported: Bool
    public var embeddingSupported: Bool
    public var topicClassifierSupported: Bool
    public var sensitiveContentSupported: Bool
    public var slangIdiomPack: Bool
    public var calibrationStatus: String
    public var evalDatasetSize: Int
    public var certification: LanguageCertification
    public init(locale: String, script: String, languageIDSupported: Bool = false, ocrSupported: Bool = false,
                speechSupported: Bool = false, embeddingSupported: Bool = false, topicClassifierSupported: Bool = false,
                sensitiveContentSupported: Bool = false, slangIdiomPack: Bool = false, calibrationStatus: String = "UNAVAILABLE",
                evalDatasetSize: Int = 0, certification: LanguageCertification = .unassessed) {
        self.locale = locale; self.script = script; self.languageIDSupported = languageIDSupported
        self.ocrSupported = ocrSupported; self.speechSupported = speechSupported; self.embeddingSupported = embeddingSupported
        self.topicClassifierSupported = topicClassifierSupported; self.sensitiveContentSupported = sensitiveContentSupported
        self.slangIdiomPack = slangIdiomPack; self.calibrationStatus = calibrationStatus
        self.evalDatasetSize = evalDatasetSize; self.certification = certification
    }
}

public struct LanguageCapabilityRegistry: Sendable {
    private var map: [String: LanguageCapability]
    public init() {
        // EN + TR are the first quality languages (lab-supported, not certified — no production claim).
        let en = LanguageCapability(locale: "en", script: "Latin", languageIDSupported: true, ocrSupported: true,
            speechSupported: false, embeddingSupported: true, topicClassifierSupported: true, sensitiveContentSupported: true,
            slangIdiomPack: true, calibrationStatus: "UNAVAILABLE_INSUFFICIENT_DATA", evalDatasetSize: 20, certification: .labSupported)
        let tr = LanguageCapability(locale: "tr", script: "Latin", languageIDSupported: true, ocrSupported: true,
            speechSupported: false, embeddingSupported: false, topicClassifierSupported: true, sensitiveContentSupported: true,
            slangIdiomPack: true, calibrationStatus: "UNAVAILABLE_INSUFFICIENT_DATA", evalDatasetSize: 20, certification: .labSupported)
        map = ["en": en, "tr": tr]
    }
    public func capability(_ locale: String) -> LanguageCapability {
        map[locale] ?? LanguageCapability(locale: locale, script: "Unknown", certification: .unassessed)  // never inherit certified threshold
    }
    public func isAtLeast(_ locale: String, _ level: LanguageCertification) -> Bool { capability(locale).certification >= level }
    public var allLocales: [String] { Array(map.keys).sorted() }

    /// §15 non-binding expansion priority (architecture supports all; certification incremental).
    public func expansionPriority(demand: Double, reach: Double, systemCapability: Double,
                                  dataAvailability: Double, cost: Double) -> Double {
        (demand * reach * systemCapability * dataAvailability) / max(0.1, cost)
    }
}
