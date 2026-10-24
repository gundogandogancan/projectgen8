//
//  GuardianLiveActivityController.swift — REAL ActivityKit lifecycle (PROMPT 007C)
//  Starts/updates/ends a real Live Activity so the Dynamic Island + lock screen actually render Guardian state.
//  Start is user-initiated (Guardian ON). Updates are debounced via the tested LiveActivityUpdatePolicy — no per-swipe
//  spam. Content-identity change ends the old Activity and starts a new one (stale/positive-safe). Logs device truth.
//
import Foundation
import GuardianCore
import os

#if canImport(ActivityKit)
import ActivityKit

@MainActor
final class GuardianLiveActivityController {
    static let shared = GuardianLiveActivityController()
    private let log = Logger(subsystem: "com.gen8.guardian.dev", category: "LiveActivity")
    private let policy = LiveActivityUpdatePolicy()
    private var current: Activity<GuardianActivityAttributes>?
    private var currentContentID: String?
    private var seq: UInt64 = 0
    /// The wall-clock start of the CURRENT session — feeds the Island's system-animated Text(timerInterval:) so the
    /// timer ticks continuously with zero app updates. Reset only when a NEW Activity starts (content-identity change).
    private var sessionStart = Date()
    private init() {}

    // Unified log (Console.app) + append to a container file we can pull off-device via `devicectl device copy from`.
    private func emit(_ s: String) {
        print("GEN8_LA \(s)"); log.notice("\(s, privacy: .public)")
        let line = "GEN8_LA \(s)\n"
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let url = dir.appendingPathComponent("gen8_la_proof.log")
            if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
            else { try? line.data(using: .utf8)?.write(to: url) }
        }
    }

    var areActivitiesEnabled: Bool {
        if #available(iOS 16.1, *) { return ActivityAuthorizationInfo().areActivitiesEnabled } else { return false }
    }
    var activeCount: Int {
        if #available(iOS 16.1, *) { return Activity<GuardianActivityAttributes>.activities.count } else { return 0 }
    }

    /// §proof — log authorization + current active count + whether we have ever started one.
    func logDiagnostics(_ tag: String) {
        emit("DIAG tag=\(tag) areActivitiesEnabled=\(areActivitiesEnabled) activeCount=\(activeCount) hasCurrent=\(current != nil)")
    }

    /// User-initiated start (Guardian ON). Idempotent: if one is already active, no-op. The optional `marker` is the
    /// pure, state-derived heat band + continuous position for the Island bar (no fabricated score — see
    /// GuardianHeatMarkerV1). nil → a dormant CLEAR marker at rest (the start moment, before any decision).
    func start(contentID: String, surface: NativeSurfaceState, label: String,
               marker: GuardianHeatMarkerV1? = nil) {
        guard #available(iOS 16.1, *) else { emit("START skipped: iOS<16.1"); return }
        guard areActivitiesEnabled else { emit("START blocked: areActivitiesEnabled=false"); return }
        if current != nil { emit("START noop: already active"); return }
        seq += 1
        sessionStart = Date()   // a fresh session → the alive timer restarts from zero
        let m = marker ?? GuardianHeatMarkerV1.fromSurfaceRaw(surface.rawValue, confidence: 0)
        let attrs = GuardianActivityAttributes(contentID: contentID)
        let state = GuardianActivityAttributes.ContentState(surface: surface.rawValue, label: label, sequence: seq,
                                                            bandRaw: m.band.rawValue, bandPosition: m.position,
                                                            sessionStart: sessionStart)
        do {
            let act = try Activity.request(attributes: attrs,
                                           content: .init(state: state, staleDate: nil),
                                           pushType: nil)   // local activity (no push) — works without paid push entitlement
            current = act; currentContentID = contentID
            emit("START ok id=\(act.id) contentID=\(contentID) surface=\(surface.rawValue) band=\(m.band.rawValue) pos=\(String(format: "%.3f", m.position)) activeCount=\(activeCount) activityState=\(String(describing: act.activityState))")
        } catch {
            emit("START error=\(error.localizedDescription)")
        }
    }

    /// Debounced update. Content-identity change ⇒ end old + start new (never carry a stale positive across content).
    /// `marker` is the state-derived heat band + continuous marker position (no fabricated score). A content switch
    /// that moves the marker to a new band is the "marker slides to the watched band the instant content changes".
    func update(contentID: String, surface: NativeSurfaceState, label: String,
                marker: GuardianHeatMarkerV1? = nil) {
        guard #available(iOS 16.1, *), let act = current else { return }
        if contentID != currentContentID {              // identity change → restart cleanly
            Task { await end(reason: "content-change"); start(contentID: contentID, surface: surface, label: label, marker: marker) }
            return
        }
        seq += 1
        let escalation = (surface == .shieldMatch || surface == .caution)
        let decision = policy.consider(contentID: contentID, sequence: seq, state: surface,
                                       nowNanos: DispatchTime.now().uptimeNanoseconds, isSafetyEscalation: escalation)
        guard decision == .accepted else { emit("UPDATE suppressed=\(decision) surface=\(surface.rawValue)"); return }
        let m = marker ?? GuardianHeatMarkerV1.fromSurfaceRaw(surface.rawValue, confidence: 0)
        let state = GuardianActivityAttributes.ContentState(surface: surface.rawValue, label: label, sequence: seq,
                                                            bandRaw: m.band.rawValue, bandPosition: m.position,
                                                            sessionStart: sessionStart)
        Task {
            await act.update(.init(state: state, staleDate: nil))
            emit("UPDATE ok surface=\(surface.rawValue) band=\(m.band.rawValue) pos=\(String(format: "%.3f", m.position)) seq=\(seq)")
        }
    }

    /// In-app CONTROLLED REELS → drive the Island band. When the app is foreground and a session Activity is already
    /// live, each reel decision slides the marker to THAT reel's band (the watched content's band) WITHOUT restarting
    /// the Activity — the reel's content-switch is expressed purely as a marker/band move (the micro-iteration goal).
    /// No-op if no Activity is live (reels never START one — only Guardian ON does, preserving the lifecycle law).
    /// `surface` keeps the lock-safe leading glyph honest for the reel's band; `marker` carries the real band+position.
    func reelMarker(label: String, surface: NativeSurfaceState, marker: GuardianHeatMarkerV1) {
        guard #available(iOS 16.1, *), let act = current, let cid = currentContentID else { return }
        seq += 1
        let escalation = marker.band.impliesAttention
        let decision = policy.consider(contentID: cid, sequence: seq, state: surface,
                                       nowNanos: DispatchTime.now().uptimeNanoseconds, isSafetyEscalation: escalation)
        guard decision == .accepted else { emit("REEL suppressed=\(decision) band=\(marker.band.rawValue)"); return }
        let state = GuardianActivityAttributes.ContentState(surface: surface.rawValue, label: label, sequence: seq,
                                                            bandRaw: marker.band.rawValue, bandPosition: marker.position,
                                                            sessionStart: sessionStart)
        Task {
            await act.update(.init(state: state, staleDate: nil))
            emit("REEL ok band=\(marker.band.rawValue) pos=\(String(format: "%.3f", marker.position)) seq=\(seq)")
        }
    }

    /// End (Guardian OFF / app background). Clears so no stale Activity lingers.
    func end(reason: String) async {
        guard #available(iOS 16.1, *), let act = current else { return }
        await act.end(nil, dismissalPolicy: .immediate)
        emit("END reason=\(reason) activeCount=\(activeCount)")
        current = nil; currentContentID = nil
    }

    /// DEBUG/headless device proof: exercise the real lifecycle and log device truth. Not part of normal UX.
    func devExercise() {
        logDiagnostics("before-start")
        start(contentID: "dev-exercise", surface: .guardianOn, label: "Guardian on")
        logDiagnostics("after-start")
    }
}
#endif
