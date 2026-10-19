import Foundation

// MARK: - PROMPT 009A-R1 — profile-aware item grouping V2.
// The P009A device failure was NOT "the brain cannot group items" — it was "the brain was calibrated for evidence
// the extension does not possess" (Tier-0 merge ceiling 0.49 < global threshold 0.50). V2 makes the evidence
// PROFILE canonical: each profile declares its channels + theoretical ceiling, same-scores are normalized by the
// PROFILE ceiling, missing evidence is never negative evidence, and every runnable profile gets its own predeclared
// lab gate. The §7 strong-new veto remains ABSOLUTE. v1 engine/policy stay frozen as evidence (untouched).

// MARK: - §2 canonical identity evidence profiles.

public enum IdentityEvidenceChannelV1: String, Sendable, Codable, CaseIterable {
    // same-item channels
    case themeContinuity = "THEME_CONTINUITY"               // content signature proximity
    case projectionContinuity = "PROJECTION_CONTINUITY"     // §6A cross-shot row/col structure
    case histogramContinuity = "HISTOGRAM_CONTINUITY"       // §6B compact luma histogram (supportive only)
    case editCadence = "EDIT_CADENCE"                       // §6C burst pattern
    case chromeContinuity = "CHROME_CONTINUITY"
    case regionalContinuity = "REGIONAL_CONTINUITY"         // §6D edges/global persistence
    case cutPrior = "CUT_PRIOR"
    case captionMatch = "CAPTION_MATCH"                     // Tier-1 only
    case audioContinuity = "AUDIO_CONTINUITY"               // Tier-1 only
}

public struct IdentityEvidenceProfileV1: Sendable, Codable, Equatable {
    public let name: String
    public let availableSameChannels: [IdentityEvidenceChannelV1]
    public let unavailableModalities: [String]
    public let resourceBudget: String
    public let privacyClass: String
    public let mergePolicyRevision: String
    public let fallback: String
    public init(name: String, availableSameChannels: [IdentityEvidenceChannelV1], unavailableModalities: [String],
                resourceBudget: String, privacyClass: String, mergePolicyRevision: String, fallback: String) {
        self.name = name; self.availableSameChannels = availableSameChannels
        self.unavailableModalities = unavailableModalities; self.resourceBudget = resourceBudget
        self.privacyClass = privacyClass; self.mergePolicyRevision = mergePolicyRevision; self.fallback = fallback
    }
    public static let extensionFastTier0 = IdentityEvidenceProfileV1(
        name: "EXTENSION_FAST_TIER0",
        availableSameChannels: [.themeContinuity, .projectionContinuity, .histogramContinuity, .editCadence,
                                .chromeContinuity, .regionalContinuity, .cutPrior],
        unavailableModalities: ["captions", "speech", "audio", "app-bundle-identity", "cloud/VLM"],
        resourceBudget: "O(1) per shot commit; no Vision/VLM; ~50MB extension",
        privacyClass: "DERIVED_NON_RECONSTRUCTIVE", mergePolicyRevision: "item-grouping-policy-v2-extension-tier0",
        fallback: "AMBIGUOUS provisional split (never fake certainty)")
    public static let appFullTier1 = IdentityEvidenceProfileV1(
        name: "APP_FULL_TIER1",
        availableSameChannels: IdentityEvidenceChannelV1.allCases,
        unavailableModalities: ["app-bundle-identity (cross-app)", "cloud/VLM (pending packs)"],
        resourceBudget: "Tier-0 first; ambiguity escalation to caption/audio where legitimately in-process",
        privacyClass: "DERIVED_NON_RECONSTRUCTIVE", mergePolicyRevision: "item-grouping-policy-v2-app-tier1",
        fallback: "AMBIGUOUS provisional split")
    /// BLOCKED until official shared-container capability exists (§3): declared, not runnable.
    public static let futureSharedTier1 = IdentityEvidenceProfileV1(
        name: "FUTURE_SHARED_TIER1", availableSameChannels: [], unavailableModalities: ["ALL — capability BLOCKED"],
        resourceBudget: "BLOCKED", privacyClass: "BLOCKED", mergePolicyRevision: "BLOCKED", fallback: "BLOCKED")
}

