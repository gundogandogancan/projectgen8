import Foundation

// MARK: - Functionally-durable visual reference signature (PROMPT 006C §1,§2,§4 Strategy A)
// A matcher-CONSUMABLE derived representation: perceptual hashes + a normalized vector, fully under our control.
// No raw image. Survives process teardown because comparison needs only these persisted bytes.

public struct VisualSignatureComponent: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case aHash = "AHASH64", dHash = "DHASH64", normVector = "NORMVEC256" }
    public var kind: Kind
    public var algorithmID: String
    public var engineRevision: String
    public var dimension: Int
    public var data: Data               // 8 bytes for 64-bit hashes; float32-LE bytes for the vector
    public var checksum: String         // SHA-256-free lightweight checksum (FNV-1a) — integrity, not secrecy
    public var normalization: String
    public var createdAtEpoch: Double
    public var rightsClass: String
    public var privacyClass: String
    public var compatibilityVersion: Int
    public init(kind: Kind, algorithmID: String, engineRevision: String, dimension: Int, data: Data,
                normalization: String, createdAtEpoch: Double, rightsClass: String = "user-permitted",
                privacyClass: String = "on-device-only", compatibilityVersion: Int = 1) {
        self.kind = kind; self.algorithmID = algorithmID; self.engineRevision = engineRevision; self.dimension = dimension
        self.data = data; self.checksum = VisualSignatureComponent.fnv1a(data); self.normalization = normalization
        self.createdAtEpoch = createdAtEpoch; self.rightsClass = rightsClass; self.privacyClass = privacyClass
        self.compatibilityVersion = compatibilityVersion
    }
    public var isIntact: Bool { checksum == VisualSignatureComponent.fnv1a(data) }
    public static func fnv1a(_ data: Data) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in data { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(h, radix: 16)
    }
}

public struct PersistedVisualReferenceSignature: Codable, Sendable, Equatable {
    public static let formatVersion = "visual-sig-v1"
    public static let currentEngineRevision = "sig-r1"
    public static let currentCompatibilityVersion = 1
    public var formatVersion: String
    public var ruleID: String
    public var components: [VisualSignatureComponent]
    public init(ruleID: String, components: [VisualSignatureComponent], formatVersion: String = PersistedVisualReferenceSignature.formatVersion) {
        self.ruleID = ruleID; self.components = components; self.formatVersion = formatVersion
    }
    public func component(_ kind: VisualSignatureComponent.Kind) -> VisualSignatureComponent? { components.first { $0.kind == kind } }
    public var allIntact: Bool { !components.isEmpty && components.allSatisfy { $0.isIntact } }
    /// 006C §7 — a signature is consumable only if format + engine revision + compatibility version all match current.
    public func isCompatible(engineRevision: String = PersistedVisualReferenceSignature.currentEngineRevision,
                             compatibilityVersion: Int = PersistedVisualReferenceSignature.currentCompatibilityVersion) -> Bool {
        formatVersion == PersistedVisualReferenceSignature.formatVersion && allIntact
            && components.allSatisfy { $0.engineRevision == engineRevision && $0.compatibilityVersion == compatibilityVersion }
    }
}

// Pure, headless comparison the matcher consumes from persisted bytes (006C §3 — no framework object needed at compare time).
public struct VisualSignatureComparator: Sendable {
    public struct Distances: Sendable, Equatable { public let aHashHamming: Int; public let dHashHamming: Int; public let vectorL2: Double }
    public init() {}

    /// Returns a match state (or .matcherUnavailable if incompatible/corrupt) by comparing two persisted signatures.
    public func compare(_ a: PersistedVisualReferenceSignature, _ b: PersistedVisualReferenceSignature) -> (state: ShieldMatchState, distances: Distances?) {
        guard a.isCompatible(), b.isCompatible() else { return (.matcherUnavailable, nil) }
        guard let aHashA = a.component(.aHash), let aHashB = b.component(.aHash),
              let dHashA = a.component(.dHash), let dHashB = b.component(.dHash) else { return (.matchabilityUnknown, nil) }
        let aHam = hamming64(aHashA.data, aHashB.data)
        let dHam = hamming64(dHashA.data, dHashB.data)
        var vecL2 = Double.greatestFiniteMagnitude
        if let vA = a.component(.normVector), let vB = b.component(.normVector) { vecL2 = l2(vA.data, vB.data) }
        let d = Distances(aHashHamming: aHam, dHashHamming: dHam, vectorL2: vecL2)
        // Thresholds locked from measured synthetic-image behaviour (see VisualSignatureDurabilityTests debug run).
        let state: ShieldMatchState
        if aHam <= 6 && dHam <= 8 { state = .matchHigh }
        else if aHam <= 10 && dHam <= 14 { state = .matchMedium }
        else if aHam <= 14 && dHam <= 18 { state = .matchLow }
        else { state = .noMatch }
        return (state, d)
    }

    private func hamming64(_ x: Data, _ y: Data) -> Int {
        let a = x.withUnsafeBytes { $0.load(as: UInt64.self) }
        let b = y.withUnsafeBytes { $0.load(as: UInt64.self) }
        return (a ^ b).nonzeroBitCount
    }
    private func l2(_ x: Data, _ y: Data) -> Double {
        let a = floats(x), b = floats(y); guard a.count == b.count, !a.isEmpty else { return .greatestFiniteMagnitude }
        var s = 0.0; for i in a.indices { let d = Double(a[i] - b[i]); s += d * d }
        return (s / Double(a.count)).squareRoot()
    }
    private func floats(_ d: Data) -> [Float] {
        let n = d.count / 4; return d.withUnsafeBytes { raw in (0..<n).map { raw.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) } }
    }
}

// Helpers to pack a 64-bit hash into Data (used by the signature engine + tests).
public enum VisualSignatureBits {
    public static func pack(_ bits: UInt64) -> Data { withUnsafeBytes(of: bits) { Data($0) } }
    public static func floatsToData(_ xs: [Float]) -> Data { xs.withUnsafeBytes { Data($0) } }
}
