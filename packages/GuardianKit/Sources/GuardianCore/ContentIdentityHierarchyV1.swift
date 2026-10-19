import Foundation

// MARK: - PROMPT 009A — Hierarchical content identity: the BRAIN ABOVE THE EYE.
// Canonical hierarchy (§1, permanent):
//   OBSERVATION → FRAME → SHOT/PERSISTENT-VISUAL-SEGMENT → SCENE → CONTENT ITEM → TOPIC/NARRATIVE → CONTENT DNA
//   → PERSONAL POLICY → GUARDIAN ADMISSION.
// A cut may create a new SHOT without creating a new CONTENT ITEM. A swipe may create a new CONTENT ITEM even if
// the next item looks similar. These levels are never collapsed again.
// The V5 sensor (`boundary-policy-v5`) is FROZEN and reclassified: it detects SHOTS / persistent visual segments,
// NOT feed items (§0/§3). No V5 threshold is retuned here.

// MARK: - §2 versioned identity objects. IDs are opaque session-scoped counters — they never encode raw content.

public struct ObservationID: Hashable, Sendable, Codable { public let raw: UInt64; public init(_ r: UInt64) { raw = r } }
public struct ShotID: Hashable, Sendable, Codable { public let raw: UInt64; public init(_ r: UInt64) { raw = r } }
public struct SceneID: Hashable, Sendable, Codable { public let raw: UInt64; public init(_ r: UInt64) { raw = r } }
public struct ContentItemID: Hashable, Sendable, Codable { public let raw: UInt64; public init(_ r: UInt64) { raw = r } }
public struct ContentDNAID: Hashable, Sendable, Codable { public let raw: UInt64; public init(_ r: UInt64) { raw = r } }
public struct EvidenceNodeID: Hashable, Sendable, Codable { public let raw: UInt64; public init(_ r: UInt64) { raw = r } }
public struct EvidenceSourceID: Hashable, Sendable, Codable { public let raw: String; public init(_ r: String) { raw = r } }

/// §2 identity revisioning: provisional → refined/confirmed; split/merge/invalidation are versioned, never silent.
public enum IdentityLifecycleV1: String, Sendable, Codable {
    case provisional = "PROVISIONAL", confirmed = "CONFIRMED", refined = "REFINED"
    case split = "SPLIT", merged = "MERGED", invalidated = "INVALIDATED", evicted = "EVICTED"
}
public struct ContentIdentityRevision: Sendable, Codable, Equatable {
    public var number: Int
    public var lifecycle: IdentityLifecycleV1
    public var reason: String                  // compact derived reason, never raw content
    public init(number: Int, lifecycle: IdentityLifecycleV1, reason: String) {
        self.number = number; self.lifecycle = lifecycle; self.reason = reason
    }
}

// MARK: - §3 shot segmenter contract freeze — V5 semantics wrapped, renamed to what it actually detects.

/// How the sensor saw the transition INTO this shot (derived, compact).
public enum ShotTransitionInV1: String, Sendable, Codable {
    case sessionStart = "SESSION_START", cut = "CUT", swipeConfirmed = "SWIPE_CONFIRMED"
    case crossfade = "CROSSFADE", appSurface = "APP_SURFACE"
}

/// Compact derived descriptor of one SHOT (persistent visual segment). No raw media; signatures only.
public struct ShotDescriptorV1: Sendable {
    public let shotID: ShotID
    public let observationID: ObservationID
    public var startMs: Double
    public var endMs: Double
    public var durationMs: Double { max(0, endMs - startMs) }
    public let representative: SegmentFrameV4          // derived multi-region signature + projections
    public let transitionIn: ShotTransitionInV1
    public let swipeGate: SwipeGateStateV1
    public let replacementRatioIn: Double
    public let confidenceIn: Double
    // Optional cross-modal fingerprints (Tier-1 / app-process only; nil = honestly unavailable):
    public let captionFingerprint: UInt64?             // derived text fingerprint, non-reconstructive
    public let audioContinuityWithPrevious: Bool?      // derived continuity flag only (no audio retained)
    public init(shotID: ShotID, observationID: ObservationID, startMs: Double, endMs: Double,
                representative: SegmentFrameV4, transitionIn: ShotTransitionInV1, swipeGate: SwipeGateStateV1,
                replacementRatioIn: Double, confidenceIn: Double,
                captionFingerprint: UInt64? = nil, audioContinuityWithPrevious: Bool? = nil) {
        self.shotID = shotID; self.observationID = observationID; self.startMs = startMs; self.endMs = endMs
        self.representative = representative; self.transitionIn = transitionIn; self.swipeGate = swipeGate
        self.replacementRatioIn = replacementRatioIn; self.confidenceIn = confidenceIn
        self.captionFingerprint = captionFingerprint; self.audioContinuityWithPrevious = audioContinuityWithPrevious
    }
}