// MARK: - §6 cheap Tier-0 evidence components (extension-safe; derived-only; no raw retention).

public enum CrossShotProjectionContinuityV1 {
    /// Zero-offset correlation of row+col projections — coarse spatial/layout structure continuity (§6A).
    public static func score(_ a: SegmentFrameV4, _ b: SegmentFrameV4) -> Double {
        let r = CoherentTranslationV4.score(a.rowProjection, b.rowProjection, maxOffset: 0).peak
        let c = CoherentTranslationV4.score(a.colProjection, b.colProjection, maxOffset: 0).peak
        return max(0, (r + c) / 2)
    }
}
public enum CrossShotHistogramContinuityV1 {
    /// Compact luma-histogram L1 distance (0..1). Supportive only — never sole merge evidence (§6B).
    public static func distance(_ a: SegmentFrameV4, _ b: SegmentFrameV4) -> Double {
        let ha = a.regions.lumaHistogram, hb = b.regions.lumaHistogram
        guard ha.count == hb.count, !ha.isEmpty else { return 1 }
        let tot = Double(max(1, ha.reduce(0,+)))
        var s = 0; for i in ha.indices { s += abs(ha[i] - hb[i]) }
        return min(1, Double(s) / (2 * tot))
    }
}
public enum EditCadenceContinuityV1 {
    /// §6C: a plain cut arriving within the burst window of the previous boundary = edit-burst continuity.
    public static func isBurst(gapMs: Double, transition: ShotTransitionInV1, burstGapMs: Double) -> Bool {
        transition == .cut && gapMs < burstGapMs
    }
}
public enum CrossShotRegionalContinuityV1 {
    /// §6D: persistence of edges+global layout regions (normalized; reliability handled upstream; no app geometry).
    public static func distance(_ a: SegmentFrameV4, _ b: SegmentFrameV4) -> Double {
        let d = a.regions.distances(to: b.regions)
        return (d.left + d.right + d.global) / 3
    }
}

// MARK: - §8 evidence-ceiling-aware policy. Same-score normalized by PROFILE ceiling; missing evidence adds 0.

public struct ProfileAwareItemGroupingPolicyV2: Sendable, Codable, Equatable {
    public var revision: String
    public var profileName: String
    // same-channel weights (channel absent from profile → contributes 0, NEVER negative)
    public var wTheme: Double, wProjection: Double, wHistogram: Double, wCadence: Double
    public var wChrome: Double, wRegional: Double, wCutPrior: Double
    public var wCaption: Double, wAudio: Double          // Tier-1 channels (0-weighted in Tier-0 ceiling)
    // new-item channel weights (profile-independent: all derivable in Tier 0 except caption/audio breaks)
    public var wSwipeNew: Double, wSurfaceNew: Double, wThemeDiscNew: Double, wProjectionBreakNew: Double
    public var wHistogramBreakNew: Double, wLongDwellNew: Double, wCrossfadeNew: Double
    public var wCaptionChangeNew: Double, wAudioBreakNew: Double, wCachePriorNew: Double
    // feature thresholds
    public var themeContinuityMax: Double, themeDiscontinuityMin: Double
    public var strongThemeContinuityMax: Double
    public var projectionContinuityMin: Double, projectionBreakMax: Double
    public var histogramContinuityMax: Double, histogramBreakMin: Double
    public var chromeSameMax: Double, chromeChangeMin: Double
    public var regionalContinuityMax: Double
    public var burstGapMs: Double, longDwellMs: Double
    // §9 monotonic rule-based decision (deterministic, inspectable, tiny, versioned, profile-specific)
    public var confirmSameNormalized: Double     // on S = rawSame / profileCeiling
    public var confirmNewRaw: Double
    public var sameVetoLevel: Double             // high S makes a weak NEW suspicious → AMBIGUOUS
    public var newVetoLevel: Double              // any N ≥ this blocks SAME
    public var maxShotsPerItem: Int

