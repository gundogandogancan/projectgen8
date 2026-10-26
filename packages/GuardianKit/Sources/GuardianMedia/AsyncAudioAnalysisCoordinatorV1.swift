//
//  AsyncAudioAnalysisCoordinatorV1.swift — R10 §1/§2 (P0-1/P0-2): the TRUE ASYNC AUDIO work model + the ONE
//  OWNERSHIP DISCIPLINE for the bounded hand-off, plus the APPLY-OR-DROP revalidation that gates a LATE async result.
//
//  WHY THIS EXISTS (R10 mandate §1 — the R9 production defect): R9's `analyzeAudioWindowForItem` ran
//  `audioWorkerQueue.sync { analyzeWindow(...) }` INSIDE the heavy per-item evaluation on the ReplayKit serial VIDEO
//  callback. Although the analysis dispatched to a worker queue, the caller BLOCKED (`.sync`) waiting for it, so the
//  video decision path waited on SoundAnalysis — not a true async work model. The video frame path must NEVER wait
//  on audio (mandate §1: "Video kare işleme yolu SoundAnalysis sonuçlarını beklemeyecek").
//
//  THE NEW WORK MODEL (mandate §1):
//    1. The capture callback makes a SHORT-LIVED PCM copy (already done by LiveAudioPCMExtractorV1) → a BOUNDED
//       hand-off (owned by the store below) → returns immediately.
//    2. The heavy per-item path SUBMITS a window request (snapshots the live identity into an APPLY TICKET) and
//       RETURNS — it does NOT wait. While a window is in flight the world-model audio modality is PENDING.
//    3. An OFF-CALLBACK async worker runs the real SoundAnalysis window (LiveAudioStreamSessionV1.analyzeWindow).
//    4. On completion, the worker REVALIDATES the result against the CURRENT live identity via the pure
//       `ApplyDecisionV1` here: {session, item identity revision, generation, policy revision, family revision,
//       guardian-on, capture-active} must ALL still match the ticket. VALID → apply (progressive same-item update +
//       bounded re-adjudication through the existing bridge/adjudicator). INVALID → DROP + count the reason.
//
//  THE INVARIANTS (mandate §1): PENDING ≠ AVAILABLE. RESULT ARRIVED ≠ SAME ITEM. ASYNC CALLBACK ≠ SAFE TO APPLY.
//  A window result is applied ONLY when every binding field still matches the live state at completion time; a stale
//  result (new item / Guardian off / profile changed / capture stopped / session ended) is dropped and counted.
//
//  OWNERSHIP (mandate §2): `AudioHandoffStoreV1` is a SINGLE serial-queue-confined store that owns BOTH the derived
//  bounded queue AND the PCM-byte accounting under ONE discipline, with shared caps: max bytes AND max duration AND
//  max OUTSTANDING windows; a memory high-water mark; PCM released at window completion; a session-end purge (no
//  cross-session leakage). It is `@unchecked Sendable` with a documented protection invariant: EVERY property is read
//  and written ONLY inside `queue.sync`/`queue.async(flags:.barrier)` blocks — there is no un-serialized access path.
//
//  Pure value types + one serial-queue-confined reference store. No SoundAnalysis/AVFoundation import here (the PCM is
//  held as an opaque handle by the caller) — so the apply-or-drop state machine + the bounded accounting are testable
//  on EVERY SDK without a device. Lives in GuardianMedia (GuardianCore frozen).
//
import Foundation

// MARK: - §1 the APPLY TICKET — the live identity an in-flight window was SUBMITTED under

/// R10 §1 — the identity snapshot a window request is stamped with when it is SUBMITTED. The async completion
/// revalidates against the live snapshot: EVERY field must still match or the result is dropped. This is the single
/// binding the firewall checks (mandate §1/§4: generation alone is not enough — session + item + policy + family +
/// guardian-on + capture-active are ALL part of the freshness contract).
public struct AudioApplyTicketV1: Sendable, Equatable {
    public let sessionID: String
    public let itemIdentityRevision: Int
    public let generation: UInt64
    public let policyRevision: UInt64
    public let familyRevision: UInt64
    /// A monotonic request id so a later submission supersedes an earlier in-flight one for the SAME item (defense in
    /// depth: if two windows were ever in flight, only the freshest applies).
    public let requestID: UInt64
    public init(sessionID: String, itemIdentityRevision: Int, generation: UInt64,
                policyRevision: UInt64, familyRevision: UInt64, requestID: UInt64) {
        self.sessionID = sessionID; self.itemIdentityRevision = itemIdentityRevision
        self.generation = generation; self.policyRevision = policyRevision
        self.familyRevision = familyRevision; self.requestID = requestID
    }
}