public struct ShotBoundaryEvent: Sendable {
    public let newShot: ShotDescriptorV1
    public let closedShot: ShotDescriptorV1?           // the shot that just ended (nil at session start)
    public let reasons: [SegmentReasonV5]
    public let policyRevision: String
}

/// §3 `ShotSegmenterV5` — the FROZEN V5 engine re-expressed under its true contract: it emits SHOT boundaries
/// (persistent visual segment changes). It does NOT claim feed-item detection; item grouping lives above it.
/// V5 internals, tests, and evidence are preserved untouched (adapter pattern, §12).
public final class ShotSegmenterV5: @unchecked Sendable {
    public let observationID: ObservationID
    private let core: BoundaryEvidenceAccumulatorV5
    private var nextShotRaw: UInt64 = 0
    private var current: ShotDescriptorV1?
    public var policyRevision: String { core.policy.revision }
    public var shotCount: Int { core.committedSegmentCount }

    public init(observationID: ObservationID, policy: ContentBoundaryPolicyV5 = .frozenV5) {
        self.observationID = observationID
        self.core = BoundaryEvidenceAccumulatorV5(policy: policy)
    }

    private func transition(for ev: SegmentEventV5, first: Bool) -> ShotTransitionInV1 {
        if first { return .sessionStart }
        if ev.swipeGate == .swipeTransitionConfirmed { return .swipeConfirmed }
        if ev.reasons.contains(.gradualTransition) { return .crossfade }
        if ev.reasons.contains(.appSurfaceTransition) { return .appSurface }
        return .cut
    }

    /// Feed one ephemeral sample; returns the raw V5 event plus a ShotBoundaryEvent when a shot commits.
    public func process(_ f: SegmentFrameV4, timestampMs: Double) -> (event: SegmentEventV5, boundary: ShotBoundaryEvent?) {
        let ev = core.process(f, timestampMs: timestampMs)
        guard ev.committedNew else {
            current?.endMs = timestampMs
            return (ev, nil)
        }
        let first = current == nil
        var closed = current
        closed?.endMs = timestampMs
        nextShotRaw += 1
        let shot = ShotDescriptorV1(shotID: ShotID(nextShotRaw), observationID: observationID,
                                    startMs: timestampMs, endMs: timestampMs, representative: f,
                                    transitionIn: transition(for: ev, first: first), swipeGate: ev.swipeGate,
                                    replacementRatioIn: ev.replacementRatio, confidenceIn: ev.confidence)
        current = shot
        return (ev, ShotBoundaryEvent(newShot: shot, closedShot: closed, reasons: ev.reasons, policyRevision: core.policy.revision))
    }
}

// MARK: - §4 hierarchical temporal graph — bounded; inactive history compacts into item summaries.

public enum TemporalNodeV1: Sendable {
    case shot(ShotID), scene(SceneID), item(ContentItemID)
}
public enum TemporalEdgeTypeV1: String, Sendable, Codable {
    case temporalAdjacency = "TEMPORAL_ADJACENCY"
    case likelySameItem = "LIKELY_SAME_ITEM", confirmedSameItem = "CONFIRMED_SAME_ITEM"
    case likelyNewItem = "LIKELY_NEW_ITEM", confirmedNewItem = "CONFIRMED_NEW_ITEM"
    case ambiguous = "AMBIGUOUS"
    case semanticContinuity = "SEMANTIC_CONTINUITY", audioContinuity = "AUDIO_CONTINUITY", visualContinuity = "VISUAL_CONTINUITY"
    case interactionTransition = "INTERACTION_TRANSITION", provenance = "PROVENANCE"
}
public struct TemporalEdgeV1: Sendable {
    public let type: TemporalEdgeTypeV1
    public let fromShot: ShotID
    public let toShot: ShotID
    public let confidence: Double
    public let atMs: Double
    public init(type: TemporalEdgeTypeV1, fromShot: ShotID, toShot: ShotID, confidence: Double, atMs: Double) {
        self.type = type; self.fromShot = fromShot; self.toShot = toShot; self.confidence = confidence; self.atMs = atMs
    }
}
/// Compacted summary left behind when active graph detail is evicted (§4): counts only, no raw content.
public struct CompactedItemSummaryV1: Sendable {
    public let itemID: ContentItemID
    public let shotCount: Int
    public let sceneCount: Int
    public let firstMs: Double
    public let lastMs: Double
}