    public init(revision: String, profileName: String,
                wTheme: Double = 0.20, wProjection: Double = 0.20, wHistogram: Double = 0.15, wCadence: Double = 0.15,
                wChrome: Double = 0.10, wRegional: Double = 0.10, wCutPrior: Double = 0.05,
                wCaption: Double = 0.35, wAudio: Double = 0.30,
                wSwipeNew: Double = 0.50, wSurfaceNew: Double = 0.40, wThemeDiscNew: Double = 0.25,
                wProjectionBreakNew: Double = 0.20, wHistogramBreakNew: Double = 0.20, wLongDwellNew: Double = 0.15,
                wCrossfadeNew: Double = 0.15, wCaptionChangeNew: Double = 0.30, wAudioBreakNew: Double = 0.20,
                wCachePriorNew: Double = 0.30,
                themeContinuityMax: Double = 0.22, themeDiscontinuityMin: Double = 0.30, strongThemeContinuityMax: Double = 0.12,
                projectionContinuityMin: Double = 0.80, projectionBreakMax: Double = 0.30,
                histogramContinuityMax: Double = 0.15, histogramBreakMin: Double = 0.35,
                chromeSameMax: Double = 0.10, chromeChangeMin: Double = 0.30, regionalContinuityMax: Double = 0.15,
                burstGapMs: Double = 3200, longDwellMs: Double = 3800,
                confirmSameNormalized: Double = 0.50, confirmNewRaw: Double = 0.35,
                sameVetoLevel: Double = 0.55, newVetoLevel: Double = 0.30, maxShotsPerItem: Int = 64) {
        self.revision = revision; self.profileName = profileName
        self.wTheme = wTheme; self.wProjection = wProjection; self.wHistogram = wHistogram; self.wCadence = wCadence
        self.wChrome = wChrome; self.wRegional = wRegional; self.wCutPrior = wCutPrior
        self.wCaption = wCaption; self.wAudio = wAudio
        self.wSwipeNew = wSwipeNew; self.wSurfaceNew = wSurfaceNew; self.wThemeDiscNew = wThemeDiscNew
        self.wProjectionBreakNew = wProjectionBreakNew; self.wHistogramBreakNew = wHistogramBreakNew
        self.wLongDwellNew = wLongDwellNew; self.wCrossfadeNew = wCrossfadeNew
        self.wCaptionChangeNew = wCaptionChangeNew; self.wAudioBreakNew = wAudioBreakNew; self.wCachePriorNew = wCachePriorNew
        self.themeContinuityMax = themeContinuityMax; self.themeDiscontinuityMin = themeDiscontinuityMin
        self.strongThemeContinuityMax = strongThemeContinuityMax
        self.projectionContinuityMin = projectionContinuityMin; self.projectionBreakMax = projectionBreakMax
        self.histogramContinuityMax = histogramContinuityMax; self.histogramBreakMin = histogramBreakMin
        self.chromeSameMax = chromeSameMax; self.chromeChangeMin = chromeChangeMin; self.regionalContinuityMax = regionalContinuityMax
        self.burstGapMs = burstGapMs; self.longDwellMs = longDwellMs
        self.confirmSameNormalized = confirmSameNormalized; self.confirmNewRaw = confirmNewRaw
        self.sameVetoLevel = sameVetoLevel; self.newVetoLevel = newVetoLevel; self.maxShotsPerItem = maxShotsPerItem
    }

