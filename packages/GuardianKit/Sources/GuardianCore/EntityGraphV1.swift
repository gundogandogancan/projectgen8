import Foundation

// MARK: - P009C §5 — entity graph. LAW: never identify real people from images; no sensitive-trait
// inference; confidence + provenance required; conflicting entity evidence stays UNRESOLVED.

public enum EntityKindV1: String, Sendable, Codable, CaseIterable {
    case personPresent = "person-present"          // NON-identifying presence only
    case organization, place, product, object, activity, event, concept
    case mediaTitle = "media-title"                // only if legally/technically sourced
    case brandLogoCandidate = "brand-logo-candidate"
}

public struct EntityNodeV1: Sendable {
    public let canonical: String                   // durable ATOM ID when mapped; "entity:unmapped:<kind>#n" otherwise
    public let kind: EntityKindV1
    /// P009C-R1 F-1: non-nil ONLY when the provider label mapped through DurableEntityVocabularyV1.
    /// nil = EPHEMERAL/UNKNOWN — this node can never enter durable DNA.
    public let durableAtomID: String?
    public let ephemeralLabel: String              // raw provider label — in-memory/lab display only, never durable
    public var confidence: Double
    public var observations: Int
    public var provenance: [String]
    public var conflicting: Bool                   // conflicting evidence → stays unresolved, both retained
    public var uncertainty: Double
}

public final class EntityGraphV1: @unchecked Sendable {
    public static let revision = "entity-graph-v1"
    /// scene labels that imply a NON-identifying person presence
    static let personPresenceScenes: Set<String> = ["person-speaking", "person", "people", "crowd-visual"]
    /// structurally FORBIDDEN canonical forms — identity/sensitive traits can never enter the graph
    static let forbiddenFragments = ["face-id", "identity:", "name:", "ethnicity", "religion", "sexual", "health-condition"]
    private(set) public var nodes: [String: EntityNodeV1] = [:]
    public let maxNodes: Int
    private let lock = NSLock()
    public init(maxNodes: Int = 128) { self.maxNodes = maxNodes }

    private var unmappedCounter = 0
    @discardableResult
    public func observe(label: String, kind: EntityKindV1, confidence: Double, provenance: String) -> Bool {
        guard !Self.forbiddenFragments.contains(where: { label.lowercased().contains($0) }) else { return false }
        guard kind != .personPresent || Self.personPresenceScenes.contains(label) || label == "speech-speaker" else {
            return false                                                  // person entities only via presence signals
        }
        // P009C-R1 F-1: canonical IDs come from the CLOSED vocabulary only. Unmapped provider labels stay
        // EPHEMERAL/UNKNOWN — their canonical carries no provider text and they can never become durable.
        let mapped = DurableEntityVocabularyV1.atom(forProviderLabel: label)
        lock.lock(); defer { lock.unlock() }
        let canonical: String
        let atomID: String?
        if let (mappedKind, atom) = mapped, mappedKind == kind {
            canonical = atom.atomID; atomID = atom.atomID
        } else {
            // dedupe ephemeral nodes by raw label within this graph instance (in-memory key only)
            if let existing = nodes.values.first(where: { $0.durableAtomID == nil && $0.ephemeralLabel == label && $0.kind == kind }) {
                var n = existing
                n.observations += 1
                n.confidence = max(n.confidence, min(1, max(0, confidence)))
                if n.provenance.count < 16 { n.provenance.append(provenance) }
                nodes[n.canonical] = n
                return true
            }
            unmappedCounter += 1
            canonical = "entity:unmapped:\(kind.rawValue)#\(unmappedCounter)"
            atomID = nil
        }
        if var n = nodes[canonical] {
            n.observations += 1
            n.confidence = max(n.confidence, min(1, max(0, confidence)))  // repeated sightings strengthen presence…
            if n.provenance.count < 16 { n.provenance.append(provenance) }
            nodes[canonical] = n
        } else {
            guard nodes.count < maxNodes else { return false }
            nodes[canonical] = EntityNodeV1(canonical: canonical, kind: kind, durableAtomID: atomID,
                                            ephemeralLabel: label,
                                            confidence: min(1, max(0, confidence)), observations: 1,
                                            provenance: [provenance], conflicting: false,
                                            uncertainty: 1 - min(1, max(0, confidence)))
        }
        return true
    }
    /// §5 conflicting entity evidence: BOTH candidates retained, marked conflicting, never auto-resolved.
    public func markConflict(_ canonicalA: String, _ canonicalB: String) {
        lock.lock(); defer { lock.unlock() }
        if var a = nodes[canonicalA] { a.conflicting = true; a.uncertainty = max(a.uncertainty, 0.7); nodes[canonicalA] = a }
        if var b = nodes[canonicalB] { b.conflicting = true; b.uncertainty = max(b.uncertainty, 0.7); nodes[canonicalB] = b }
    }
    public func all() -> [EntityNodeV1] { lock.lock(); defer { lock.unlock() }; return Array(nodes.values).sorted { $0.canonical < $1.canonical } }
    public var count: Int { lock.lock(); defer { lock.unlock() }; return nodes.count }
}
