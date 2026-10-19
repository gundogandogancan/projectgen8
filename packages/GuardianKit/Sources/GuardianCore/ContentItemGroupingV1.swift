import Foundation

// MARK: - PROMPT 009A §5–§11 — the item-grouping brain above the shot sensor.
// The eye (ShotSegmenterV5) sees persistent visual segments. THIS layer decides which segments belong to the same
// CONTENT ITEM. Safety-first (§7): a false merge can leak a safe Guardian admission across identity boundaries, so
// uncertain SAME_ITEM never silently inherits safe state — prefer provisional split/AMBIGUOUS over unsafe merge.

// MARK: - §5 evidence graph. Every edge carries source/timestamp/confidence/freshness/privacy/capability/version.

public enum EvidencePrivacyClassV1: String, Sendable, Codable {
    case derivedNonReconstructive = "DERIVED_NON_RECONSTRUCTIVE"
    case derivedLinkable = "DERIVED_LINKABLE"           // could correlate across sessions — bounded retention
    case ephemeralOnly = "EPHEMERAL_ONLY"               // never persisted
}
public enum EvidenceModalityV1: String, Sendable, Codable {
    case visual = "VISUAL", text = "TEXT", audio = "AUDIO", temporal = "TEMPORAL", surface = "UI_SURFACE", cache = "CACHE_PRIOR"
}
public struct IdentityEvidenceEdgeV1: Sendable {
    public let id: EvidenceNodeID
    public let modality: EvidenceModalityV1
    public let source: EvidenceSourceID
    public let fromShot: ShotID
    public let toShot: ShotID
    public let supportsSameItem: Bool                   // true = merge evidence, false = new-item evidence
    public let confidence: Double                       // 0..1
    public let atMs: Double
    public let freshnessMs: Double
    public let privacyClass: EvidencePrivacyClassV1
    public let capabilityProvenance: String             // e.g. "tier0-visual", "tier1-ocr", "official-surface-api"
    public let modelVersion: String
}

/// §5 bounded container for identity evidence edges (per observation session).
public final class ContentIdentityEvidenceGraphV1: @unchecked Sendable {
    public let maxEdges: Int
    private(set) public var edges: [IdentityEvidenceEdgeV1] = []
    private var nextRaw: UInt64 = 0
    public init(maxEdges: Int = 1024) { self.maxEdges = max(64, maxEdges) }
    @discardableResult
    public func add(modality: EvidenceModalityV1, source: String, from: ShotID, to: ShotID, supportsSameItem: Bool,
                    confidence: Double, atMs: Double, privacy: EvidencePrivacyClassV1,
                    capability: String, modelVersion: String) -> IdentityEvidenceEdgeV1 {
        nextRaw += 1
        let e = IdentityEvidenceEdgeV1(id: EvidenceNodeID(nextRaw), modality: modality, source: EvidenceSourceID(source),
                                       fromShot: from, toShot: to, supportsSameItem: supportsSameItem,
                                       confidence: max(0, min(1, confidence)), atMs: atMs, freshnessMs: 0,
                                       privacyClass: privacy, capabilityProvenance: capability, modelVersion: modelVersion)
        edges.append(e)
        if edges.count > maxEdges { edges.removeFirst(edges.count - maxEdges) }
        return e
    }
    public func edges(to shot: ShotID) -> [IdentityEvidenceEdgeV1] { edges.filter { $0.toShot == shot } }
}

// MARK: - §6 grouping states + §19 decision record.

public enum ItemGroupingStateV1: String, Sendable, Codable {
    case shotOnly = "SHOT_ONLY"
    case candidateSameItem = "CANDIDATE_SAME_ITEM", sameItemConfirmed = "SAME_ITEM_CONFIRMED"
    case candidateNewItem = "CANDIDATE_NEW_ITEM", newItemConfirmed = "NEW_ITEM_CONFIRMED"
    case ambiguous = "AMBIGUOUS"
}