    /// §8 profile ceiling = sum of weights of the channels the profile actually possesses.
    public func sameCeiling(for profile: IdentityEvidenceProfileV1) -> Double {
        var c = 0.0
        for ch in profile.availableSameChannels {
            switch ch {
            case .themeContinuity: c += wTheme
            case .projectionContinuity: c += wProjection
            case .histogramContinuity: c += wHistogram
            case .editCadence: c += wCadence
            case .chromeContinuity: c += wChrome
            case .regionalContinuity: c += wRegional
            case .cutPrior: c += wCutPrior
            case .captionMatch: c += wCaption
            case .audioContinuity: c += wAudio
            }
        }
        return max(0.0001, c)
    }

    /// FROZEN after TUNE only (see P009A_R1_TUNE_RESULTS).
    public static let frozenTier0 = ProfileAwareItemGroupingPolicyV2(
        revision: "item-grouping-policy-v2-extension-tier0", profileName: "EXTENSION_FAST_TIER0")
    public static let frozenTier1 = ProfileAwareItemGroupingPolicyV2(
        revision: "item-grouping-policy-v2-app-tier1", profileName: "APP_FULL_TIER1")
}

// MARK: - §20 thermal-aware degradation contract (device reached FAIR for 45/73 decisions).

public enum ThermalBucketV1: String, Sendable, Codable { case nominal, fair, serious, critical }
public enum ThermalAwareDegradationV1 {
    /// Under FAIR, OPTIONAL deep work defers (cheap mandatory path continues); serious/critical → no deep work.
    public static func allowOptionalDeepWork(_ t: ThermalBucketV1) -> Bool { t == .nominal }
    public static func allowSafetyCriticalDeepWork(_ t: ThermalBucketV1) -> Bool { t == .nominal || t == .fair }
}

// MARK: - §6/§8 the V2 grouping engine. Reuses ShotDescriptorV1 / evidence graph / accumulator / decision types.

public final class ContentItemGroupingEngineV2: @unchecked Sendable {
    public let policy: ProfileAwareItemGroupingPolicyV2
    public let profile: IdentityEvidenceProfileV1
    public let evidenceGraph: ContentIdentityEvidenceGraphV1
    public let accumulator = ContentItemEvidenceAccumulatorV1()
    private let lock = NSLock()
    public typealias ItemRecord = ContentItemGroupingEngineV1.ItemRecord
    private(set) public var itemsInOrder: [ItemRecord] = []
    private(set) public var revisions: [ContentIdentityRevision] = []
    private var nextItemRaw: UInt64 = 0
    private var nextDNARaw: UInt64 = 0
    private var lastBoundaryMs: Double = -1e12

    public init(policy: ProfileAwareItemGroupingPolicyV2, profile: IdentityEvidenceProfileV1,
                evidenceGraph: ContentIdentityEvidenceGraphV1 = .init()) {
        self.policy = policy; self.profile = profile; self.evidenceGraph = evidenceGraph
    }
    public var confirmedOrProvisionalItemCount: Int { itemsInOrder.count }
    public var currentItem: ItemRecord? { itemsInOrder.last }
    public var sameCeiling: Double { policy.sameCeiling(for: profile) }

    private func has(_ ch: IdentityEvidenceChannelV1) -> Bool { profile.availableSameChannels.contains(ch) }
    private func themeDistance(_ a: SegmentFrameV4, _ item: ItemRecord) -> Double {
        let refs = item.shots.suffix(6); guard !refs.isEmpty else { return 1 }
        return refs.map { r -> Double in
            let d = a.regions.distances(to: r.representative.regions)
            return 0.7 * d.center + 0.3 * d.global
        }.min() ?? 1
    }
    private func openItem(with shot: ShotDescriptorV1, provisional: Bool, reason: String) -> ItemRecord {
        nextItemRaw += 1
        let rev = ContentIdentityRevision(number: 1, lifecycle: provisional ? .provisional : .confirmed, reason: reason)
        let rec = ItemRecord(id: ContentItemID(nextItemRaw), revision: rev, shots: [shot], provisional: provisional)
        itemsInOrder.append(rec); revisions.append(rev)
        accumulator.addShot(shot, to: rec.id, provenance: reason)
        return rec
    }