/// R10 §1 — the LIVE identity at the moment a window completes. The apply-or-drop decision compares the ticket against
/// this. `guardianActive` is false when Guardian was turned OFF / went idle; `captureActive` is false when the capture
/// session ended or the broadcast stopped. `sessionID` differs when a new broadcast session started.
public struct AudioLiveStateV1: Sendable, Equatable {
    public let sessionID: String
    public let itemIdentityRevision: Int
    public let generation: UInt64
    public let policyRevision: UInt64
    public let familyRevision: UInt64
    public let guardianActive: Bool
    public let captureActive: Bool
    /// The latest request id the store has submitted (a completion for an older request is superseded).
    public let latestRequestID: UInt64
    public init(sessionID: String, itemIdentityRevision: Int, generation: UInt64,
                policyRevision: UInt64, familyRevision: UInt64,
                guardianActive: Bool, captureActive: Bool, latestRequestID: UInt64) {
        self.sessionID = sessionID; self.itemIdentityRevision = itemIdentityRevision
        self.generation = generation; self.policyRevision = policyRevision
        self.familyRevision = familyRevision; self.guardianActive = guardianActive
        self.captureActive = captureActive; self.latestRequestID = latestRequestID
    }
}

/// R10 §1 — WHY a late async result was dropped (or applied). Each is counted honestly for the resource report; a drop
/// is NEVER silent (mandate §1: "invalid → result dropped + counted"). `applied` is the only non-drop outcome.
public enum AudioApplyDecisionV1: String, Sendable, Equatable, CaseIterable {
    case applied            = "APPLIED"              // every binding field still matches → progressive same-item update
    case droppedSession     = "DROPPED_SESSION_ENDED"   // a NEW broadcast session started (or capture ended)
    case droppedItemChanged = "DROPPED_ITEM_CHANGED"    // the user swiped to a new item (revision/generation advanced)
    case droppedGuardianOff = "DROPPED_GUARDIAN_OFF"    // Guardian was turned off / went idle while in flight
    case droppedPolicyChanged = "DROPPED_POLICY_CHANGED" // a shield-policy revision change invalidated the ticket
    case droppedFamilyChanged = "DROPPED_FAMILY_CHANGED" // a family-profile (child) revision change invalidated it
    case droppedSuperseded  = "DROPPED_SUPERSEDED"      // a fresher window request for the SAME item was submitted

    /// The honest reason a child-safety reviewer reads: did we apply the late audio to the CURRENT item or drop it?
    public var didApply: Bool { self == .applied }
}

/// R10 §1 — the PURE apply-or-drop authority. Given the ticket a window was submitted under and the live state at
/// completion time, decide whether the (real, already-analyzed) result may be applied to the CURRENT item, or must be
/// dropped (and why). This is the single firewall for the ASYNC completion path — it has NO SoundAnalysis dependency
/// and is exhaustively testable (the mandated matrix: same item applies; new item / Guardian off / child profile
/// changed / capture stopped / session ended → dropped). Precedence is explicit and ordered.
public enum AudioAsyncRevalidatorV1 {
    public static func decide(ticket: AudioApplyTicketV1, live: AudioLiveStateV1) -> AudioApplyDecisionV1 {
        // 1. SESSION / CAPTURE first — a new session or a stopped capture invalidates everything (no cross-session
        //    leakage; a result from a dead session can never touch a live one — mandate §2 "önceki oturumun PCM'si
        //    sonraki oturuma sızmamalı" extended to the completed result).
        if ticket.sessionID != live.sessionID { return .droppedSession }
        if !live.captureActive { return .droppedSession }
        // 2. GUARDIAN OFF / IDLE — analysis consent was withdrawn while the window was in flight; we never apply audio
        //    to a surface the user has paused (mandate §1: "Guardian'ı kapatır → düşürülmeli").
        if !live.guardianActive { return .droppedGuardianOff }
        // 3. ITEM IDENTITY — the user swiped to new content (revision or generation advanced). A stale result can
        //    NEVER bind to a new item (mandate §1: "yeni Reels'e geçer → eski ses sonucu yeni içeriğe uygulanamaz").
        if ticket.itemIdentityRevision != live.itemIdentityRevision { return .droppedItemChanged }
        if ticket.generation != live.generation { return .droppedItemChanged }
        // 4. POLICY / FAMILY FRESHNESS — a shield or family (child) policy change invalidates the decision the ticket
        //    was bound to (mandate §1/§4: "çocuk profilini değiştirir → policy revision mismatch → düşürülmeli").
        if ticket.policyRevision != live.policyRevision { return .droppedPolicyChanged }
        if ticket.familyRevision != live.familyRevision { return .droppedFamilyChanged }
        // 5. SUPERSEDED — a fresher window request for the SAME item was submitted after this one; only the freshest
        //    applies (defense in depth against two concurrent in-flight windows for one item).
        if ticket.requestID < live.latestRequestID { return .droppedSuperseded }
        return .applied
    }
}