/// P009A-R2 (audit finding B1): raw per-channel values at a shot transition — DERIVED SCALARS ONLY. This is what
/// the measured-evidence run logs; without it, channel attribution is an under-determined inference from S/N.
public struct GroupingChannelTelemetryV1: Sendable {
    public let themeDistance: Double            // content-signature distance to the current item (min over refs)
    public let projectionCorrelation: Double    // cross-shot row/col structure continuity (0..1)
    public let histogramDistance: Double        // 4-bin luma L1 (0..1)
    public let chromeDistance: Double           // top/bottom band distance
    public let regionalDistance: Double         // edges+global persistence distance
    public let gapSinceLastBoundaryMs: Double   // edit-cadence feature
    public let previousShotDwellMs: Double      // long-dwell feature
    public let elapsedItemMs: Double            // time since current item opened
    public let strongNew: Bool
    public let anchored: Bool                   // content/cross-modal anchor present
    public let firedEvidence: [String]          // evidence-source names that actually fired
    public init(themeDistance: Double, projectionCorrelation: Double, histogramDistance: Double,
                chromeDistance: Double, regionalDistance: Double, gapSinceLastBoundaryMs: Double,
                previousShotDwellMs: Double, elapsedItemMs: Double, strongNew: Bool, anchored: Bool, firedEvidence: [String]) {
        self.themeDistance = themeDistance; self.projectionCorrelation = projectionCorrelation
        self.histogramDistance = histogramDistance; self.chromeDistance = chromeDistance
        self.regionalDistance = regionalDistance; self.gapSinceLastBoundaryMs = gapSinceLastBoundaryMs
        self.previousShotDwellMs = previousShotDwellMs; self.elapsedItemMs = elapsedItemMs
        self.strongNew = strongNew; self.anchored = anchored; self.firedEvidence = firedEvidence
    }
}

public struct ItemGroupingDecisionV1: Sendable {
    public let state: ItemGroupingStateV1
    public let itemID: ContentItemID
    public let itemRevision: ContentIdentityRevision
    public let openedNewItem: Bool
    public let provisional: Bool                        // AMBIGUOUS → provisional split (safety-first)
    public let mergeScore: Double
    public let newScore: Double
    public let evidence: [IdentityEvidenceEdgeV1]
    public let safeAdmissionInheritance: Bool           // §7: NEVER true unless SAME_ITEM_CONFIRMED
    public var channels: GroupingChannelTelemetryV1? = nil   // populated by EngineV2; nil in the frozen V1 engine
}

// MARK: - §6/§7/§9 grouping policy (versioned; tuned on TUNE only, frozen before held-out).

public struct ItemGroupingPolicyV1: Sendable, Codable, Equatable {
    public var revision: String
    // evidence weights (Tier 0 cheap + Tier 1 cross-modal when available)
    public var wCaptionMatch: Double, wCaptionChange: Double
    public var wAudioContinuity: Double, wAudioBreak: Double
    public var wThemeContinuity: Double, wThemeDiscontinuity: Double
    public var wChromeSame: Double, wChromeChange: Double
    public var wSwipeConfirmed: Double, wCrossfade: Double, wCutPrior: Double
    public var wBurstCadence: Double, wLongDwell: Double
    public var wCachePrior: Double
    // feature thresholds
    public var themeContinuityMax: Double       // center-signature distance ≤ → theme continuity
    public var themeDiscontinuityMin: Double
    public var chromeSameMax: Double
    public var chromeChangeMin: Double
    public var burstGapMs: Double               // cut arriving sooner than this after previous boundary = edit-burst
    public var longDwellMs: Double              // shot lived at least this long before transition = user-watched
    // decision thresholds (§6/§7 — merge needs MORE than new: precision-first merges)
    public var confirmNewThreshold: Double
    public var confirmSameThreshold: Double
    public var decisionMargin: Double
    public var maxShotsPerItem: Int             // §20 guard: internal cuts must not grow an item unboundedly
    public init(revision: String = "item-grouping-policy-v1",
                wCaptionMatch: Double = 0.35, wCaptionChange: Double = 0.30,
                wAudioContinuity: Double = 0.30, wAudioBreak: Double = 0.20,
                wThemeContinuity: Double = 0.22, wThemeDiscontinuity: Double = 0.22,
                wChromeSame: Double = 0.05, wChromeChange: Double = 0.38,
                wSwipeConfirmed: Double = 0.48, wCrossfade: Double = 0.15, wCutPrior: Double = 0.10,
                wBurstCadence: Double = 0.12, wLongDwell: Double = 0.12,
                wCachePrior: Double = 0.30,
                themeContinuityMax: Double = 0.22, themeDiscontinuityMin: Double = 0.42,
                chromeSameMax: Double = 0.10, chromeChangeMin: Double = 0.30,
                burstGapMs: Double = 3200, longDwellMs: Double = 3800,
                confirmNewThreshold: Double = 0.42, confirmSameThreshold: Double = 0.50, decisionMargin: Double = 0.12,
                maxShotsPerItem: Int = 64) {
        self.revision = revision
        self.wCaptionMatch = wCaptionMatch; self.wCaptionChange = wCaptionChange
        self.wAudioContinuity = wAudioContinuity; self.wAudioBreak = wAudioBreak
        self.wThemeContinuity = wThemeContinuity; self.wThemeDiscontinuity = wThemeDiscontinuity
        self.wChromeSame = wChromeSame; self.wChromeChange = wChromeChange
        self.wSwipeConfirmed = wSwipeConfirmed; self.wCrossfade = wCrossfade; self.wCutPrior = wCutPrior
        self.wBurstCadence = wBurstCadence; self.wLongDwell = wLongDwell; self.wCachePrior = wCachePrior
        self.themeContinuityMax = themeContinuityMax; self.themeDiscontinuityMin = themeDiscontinuityMin
        self.chromeSameMax = chromeSameMax; self.chromeChangeMin = chromeChangeMin
        self.burstGapMs = burstGapMs; self.longDwellMs = longDwellMs
        self.confirmNewThreshold = confirmNewThreshold; self.confirmSameThreshold = confirmSameThreshold
        self.decisionMargin = decisionMargin; self.maxShotsPerItem = maxShotsPerItem
    }
    /// FROZEN on TUNE only (see P009A_TUNE_RESULTS). Used for HELD-OUT / STRESS / device validation.
    public static let frozenV1 = ItemGroupingPolicyV1()
}