    public func process(_ shot: ShotDescriptorV1, cachePrior: IdentityCacheOutcomeV1 = .miss) -> ItemGroupingDecisionV1 {
        lock.lock(); defer { lock.unlock() }
        let now = shot.startMs
        guard var item = itemsInOrder.last, let prevShot = itemsInOrder.last?.shots.last else {
            let rec = openItem(with: shot, provisional: false, reason: "session-start")
            lastBoundaryMs = now
            return ItemGroupingDecisionV1(state: .newItemConfirmed, itemID: rec.id, itemRevision: rec.revision,
                                          openedNewItem: true, provisional: false, mergeScore: 0, newScore: 1,
                                          evidence: [], safeAdmissionInheritance: false)
        }
        var same = 0.0, newer = 0.0
        var collected: [IdentityEvidenceEdgeV1] = []
        var themeAnchor = false, burstAnchor = false, captionAnchor = false, audioAnchor = false
        func ev(_ m: EvidenceModalityV1, _ src: String, isSame: Bool, _ c: Double, cap: String) {
            let e = evidenceGraph.add(modality: m, source: src, from: prevShot.shotID, to: shot.shotID,
                                      supportsSameItem: isSame, confidence: c, atMs: now,
                                      privacy: .derivedNonReconstructive, capability: cap, modelVersion: policy.revision)
            collected.append(e)
            if isSame { same += c } else { newer += c }
        }
        let dChrome: Double = {
            let d = shot.representative.regions.distances(to: prevShot.representative.regions)
            return (d.top + d.bottom) / 2
        }()
        // ---- new-item channels (missing modality → nothing; never negative) ----
        var strongNew = false
        switch shot.transitionIn {
        case .swipeConfirmed: ev(.temporal, "swipe-confirmed", isSame: false, policy.wSwipeNew, cap: "tier0-temporal"); strongNew = true
        case .appSurface: ev(.surface, "surface-transition", isSame: false, policy.wSurfaceNew, cap: "tier0-surface"); strongNew = true
        case .crossfade: ev(.temporal, "crossfade", isSame: false, policy.wCrossfadeNew, cap: "tier0-temporal")
        case .cut: if has(.cutPrior) { ev(.temporal, "cut-prior", isSame: true, policy.wCutPrior, cap: "tier0-temporal") }
        case .sessionStart: break
        }
        if dChrome >= policy.chromeChangeMin { ev(.surface, "chrome-change", isSame: false, policy.wSurfaceNew, cap: "tier0-surface"); strongNew = true }
        let theme = themeDistance(shot.representative, item)
        if theme >= policy.themeDiscontinuityMin { ev(.visual, "theme-discontinuity", isSame: false, policy.wThemeDiscNew, cap: "tier0-visual") }
        let proj = CrossShotProjectionContinuityV1.score(shot.representative, prevShot.representative)
        if proj <= policy.projectionBreakMax { ev(.visual, "projection-break", isSame: false, policy.wProjectionBreakNew, cap: "tier0-visual") }
        let hist = CrossShotHistogramContinuityV1.distance(shot.representative, prevShot.representative)
        if hist >= policy.histogramBreakMin { ev(.visual, "histogram-break", isSame: false, policy.wHistogramBreakNew, cap: "tier0-visual") }
        if prevShot.durationMs >= policy.longDwellMs { ev(.temporal, "long-dwell", isSame: false, policy.wLongDwellNew, cap: "tier0-temporal") }
        if case .hit(_, let conf) = cachePrior { ev(.cache, "dna-cache-prior", isSame: false, policy.wCachePriorNew * conf, cap: "tier0-cache") }
        if profile.availableSameChannels.contains(.captionMatch), let c = shot.captionFingerprint {
            let caps = accumulator.items[item.id]?.captionFingerprints ?? []
            if caps.contains(c) { ev(.text, "caption-match", isSame: true, policy.wCaption, cap: "tier1-text"); captionAnchor = true }
            else if !caps.isEmpty { ev(.text, "caption-change", isSame: false, policy.wCaptionChangeNew, cap: "tier1-text") }
        }
        if profile.availableSameChannels.contains(.audioContinuity), let a = shot.audioContinuityWithPrevious {
            if a { ev(.audio, "audio-continuity", isSame: true, policy.wAudio, cap: "tier1-audio"); audioAnchor = true }
            else { ev(.audio, "audio-break", isSame: false, policy.wAudioBreakNew, cap: "tier1-audio") }
        }
        // ---- same-item channels (profile-gated; absent channel contributes 0) ----
        if has(.themeContinuity) && theme <= policy.themeContinuityMax {
            ev(.visual, "theme-continuity", isSame: true, policy.wTheme, cap: "tier0-visual")
            // Two-level anchor: a STRONG theme match anchors regardless of dwell; a WEAK match anchors only at
            // edit cadence (no long dwell before the cut). A similar-but-different item after normal watching
            // (long dwell) must NOT merge on a weak theme — that is the device-like false-merge mechanism.
            if theme <= policy.strongThemeContinuityMax { themeAnchor = true }
            else if prevShot.durationMs < policy.longDwellMs { themeAnchor = true }
        }
        if has(.projectionContinuity) && proj >= policy.projectionContinuityMin { ev(.visual, "projection-continuity", isSame: true, policy.wProjection, cap: "tier0-visual") }
        if has(.histogramContinuity) && hist <= policy.histogramContinuityMax { ev(.visual, "histogram-continuity", isSame: true, policy.wHistogram, cap: "tier0-visual") }
        let gap = now - lastBoundaryMs
        if has(.editCadence) && EditCadenceContinuityV1.isBurst(gapMs: gap, transition: shot.transitionIn, burstGapMs: policy.burstGapMs) {
            ev(.temporal, "edit-burst", isSame: true, policy.wCadence, cap: "tier0-temporal"); burstAnchor = true
        }
        if has(.chromeContinuity) && dChrome <= policy.chromeSameMax { ev(.surface, "chrome-continuity", isSame: true, policy.wChrome, cap: "tier0-surface") }
        let regional = CrossShotRegionalContinuityV1.distance(shot.representative, prevShot.representative)
        if has(.regionalContinuity) && regional <= policy.regionalContinuityMax {
            ev(.surface, "regional-continuity", isSame: true, policy.wRegional, cap: "tier0-surface")
        }
        if item.shots.count >= policy.maxShotsPerItem { newer += 0.2 }
        lastBoundaryMs = now

        // ---- §9 monotonic decision on NORMALIZED same score (profile ceiling) + raw new score ----
        let S = same / sameCeiling
        let N = newer
        // §6B/§6C guard: style-only continuity (projection/histogram/chrome/regional) AND cadence can never be the
        // sole merge basis — SAME requires a CONTENT or CROSS-MODAL anchor (theme / caption / audio). Edit-burst
        // SUPPORTS the score but cannot anchor (a style-similar different item at burst cadence must not merge).
        let anchored = themeAnchor || captionAnchor || audioAnchor
        _ = burstAnchor
        let state: ItemGroupingStateV1
        if strongNew {                                                   // §7 veto is ABSOLUTE
            state = N >= policy.confirmNewRaw ? .newItemConfirmed : .ambiguous
        } else if N >= policy.confirmNewRaw && S < policy.sameVetoLevel {
            state = .newItemConfirmed
        } else if S >= policy.confirmSameNormalized && N < policy.newVetoLevel && anchored {
            state = .sameItemConfirmed
        } else {
            state = .ambiguous
        }
        // P009A-R2 (audit B1): expose the RAW per-channel values — derived scalars only. This is the telemetry the
        // measured-evidence run logs; it removes the need to infer channel behavior from aggregate S/N.
        let channels = GroupingChannelTelemetryV1(
            themeDistance: theme, projectionCorrelation: proj, histogramDistance: hist,
            chromeDistance: dChrome, regionalDistance: regional, gapSinceLastBoundaryMs: gap,
            previousShotDwellMs: prevShot.durationMs,
            elapsedItemMs: now - (item.shots.first?.startMs ?? now),
            strongNew: strongNew, anchored: anchored,
            firedEvidence: collected.map { $0.source.raw })
        switch state {
        case .newItemConfirmed:
            let rec = openItem(with: shot, provisional: false, reason: "new-item-evidence")
            return ItemGroupingDecisionV1(state: .newItemConfirmed, itemID: rec.id, itemRevision: rec.revision,
                                          openedNewItem: true, provisional: false, mergeScore: S, newScore: N,
                                          evidence: collected, safeAdmissionInheritance: false, channels: channels)
        case .sameItemConfirmed:
            item.shots.append(shot)
            itemsInOrder[itemsInOrder.count - 1] = item
            accumulator.addShot(shot, to: item.id, provenance: "same-item-evidence")
            return ItemGroupingDecisionV1(state: .sameItemConfirmed, itemID: item.id, itemRevision: item.revision,
                                          openedNewItem: false, provisional: item.provisional, mergeScore: S, newScore: N,
                                          evidence: collected, safeAdmissionInheritance: !item.provisional, channels: channels)
        default:
            accumulator.reportConflict(item: item.id)
            let rec = openItem(with: shot, provisional: true, reason: "ambiguous-provisional-split")
            return ItemGroupingDecisionV1(state: .ambiguous, itemID: rec.id, itemRevision: rec.revision,
                                          openedNewItem: true, provisional: true, mergeScore: S, newScore: N,
                                          evidence: collected, safeAdmissionInheritance: false, channels: channels)
        }
    }

