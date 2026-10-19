import Foundation

// MARK: - P009B §15–§17 — cross-modal evidence graph, content understanding state, ContentDNA candidate.

// MARK: - §15 cross-modal EXPERT-evidence graph. No majority vote; safety-critical strong evidence dominates.
// Naming note: the P008-era `CrossModalEvidenceGraphV1` (CrossModalEvidenceGraph.swift) is the CONCEPT-level fuser
// over MultimodalContentUnderstandingV1 and remains frozen evidence. THIS type relates P009B ExpertEvidenceV2
// records (agreement/contradiction/stale/unavailable) — hence `CrossModalExpertGraphV1`.

public enum CrossModalEdgeTypeV1: String, Sendable, Codable {
    case agreesWith = "AGREES_WITH", contradicts = "CONTRADICTS", supports = "SUPPORTS", weakSupport = "WEAK_SUPPORT"
    case temporalPrecedes = "TEMPORAL_PRECEDES", sameScope = "SAME_SCOPE", stale = "STALE"
    case supersedes = "SUPERSEDES", unavailableDependency = "UNAVAILABLE_DEPENDENCY"
}

public struct CrossModalEdgeV1: Sendable {
    public let type: CrossModalEdgeTypeV1
    public let fromDomain: ExpertDomainV2
    public let toDomain: ExpertDomainV2
    public let reason: String
}

public final class CrossModalExpertGraphV1: @unchecked Sendable {
    private(set) public var edges: [CrossModalEdgeV1] = []
    private let lock = NSLock(); public let maxEdges: Int
    public init(maxEdges: Int = 512) { self.maxEdges = maxEdges }
    private func add(_ e: CrossModalEdgeV1) {
        edges.append(e); if edges.count > maxEdges { edges.removeFirst(edges.count - maxEdges) }
    }
    public var contradictions: [CrossModalEdgeV1] { lock.lock(); defer { lock.unlock() }; return edges.filter { $0.type == .contradicts } }
    public var agreements: [CrossModalEdgeV1] { lock.lock(); defer { lock.unlock() }; return edges.filter { $0.type == .agreesWith } }

    /// §15 relate the evidence set of one item/generation. Pure pairwise semantics — no majority shortcut.
    public func relate(_ evidence: [ExpertEvidenceV2]) {
        lock.lock(); defer { lock.unlock() }
        let live = evidence.filter { !$0.stale }
        func has(_ e: ExpertEvidenceV2, _ prefix: String) -> Bool { e.labels.contains { $0.hasPrefix(prefix) || $0.contains(prefix) } }
        for i in live.indices {
            for j in live.indices where j > i {
                let a = live[i], b = live[j]
                if !a.inputModalityAvailable || !b.inputModalityAvailable {
                    add(CrossModalEdgeV1(type: .unavailableDependency, fromDomain: a.domain, toDomain: b.domain, reason: "modality-unavailable"))
                    continue
                }
                // the §15 canonical conflict families
                let aRisk = has(a, "safety:sensitive") || has(a, "safety:fear") || has(a, "temporal:risk-escalated") || has(a, "symbol:warning")
                let bRisk = has(b, "safety:sensitive") || has(b, "safety:fear") || has(b, "temporal:risk-escalated") || has(b, "symbol:warning")
                let aPositive = has(a, "benefit:") && !has(a, "benefit:none")
                let bPositive = has(b, "benefit:") && !has(b, "benefit:none")
                if (aRisk && bPositive) || (bRisk && aPositive) {
                    add(CrossModalEdgeV1(type: .contradicts, fromDomain: a.domain, toDomain: b.domain,
                                         reason: "risk-vs-positive (safety-critical evidence dominates; no vote)"))
                } else if aRisk && bRisk {
                    add(CrossModalEdgeV1(type: .agreesWith, fromDomain: a.domain, toDomain: b.domain, reason: "risk-agreement"))
                } else if aPositive && bPositive {
                    add(CrossModalEdgeV1(type: .agreesWith, fromDomain: a.domain, toDomain: b.domain, reason: "benefit-agreement"))
                } else {
                    add(CrossModalEdgeV1(type: .weakSupport, fromDomain: a.domain, toDomain: b.domain, reason: "co-occurrence"))
                }
            }
        }
        for e in evidence where e.stale {
            add(CrossModalEdgeV1(type: .stale, fromDomain: e.domain, toDomain: e.domain, reason: "stale-generation"))
        }
    }
}

// MARK: - §16 content understanding state — the first unified "what is happening?" (NOT PersonalSuitability).

