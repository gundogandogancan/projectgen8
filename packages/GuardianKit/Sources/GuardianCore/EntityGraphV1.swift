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
    public let canonical: String                   // "entity:<kind>:<label>" — scene-level, non-identifying
    public let kind: EntityKindV1
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

    @discardableResult
    public func observe(label: String, kind: EntityKindV1, confidence: Double, provenance: String) -> Bool {
        let canonical = "entity:\(kind.rawValue):\(label)"
        guard !Self.forbiddenFragments.contains(where: { canonical.lowercased().contains($0) }) else { return false }
        guard kind != .personPresent || Self.personPresenceScenes.contains(label) || label == "speech-speaker" else {
            return false                                                  // person entities only via presence signals
        }
        lock.lock(); defer { lock.unlock() }
        if var n = nodes[canonical] {
            n.observations += 1
            n.confidence = max(n.confidence, min(1, max(0, confidence)))  // repeated sightings strengthen presence…
            if n.provenance.count < 16 { n.provenance.append(provenance) }
            nodes[canonical] = n
        } else {
            guard nodes.count < maxNodes else { return false }
            nodes[canonical] = EntityNodeV1(canonical: canonical, kind: kind,
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