/// §9 capability tiers: the extension runs Tier 0 only (cheap derived continuity); the app process may add Tier 1
/// cross-modal evidence (captions/audio) when legitimately available in-process. Same semantic contract.
public enum GroupingCapabilityProfileV1: String, Sendable, Codable {
    case extensionFast = "EXTENSION_FAST_TIER0", appFull = "APP_FULL_TIER1"
}

// MARK: - §8 per-item evidence accumulator (consolidation + escalation).

public struct ItemEvidenceSummaryV1: Sendable {
    public var shotIDs: [ShotID] = []
    public var captionFingerprints: Set<UInt64> = []
    public var riskEscalated = false                     // a later dangerous shot escalates the whole item
    public var maxRiskConfidence: Double = 0
    public var conflicts: Int = 0
    public var provenance: [String] = []
    public var firstMs: Double = 0
    public var lastMs: Double = 0
}
public final class ContentItemEvidenceAccumulatorV1: @unchecked Sendable {
    private(set) public var items: [ContentItemID: ItemEvidenceSummaryV1] = [:]
    public init() {}
    public func addShot(_ shot: ShotDescriptorV1, to item: ContentItemID, provenance: String) {
        var s = items[item] ?? ItemEvidenceSummaryV1()
        if s.shotIDs.isEmpty { s.firstMs = shot.startMs }
        s.shotIDs.append(shot.shotID); s.lastMs = shot.endMs
        if let c = shot.captionFingerprint { s.captionFingerprints.insert(c) }
        s.provenance.append(provenance)
        items[item] = s
    }
    /// §8 escalation: later risk evidence escalates the ITEM; earlier harmless shots can never suppress it.
    public func reportRisk(item: ContentItemID, confidence: Double) {
        var s = items[item] ?? ItemEvidenceSummaryV1()
        s.riskEscalated = s.riskEscalated || confidence > 0
        s.maxRiskConfidence = max(s.maxRiskConfidence, confidence)   // monotone: never decreases
        items[item] = s
    }
    public func reportConflict(item: ContentItemID) {
        var s = items[item] ?? ItemEvidenceSummaryV1(); s.conflicts += 1; items[item] = s
    }
}

// MARK: - §10 item-level ContentDNA (score stays OFF; UNKNOWN preserved).

