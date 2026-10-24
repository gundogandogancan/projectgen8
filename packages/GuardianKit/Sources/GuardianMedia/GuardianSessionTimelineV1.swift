//
//  GuardianSessionTimelineV1.swift — C/D-lane: the "Bu Oturum" (This Session) LIVE SESSION TIMELINE.
//
//  WHY THIS EXISTS (mandate C/D/E): the user should be able to SEE what the Guardian actually did this session —
//  the real event stream from the engine, not a fabricated narrative. Each event is the MINIMUM privacy-safe
//  surface: a monotonic time, a CATEGORY, a STATUS, a short derived DESCRIPTION, and the REAL reason code behind
//  it (reused by the per-event "Neden?"). NOTHING ELSE — never raw OCR text, frames, titles or personal content.
//
//  TWO DISTINCT CONCEPTS (mandate F): a HEARTBEAT (GuardianObservationHeartbeatV1) proves the session is ALIVE at
//  frame cadence; a TIMELINE EVENT is a MEANINGFUL Guardian moment (started / new content / decision / content
//  changed / interrupted). They are produced on completely different cadences and must never be conflated.
//
//  PRIVACY / RETENTION (mandate D): the default is a short-lived, RAM-FIRST, BOUNDED ring (capacity 64) owned by
//  the writer process. Because the extension and the app are SEPARATE processes, the live feed must cross an App
//  Group boundary (the same IPC class the heartbeat uses). We mirror a BOUNDED, DERIVED-ONLY snapshot through the
//  App Group suite — this is UserDefaults, i.e. shared persistent storage, NOT RAM-only — so it is declared
//  honestly here with: a hard event cap, a per-event + per-snapshot TTL, session-id scoping, and MANDATORY
//  session-end cleanup (clear()). A crashed broadcast leaves at most one stale snapshot, which the reader discards
//  on TTL / session-id mismatch and the next session overwrites + clears. No history is kept beyond the session.
//
//  This type lives in GuardianMedia (ungoverned) and is dual-compiled into BOTH the Gen8 app and the
//  GuardianBroadcastExtension — identical pattern to GuardianObservationHeartbeatV1 / Tier1IdentityResolutionV1.
//
import Foundation

// MARK: - Event vocabulary (categorical — never free-form narrative)

/// The KIND of meaningful Guardian moment. Closed set so the UI can render + translate each honestly; no event is
/// ever invented outside this vocabulary, and every one maps to a REAL engine transition.
public enum GuardianTimelineCategoryV1: String, Sendable, Equatable, Codable {
    case sessionStarted   = "SESSION_STARTED"    // broadcast really began (osConfirmed)
    case sessionEnded     = "SESSION_ENDED"      // broadcast finished / Guardian off
    case newContent       = "NEW_CONTENT"        // a new content item was detected
    case identityResolved = "IDENTITY_RESOLVED"  // identity confirmed (same/new) by Tier-1 fusion
    case evidenceCaptured = "EVIDENCE_CAPTURED"  // text/visual evidence obtained for the current item
    case decision         = "DECISION"           // a Guardian decision was produced for the current item
    case contentChanged   = "CONTENT_CHANGED"    // content changed → the prior decision was invalidated
    case observationGap   = "OBSERVATION_GAP"    // observation interrupted (paused / stalled)
    case observationResumed = "OBSERVATION_RESUMED" // observation resumed after an interruption
}

/// The STATUS tone of an event — drives the UI dot colour WITHOUT ever claiming "content is safe" (mandate A4:
/// a non-match is `benign` evidence-for-the-analysis-scope, never a blanket safety claim).
public enum GuardianTimelineStatusV1: String, Sendable, Equatable, Codable {
    case active     = "ACTIVE"      // lifecycle / informational (green)
    case benign     = "BENIGN"      // evidence examined, no shield/caution signal in scope (green, scoped claim)
    case caution    = "CAUTION"     // a caution-level signal (orange)
    case shieldMatch = "SHIELD_MATCH" // a personal-shield match (red)
    case unknown    = "UNKNOWN"     // honest abstention — not yet decided (neutral)
    case ended      = "ENDED"       // session/observation stopped (neutral)
}

// MARK: - A single timeline event (the full privacy-safe surface — nothing more is permitted)

