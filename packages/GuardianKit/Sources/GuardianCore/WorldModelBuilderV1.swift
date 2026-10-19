import Foundation

// MARK: - P009C — the canonical path: mesh evidence → episodes → graphs → weighting → contradiction
// resolution → ContentWorldModelV1. All inputs are DERIVED P009B evidence; no raw media.

/// One observation unit entering the builder: the mesh's route output for one temporal segment.
public struct EpisodeObservationV1: Sendable {
    public let startMs: Double
    public let endMs: Double
    public let shotIDs: [ShotID]
    public let evidence: [ExpertEvidenceV2]
    public let unknownReasons: [String]
    public let sourceText: String?                 // derived text for context-tag heuristics (EPHEMERAL — never persisted)
    public let sourceLanguage: String?             // R1 F-2: locale for language-aware cue tokenization
    public init(startMs: Double, endMs: Double, shotIDs: [ShotID], evidence: [ExpertEvidenceV2],
                unknownReasons: [String], sourceText: String? = nil, sourceLanguage: String? = nil) {
        self.startMs = startMs; self.endMs = endMs; self.shotIDs = shotIDs
        self.evidence = evidence; self.unknownReasons = unknownReasons; self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
    }
}

public final class WorldModelBuilderV1: @unchecked Sendable {
    public static let revision = "world-model-builder-v1"
    public let maxEpisodes: Int
    private let lock = NSLock()
    private var nextEpisodeID: UInt64 = 1
    public init(maxEpisodes: Int = 256) { self.maxEpisodes = maxEpisodes }