public struct ContentDNAItemV1: Sendable {
    public let dnaID: ContentDNAID
    public let itemID: ContentItemID
    public var revision: ContentIdentityRevision
    public var shotCount: Int
    public var sceneCount: Int
    public var modalitySummary: [EvidenceModalityV1: Int]     // evidence-edge counts per modality (derived)
    public var temporalSpanMs: Double
    public var riskEscalated: Bool
    public var uncertainty: Double                             // 0 = confident identity, 1 = fully ambiguous
    public var provenance: [String]
    public var privacyClass: EvidencePrivacyClassV1
    public var modelVersions: [String]
    public var expiresAtMs: Double                             // cache freshness
    public var invalidated: Bool = false
}

// MARK: - §11 identity cache: one expensive understanding → many cheap decisions. Non-reconstructive keys.

public struct IdentityCacheRecordV1: Sendable {
    public let dnaID: ContentDNAID
    public let fullSignature: MultiRegionSignature            // for collision verification (derived, non-reconstructive)
    public var confidence: Double
    public var version: String
    public var expiresAtMs: Double
    public var localScope: Bool                               // local-only by default; global sharing is policy-gated
    public var privacyClass: EvidencePrivacyClassV1
}
public enum IdentityCacheOutcomeV1: Sendable, Equatable {
    case hit(ContentDNAID, confidence: Double)
    case collisionReanalyze                                   // key matched but signature distance too large (§11)
    case miss
}
public final class ContentIdentityCacheV1: @unchecked Sendable {
    public let maxEntries: Int
    public let collisionMaxDistance: Double
    private var store: [UInt64: IdentityCacheRecordV1] = [:]  // key = quantized derived signature (not raw content)
    private var order: [UInt64] = []
    public private(set) var hits = 0, misses = 0, collisions = 0
    public init(maxEntries: Int = 512, collisionMaxDistance: Double = 0.12) {
        self.maxEntries = max(16, maxEntries); self.collisionMaxDistance = collisionMaxDistance
    }
    /// Non-reconstructive key: coarse quantization of the derived region signature (content cannot be rebuilt from it).
    public static func key(for sig: MultiRegionSignature) -> UInt64 {
        // popcount buckets per region → 6×8-bit digest; coarse by design (collisions are verified, then degrade to re-analysis)
        func b(_ v: UInt64) -> UInt64 { UInt64(v.nonzeroBitCount) }
        return (b(sig.center) << 40) | (b(sig.global) << 32) | (b(sig.top) << 24) | (b(sig.bottom) << 16) | (b(sig.left) << 8) | b(sig.right)
    }
    public func lookup(_ sig: MultiRegionSignature, nowMs: Double) -> IdentityCacheOutcomeV1 {
        let k = Self.key(for: sig)
        guard let rec = store[k], rec.expiresAtMs > nowMs else { misses += 1; return .miss }
        let d = sig.distances(to: rec.fullSignature)
        let dist = (d.center + d.global) / 2
        if dist <= collisionMaxDistance { hits += 1; return .hit(rec.dnaID, confidence: rec.confidence) }
        collisions += 1
        return .collisionReanalyze                            // §11: collision uncertainty degrades to re-analysis
    }
    public func insert(_ rec: IdentityCacheRecordV1, for sig: MultiRegionSignature) {
        let k = Self.key(for: sig)
        if store[k] == nil { order.append(k) }
        store[k] = rec
        while order.count > maxEntries { let evict = order.removeFirst(); store.removeValue(forKey: evict) }
    }
    public func invalidate(dnaID: ContentDNAID) {
        for (k, r) in store where r.dnaID == dnaID { store.removeValue(forKey: k); order.removeAll { $0 == k } }
    }
    public var count: Int { store.count }
}

// MARK: - §6/§7 the grouping engine.

@available(*, deprecated, message: "LEGACY (P009A frozen evidence only). Dead durationMs dwell; inheritance not tier-restricted; predates EvidenceIndependenceGuardV1 and the Phase-C provisional-identity contract. Production MUST use ContentItemGroupingEngineV2. Retained solely for audit reproducibility (D-0020).")
public final class ContentItemGroupingEngineV1: @unchecked Sendable {
    public let policy: ItemGroupingPolicyV1
    public let profile: GroupingCapabilityProfileV1
    public let evidenceGraph: ContentIdentityEvidenceGraphV1
    public let accumulator = ContentItemEvidenceAccumulatorV1()
    private let lock = NSLock()

