//
//  PrefetchCoordinatorV1.swift — §C: the PREFETCH PRE-EXPOSURE PIPELINE for the Controlled Reels Player.
//
//  BIG GOAL (mandate C, the centerpiece): while the user watches reel A, the NEXT reel (N+1 only) is evaluated
//  AHEAD OF TIME at low priority, so the moment the user swipes to it we can APPLY the already-computed decision
//  WITHOUT re-decoding/re-OCR'ing — a hidden reel is hidden BEFORE it starts, an allowed reel plays instantly, an
//  unknown reel still gets its honest gate. This is NOT a new decision engine: it drives the SAME ReelsDecisionEngine
//  / ShieldEvaluatorV2 / AdaptiveSampler path the on-demand flow uses (D3: identical decisions), only earlier and at
//  lower priority. It runs ONLY on OUR controlled surface (no third-party "we know the next reel" claim, rule 18).
//
//  WHY A SEPARATE COORDINATOR (not inside the brain): the brain is the pure per-item policy. Prefetch is an
//  ORCHESTRATION concern — WHEN to pre-evaluate, WHICH item (strictly N+1), the bounded cache keyed by the full C3
//  token, and REAL cancellation (C4). Keeping it separate means the cache/cancel/token logic is unit-testable without
//  the AVPlayer runtime, and the brain's decision semantics stay untouched.
//
//  C1  — N+1 ONLY. N+2/N+3 are deliberately NOT opened (unmeasured; the mandate forbids it until measured).
//  C2  — low-priority (.utility) Task runs the EXISTING evaluate path; the result is cached in a bounded RAM entry.
//  C3  — the cache key is the FULL token (session/content/assetFingerprint/policyRevision/evaluatorVersion/
//        providerVersion/generation/exceptionState/coverage). Any drift ⇒ the cache is invalid ⇒ re-evaluate.
//  C4  — foreground always beats prefetch; every listed trigger CANCELS the in-flight Task (real Task cancellation —
//        the sampler already honours Task.isCancelled, so decode/OCR actually stops, not just a token flip).
//  C5  — after the verdict, raw OCR text is STRIPPED from the cached decision (rule ids + timestamps + counts kept).
//  D1  — a valid cached decision is reused verbatim; UNKNOWN / PARTIAL_COVERAGE are preserved, never upgraded to CLEAR.
//
import Foundation
import GuardianCore
#if canImport(AVFoundation)
import AVFoundation

/// §C3 — the FULL prefetch token. A cached decision is reusable ONLY when every field still matches on swipe. Any
/// change (a new policy revision, a different asset, an advanced evaluation generation, a changed override/exception
/// state) invalidates the cache — so a stale pre-exposure result can never drive the wrong decision, and a "Yine de
/// göster" override can never be carried to a different reel (acceptance #7/#8).
public struct PrefetchTokenV1: Sendable, Equatable, Hashable {
    public let sessionID: String          // the player session; a new session never reuses a prior one's cache
    public let contentID: String          // the specific reel
    public let assetFingerprint: String   // the asset's content version (path + size + mtime) — content changed ⇒ miss
    public let policyRevision: UInt64      // the rule-set version; a rule change invalidates the cache
    public let evaluatorVersion: String    // the decision engine version
    public let providerVersion: String     // the evidence provider version
    public let generation: UInt64          // the brain's evaluation generation at prefetch time (supersede guard)
    public let exceptionState: String      // a stable digest of the user's override/exception state for THIS content
    public let coveragePlan: Int           // the planned sample budget the prefetch intended (coverage provenance)

    public init(sessionID: String, contentID: String, assetFingerprint: String, policyRevision: UInt64,
                evaluatorVersion: String, providerVersion: String, generation: UInt64,
                exceptionState: String, coveragePlan: Int) {
        self.sessionID = sessionID; self.contentID = contentID; self.assetFingerprint = assetFingerprint
        self.policyRevision = policyRevision; self.evaluatorVersion = evaluatorVersion
        self.providerVersion = providerVersion; self.generation = generation
        self.exceptionState = exceptionState; self.coveragePlan = coveragePlan
    }

    /// §C3 — a best-effort content-version fingerprint for a LOCAL owned asset: path + byte size + modification time.
    /// If the file is unreadable we fall back to the path alone (still content-scoped by id); the decision is never
    /// claimed more certain than the evidence — an unreadable asset simply never matches a prior fingerprint.
    public static func assetFingerprint(url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        return "\(url.lastPathComponent)|\(size)|\(Int(mtime))"
    }
}