    /// §11 versioned deferred merge of a PROVISIONAL item back into its predecessor (no admission inheritance before).
    @discardableResult
    public func mergeProvisionalBack(itemID: ContentItemID, dnaInvalidator: (ContentDNAID) -> Void) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let idx = itemsInOrder.firstIndex(where: { $0.id == itemID }), idx > 0, itemsInOrder[idx].provisional else { return false }
        var target = itemsInOrder[idx - 1]
        let merged = itemsInOrder.remove(at: idx)
        if let dna = target.dnaID { dnaInvalidator(dna); target.dnaID = nil }   // identity changed → DNA rebuild
        target.shots.append(contentsOf: merged.shots)
        target.revision = ContentIdentityRevision(number: target.revision.number + 1, lifecycle: .merged, reason: "deferred-coalesce")
        itemsInOrder[idx - 1] = target
        revisions.append(target.revision)
        for s in merged.shots { accumulator.addShot(s, to: target.id, provenance: "deferred-coalesce") }
        return true
    }
    public func mintDNA(for itemID: ContentItemID, nowMs: Double, ttlMs: Double = 3_600_000) -> ContentDNAItemV1? {
        lock.lock(); defer { lock.unlock() }
        guard let idx = itemsInOrder.firstIndex(where: { $0.id == itemID }) else { return nil }
        var rec = itemsInOrder[idx]
        nextDNARaw += 1
        let dna = ContentDNAItemV1(dnaID: ContentDNAID(nextDNARaw), itemID: itemID, revision: rec.revision,
                                   shotCount: rec.shots.count, sceneCount: 1, modalitySummary: [:],
                                   temporalSpanMs: (rec.shots.last?.endMs ?? 0) - (rec.shots.first?.startMs ?? 0),
                                   riskEscalated: accumulator.items[itemID]?.riskEscalated ?? false,
                                   uncertainty: rec.provisional ? 0.8 : 0.2, provenance: [policy.revision],
                                   privacyClass: .derivedNonReconstructive,
                                   modelVersions: [policy.revision, "boundary-policy-v5"], expiresAtMs: nowMs + ttlMs)
        rec.dnaID = dna.dnaID; itemsInOrder[idx] = rec
        return dna
    }
}