    public func build(observations: [EpisodeObservationV1], itemID: ContentItemID?, itemProvisional: Bool,
                      identityRevision: UInt64, generation: UInt64, nowMs: Double) -> ContentWorldModelV1 {
        let topics = TopicGraphV1()
        let entities = EntityGraphV1()
        let intents = IntentGraphV1()
        let eventGraph = EventStateGraphV1()
        let timeline = NarrativeTimelineV1()
        let provenance = WorldModelProvenanceV1()
        var emotional = EmotionalSensitiveLoadV1()
        var episodes: [SemanticEpisodeV1] = []
        var resolutions: [ContradictionResolutionV1] = []
        var allSafety: Set<String> = [], allBenefit: Set<String> = [], allManip: Set<String> = []
        var coverage: [ExpertDomainV2: Double] = [:]
        var meshVersions: Set<String> = []
        var oodFlags = 0
        var allUnknown: [String] = []
        var anyProvisionalEvidence = false
        var evidenceItems: Set<UInt64> = []
        var evidenceGens: Set<UInt64> = []
        var lastDominant: Set<String> = []
        var firstRiskAtMs: Double?
        var lastPositiveAtMs: Double?

        for (idx, obs) in observations.enumerated() {
            if episodes.count >= maxEpisodes { allUnknown.append("wm:episodes-bounded-dropped:\(observations.count - idx)"); break }
            let live = obs.evidence.filter { !$0.stale && $0.generation == generation }
            let staleExcluded = obs.evidence.count - live.count
            if staleExcluded > 0 { allUnknown.append("wm:stale-evidence-excluded:\(staleExcluded)") }
            for e in live {
                if e.itemProvisional && e.itemID != nil { anyProvisionalEvidence = true }
                if let i = e.itemID?.raw { evidenceItems.insert(i) }
                if e.itemID != nil { evidenceGens.insert(e.generation) }
                if e.inputModalityAvailable { meshVersions.insert(e.modelVersion) }   // "n/a" placeholders excluded
                if e.oodIndicator { oodFlags += 1 }
                coverage[e.domain] = max(coverage[e.domain] ?? 0, e.coverage)
            }
            allUnknown.append(contentsOf: obs.unknownReasons.prefix(4))

            // ── concepts/topics (weighted — correlated families never stack: weigh per family first)
            let labels = live.flatMap { $0.labels }
            let contextTags = ContradictionResolverV1.detectContextTags(text: obs.sourceText, language: obs.sourceLanguage)
            var episodeConcepts: Set<String> = []
            for e in live {
                let w = EvidenceWeigherV1.weight(of: e, contradictionInvolved: false, identityStable: !itemProvisional)
                for l in e.labels {
                    if let concept = SemanticTaxonomyV1.concept(for: l) {
                        episodeConcepts.insert(concept)
                        topics.observe(concept: concept, weight: w, uncertainty: e.uncertainty,
                                       atMs: obs.startMs, provenance: e.provenance)
                    }
                }
            }
            // ── entities (non-identifying; scene/audio derived)
            var episodePlaceEntities: [String] = []
            for e in live where e.domain == .vision {
                for l in e.labels where l.hasPrefix("scene:") {
                    let scene = String(l.dropFirst("scene:".count))
                    let kind: EntityKindV1 = EntityGraphV1.personPresenceScenes.contains(scene) ? .personPresent
                        : (SemanticTaxonomyV1.sceneConcept[scene] == "concept:calm-nature" ? .place : .object)
                    if entities.observe(label: scene, kind: kind, confidence: e.confidence, provenance: e.provenance),
                       e.confidence >= 0.6,
                       let mapped = DurableEntityVocabularyV1.atom(forProviderLabel: scene),
                       mapped.0 == .place {                               // vocabulary kind is authoritative
                        episodePlaceEntities.append(mapped.1.atomID)
                    }
                }
            }
            // §5: two strong, different PLACE entities inside ONE moment = conflicting evidence —
            // both retained, marked conflicting, never auto-resolved
            if episodePlaceEntities.count >= 2 {
                for i in episodePlaceEntities.indices {
                    for j in episodePlaceEntities.indices where j > i && episodePlaceEntities[i] != episodePlaceEntities[j] {
                        entities.markConflict(episodePlaceEntities[i], episodePlaceEntities[j])
                    }
                }
            }
            for e in live where e.domain == .audioEvent {
                for l in e.labels where l == "audio:crowd" || l == "audio:applause" {
                    _ = entities.observe(label: "audience", kind: .activity, confidence: e.confidence, provenance: e.provenance)
                }
            }
            // ── intent hypotheses (supported + countered; never a fact)
            observeIntents(labels: labels, live: live, contextTags: contextTags, intents: intents, atMs: obs.startMs)
            // ── per-episode safety/benefit/manipulation/emotion
            let safety = labels.filter { $0.hasPrefix("safety:") }
            let benefit = labels.filter { $0.hasPrefix("benefit:") && !$0.contains("none") }
            let manip = labels.filter { $0.hasPrefix("attention:") || $0.hasPrefix("pattern:manipulation") }
            allSafety.formUnion(safety); allBenefit.formUnion(benefit); allManip.formUnion(manip)
            // CURRENT-moment risk excludes the temporal expert (its monotone memory is HISTORICAL risk);
            // both feed escalation, only the current value can show recovery (§8 law split)
            let (currentRisk, _) = EvidenceWeigherV1.combine(live.filter { e in
                e.domain != .temporal && e.labels.contains { $0.hasPrefix("safety:sensitive") || $0.hasPrefix("safety:fear") } })
            let temporalMax = live.first(where: { $0.domain == .temporal })?.features["maxRisk"] ?? 0
            let riskStrength = max(currentRisk, min(1, max(0, temporalMax)))
            for e in live {
                let w = EvidenceWeigherV1.weight(of: e, contradictionInvolved: false, identityStable: !itemProvisional)
                emotional.observe(labels: e.labels, weight: w, provenance: e.provenance)
            }
            // ── contradiction resolution for this segment (risk vs positive)
            let riskEv = live.filter { e in e.labels.contains { $0.hasPrefix("safety:sensitive") || $0.hasPrefix("safety:fear") || $0 == "temporal:risk-escalated" || $0.hasPrefix("symbol:warning") } }
            let posEv = live.filter { e in e.labels.contains { $0.hasPrefix("benefit:") && !$0.contains("none") } }
            var episodeContradictions = 0
            if !riskEv.isEmpty && !posEv.isEmpty {
                let res = ContradictionResolverV1.resolve(ContradictionCaseV1(
                    riskEvidence: riskEv, positiveEvidence: posEv, contextTags: contextTags,
                    riskEarlierMs: firstRiskAtMs, positiveLaterMs: obs.startMs))
                resolutions.append(res)
                episodeContradictions = 1
                eventGraph.record(SemanticEventV1(kind: .contradictionSurfaced, atMs: obs.startMs,
                                                  detail: "contradiction:\(res.outcome.rawValue)", episodeID: nextEpisodeID,
                                                  provenance: ContradictionResolverV1.revision))
            }
            if riskStrength >= 0.5 && firstRiskAtMs == nil { firstRiskAtMs = obs.startMs }
            if !posEv.isEmpty { lastPositiveAtMs = obs.startMs }

            // ── episode assembly (+ merge with previous when same dominant topic)
            let (strength, _) = EvidenceWeigherV1.combine(live)
            let episode = SemanticEpisodeV1(
                episodeID: nextEpisodeID, startMs: obs.startMs, endMs: obs.endMs, shotIDs: obs.shotIDs,
                itemID: itemID, itemProvisional: itemProvisional,
                topicCandidates: episodeConcepts.sorted(), entityCandidates: [],
                intentCandidates: intents.ranked().prefix(3).map { $0.intent.rawValue },
                safetyEvidence: safety.sorted(), benefitEvidence: benefit.sorted(),
                manipulationEvidence: manip.sorted(), emotionalLoad: emotional.labels,
                contextTags: contextTags, modalityCoverage: coverage,
                contradictions: episodeContradictions, confidence: strength,
                // R1 §9 uncertainty review: strength-derived (family-law-bounded) — the old per-record MIN
                // let one confident expert mask nine uncertain ones (optimistic aggregation, audit F-7)
                uncertainty: live.isEmpty ? 1 : 1 - strength,
                oodFlags: live.filter { $0.oodIndicator }.count,
                provenance: live.map { $0.provenance }, generation: generation)
            nextEpisodeID &+= 1
            if let prev = episodes.last, Set(prev.topicCandidates) == episodeConcepts, !episodeConcepts.isEmpty,
               let merged = SemanticEpisodeV1.merge(prev, episode, newID: prev.episodeID) {
                episodes[episodes.count - 1] = merged          // same-topic adjacency → merge (revision bump)
            } else {
                episodes.append(episode)
                if let prev = lastDominant.first, !episodeConcepts.isEmpty, episodeConcepts.isDisjoint(with: lastDominant) {
                    eventGraph.record(SemanticEventV1(kind: .topicShift, atMs: obs.startMs,
                                                      detail: "event:topic-shift:\(prev)→\(episodeConcepts.sorted().first ?? "?")",
                                                      episodeID: episode.episodeID, provenance: Self.revision))
                }
            }
            if !episodeConcepts.isEmpty { lastDominant = episodeConcepts }

            // ── narrative segment + events: historical risk registered first (monotone), segment carries
            // CURRENT risk so recovery is observable while escalation is never erased
            timeline.registerRisk(riskStrength, atMs: obs.startMs)
            timeline.append(NarrativeSegmentV1(episodeID: episodes.last?.episodeID ?? 0, startMs: obs.startMs,
                                               endMs: obs.endMs, dominantConcepts: episodeConcepts.sorted(),
                                               riskLevel: currentRisk, benefitPresent: !benefit.isEmpty,
                                               manipulationPresent: !manip.isEmpty))
            if riskStrength >= 0.6 {
                eventGraph.record(SemanticEventV1(kind: .riskEscalation, atMs: obs.startMs,
                                                  detail: "event:risk-escalation", episodeID: episodes.last?.episodeID,
                                                  provenance: Self.revision))
            } else if timeline.maxRiskSeen >= 0.6 && currentRisk < 0.2 {
                eventGraph.recordRecovery(atMs: obs.startMs, episodeID: episodes.last?.episodeID)
            }
            if labels.contains(where: { $0 == "attention:cta-clickbait" || $0 == "attention:urgency-language" }),
               idx >= observations.count - 2 {
                timeline.markCTANearEnd()
                eventGraph.record(SemanticEventV1(kind: .ctaAppearance, atMs: obs.startMs,
                                                  detail: "event:cta-appearance", episodeID: episodes.last?.episodeID,
                                                  provenance: Self.revision))
            }
            provenance.record(WorldModelProvenanceEntryV1(
                subject: "episode:\(episodes.last?.episodeID ?? 0)", producer: Self.revision,
                basis: live.map { $0.provenance }, modelVersions: Array(meshVersions),
                taxonomyVersion: SemanticTaxonomyV1.version, generation: generation, atMs: obs.startMs))
        }
        if timeline.maxRiskSeen >= 0.6 && resolutions.isEmpty && lastPositiveAtMs != nil { timeline.markUnresolvedEnding() }

        // ── final assembly
        let ranked = topics.ranked()
        let primary = Array(ranked.prefix(3)), secondary = Array(ranked.dropFirst(3).prefix(8))
        let uncertainty = SemanticUncertaintyModelV1.assess(
            evidence: observations.flatMap { $0.evidence }, unknownReasons: allUnknown,
            itemProvisional: itemProvisional, contradictions: resolutions.count, topicCount: ranked.count)
        let (overallStrength, _) = EvidenceWeigherV1.combine(observations.flatMap { $0.evidence }.filter { !$0.stale })
        let conflicting = resolutions.contains { $0.outcome == .unresolved }
        let state = SemanticUncertaintyModelV1.state(strength: overallStrength, uncertainty: uncertainty,
                                                     conflicting: conflicting,
                                                     anyEvidence: observations.contains { !$0.evidence.isEmpty })
        // readiness demands SEMANTIC content — temporal bookkeeping alone can never make DNA (its
        // monotone counters exist even for empty/unsupported input)
        let (semanticStrength, _) = EvidenceWeigherV1.combine(
            observations.flatMap { $0.evidence }.filter { !$0.stale && $0.domain != .temporal })
        let readiness = !itemProvisional && !anyProvisionalEvidence && semanticStrength > 0.2
            && state != .unavailable && state != .unknown && !episodes.isEmpty
        return ContentWorldModelV1(
            identityStatus: itemProvisional ? "provisional" : "confirmed", itemID: itemID,
            identityRevision: identityRevision, generation: generation, episodes: episodes,
            primaryTopics: primary, secondaryTopics: secondary, topicTransitions: topics.transitions,
            entities: entities.all(), intents: intents.ranked(), intentAmbiguous: intents.isAmbiguous,
            events: eventGraph.ordered, causeHypotheses: eventGraph.causeHypotheses,
            narrativeLabels: timeline.summaryLabels(), narrativeMotifs: timeline.motifs(),
            maxRiskSeen: timeline.maxRiskSeen,
            safetyEvidence: allSafety.sorted(), benefitEvidence: allBenefit.sorted(),
            manipulationEvidence: allManip.sorted(), emotionalLoad: emotional.labels,
            contradictionResolutions: resolutions, modalityCoverage: coverage,
            uncertainty: uncertainty, knowledgeState: state, oodFlags: oodFlags,
            provenance: provenance, freshnessAtMs: nowMs, taxonomyVersion: SemanticTaxonomyV1.version,
            meshModelVersions: meshVersions.sorted(), privacyClass: .derivedCacheable,
            anyEvidenceProvisional: anyProvisionalEvidence, evidenceItemIDs: evidenceItems,
            evidenceGenerations: evidenceGens, readiness: readiness)
    }