    public struct ItemRecord {
        public var id: ContentItemID
        public var revision: ContentIdentityRevision
        public var shots: [ShotDescriptorV1]
        public var provisional: Bool
        public var dnaID: ContentDNAID?
        public var safeAdmissionCached: Bool = false       // §7 subject: may NEVER leak across uncertain boundaries
    }
    private(set) public var itemsInOrder: [ItemRecord] = []
    private var nextItemRaw: UInt64 = 0
    private var nextDNARaw: UInt64 = 0
    private var lastBoundaryMs: Double = -1e12
    private(set) public var revisions: [ContentIdentityRevision] = []

    public init(policy: ItemGroupingPolicyV1 = .frozenV1, profile: GroupingCapabilityProfileV1 = .appFull,
                evidenceGraph: ContentIdentityEvidenceGraphV1 = .init()) {
        self.policy = policy; self.profile = profile; self.evidenceGraph = evidenceGraph
    }

    public var confirmedOrProvisionalItemCount: Int { itemsInOrder.count }
    public var currentItem: ItemRecord? { itemsInOrder.last }

    private func themeDistance(_ a: SegmentFrameV4, _ item: ItemRecord) -> Double {
        // min distance of the incoming shot's center/global signature to the item's recent shots (visual continuity)
        let refs = item.shots.suffix(6)
        guard !refs.isEmpty else { return 1 }
        return refs.map { r -> Double in
            let d = a.regions.distances(to: r.representative.regions)
            return 0.6 * d.center + 0.25 * d.global + 0.15 * d.histogram
        }.min() ?? 1
    }
    private func chromeDistance(_ a: SegmentFrameV4, _ item: ItemRecord) -> Double {
        guard let r = item.shots.last else { return 1 }
        let d = a.regions.distances(to: r.representative.regions)
        return (d.top + d.bottom) / 2
    }

    private func openItem(with shot: ShotDescriptorV1, provisional: Bool, reason: String) -> ItemRecord {
        nextItemRaw += 1
        let rev = ContentIdentityRevision(number: 1, lifecycle: provisional ? .provisional : .confirmed, reason: reason)
        let rec = ItemRecord(id: ContentItemID(nextItemRaw), revision: rev, shots: [shot], provisional: provisional)
        itemsInOrder.append(rec); revisions.append(rev)
        accumulator.addShot(shot, to: rec.id, provenance: reason)
        return rec
    }