/// §C5 — strip raw OCR text from a decision once the verdict is known. The cached pre-exposure decision keeps the
/// honest derived evidence (matched rule ids, examined timestamps, per-sample OUTCOME, coverage counts) but DISCARDS
/// the recognized screen text so no personal content lingers in the RAM cache after we no longer need it to decide.
/// The Video Kanıtı sheet for a prefetched item then shows sample dots + the matched rule, with an honest note that
/// raw text is unavailable (it was never retained). Pure function — testable without the player.
public enum PrefetchDecisionSanitizerV1 {
    public static func stripRawText(_ d: ReelDecisionV1) -> ReelDecisionV1 {
        let strippedTimed = d.timedEvidence.map { rec in
            ReelsTimedEvidenceV1(timestampSeconds: rec.timestampSeconds, modality: rec.modality,
                                 // keep the OCR STATUS (ran / ranNoText / notDecoded) but drop the recognized TEXT
                                 ocrStatus: rec.ocrStatus, text: "", matchedRuleID: rec.matchedRuleID)
        }
        return ReelDecisionV1(contentID: d.contentID, policyRevision: d.policyRevision, state: d.state,
                              intent: d.intent, matchState: d.matchState, layerDecision: d.layerDecision,
                              appliedAction: d.appliedAction, matchedRuleID: d.matchedRuleID,
                              provenance: d.provenance, coverage: d.coverage, uncertainty: d.uncertainty,
                              reason: d.reason, surfaceControlled: d.surfaceControlled,
                              coverageComplete: d.sampleExecutionComplete,
                              examinedTimepointsSeconds: d.examinedTimepointsSeconds,
                              temporalCoverageLimited: d.temporalCoverageLimited, timedEvidence: strippedTimed,
                              coverageCounters: d.coverageCounters)
    }
}

/// §C — the prefetch coordinator. One per player session. MainActor (it drives/reads the MainActor brain), but the
/// heavy evaluation runs inside a detached low-priority Task so it never blocks the foreground. Bounded to a SINGLE
/// cache entry (N+1 only, C1). Every public mutation is a real pipeline moment the model calls.
@MainActor
public final class PrefetchCoordinatorV1 {
    public static let version = "prefetch-coordinator-v1"

    private let sessionID: String
    private weak var brain: ReelsPlayerModelV1?
    private let items: [ReelItemV1]

    // The SINGLE bounded cache entry (C1/C5): the token it was produced under + the sanitized decision.
    private var cachedToken: PrefetchTokenV1?
    private var cachedDecision: ReelDecisionV1?
    private var inFlight: Task<Void, Never>?
    private var inFlightToken: PrefetchTokenV1?

    // Honest telemetry (no fabricated numbers): real counts the model/tests can read.
    public private(set) var prefetchStarted = 0
    public private(set) var prefetchCompleted = 0
    public private(set) var prefetchCancelled = 0
    public private(set) var cacheHits = 0
    public private(set) var cacheMisses = 0
    public private(set) var wastedPrefetches = 0   // completed but never consumed (swiped elsewhere / invalidated)

    public init(sessionID: String, brain: ReelsPlayerModelV1, items: [ReelItemV1]) {
        self.sessionID = sessionID; self.brain = brain; self.items = items
    }

    /// The strictly-N+1 index for a given current index, or nil at the end of the list (C1).
    public func nextIndex(after current: Int) -> Int? {
        let n = current + 1
        return items.indices.contains(n) ? n : nil
    }

    /// §C2/§C3 — mint the token for the N+1 item at the CURRENT brain state (policy revision + generation + override
    /// state). Returns nil when there is no N+1 item. Pure read of the brain's live state.
    public func makeToken(forNextAfter current: Int) -> PrefetchTokenV1? {
        guard let brain, let n = nextIndex(after: current) else { return nil }
        let item = items[n]
        return PrefetchTokenV1(sessionID: sessionID, contentID: item.id,
                               assetFingerprint: PrefetchTokenV1.assetFingerprint(url: item.url),
                               policyRevision: brain.policyRevision,
                               evaluatorVersion: ReelsDecisionEngineV1.version,
                               providerVersion: ReelsEvidenceProviderV1.version,
                               generation: brain.evaluationGeneration,
                               exceptionState: brain.overrideStateDigest(for: item.id),
                               coveragePlan: ReelsAdaptiveSamplerV1.maxBudget)
    }