    private func observeIntents(labels: [String], live: [ExpertEvidenceV2], contextTags: [SemanticContextTagV1],
                                intents: IntentGraphV1, atMs: Double) {
        func modality(_ prefix: String) -> ExpertDomainV2 {
            if prefix.hasPrefix("benefit") { return .benefitEvidence }
            if prefix.hasPrefix("attention") { return .attentionPressure }
            if prefix.hasPrefix("safety") { return .safetyEvidence }
            return .languageOCR
        }
        for l in labels {
            if l == "benefit:educational-candidate" { intents.support(.teach, modality: modality(l), evidence: l, weight: 0.6, atMs: atMs) }
            if l.hasPrefix("safety:sensitive-death-disease-news") { intents.support(.inform, modality: modality(l), evidence: l, weight: 0.4, atMs: atMs) }
            if l == "attention:cta-clickbait" {
                intents.support(.seekEngagement, modality: modality(l), evidence: l, weight: 0.5, atMs: atMs)
                intents.support(.sell, modality: modality(l), evidence: l, weight: 0.3, atMs: atMs)
            }
            if l == "attention:urgency-language" { intents.support(.persuade, modality: modality(l), evidence: l, weight: 0.5, atMs: atMs) }
            if l.hasPrefix("safety:fear-threat") { intents.support(.warn, modality: modality(l), evidence: l, weight: 0.3, atMs: atMs)
                intents.support(.provoke, modality: modality(l), evidence: l, weight: 0.3, atMs: atMs) }
            if l == "benefit:calm-nature-candidate" || l == "music:present" { intents.support(.entertain, modality: .benefitEvidence, evidence: l, weight: 0.3, atMs: atMs) }
            if l.hasPrefix("pattern:emotional-language") { intents.support(.expressEmotion, modality: .languageOCR, evidence: l, weight: 0.3, atMs: atMs) }
        }
        if contextTags.contains(.satireHumorCandidate) {
            intents.support(.satireHumor, modality: .languageOCR, evidence: "context:satire-humor-candidate", weight: 0.4, atMs: atMs)
            intents.counter(.inform, evidence: "context:satire-humor-candidate")
        }
        if contextTags.contains(.quoted) { intents.counter(.provoke, evidence: "context:quoted") }
        if intents.ranked().isEmpty { intents.support(.unknown, modality: .temporal, evidence: "wm:no-intent-evidence", weight: 0.1, atMs: atMs) }
    }
}