// MARK: - §11 deferred item coalescer: an ambiguous internal cut may merge LATER on strong continuity evidence.

public final class DeferredItemCoalescerV1: @unchecked Sendable {
    public let minSupportingShots: Int
    public let themeContinuityMax: Double
    public let projectionContinuityMin: Double
    public private(set) var deferredMerges = 0
    public init(minSupportingShots: Int = 2, themeContinuityMax: Double = 0.22, projectionContinuityMin: Double = 0.80) {
        self.minSupportingShots = minSupportingShots; self.themeContinuityMax = themeContinuityMax
        self.projectionContinuityMin = projectionContinuityMin
    }
    /// Called after each decision. If the CURRENT item is provisional, has gathered enough shots, and its shots show
    /// CONTENT (theme) + layout continuity with the predecessor item's recent shots, and no strong-new cue entered it
    /// → merge back (versioned; DNA invalidated by the engine). Bounded: inspects ≤6 recent shots per side.
    @discardableResult
    public func tryCoalesce(engine: ContentItemGroupingEngineV2, dnaInvalidator: (ContentDNAID) -> Void) -> Bool {
        guard let cur = engine.currentItem, cur.provisional, cur.shots.count >= minSupportingShots,
              engine.itemsInOrder.count >= 2 else { return false }
        // no strong-new cue may have opened this provisional item
        if let first = cur.shots.first, first.transitionIn == .swipeConfirmed || first.transitionIn == .appSurface { return false }
        func supportCount(against refs: ArraySlice<ShotDescriptorV1>) -> Int {
            var supported = 0
            for s in cur.shots.suffix(6) {
                let bestTheme = refs.map { r -> Double in
                    let d = s.representative.regions.distances(to: r.representative.regions)
                    return 0.7 * d.center + 0.3 * d.global
                }.min() ?? 1
                let bestProj = refs.map { CrossShotProjectionContinuityV1.score(s.representative, $0.representative) }.max() ?? 0
                if bestTheme <= themeContinuityMax && bestProj >= projectionContinuityMin { supported += 1 }
            }
            return supported
        }
        let prev = engine.itemsInOrder[engine.itemsInOrder.count - 2]
        // CONTENT anchor required for a deferred merge (style alone never merges — same rule as the live path)
        if supportCount(against: prev.shots.suffix(6)) >= minSupportingShots {
            let ok = engine.mergeProvisionalBack(itemID: cur.id, dnaInvalidator: dnaInvalidator)
            if ok { deferredMerges += 1 }
            return ok
        }
        // SANDWICH repair: an outlier provisional sits between two runs of the SAME item (cur matches item k-2 and
        // the intermediate item is ALSO provisional, not strong-new) → chain-merge cur → prev → prevPrev.
        if prev.provisional, engine.itemsInOrder.count >= 3 {
            if let pf = prev.shots.first, pf.transitionIn == .swipeConfirmed || pf.transitionIn == .appSurface { return false }
            let prevPrev = engine.itemsInOrder[engine.itemsInOrder.count - 3]
            if supportCount(against: prevPrev.shots.suffix(6)) >= minSupportingShots {
                let first = engine.mergeProvisionalBack(itemID: cur.id, dnaInvalidator: dnaInvalidator)
                guard first, let combined = engine.currentItem, combined.provisional else { return first }
                let second = engine.mergeProvisionalBack(itemID: combined.id, dnaInvalidator: dnaInvalidator)
                if first || second { deferredMerges += 1 }
                return second
            }
        }
        return false
    }
}