public struct ContentUnderstandingStateV1: Sendable {
    public let identityStatus: String                        // "provisional" | "confirmed"
    public let modalityCoverage: [ExpertDomainV2: Double]
    public let expertAvailability: [ExpertDomainV2: ExpertAvailabilityV2]
    public let topicCandidates: [String]
    public let entities: [String]
    public let intentCandidates: [String]
    public let safetyEvidence: [String]
    public let benefitEvidence: [String]
    public let attentionPressure: [String]
    public let emotionalLoad: [String]
    public let temporalNarrative: [String]
    public let contradictions: Int
    public let uncertainty: Double
    public let oodFlags: Int
    public let evidenceQuality: Double                       // coverage-weighted, NOT a suitability meaning
    public let provenance: [String]
    public let staleEvidenceExcluded: Int
    public let contentDNAReady: Bool
    public let unknownReasons: [String]

    /// §16 build from provenance-bearing evidence + graph. Prefers UNKNOWN over forced interpretation.
    public static func build(itemProvisional: Bool, evidence: [ExpertEvidenceV2],
                             graph: CrossModalExpertGraphV1, registry: ExpertRegistryV2,
                             unknownReasons: [String]) -> ContentUnderstandingStateV1 {
        let live = evidence.filter { !$0.stale }
        var coverage: [ExpertDomainV2: Double] = [:]
        var avail: [ExpertDomainV2: ExpertAvailabilityV2] = [:]
        for d in ExpertDomainV2.allCases { avail[d] = registry.availability(d) }
        for e in live { coverage[e.domain] = max(coverage[e.domain] ?? 0, e.coverage) }
        func collect(_ prefix: String) -> [String] { live.flatMap { $0.labels }.filter { $0.hasPrefix(prefix) } }
        let quality = live.isEmpty ? 0 : live.map { $0.coverage * (1 - $0.uncertainty) }.reduce(0,+) / Double(live.count)
        let uncertainty = live.isEmpty ? 1 : live.map { $0.uncertainty }.reduce(0,+) / Double(live.count)
        return ContentUnderstandingStateV1(
            identityStatus: itemProvisional ? "provisional" : "confirmed",
            modalityCoverage: coverage, expertAvailability: avail,
            topicCandidates: collect("topic:"), entities: collect("entity:"), intentCandidates: collect("intent:"),
            safetyEvidence: collect("safety:"), benefitEvidence: collect("benefit:"),
            attentionPressure: collect("attention:"), emotionalLoad: collect("pattern:emotional"),
            temporalNarrative: collect("temporal:"),
            contradictions: graph.contradictions.count,
            uncertainty: uncertainty, oodFlags: live.filter { $0.oodIndicator }.count,
            evidenceQuality: quality,
            provenance: live.map { $0.provenance },
            staleEvidenceExcluded: evidence.count - live.count,
            contentDNAReady: !itemProvisional && quality > 0,
            unknownReasons: unknownReasons)
    }
}

// MARK: - §17 ContentDNA candidate V2 — durable minting only on resolved identity.

public struct ContentDNACandidateV2: Sendable {
    public let dnaID: ContentDNAID
    public let itemID: ContentItemID
    public let semanticDimensions: [String: [String]]        // topic/safety/benefit/attention label groups
    public let temporalSummary: [String]
    public let modalityCoverage: [ExpertDomainV2: Double]
    public let uncertainty: Double
    public let oodFlags: Int
    public let provenance: [String]
    public let modelVersions: [String]
    public let freshnessExpiresAtMs: Double
    public let privacyClass: EvidencePrivacyClassV1

    /// §17: nil while identity is provisional — shot/scene evidence is maintained upstream; no unsafe finalization.
    public static func mint(from state: ContentUnderstandingStateV1, itemID: ContentItemID, itemProvisional: Bool,
                            dnaRaw: UInt64, nowMs: Double, ttlMs: Double = 3_600_000,
                            modelVersions: [String]) -> ContentDNACandidateV2? {
        guard !itemProvisional, state.contentDNAReady else { return nil }
        return ContentDNACandidateV2(
            dnaID: ContentDNAID(dnaRaw), itemID: itemID,
            semanticDimensions: ["topic": state.topicCandidates, "safety": state.safetyEvidence,
                                 "benefit": state.benefitEvidence, "attention": state.attentionPressure],
            temporalSummary: state.temporalNarrative, modalityCoverage: state.modalityCoverage,
            uncertainty: state.uncertainty, oodFlags: state.oodFlags,
            provenance: state.provenance, modelVersions: modelVersions,
            freshnessExpiresAtMs: nowMs + ttlMs, privacyClass: .derivedNonReconstructive)
    }
}