    /// Process a committed shot boundary. Decides SAME_ITEM / NEW_ITEM / AMBIGUOUS per §6 rules.
    public func process(_ shot: ShotDescriptorV1, cachePrior: IdentityCacheOutcomeV1 = .miss) -> ItemGroupingDecisionV1 {
        lock.lock(); defer { lock.unlock() }
        let now = shot.startMs
        guard var item = itemsInOrder.last else {
            let rec = openItem(with: shot, provisional: false, reason: "session-start")
            lastBoundaryMs = now
            return ItemGroupingDecisionV1(state: .newItemConfirmed, itemID: rec.id, itemRevision: rec.revision,
                                          openedNewItem: true, provisional: false, mergeScore: 0, newScore: 1,
                                          evidence: [], safeAdmissionInheritance: false)
        }
        let prevShot = item.shots.last!
        var merge = 0.0, newer = 0.0
        var collected: [IdentityEvidenceEdgeV1] = []
        func ev(_ m: EvidenceModalityV1, _ src: String, same: Bool, _ c: Double, cap: String) {
            let e = evidenceGraph.add(modality: m, source: src, from: prevShot.shotID, to: shot.shotID, supportsSameItem: same,
                                      confidence: c, atMs: now, privacy: .derivedNonReconstructive, capability: cap,
                                      modelVersion: policy.revision)
            collected.append(e)
            if same { merge += c } else { newer += c }
        }
        // TEMPORAL / interaction (§5): swipe = user gesture = strong new-item; crossfade mild; cut weak merge prior.
        switch shot.transitionIn {
        case .swipeConfirmed: ev(.temporal, "swipe-gate", same: false, policy.wSwipeConfirmed, cap: "tier0-temporal")
        case .crossfade: ev(.temporal, "crossfade", same: false, policy.wCrossfade, cap: "tier0-temporal")
        case .appSurface: ev(.surface, "surface-change", same: false, policy.wChromeChange, cap: "tier0-surface")
        case .cut: ev(.temporal, "cut-prior", same: true, policy.wCutPrior, cap: "tier0-temporal")
        case .sessionStart: break
        }
        // cadence: an edit-burst cut (short gap) is merge evidence; a long-watched shot before transition is new evidence
        let gap = now - lastBoundaryMs
        if shot.transitionIn == .cut && gap < policy.burstGapMs { ev(.temporal, "edit-burst", same: true, policy.wBurstCadence, cap: "tier0-temporal") }
        if prevShot.durationMs >= policy.longDwellMs { ev(.temporal, "long-dwell", same: false, policy.wLongDwell, cap: "tier0-temporal") }
        // VISUAL theme continuity vs the item (§5 visual)
        let theme = themeDistance(shot.representative, item)
        if theme <= policy.themeContinuityMax { ev(.visual, "theme-continuity", same: true, policy.wThemeContinuity, cap: "tier0-visual") }
        else if theme >= policy.themeDiscontinuityMin { ev(.visual, "theme-discontinuity", same: false, policy.wThemeDiscontinuity, cap: "tier0-visual") }
        // UI/SURFACE chrome continuity (weak same-app signal; change = app/surface transition)
        let chrome = chromeDistance(shot.representative, item)
        if chrome <= policy.chromeSameMax { ev(.surface, "chrome-same", same: true, policy.wChromeSame, cap: "tier0-surface") }
        else if chrome >= policy.chromeChangeMin { ev(.surface, "chrome-change", same: false, policy.wChromeChange, cap: "tier0-surface") }
        // TEXT caption fingerprint (Tier 1 — app profile only; nil = honestly unavailable)
        if profile == .appFull, let c = shot.captionFingerprint {
            let itemCaps = accumulator.items[item.id]?.captionFingerprints ?? []
            if itemCaps.contains(c) { ev(.text, "caption-match", same: true, policy.wCaptionMatch, cap: "tier1-text") }
            else if !itemCaps.isEmpty { ev(.text, "caption-change", same: false, policy.wCaptionChange, cap: "tier1-text") }
        }
        // AUDIO continuity (Tier 1)
        if profile == .appFull, let a = shot.audioContinuityWithPrevious {
            if a { ev(.audio, "audio-continuity", same: true, policy.wAudioContinuity, cap: "tier1-audio") }
            else { ev(.audio, "audio-break", same: false, policy.wAudioBreak, cap: "tier1-audio") }
        }
        // CACHE prior (§5/§11)
        if case .hit(_, let conf) = cachePrior { ev(.cache, "dna-cache-hit", same: false, policy.wCachePrior * conf, cap: "tier0-cache") }
        // guard: unbounded internal cuts must not grow one item forever
        if item.shots.count >= policy.maxShotsPerItem { newer += 0.2 }

        lastBoundaryMs = now
        // §6/§7 decision. Merge is precision-first: strong new-item evidence vetoes a merge.
        let strongNew = shot.transitionIn == .swipeConfirmed || chrome >= policy.chromeChangeMin
        if newer >= policy.confirmNewThreshold && newer >= merge + policy.decisionMargin {
            let rec = openItem(with: shot, provisional: false, reason: "new-item-evidence")
            return ItemGroupingDecisionV1(state: .newItemConfirmed, itemID: rec.id, itemRevision: rec.revision,
                                          openedNewItem: true, provisional: false, mergeScore: merge, newScore: newer,
                                          evidence: collected, safeAdmissionInheritance: false)
        }
        if merge >= policy.confirmSameThreshold && merge >= newer + policy.decisionMargin && !strongNew {
            item.shots.append(shot)
            itemsInOrder[itemsInOrder.count - 1] = item
            accumulator.addShot(shot, to: item.id, provenance: "same-item-evidence")
            return ItemGroupingDecisionV1(state: .sameItemConfirmed, itemID: item.id, itemRevision: item.revision,
                                          openedNewItem: false, provisional: item.provisional, mergeScore: merge, newScore: newer,
                                          evidence: collected, safeAdmissionInheritance: !item.provisional)   // §7
        }
        // §6 rule 3 + §7: insufficient evidence → AMBIGUOUS → provisional split; NEVER inherit safe admission.
        accumulator.reportConflict(item: item.id)
        let rec = openItem(with: shot, provisional: true, reason: "ambiguous-provisional-split")
        return ItemGroupingDecisionV1(state: .ambiguous, itemID: rec.id, itemRevision: rec.revision,
                                      openedNewItem: true, provisional: true, mergeScore: merge, newScore: newer,
                                      evidence: collected, safeAdmissionInheritance: false)
    }