public final class HierarchicalTemporalGraphV1: @unchecked Sendable {
    public let maxActiveShots: Int
    public let sceneWindowMs: Double
    private(set) public var shots: [ShotID] = []                 // active (bounded) in temporal order
    private(set) public var edges: [TemporalEdgeV1] = []         // bounded alongside shots
    private(set) public var shotToItem: [ShotID: ContentItemID] = [:]
    private(set) public var shotToScene: [ShotID: SceneID] = [:]
    private(set) public var compacted: [CompactedItemSummaryV1] = []
    private var shotTimes: [ShotID: (start: Double, end: Double)] = [:]
    private var nextSceneRaw: UInt64 = 0
    private var lastSceneID: SceneID?
    private var lastShotEndMs: Double = -1e12
    private var lastItemForScene: ContentItemID?

    public init(maxActiveShots: Int = 128, sceneWindowMs: Double = 30_000) {
        self.maxActiveShots = max(8, maxActiveShots); self.sceneWindowMs = sceneWindowMs
    }

    public func addShot(_ shot: ShotDescriptorV1, item: ContentItemID) {
        shots.append(shot.shotID)
        shotTimes[shot.shotID] = (shot.startMs, shot.endMs)
        shotToItem[shot.shotID] = item
        // §1 SCENE = temporal window of consecutive shots within one item (new item or window overflow → new scene)
        if lastItemForScene != item || shot.startMs - lastShotEndMs > sceneWindowMs || lastSceneID == nil {
            nextSceneRaw += 1; lastSceneID = SceneID(nextSceneRaw)
        }
        shotToScene[shot.shotID] = lastSceneID
        lastItemForScene = item; lastShotEndMs = shot.endMs
        if let prev = shots.dropLast().last {
            edges.append(TemporalEdgeV1(type: .temporalAdjacency, fromShot: prev, toShot: shot.shotID, confidence: 1, atMs: shot.startMs))
        }
        compactIfNeeded()
    }
    public func addEdge(_ e: TemporalEdgeV1) { edges.append(e); compactIfNeeded() }
    public func reassign(shot: ShotID, to item: ContentItemID) { shotToItem[shot] = item }

    /// §4 bounded memory: oldest shots compact into per-item summaries; detail edges dropped with them.
    private func compactIfNeeded() {
        while shots.count > maxActiveShots {
            let victim = shots.removeFirst()
            let item = shotToItem[victim] ?? ContentItemID(0)
            let t = shotTimes[victim] ?? (0, 0)
            if let idx = compacted.firstIndex(where: { $0.itemID == item }) {
                let c = compacted[idx]
                compacted[idx] = CompactedItemSummaryV1(itemID: item, shotCount: c.shotCount + 1,
                                                        sceneCount: c.sceneCount, firstMs: min(c.firstMs, t.start), lastMs: max(c.lastMs, t.end))
            } else {
                compacted.append(CompactedItemSummaryV1(itemID: item, shotCount: 1, sceneCount: 1, firstMs: t.start, lastMs: t.end))
            }
            shotToItem.removeValue(forKey: victim); shotToScene.removeValue(forKey: victim); shotTimes.removeValue(forKey: victim)
            edges.removeAll { $0.fromShot == victim || $0.toShot == victim }
        }
        if edges.count > maxActiveShots * 12 { edges.removeFirst(edges.count - maxActiveShots * 12) }
    }
    public var activeShotCount: Int { shots.count }
    public func sceneCount(for item: ContentItemID) -> Int {
        Set(shotToItem.filter { $0.value == item }.keys.compactMap { shotToScene[$0] }).count
    }
}