    /// §C2 — kick off the low-priority prefetch of N+1. Called when the CURRENT item reaches a settled state. Cancels
    /// any prior in-flight prefetch first (only one N+1 is ever pending, C1). No-op at the end of the list, or when a
    /// VALID cache entry for the same token already exists (don't redo work we already have).
    public func prefetchNext(after current: Int) {
        guard let brain, let n = nextIndex(after: current), let token = makeToken(forNextAfter: current) else {
            cancel(reason: "no-next-item"); return
        }
        // Already have a valid, matching cache entry → nothing to do (D1: reuse, don't recompute).
        if cachedToken == token, cachedDecision != nil { return }
        // A new target (different item/policy/generation) supersedes any in-flight prefetch (C4 real cancellation).
        if inFlightToken != token { cancel(reason: "retarget") }
        guard inFlight == nil else { return }   // the same token is already being prefetched
        let item = items[n]
        inFlightToken = token
        prefetchStarted += 1
        // §C4 — a .utility (low) priority Task. The foreground always outranks it; AVFoundation decode + OCR inside the
        // provider check Task.isCancelled, so cancelling this Task really stops the decode work, not just a flag flip.
        inFlight = Task(priority: .utility) { [weak self, weak brain] in
            guard let brain else { return }
            // The SAME guarded evaluate path the on-demand flow uses, but in PREFETCH mode: it does NOT disturb the
            // foreground item's state/cache (it writes nothing to `currentIndex`/foreground state), and it honours the
            // brain's generation guard so a superseding foreground event abandons this result.
            let result = await brain.evaluatePrefetch(item, capturedGeneration: token.generation)
            await MainActor.run {
                guard let self else { return }
                self.inFlight = nil
                self.inFlightToken = nil
                if Task.isCancelled { self.prefetchCancelled += 1; return }
                switch result {
                case .superseded:
                    // A foreground event advanced the generation while we evaluated → discard (never cache a stale one).
                    self.prefetchCancelled += 1
                case .applied(let decision):
                    // Re-mint the token NOW and confirm nothing drifted while the Task ran (policy/generation/override).
                    guard let liveToken = self.makeToken(forNextAfter: current), liveToken == token else {
                        self.wastedPrefetches += 1; return   // the world moved under us — do not cache a stale entry
                    }
                    // §C5 — strip raw OCR text before caching: keep rule ids + timestamps + counts only.
                    self.cachedToken = liveToken
                    self.cachedDecision = PrefetchDecisionSanitizerV1.stripRawText(decision)
                    self.prefetchCompleted += 1
                }
            }
        }
    }

    /// §C2/§D1 — REVALIDATE on swipe: return the cached decision for `item` IFF the cache token still exactly equals a
    /// freshly-minted token for it (same policy/asset/generation/override). A hit means we can APPLY WITHOUT re-decode.
    /// A miss (any drift, or no entry) returns nil and the caller runs the normal on-demand gate. We NEVER upgrade an
    /// UNKNOWN/partial cached decision to CLEAR here — the decision is returned exactly as it was computed (D1).
    public func revalidatedDecision(for item: ReelItemV1, atIndex index: Int) -> ReelDecisionV1? {
        guard let cachedToken, let cachedDecision, cachedToken.contentID == item.id else { cacheMisses += 1; return nil }
        // Re-mint the token as if N+1 were `index-1`'s next, i.e. for THIS item at the live brain state, and compare.
        guard let liveToken = makeToken(forNextAfter: index - 1), liveToken == cachedToken else {
            // Drift (policy/asset/generation/override changed) → the cache is stale. Drop it and miss honestly.
            invalidate(reason: "token-drift-on-revalidate"); cacheMisses += 1; return nil
        }
        cacheHits += 1
        return cachedDecision
    }

    /// §E — a NON-consuming peek: is there a VALID cached decision for the N+1 item after `current` (token still
    /// matches the live brain state)? Drives the optional low-profile "değerlendirme hazır" indicator without
    /// counting a cache hit/miss. Does not mutate the cache.
    public func revalidatedDecisionIsCachedPeek(forNextAfter current: Int) -> Bool {
        guard let cachedToken, cachedDecision != nil, let liveToken = makeToken(forNextAfter: current) else { return false }
        return cachedToken == liveToken
    }

    /// §C4 — CANCEL the in-flight prefetch (real Task cancellation). Call on every listed trigger: swipe, queue
    /// direction change, Guardian OFF, IDLE, policyRevision change, thermal pressure, memory pressure, surface leave.
    public func cancel(reason: String) {
        if inFlight != nil { prefetchCancelled += 1 }
        inFlight?.cancel()
        inFlight = nil
        inFlightToken = nil
    }

    /// §C3 — invalidate the cached decision (policy/content change, override). Distinct from cancel (which stops an
    /// in-flight evaluation); this drops a COMPLETED cache entry so a stale pre-exposure decision can't be applied.
    public func invalidate(reason: String) {
        if cachedDecision != nil { /* a cached entry existed; dropping it is honest invalidation, not a waste */ }
        cachedToken = nil
        cachedDecision = nil
    }

    /// §C5 — session-end cleanup: cancel in-flight work + wipe the cache + temporary evidence. No raw frame/OCR/
    /// personal content survives the session. Called from the model's stop().
    public func teardown() {
        cancel(reason: "session-end")
        invalidate(reason: "session-end")
    }

    /// Honest one-line telemetry (real counts only — no fabricated percentages unless derivable).
    public var summary: String {
        "prefetch=\(Self.version) started=\(prefetchStarted) completed=\(prefetchCompleted) cancelled=\(prefetchCancelled) hits=\(cacheHits) misses=\(cacheMisses) wasted=\(wastedPrefetches)"
    }
}
#endif