    /// §6 rule 6 — later evidence may revise a PROVISIONAL split back into the previous item (versioned merge).
    @discardableResult
    public func reviseMergeProvisional(itemID: ContentItemID, strongEvidenceConfidence: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard strongEvidenceConfidence >= 0.8,
              let idx = itemsInOrder.firstIndex(where: { $0.id == itemID }), idx > 0,
              itemsInOrder[idx].provisional else { return false }
        var target = itemsInOrder[idx - 1]
        let merged = itemsInOrder.remove(at: idx)
        target.shots.append(contentsOf: merged.shots)
        target.revision = ContentIdentityRevision(number: target.revision.number + 1, lifecycle: .merged,
                                                  reason: "late-strong-evidence")
        itemsInOrder[idx - 1] = target
        revisions.append(target.revision)
        for s in merged.shots { accumulator.addShot(s, to: target.id, provenance: "revision-merge") }
        return true
    }

    /// §2/§10 — splitting an item invalidates its DNA (identity changed; cached understanding may not apply).
    public func splitItem(itemID: ContentItemID, atShotIndex: Int, dnaInvalidator: (ContentDNAID) -> Void) -> ContentItemID? {
        lock.lock(); defer { lock.unlock() }
        guard let idx = itemsInOrder.firstIndex(where: { $0.id == itemID }),
              atShotIndex > 0, atShotIndex < itemsInOrder[idx].shots.count else { return nil }
        var original = itemsInOrder[idx]
        let movedShots = Array(original.shots[atShotIndex...])
        original.shots = Array(original.shots[..<atShotIndex])
        original.revision = ContentIdentityRevision(number: original.revision.number + 1, lifecycle: .split, reason: "identity-split")
        if let dna = original.dnaID { dnaInvalidator(dna); original.dnaID = nil }
        itemsInOrder[idx] = original
        revisions.append(original.revision)
        nextItemRaw += 1
        let rev = ContentIdentityRevision(number: 1, lifecycle: .provisional, reason: "split-remainder")
        let newRec = ItemRecord(id: ContentItemID(nextItemRaw), revision: rev, shots: movedShots, provisional: true)
        itemsInOrder.insert(newRec, at: idx + 1)
        revisions.append(rev)
        return newRec.id
    }

    /// §10 mint item-level ContentDNA (score stays OFF — DNA carries evidence, never a numeric suitability).
    public func mintDNA(for itemID: ContentItemID, nowMs: Double, ttlMs: Double = 3_600_000) -> ContentDNAItemV1? {
        lock.lock(); defer { lock.unlock() }
        guard let idx = itemsInOrder.firstIndex(where: { $0.id == itemID }) else { return nil }
        var rec = itemsInOrder[idx]
        nextDNARaw += 1
        let summary = accumulator.items[itemID]
        var modality: [EvidenceModalityV1: Int] = [:]
        for e in evidenceGraph.edges where rec.shots.contains(where: { $0.shotID == e.toShot }) {
            modality[e.modality, default: 0] += 1
        }
        let dna = ContentDNAItemV1(dnaID: ContentDNAID(nextDNARaw), itemID: itemID, revision: rec.revision,
                                   shotCount: rec.shots.count, sceneCount: 1,
                                   modalitySummary: modality,
                                   temporalSpanMs: (summary?.lastMs ?? 0) - (summary?.firstMs ?? 0),
                                   riskEscalated: summary?.riskEscalated ?? false,
                                   uncertainty: rec.provisional ? 0.8 : 0.2,
                                   provenance: summary?.provenance ?? [], privacyClass: .derivedNonReconstructive,
                                   modelVersions: [policy.revision, "boundary-policy-v5"],
                                   expiresAtMs: nowMs + ttlMs)
        rec.dnaID = dna.dnaID
        itemsInOrder[idx] = rec
        return dna
    }
}