public struct GuardianTimelineEventV1: Sendable, Equatable, Codable, Identifiable {
    /// Monotonic per-session sequence (also the stable identity for SwiftUI).
    public let sequence: UInt64
    public var id: UInt64 { sequence }
    /// Wall-clock instant (seconds since 1970) — the ONLY time surface shown to the user.
    public let epochSeconds: Double
    public let category: GuardianTimelineCategoryV1
    public let status: GuardianTimelineStatusV1
    /// The REAL reason code (same enum the Live Insight "Neden?" uses). Drives the per-event explanation. Optional:
    /// pure lifecycle events (started/ended) may carry none.
    public let reasonCodeRaw: String?
    /// The resolved identity revision this event belongs to (mandate C: events match session id + identity
    /// revision). Lets the UI group events by content and prevents cross-content drift.
    public let identityRevision: Int

    public init(sequence: UInt64, epochSeconds: Double, category: GuardianTimelineCategoryV1,
                status: GuardianTimelineStatusV1, reasonCodeRaw: String?, identityRevision: Int) {
        self.sequence = sequence; self.epochSeconds = epochSeconds
        self.category = category; self.status = status
        self.reasonCodeRaw = reasonCodeRaw; self.identityRevision = identityRevision
    }
}

// MARK: - The session-scoped envelope carried over IPC (bounded + TTL + session id)

public struct GuardianTimelineSnapshotV1: Sendable, Equatable, Codable {
    /// The session this snapshot belongs to — a reader for a DIFFERENT session discards it (A2 cross-session law).
    public let sessionID: String
    /// When this snapshot was written (for TTL; a crashed broadcast's snapshot ages out).
    public let writtenAtEpoch: Double
    /// Whether the writer is still broadcasting (false after broadcastFinished → reader shows ENDED, never live).
    public let broadcasting: Bool
    public let events: [GuardianTimelineEventV1]

    public init(sessionID: String, writtenAtEpoch: Double, broadcasting: Bool, events: [GuardianTimelineEventV1]) {
        self.sessionID = sessionID; self.writtenAtEpoch = writtenAtEpoch
        self.broadcasting = broadcasting; self.events = events
    }
}

// MARK: - The writer (extension side): bounded RAM ring + dedup + bounded mirror to the App Group

/// One instance per broadcast session. RAM-first: the authoritative event list is the in-memory ring; the App
/// Group mirror is a derived, bounded snapshot. Serial by contract (called from the SampleHandler frame path).
public final class GuardianSessionTimelineWriterV1 {
    /// Hard cap on retained events (mandate D: 50–100). 64 keeps the snapshot small for the UserDefaults mirror
    /// while comfortably covering a normal session; the oldest events are dropped first (bounded, never grows).
    public static let capacity = 64
    /// The mirror key in the App Group suite (distinct from the heartbeat key).
    public static let snapshotKey = "guardian.session.timeline.v1"
    /// How long a mirrored snapshot is honoured by a reader before it is treated as stale (crash safety). Generous
    /// vs the heartbeat window because the timeline is a REVIEW surface, not a liveness surface.
    public static let snapshotTTLSeconds: Double = 30.0

    public let sessionID: String
    private let suite: UserDefaults?
    private var ring: [GuardianTimelineEventV1] = []
    private var seq: UInt64 = 0
    private var broadcasting = true
    // Dedup state (mandate C/F: the same event is not appended over and over).
    private var lastCategory: GuardianTimelineCategoryV1?
    private var lastStatus: GuardianTimelineStatusV1?
    private var lastReason: String?
    private var lastIdentityRevision: Int = -1

    public init(sessionID: String, suite: UserDefaults?) {
        self.sessionID = sessionID; self.suite = suite
    }

    /// How many events are currently retained (bounded by capacity). For tests / diagnostics.
    public var count: Int { ring.count }
    public var events: [GuardianTimelineEventV1] { ring }