// MARK: - §1 the honest PENDING availability state (extends the R9 ladder)

/// R10 §1 — the DISTINCT PENDING world-model audio coverage state. While a window is IN FLIGHT (submitted on the async
/// worker, not yet completed/revalidated) the audio modality is PENDING — NOT available, NOT a non-analysis terminal.
/// PENDING ≠ AVAILABLE (mandate §1). This is surfaced to the coverage UI as "ses: analiz sürüyor" and maps to the
/// R9 ladder's submitted-but-pending rung (`classifierWindowSubmitted`) so the existing availability mapping stays
/// UNAVAILABLE (no fake clean result while pending) — but the UI can tell PENDING apart from a hard deferral.
public enum AudioCoverageLifecycleV1: String, Sendable, Equatable, CaseIterable, Codable {
    case notAttempted = "AUDIO_NOT_ATTEMPTED"   // no window requested for this item yet (coverage genuinely unknown)
    case pending      = "AUDIO_PENDING"         // a window is IN FLIGHT on the async worker (analiz sürüyor)
    case resolved     = "AUDIO_RESOLVED"        // a window completed (its ladder state carries the honest terminal)

    /// The R9 ladder rung PENDING maps to for the coarse availability (a submitted-but-un-completed window is PENDING,
    /// which the R9 ladder already maps to UNAVAILABLE — never a fake clean/available result).
    public var pendingLadderState: LiveAudioAnalysisStateV1 { .classifierWindowSubmitted }
}

// MARK: - §2 the ONE ownership discipline — a serial-queue-confined bounded hand-off store

/// R10 §2 — the SINGLE OWNERSHIP store for the bounded audio hand-off. It unifies the DERIVED bounded queue
/// (BoundedAudioQueueV1, which already enforces count/bytes/duration) AND the OUTSTANDING-WINDOW accounting under ONE
/// serial-queue discipline, plus a memory HIGH-WATER mark and a session-end PURGE.
///
/// PROTECTION INVARIANT (mandate §2 — `@unchecked Sendable` justification): every stored property
/// (`queue`, `outstandingWindows`, `peakRetainedBytes`, `nextRequestID`) is accessed ONLY inside `q.sync { }` (reads +
/// small mutations) — there is NO property access outside the serial queue. The serial queue provides a total order,
/// so there is no data race. The held PCM copies are NOT stored here (they live in the caller's SoundAnalysis-typed
/// store, released at window completion); this store owns the DERIVED accounting + the outstanding-window counter that
/// bounds concurrent analysis.
public final class AudioHandoffStoreV1: @unchecked Sendable {
    private let q = DispatchQueue(label: "com.gen8.guardian.audio.handoff.store")
    private var queue: BoundedAudioQueueV1
    /// R10 §2 — the OUTSTANDING (in-flight) window count. A new window may be SUBMITTED only while this is below the
    /// cap, so the hand-off can never spawn unbounded concurrent analysis (mandate §2 "max inference windows").
    private var outstandingWindows = 0
    private var peakRetainedBytes = 0
    private var peakOutstandingWindows = 0
    private var nextRequestID: UInt64 = 1
    private var totalSubmitted: UInt64 = 0
    private var totalDroppedBySupersede = 0
    public let maxOutstandingWindows: Int

