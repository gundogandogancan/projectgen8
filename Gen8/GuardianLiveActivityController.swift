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
    // §2.3 — the proof-log DISK WRITE is gated behind the SAME EvidenceBuildPolicyV1 pattern the SampleHandler uses
    // (structurally OFF in release; DEBUG + explicit compile/env opt-in only). Per-update disk appends must never be
    // release behaviour (the Phase-B thermal lesson applies to this writer too). os_log stays always-on (cheap).
    #if GEN8_EVIDENCE_BUILD
    private let evidenceBuild = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: true, isDebugBuild: true, envOptIn: false)
    #elseif DEBUG
    private let evidenceBuild = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: true,
        envOptIn: ProcessInfo.processInfo.environment["GEN8_EVIDENCE_BUILD"] == "1")
    #else
    private let evidenceBuild = EvidenceBuildPolicyV1.isEnabled(compileFlagSet: false, isDebugBuild: false, envOptIn: false)
    #endif
    private init() {}

    // §2.3 — os_log (.notice) ALWAYS (cheap, in-memory, OS-rate-managed). The high-volume APPEND-TO-DISK proof log
    // is gated behind `evidenceBuild` — no per-update disk writes in release.
    private func emit(_ s: String) {
        log.notice("\(s, privacy: .public)")
        guard evidenceBuild else { return }
        print("GEN8_LA \(s)")
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

    /// §2.3 — the staleDate the OS uses to render the Activity as OUT-OF-DATE if we stop updating. We tie it to the
    /// SAME freshness window the heartbeat uses (+ a small grace), so a stuck/suspended app's Activity visibly goes
    /// stale instead of masquerading as a current decision. (Note §2.4: whether a suspended app can push the update
    /// that refreshes this is DEVICE_UNVERIFIED — staleDate is exactly the honest fallback for that case.)
    private func staleDate(from now: Date = Date()) -> Date {
        now.addingTimeInterval(GuardianObservationHeartbeatBridgeV1.freshnessWindowSeconds + 2.0)
    }

    /// User-initiated start (Guardian ON). Idempotent: if one is already active, no-op. The optional `marker` is the
    /// pure, state-derived heat band + continuous position for the Island bar (no fabricated score — see
    /// GuardianHeatMarkerV1). `title` is the §2.3 state-specific title; `style` is the §2.1 user display mode.
    func start(contentID: String, surface: NativeSurfaceState, label: String,
               marker: GuardianHeatMarkerV1? = nil,
               title: String = "Gözlemde", displayStyleRaw: String = GuardianDisplayStyleRaw.heatMap) {
        guard #available(iOS 16.1, *) else { emit("START skipped: iOS<16.1"); return }
        guard areActivitiesEnabled else { emit("START blocked: areActivitiesEnabled=false"); return }
        if current != nil { emit("START noop: already active"); return }
        seq += 1
        sessionStart = Date()   // a fresh session → the alive timer restarts from zero
        let m = marker ?? GuardianHeatMarkerV1.fromSurfaceRaw(surface.rawValue, confidence: 0)
        let attrs = GuardianActivityAttributes(contentID: contentID)
        let state = GuardianActivityAttributes.ContentState(surface: surface.rawValue, label: label, sequence: seq,
                                                            bandRaw: m.band.rawValue, bandPosition: m.position,
                                                            sessionStart: sessionStart,
                                                            displayStyleRaw: displayStyleRaw, title: title)
        do {
            let act = try Activity.request(attributes: attrs,
                                           content: .init(state: state, staleDate: staleDate()),
                                           pushType: nil)   // local activity (no push) — works without paid push entitlement
            current = act; currentContentID = contentID
            emit("START ok id=\(act.id) contentID=\(contentID) surface=\(surface.rawValue) band=\(m.band.rawValue) title=\(title) style=\(displayStyleRaw) pos=\(String(format: "%.3f", m.position)) activeCount=\(activeCount) activityState=\(String(describing: act.activityState))")
        } catch {
            emit("START error=\(error.localizedDescription)")
        }
    }

    /// Debounced update. Content-identity change ⇒ end old + start new (never carry a stale positive across content).
    /// `marker` is the state-derived heat band + continuous marker position (no fabricated score). A content switch
    /// that moves the marker to a new band is the "marker slides to the watched band the instant content changes".
    func update(contentID: String, surface: NativeSurfaceState, label: String,
                marker: GuardianHeatMarkerV1? = nil,
                title: String = "Gözlemde", displayStyleRaw: String = GuardianDisplayStyleRaw.heatMap) {
        guard #available(iOS 16.1, *), let act = current else { return }
        if contentID != currentContentID {              // identity change → restart cleanly
            Task { await end(reason: "content-change")
                   start(contentID: contentID, surface: surface, label: label, marker: marker,
                         title: title, displayStyleRaw: displayStyleRaw) }
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
                                                            sessionStart: sessionStart,
                                                            displayStyleRaw: displayStyleRaw, title: title)
        Task {
            await act.update(.init(state: state, staleDate: staleDate()))
            emit("UPDATE ok surface=\(surface.rawValue) band=\(m.band.rawValue) title=\(title) style=\(displayStyleRaw) pos=\(String(format: "%.3f", m.position)) seq=\(seq)")
        }
    }

    /// In-app CONTROLLED REELS → drive the Island band. When the app is foreground and a session Activity is already
    /// live, each reel decision slides the marker to THAT reel's band (the watched content's band) WITHOUT restarting
    /// the Activity — the reel's content-switch is expressed purely as a marker/band move (the micro-iteration goal).
    /// No-op if no Activity is live (reels never START one — only Guardian ON does, preserving the lifecycle law).
    /// `surface` keeps the lock-safe leading glyph honest for the reel's band; `marker` carries the real band+position.
    func reelMarker(label: String, surface: NativeSurfaceState, marker: GuardianHeatMarkerV1,
                    title: String = "Analiz", displayStyleRaw: String = GuardianDisplayStyleRaw.heatMap) {
        guard #available(iOS 16.1, *), let act = current, let cid = currentContentID else { return }
        seq += 1
        let escalation = marker.band.impliesAttention
        let decision = policy.consider(contentID: cid, sequence: seq, state: surface,
                                       nowNanos: DispatchTime.now().uptimeNanoseconds, isSafetyEscalation: escalation)
        guard decision == .accepted else { emit("REEL suppressed=\(decision) band=\(marker.band.rawValue)"); return }
        let state = GuardianActivityAttributes.ContentState(surface: surface.rawValue, label: label, sequence: seq,
                                                            bandRaw: marker.band.rawValue, bandPosition: marker.position,
                                                            sessionStart: sessionStart,
                                                            displayStyleRaw: displayStyleRaw, title: title)
        Task {
            await act.update(.init(state: state, staleDate: staleDate()))
            emit("REEL ok band=\(marker.band.rawValue) title=\(title) pos=\(String(format: "%.3f", marker.position)) seq=\(seq)")
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