    /// Record a meaningful Guardian event. DEDUP: a run of IDENTICAL (category, status, reason, identityRevision)
    /// events collapses to the first (mandate F) — EXCEPT lifecycle gaps/resumes which are always meaningful. Each
    /// accepted event advances the sequence, appends to the bounded ring, and (optionally) mirrors to the suite.
    /// Returns the event if it was recorded, nil if it was deduped away.
    @discardableResult
    public func record(category: GuardianTimelineCategoryV1, status: GuardianTimelineStatusV1,
                       reasonCodeRaw: String?, identityRevision: Int, nowEpoch: Double,
                       mirror: Bool = true) -> GuardianTimelineEventV1? {
        if isDuplicate(category: category, status: status, reasonCodeRaw: reasonCodeRaw,
                       identityRevision: identityRevision) {
            return nil
        }
        seq &+= 1
        let ev = GuardianTimelineEventV1(sequence: seq, epochSeconds: nowEpoch, category: category,
                                         status: status, reasonCodeRaw: reasonCodeRaw,
                                         identityRevision: identityRevision)
        ring.append(ev)
        if ring.count > Self.capacity { ring.removeFirst(ring.count - Self.capacity) }
        lastCategory = category; lastStatus = status; lastReason = reasonCodeRaw
        lastIdentityRevision = identityRevision
        if mirror { writeSnapshot(nowEpoch: nowEpoch) }
        return ev
    }

    /// Dedup predicate — PURE and testable. A repeated identical event is suppressed; a change in ANY field makes
    /// it meaningful again. Lifecycle gap/resume events are never considered duplicates of a prior event.
    private func isDuplicate(category: GuardianTimelineCategoryV1, status: GuardianTimelineStatusV1,
                             reasonCodeRaw: String?, identityRevision: Int) -> Bool {
        if category == .observationGap || category == .observationResumed { return false }
        return category == lastCategory && status == lastStatus
            && reasonCodeRaw == lastReason && identityRevision == lastIdentityRevision
    }

    /// Mark the session as no longer broadcasting (broadcastFinished). The final snapshot carries broadcasting=false
    /// so a reader can show ENDED immediately, never a lingering "live".
    public func markFinished(nowEpoch: Double) {
        broadcasting = false
        writeSnapshot(nowEpoch: nowEpoch)
    }

    /// Mirror the current bounded ring to the App Group suite. Derived-only; no raw media by construction.
    private func writeSnapshot(nowEpoch: Double) {
        guard let suite else { return }
        let snap = GuardianTimelineSnapshotV1(sessionID: sessionID, writtenAtEpoch: nowEpoch,
                                              broadcasting: broadcasting, events: ring)
        if let data = try? JSONEncoder().encode(snap) { suite.set(data, forKey: Self.snapshotKey) }
    }

    /// Session-end cleanup (MANDATORY — mandate D). Removes both the mirror and the RAM ring so no history survives.
    public func clear() {
        ring.removeAll()
        suite?.removeObject(forKey: Self.snapshotKey)
    }
}

// MARK: - The reader (app side): pure, TTL- and session-aware decode

public enum GuardianSessionTimelineReaderV1 {
    /// Read the mirrored snapshot. Returns nil if absent/undecodable. The CALLER applies the TTL / session policy
    /// via `liveEvents(...)` so the freshness decision is pure and testable.
    public static func readSnapshot(suite: UserDefaults?) -> GuardianTimelineSnapshotV1? {
        guard let suite, let data = suite.data(forKey: GuardianSessionTimelineWriterV1.snapshotKey),
              let snap = try? JSONDecoder().decode(GuardianTimelineSnapshotV1.self, from: data) else { return nil }
        return snap
    }

    /// PURE freshness + session policy. Events are shown ONLY if the snapshot matches the expected session AND is
    /// within TTL. A stale snapshot (crashed broadcast) or a prior session's snapshot yields an EMPTY feed — the
    /// timeline never shows another session's events, and never shows a dead session as live.
    public static func liveEvents(_ snap: GuardianTimelineSnapshotV1?, expectedSessionID: String?,
                                  nowEpoch: Double,
                                  ttl: Double = GuardianSessionTimelineWriterV1.snapshotTTLSeconds)
        -> [GuardianTimelineEventV1] {
        guard let snap else { return [] }
        if let expected = expectedSessionID, snap.sessionID != expected { return [] }
        let age = nowEpoch - snap.writtenAtEpoch
        if age < 0 || age > ttl { return [] }
        return snap.events
    }

    /// Clear the mirror (app-side session-end cleanup, belt-and-braces with the writer's clear()).
    public static func clear(suite: UserDefaults?) {
        suite?.removeObject(forKey: GuardianSessionTimelineWriterV1.snapshotKey)
    }
}
