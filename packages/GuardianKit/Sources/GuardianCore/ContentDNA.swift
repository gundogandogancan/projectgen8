import Foundation

// MARK: - ContentDNA V1 (PROMPT 002 §7) — reusable NON-PERSONAL content intelligence
// Personal decisions (score, exclusions, family policy, admission) are NEVER written here.
// Serializable, versioned, invalidatable, bounded; stores summaries/hashes — NO raw frame/video bytes.

public struct ContentDNAV1: Sendable, Codable, Equatable {
    public static let schemaVersion = "contentdna-v1"

    // Identity
    public var contentID: String
    public var identityState: String        // I0..I4 raw
    public var versionTag: String
    public var exactHash: String?           // SHA-256 hex (non-personal, derived from public/permitted bytes)
    public var perceptualHash: [UInt8]?

    // Reusable non-personal signals
    public var language: String?
    public var extractedTextSummary: String?    // summary/features, not raw private text
    public var topics: [String]
    public var entities: [String]
    public var sensitiveCategories: [String]    // SensitiveCategory raw values
    public var semanticFingerprint: [UInt8]?
    public var temporalSummary: [String]        // coarse segment descriptors

    // Provenance / versioning
    public var engineVersions: [String: String]
    public var freshnessNanos: UInt64
    public var provenance: SignalProvenance
    public var confidence: Double?

    // ContentDNA V2 (PROMPT 003 §27): reusable NON-PERSONAL specialist-head signals.
    // MUST NOT contain the user's final score, hard exclusions, family policy, or private history.
    public var specialistSignals: [DNAHeadSignal]

    // ContentDNA V3 (PROMPT 004 §23): reusable whole-video analysis (non-personal).
    public var coverage: WholeVideoCoverage?
    public var sceneBoundarySeconds: [Double]
    public var deepenedWindowSeconds: [Double]
    public var modelPackVersion: String?
    public var rightsState: String

    // ContentDNA V4 (PROMPT 005 §16): reusable REAL-media derived signals (NO raw frames/PCM).
    public var mediaDurationSeconds: Double?
    public var representativeFrameHashes: [String]      // perceptual/exact hex — derived, not raw bytes
    public var transcriptDerivedSummary: [String]       // derived features/summaries where rights allow
    public var ocrDerivedText: [String]                 // derived OCR text tied to windows (not raw image)

    // PROMPT 006 §11 — reusable audio/music signals (NO raw PCM / NO copyrighted lyrics).
    public var audio: ContentDNAAudio?

    public init(contentID: String, identityState: String, versionTag: String,
                exactHash: String? = nil, perceptualHash: [UInt8]? = nil, language: String? = nil,
                extractedTextSummary: String? = nil, topics: [String] = [], entities: [String] = [],
                sensitiveCategories: [String] = [], semanticFingerprint: [UInt8]? = nil,
                temporalSummary: [String] = [], engineVersions: [String: String] = [:],
                freshnessNanos: UInt64 = 0, provenance: SignalProvenance = .unavailable, confidence: Double? = nil,
                specialistSignals: [DNAHeadSignal] = [], coverage: WholeVideoCoverage? = nil,
                sceneBoundarySeconds: [Double] = [], deepenedWindowSeconds: [Double] = [],
                modelPackVersion: String? = nil, rightsState: String = "UNKNOWN",
                mediaDurationSeconds: Double? = nil, representativeFrameHashes: [String] = [],
                transcriptDerivedSummary: [String] = [], ocrDerivedText: [String] = [],
                audio: ContentDNAAudio? = nil) {
        self.contentID = contentID; self.identityState = identityState; self.versionTag = versionTag
        self.exactHash = exactHash; self.perceptualHash = perceptualHash; self.language = language
        self.extractedTextSummary = extractedTextSummary; self.topics = topics; self.entities = entities
        self.sensitiveCategories = sensitiveCategories; self.semanticFingerprint = semanticFingerprint
        self.temporalSummary = temporalSummary; self.engineVersions = engineVersions
        self.freshnessNanos = freshnessNanos; self.provenance = provenance; self.confidence = confidence
        self.specialistSignals = specialistSignals
        self.coverage = coverage; self.sceneBoundarySeconds = sceneBoundarySeconds
        self.deepenedWindowSeconds = deepenedWindowSeconds; self.modelPackVersion = modelPackVersion
        self.rightsState = rightsState
        self.mediaDurationSeconds = mediaDurationSeconds; self.representativeFrameHashes = representativeFrameHashes
        self.transcriptDerivedSummary = transcriptDerivedSummary; self.ocrDerivedText = ocrDerivedText
        self.audio = audio
    }
}

/// Reusable NON-PERSONAL audio/music signals for ContentDNA (PROMPT 006 §11). No raw PCM / no lyrics.
public struct ContentDNAAudio: Sendable, Equatable, Codable {
    public var speechAvailable: Bool
    public var soundEventTimeline: [String]        // "class@t" derived labels
    public var isMusic: Bool?
    public var musicIdentity: String?              // metadata only, rights-tracked (nil if UNAVAILABLE)
    public var loudnessRMS: Double?
    public var languageLocale: String?
    public var engineVersions: [String]
    public init(speechAvailable: Bool = false, soundEventTimeline: [String] = [], isMusic: Bool? = nil,
                musicIdentity: String? = nil, loudnessRMS: Double? = nil, languageLocale: String? = nil,
                engineVersions: [String] = []) {
        self.speechAvailable = speechAvailable; self.soundEventTimeline = soundEventTimeline; self.isMusic = isMusic
        self.musicIdentity = musicIdentity; self.loudnessRMS = loudnessRMS; self.languageLocale = languageLocale
        self.engineVersions = engineVersions
    }
}

/// Reusable NON-PERSONAL specialist-head record for ContentDNA V2 (PROMPT 003 §27).
public struct DNAHeadSignal: Sendable, Equatable, Codable {
    public let headId: String
    public let headVersion: String
    public let label: String                 // structured label/value summary (non-personal)
    public let calibratedConfidence: Double? // nil = calibration UNAVAILABLE
    public let provenance: SignalProvenance
    public let freshnessNanos: UInt64
    public let rightsState: String
    public init(headId: String, headVersion: String, label: String, calibratedConfidence: Double?,
                provenance: SignalProvenance, freshnessNanos: UInt64, rightsState: String) {
        self.headId = headId; self.headVersion = headVersion; self.label = label
        self.calibratedConfidence = calibratedConfidence; self.provenance = provenance
        self.freshnessNanos = freshnessNanos; self.rightsState = rightsState
    }
}

/// Bounded local store. In-memory reference impl; a disk-backed impl plugs in later (bounded + invalidation).
public actor ContentDNAStore {
    private var store: [String: ContentDNAV1] = [:]
    private var lru: [String] = []
    private let capacity: Int
    public init(capacity: Int = 512) { self.capacity = capacity }

    /// Returns a DNA entry only if the schema/version matches (invalidation on mismatch).
    public func get(_ id: String, versionTag: String) -> ContentDNAV1? {
        guard let d = store[id], d.versionTag == versionTag else { return nil }
        return d
    }
    public func put(_ dna: ContentDNAV1) {
        store[dna.contentID] = dna
        lru.removeAll { $0 == dna.contentID }; lru.append(dna.contentID)
        while store.count > capacity, let oldest = lru.first { lru.removeFirst(); store[oldest] = nil }
    }
    public func invalidate(_ id: String) { store[id] = nil; lru.removeAll { $0 == id } }
    public var count: Int { store.count }
}
