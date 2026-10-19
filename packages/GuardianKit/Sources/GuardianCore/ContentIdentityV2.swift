import Foundation

// MARK: - Content identity V2 (PROMPT 008 §13) — hierarchical identity, more robust than one perceptual hash.
// Never reuse ContentDNA across weak identity as if exact.

public struct ContentIdentityComponentsV2: Sendable, Equatable {
    public var providerID: String?        // official source/provider id if exposed
    public var normalizedMetadata: String?
    public var textSignature: String?     // OCR/caption text fingerprint
    public var visualSignature: UInt64?   // perceptual hash
    public var temporalSignature: String? // scene/shot timeline digest
    public var audioSignature: String?
    public init(providerID: String? = nil, normalizedMetadata: String? = nil, textSignature: String? = nil,
                visualSignature: UInt64? = nil, temporalSignature: String? = nil, audioSignature: String? = nil) {
        self.providerID = providerID; self.normalizedMetadata = normalizedMetadata; self.textSignature = textSignature
        self.visualSignature = visualSignature; self.temporalSignature = temporalSignature; self.audioSignature = audioSignature
    }
}

public struct ContentIdentityV2: Sendable, Equatable {
    public let id: String
    public let confidence: ContentIdentityConfidence
    public let components: ContentIdentityComponentsV2
    /// ContentDNA reuse is allowed ONLY at STRONG/EXACT. PROVISIONAL/UNKNOWN must re-derive (never stale-reuse).
    public var mayReuseContentDNA: Bool { confidence == .exact || confidence == .strong }
}

public enum ContentIdentityResolverV2 {
    /// Derive identity + confidence from available components. Provider id ⇒ EXACT; multi-signal corroboration ⇒ STRONG;
    /// single visual/text signal ⇒ PROVISIONAL; nothing ⇒ UNKNOWN.
    public static func resolve(_ c: ContentIdentityComponentsV2) -> ContentIdentityV2 {
        if let p = c.providerID, !p.isEmpty {
            return ContentIdentityV2(id: "pid:\(p)", confidence: .exact, components: c)
        }
        var signals = 0
        if c.textSignature != nil { signals += 1 }
        if c.visualSignature != nil { signals += 1 }
        if c.temporalSignature != nil { signals += 1 }
        if c.audioSignature != nil { signals += 1 }
        if c.normalizedMetadata != nil { signals += 1 }
        let digest = [c.normalizedMetadata, c.textSignature, c.visualSignature.map { String($0, radix: 16) },
                      c.temporalSignature, c.audioSignature].compactMap { $0 }.joined(separator: "|")
        switch signals {
        case 0: return ContentIdentityV2(id: "unknown", confidence: .unknown, components: c)
        case 1: return ContentIdentityV2(id: "prov:\(digest.hashValue)", confidence: .provisional, components: c)
        default: return ContentIdentityV2(id: "strong:\(digest.hashValue)", confidence: .strong, components: c)
        }
    }
}
