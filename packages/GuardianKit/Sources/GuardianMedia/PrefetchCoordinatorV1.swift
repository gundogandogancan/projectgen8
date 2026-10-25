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
    public let assetFingerprint: String   // the asset's content version (name+size+mtime+content-hash) — change ⇒ miss
    public let policyRevision: UInt64      // the rule-set version; a rule change invalidates the cache
    public let evaluatorVersion: String    // the decision engine version
    public let providerVersion: String     // the evidence provider version
    // §A1 — EVIDENCE EPOCH (was `generation`). The cache's VALIDITY key: a previously-computed decision for this
    // content is reusable only while the evidence epoch is unchanged. It is bumped ONLY by policy/exception/content/
    // session changes — NOT by a plain cursor move. This is the A1 fix: a normal A→B swipe no longer invalidates B's
    // valid prefetch (the OLD `generation` field was bumped by advance(by:), causing a false cache miss on every
    // swipe). PRESENTATION authority (a late prefetch can't be applied after navigation moved) stays with the brain's
    // `evaluationGeneration`, checked inside evaluatePrefetch — NOT here.
    public let evidenceEpoch: UInt64
    public let exceptionState: String      // a stable digest of the user's override/exception state for THIS content
    public let coveragePlan: Int           // the planned sample budget the prefetch intended (coverage provenance)

    public init(sessionID: String, contentID: String, assetFingerprint: String, policyRevision: UInt64,
                evaluatorVersion: String, providerVersion: String, evidenceEpoch: UInt64,
                exceptionState: String, coveragePlan: Int) {
        self.sessionID = sessionID; self.contentID = contentID; self.assetFingerprint = assetFingerprint
        self.policyRevision = policyRevision; self.evaluatorVersion = evaluatorVersion
        self.providerVersion = providerVersion; self.evidenceEpoch = evidenceEpoch
        self.exceptionState = exceptionState; self.coveragePlan = coveragePlan
    }

    /// §C — a content-version fingerprint for a LOCAL owned asset. The OLD fingerprint was name+size+second-mtime
    /// only; the mandate flags a real COLLISION RISK — two different files can share a name, byte size, and whole-
    /// second mtime (e.g. a regenerated fixture written within the same second), which would let a STALE cached
    /// decision be reused for genuinely different bytes. The fix adds a cheap CONTENT HASH of the first N bytes (the
    /// region that dominates the pre-exposure analysis anyway) + the file's full duration proxy via byte size, so a
    /// same-name/same-size/same-second file with different content yields a DIFFERENT fingerprint → cache MISS →
    /// honest RE-EVALUATION (never a false cache-hit on ambiguous identity). If the bytes are unreadable we emit an
    /// explicit `noread` marker so an unverifiable asset ALSO never matches a prior fingerprint (re-evaluate, not reuse).
    public static func assetFingerprint(url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        // §2.3 — STRONGER identity: size + mtime + a HEAD hash + a TAIL hash. The old fingerprint hashed only the
        // first 64KB; two files sharing a name/size/second AND an identical header block but DIFFERENT bodies could
        // collide → a stale cached decision reused for genuinely different bytes. Adding a tail-block hash (the last
        // N bytes, which for a media container differ when the body differs even if the header is shared) makes a
        // same-head/different-body file yield a DIFFERENT fingerprint → honest cache MISS → re-evaluation (never a
        // false hit on ambiguous identity). This is still bounded (two small blocks), not a whole-file stream.
        let head = contentBlockHash(url: url, fromEnd: false)
        let tail = contentBlockHash(url: url, fromEnd: true, fileSize: size)
        // §2.3 — the fingerprint is DETERMINISTIC (name|size|mtime|head|tail). When the bytes are unreadable the head/
        // tail carry an explicit `noread` marker; `isUnverifiable(...)` detects that so the CACHE LAYER refuses to
        // treat an unverifiable asset as a trusted cache entry (a `noread` fingerprint is never SAVED as a reusable
        // decision — see prefetchNext / revalidatedDecision). Keeping the fingerprint deterministic (no random nonce)
        // preserves correct same-asset identity; the "never reuse an unverifiable asset" guarantee lives at the cache
        // boundary, not by randomizing identity (which would also break a legitimately-missing-but-stable fixture).
        return "\(url.lastPathComponent)|\(size)|\(Int(mtime))|\(head)|\(tail)"
    }

    /// §2.3 — true when the fingerprint could not verify the bytes (a `noread` head/tail). The cache layer uses this
    /// to REFUSE caching/reusing a decision for an unverifiable asset (force re-evaluation, never a stale/false hit).
    public static func isUnverifiable(_ fingerprint: String) -> Bool { fingerprint.contains("|noread") }

    /// §C/§2.3 — a cheap, bounded FNV-1a hash of a HEAD or TAIL block of the file. Reading two small blocks (not the
    /// whole asset) keeps every token mint cheap while making a same-head/different-body collision detectable (the
    /// tail block differs when the body differs). `noread` when the bytes can't be read / the file is empty (so an
    /// unverifiable file is treated as distinct + never-matching by `assetFingerprint`, forcing re-evaluation).
    static func contentBlockHash(url: URL, fromEnd: Bool, fileSize: Int64 = -1, maxBytes: Int = 64 * 1024) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "noread" }
        defer { try? handle.close() }
        if fromEnd {
            // Seek to max(0, size - maxBytes) and read the trailing block. If size is unknown or ≤ a block, the tail
            // equals the head region; that is fine (still a real hash of real bytes) — it never fabricates content.
            let size = fileSize >= 0 ? fileSize : Int64((try? handle.seekToEnd()) ?? 0)
            let offset = size > Int64(maxBytes) ? UInt64(size - Int64(maxBytes)) : 0
            try? handle.seek(toOffset: offset)
        }
        let data = (try? handle.read(upToCount: maxBytes)) ?? Data()
        guard !data.isEmpty else { return "noread" }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(hash, radix: 16)
    }

    /// Back-compat shim for the head block (kept so existing callers/tests referencing `contentHeadHash` still work).
    static func contentHeadHash(url: URL, maxBytes: Int = 64 * 1024) -> String {
        contentBlockHash(url: url, fromEnd: false, maxBytes: maxBytes)
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

/// §B3 — the honest internal lifecycle of the N+1 prefetch. The UI maps this to AT MOST a tiny "sıradaki hazır"
/// chip (a meaningful, plain indicator — never an attention-grab). READY appears ONLY when a re-validatable
/// pre-exposure decision truly exists; EVALUATING means work is really in flight; INVALIDATED/CANCELLED/UNAVAILABLE
/// are distinct honest outcomes so the chip can never claim "ready" when it is not (mandate B3).
public enum PrefetchStateV1: String, Sendable, Equatable, Codable {
    case notStarted = "NOT_STARTED"   // no prefetch kicked off for the current N+1 yet
    case evaluating = "EVALUATING"    // a prefetch Task is really running (work generated, not yet complete)
    case ready      = "READY"         // a valid, re-validatable cached decision exists for N+1
    case invalidated = "INVALIDATED"  // a completed entry was dropped (policy/override/content changed)
    case cancelled  = "CANCELLED"     // the in-flight prefetch was cancelled by a real trigger (swipe/OFF/thermal…)
    case unavailable = "UNAVAILABLE"  // there is no N+1 to prefetch (end of list) or prefetch cannot run
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

    // §B3 — the PUBLISHED prefetch state. The model reads this to refresh the chip ONLY when it really changes; the
    // chip shows READY exclusively while a re-validatable cached decision exists. Set at every real lifecycle moment.
    public private(set) var state: PrefetchStateV1 = .notStarted {
        didSet { if state != oldValue { onStateChange?(state) } }   // §2.2 — push on real change (no polling)
    }

    // §2.2 — READY-THE-INSTANT-IT-COMPLETES. The model subscribes to this closure; the coordinator fires it on EVERY
    // real state transition (including the async prefetch completion), so the UI "sıradaki hazır" chip flips the
    // moment a re-validatable decision is genuinely cached — directly from the completion callback, NOT from a timer
    // poll. Called on the MainActor (the coordinator is @MainActor). nil until the model wires it.
    public var onStateChange: (@MainActor (PrefetchStateV1) -> Void)?

    // §2.1 — WORK IDENTITY. Each kicked-off prefetch Task is stamped with a monotonic generation. The Task's own
    // completion block only clears `inFlight`/`inFlightToken` and writes state IF it is STILL the authoritative work
    // (its generation == the coordinator's current `inFlightGeneration`). An OLD Task finishing after a NEW one has
    // been kicked off can therefore NEVER erase the new work's in-flight state or stomp its result (the mandate's
    // §2.1 race). Deterministic: the generation is the sole identity used by the completion guard.
    private var inFlightGeneration: UInt64 = 0

    // Honest telemetry (no fabricated numbers): real counts the model/tests can read.
    public private(set) var prefetchStarted = 0
    public private(set) var prefetchCompleted = 0
    public private(set) var prefetchCancelled = 0
    public private(set) var cacheHits = 0
    public private(set) var cacheMisses = 0
    public private(set) var wastedPrefetches = 0   // completed but never consumed (swiped elsewhere / invalidated)

    // §2.4 — OFF/IDLE SCOPE IN THE CONTROLLED PLAYER. Heavy pre-exposure evaluation (decode+OCR+audio) must NOT run
    // when the user's product intent is Guardian OFF or when analysis consent is UNKNOWN (fail-closed). The existing
    // GuardianAnalysisGateV1.analysisConsent gate is CONSUMED here (not duplicated): a @Sendable reader returns the
    // live consent, defaulting to CONSENTED only when the model did not wire a reader (the app DOES wire it). When
    // consent != CONSENTED, prefetchNext short-circuits to UNAVAILABLE and never generates work (honest scope).
    private let analysisConsent: @Sendable () -> GuardianAnalysisGateV1.AnalysisConsentV1

    public init(sessionID: String, brain: ReelsPlayerModelV1, items: [ReelItemV1],
                analysisConsent: @escaping @Sendable () -> GuardianAnalysisGateV1.AnalysisConsentV1 = { .consented }) {
        self.sessionID = sessionID; self.brain = brain; self.items = items
        self.analysisConsent = analysisConsent
    }

    /// The strictly-N+1 index for a given current index, or nil at the end of the list (C1).
    public func nextIndex(after current: Int) -> Int? {
        let n = current + 1
        return items.indices.contains(n) ? n : nil
    }

    /// §C2/§C3/§A1 — mint the token for the N+1 item at the CURRENT brain state (policy revision + EVIDENCE EPOCH +
    /// override state). Returns nil when there is no N+1 item. Pure read of the brain's live state. The validity key
    /// is the brain's `evidenceEpoch` (NOT `evaluationGeneration`): a plain cursor move does not bump the epoch, so a
    /// normal A→B swipe re-mints an IDENTICAL token for B and the cache HITS (the A1 false-miss fix). A real policy/
    /// override/content/session change DOES bump the epoch (or changes policyRevision/exceptionState/fingerprint), so
    /// a stale decision still misses honestly.
    public func makeToken(forNextAfter current: Int) -> PrefetchTokenV1? {
        guard let brain, let n = nextIndex(after: current) else { return nil }
        let item = items[n]
        return PrefetchTokenV1(sessionID: sessionID, contentID: item.id,
                               assetFingerprint: PrefetchTokenV1.assetFingerprint(url: item.url),
                               policyRevision: brain.policyRevision,
                               evaluatorVersion: ReelsDecisionEngineV1.version,
                               providerVersion: ReelsEvidenceProviderV1.version,
                               evidenceEpoch: brain.evidenceEpoch,
                               exceptionState: brain.overrideStateDigest(for: item.id),
                               coveragePlan: ReelsAdaptiveSamplerV1.maxBudget)
    }

    /// §C2 — kick off the low-priority prefetch of N+1. Called when the CURRENT item reaches a settled state. Cancels
    /// any prior in-flight prefetch first (only one N+1 is ever pending, C1). No-op at the end of the list, or when a
    /// VALID cache entry for the same token already exists (don't redo work we already have).
    public func prefetchNext(after current: Int) {
        // §2.4 — OFF/IDLE scope: if the user turned Guardian OFF (or consent is UNKNOWN → fail-closed), do NOT generate
        // heavy pre-exposure work on the controlled surface. Cancel any in-flight prefetch and report UNAVAILABLE — an
        // honest "we are not analysing", never a fabricated ready/clean result. The desired/applied distinction stays
        // with GuardianAnalysisGateV1 (the app surfaces İsteniyor vs Uygulandı); the coordinator just honours consent.
        guard analysisConsent().mayRunAnalysis else {
            cancel(reason: "analysis-off-or-unknown"); invalidate(reason: "analysis-off-or-unknown")
            state = .unavailable; return
        }
        guard let brain, let n = nextIndex(after: current), let token = makeToken(forNextAfter: current) else {
            cancel(reason: "no-next-item"); state = .unavailable; return   // §B3 — no N+1 to prefetch (end of list)
        }
        // Already have a valid, matching cache entry → nothing to do (D1: reuse, don't recompute).
        if cachedToken == token, cachedDecision != nil { state = .ready; return }
        // A new target (different item/policy/generation) supersedes any in-flight prefetch (C4 real cancellation).
        if inFlightToken != token { cancel(reason: "retarget") }
        guard inFlight == nil else { return }   // the same token is already being prefetched
        let item = items[n]
        inFlightToken = token
        inFlightGeneration &+= 1                 // §2.1 — stamp THIS work with a fresh identity
        let workGeneration = inFlightGeneration  // captured for the completion guard (only this gen may clear state)
        prefetchStarted += 1
        state = .evaluating   // §B3 — work is really generated now; the chip shows nothing-ready until completion
        // §A1 — the PRESENTATION supersede guard uses the brain's NAVIGATION generation (NOT the token's evidence
        // epoch). Captured at kickoff on the MainActor: if a foreground swipe/skip advances the generation while we
        // evaluate, evaluatePrefetch returns `.superseded` and we discard — a late prefetch of A's successor can never
        // be applied after navigation moved on. The token's evidenceEpoch is a separate, cache-VALIDITY concern.
        let capturedGeneration = brain.evaluationGeneration
        // §C4 — a .utility (low) priority Task. The foreground always outranks it; AVFoundation decode + OCR inside the
        // provider check Task.isCancelled, so cancelling this Task really stops the decode work, not just a flag flip.
        inFlight = Task(priority: .utility) { [weak self, weak brain] in
            guard let brain else { return }
            // The SAME guarded evaluate path the on-demand flow uses, but in PREFETCH mode: it does NOT disturb the
            // foreground item's state/cache (it writes nothing to `currentIndex`/foreground state), and it honours the
            // brain's generation guard so a superseding foreground event abandons this result.
            let result = await brain.evaluatePrefetch(item, capturedGeneration: capturedGeneration)
            await MainActor.run {
                guard let self else { return }
                // §2.1 — WORK-IDENTITY GUARD: only the AUTHORITATIVE in-flight Task may mutate the coordinator's
                // in-flight state/cache/counters. If a newer prefetch superseded this one (inFlightGeneration moved),
                // this is a STALE completion: it must NOT clear the new work's inFlight/token, nor publish a state, nor
                // cache a result — it only counts as a wasted prefetch and returns. This is the §2.1 fix (an old task
                // completing can never erase new work).
                guard workGeneration == self.inFlightGeneration else {
                    self.wastedPrefetches += 1
                    return
                }
                self.inFlight = nil
                self.inFlightToken = nil
                if Task.isCancelled { self.prefetchCancelled += 1; self.state = .cancelled; return }
                switch result {
                case .superseded:
                    // A foreground event advanced the generation while we evaluated → discard (never cache a stale one).
                    self.prefetchCancelled += 1
                    self.state = .cancelled   // §B3 — superseded by navigation; the chip must NOT say ready
                case .applied(let decision):
                    // Re-mint the token NOW and confirm nothing drifted while the Task ran (policy/generation/override).
                    guard let liveToken = self.makeToken(forNextAfter: current), liveToken == token else {
                        self.wastedPrefetches += 1; self.state = .invalidated; return   // world moved — don't cache stale
                    }
                    // §C5 — strip raw OCR text before caching: keep rule ids + timestamps + counts only.
                    self.cachedToken = liveToken
                    self.cachedDecision = PrefetchDecisionSanitizerV1.stripRawText(decision)
                    self.prefetchCompleted += 1
                    self.state = .ready   // §B3 — NOW (and only now) the chip may say "sıradaki hazır"
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
        if inFlight != nil {
            prefetchCancelled += 1
            state = .cancelled   // §B3 — real in-flight work was cancelled by a trigger; the chip reflects it
        }
        inFlight?.cancel()
        inFlight = nil
        inFlightToken = nil
        inFlightGeneration &+= 1   // §2.1 — any in-flight completion that arrives after a cancel is now STALE (ignored)
    }

    /// §C3 — invalidate the cached decision (policy/content change, override). Distinct from cancel (which stops an
    /// in-flight evaluation); this drops a COMPLETED cache entry so a stale pre-exposure decision can't be applied.
    public func invalidate(reason: String) {
        if cachedDecision != nil {
            state = .invalidated   // §B3 — a completed entry was dropped (policy/override/content); never "ready" now
        }
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