    public init(capacity: Int = LiveAudioEvidenceAdapterV1.queueCapacity,
                maxBytes: Int = 512 * 1024, maxDurationSeconds: Double = 4.0,
                maxOutstandingWindows: Int = 2) {
        self.queue = BoundedAudioQueueV1(capacity: capacity, maxBytes: maxBytes, maxDurationSeconds: maxDurationSeconds)
        self.maxOutstandingWindows = max(1, maxOutstandingWindows)
    }

    /// Append a derived sample (called from the capture callback via the serial store). Bounded; drop-oldest counted.
    public func enqueue(_ s: LiveAudioQueuedSampleV1) {
        q.sync {
            queue.enqueue(s)
            peakRetainedBytes = max(peakRetainedBytes, queue.retainedBytes)
        }
    }

    /// R10 §2/§3 — drain ONLY the samples still bound to the live generation+item; stale samples discarded + counted.
    public func drainLive(liveGeneration: UInt64, liveItemRevision: Int) -> (live: [LiveAudioQueuedSampleV1], discardedStale: Int) {
        q.sync { queue.drainLive(liveGeneration: liveGeneration, liveItemRevision: liveItemRevision) }
    }

    /// R10 §2 — may we SUBMIT a new window now? True only when the outstanding-window cap is not exceeded. When true,
    /// mints + returns a fresh monotonic request id and increments the outstanding count (the caller MUST call
    /// `completeWindow()` exactly once per granted submission to release it). Returns nil when the cap is reached
    /// (the caller then defers honestly — a window is NOT spawned, counted by the caller's resource-deferred path).
    public func trySubmitWindow() -> UInt64? {
        q.sync {
            guard outstandingWindows < maxOutstandingWindows else { return nil }
            outstandingWindows += 1
            peakOutstandingWindows = max(peakOutstandingWindows, outstandingWindows)
            totalSubmitted += 1
            let id = nextRequestID
            nextRequestID += 1
            return id
        }
    }

    /// R10 §2 — release one outstanding window at completion (PCM released by the caller; here we release the slot so a
    /// new window may be submitted). Idempotent-safe: never drops below zero.
    public func completeWindow() {
        q.sync { outstandingWindows = max(0, outstandingWindows - 1) }
    }

    /// The latest request id minted (so the async revalidator can detect a superseding window for the same item).
    public var latestRequestID: UInt64 { q.sync { nextRequestID - 1 } }

    /// R10 §2 — session-end PURGE: clear everything so no PCM accounting / outstanding count / request id leaks into
    /// the next session (mandate §2 — no cross-session leakage). The peak high-water marks are kept for the summary.
    public func purgeForSessionEnd() {
        q.sync {
            queue.clear()
            outstandingWindows = 0
            // nextRequestID keeps advancing within the process (a new session uses a new sessionID, so a stale request
            // id can never match a new session's tickets via the revalidator's sessionID check).
        }
    }

    /// R10 §2/§RESOURCE — the honest accounting snapshot for the cost report (derived scalars only; never audio).
    public struct SnapshotV1: Sendable, Equatable {
        public let queuedSamples: Int
        public let retainedBytes: Int
        public let retainedDurationSeconds: Double
        public let droppedOldest: Int
        public let outstandingWindows: Int
        public let peakRetainedBytes: Int
        public let peakOutstandingWindows: Int
        public let totalSubmitted: UInt64
    }
    public var snapshot: SnapshotV1 {
        q.sync {
            SnapshotV1(queuedSamples: queue.count, retainedBytes: queue.retainedBytes,
                       retainedDurationSeconds: queue.retainedDurationSeconds, droppedOldest: queue.droppedOldest,
                       outstandingWindows: outstandingWindows, peakRetainedBytes: peakRetainedBytes,
                       peakOutstandingWindows: peakOutstandingWindows, totalSubmitted: totalSubmitted)
        }
    }

    public var count: Int { q.sync { queue.count } }
    public var droppedOldest: Int { q.sync { queue.droppedOldest } }
    public var retainedBytes: Int { q.sync { queue.retainedBytes } }
    public var retainedDurationSeconds: Double { q.sync { queue.retainedDurationSeconds } }
}
