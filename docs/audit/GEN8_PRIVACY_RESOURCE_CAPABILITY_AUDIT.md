# GEN8 — PRIVACY / RESOURCE / PLATFORM-CAPABILITY AUDIT (Independent Red-Team Audit)

Auditor: independent fresh-context audit session (Claude Fable 5, Claude Code), 2026-10-19. Findings below are from direct source inspection of production targets (`packages/GuardianKit/Sources/*`, `Gen8/`, `GuardianBroadcastExtension/`, `GuardianControlExtension/`, `Shared/`), not from docs.

## 1. PRIVACY

### 1.1 Network / cloud / analytics — VERIFIED ABSENT
Zero occurrences of URLSession / URLRequest / NWConnection / sockets / http(s) URL construction / analytics SDKs in any production source. All imports are Apple frameworks + the repo's own modules. **No code path can transmit anything off-device.** "Never uploaded" claims are structurally true. Cloud behavior: none exists (neither sync nor telemetry).

### 1.2 Raw observation lifetime — VERIFIED EPHEMERAL
Broadcast extension (`SampleHandler.segmentFrame`, lines 143-188): CVPixelBuffer locked read-only, luma sampled in place → 64-bit region hashes + 8-bin projections; buffer never retained, copied, encoded, or serialized. No OCR, speech, audio, or titles exist in the extension process at all (envelope built with `ocrText: nil, soundEvents: []`).

### 1.3 Local persistence — PRESENT, derived-only, with labeling issues
| Writer | File | Content | Assessment |
|---|---|---|---|
| SampleHandler.emit (:191-199) | extension container `Documents/gen8_crossapp_proof.log` | derived scalars/IDs/counters (SHOT/ITEM/STATS lines incl. 64-bit content signatures) | **Always-on in production builds.** Contradicts the log's own `persistToDisk=false` label (true only for frames). Also mirrored to unified log with `privacy: .public`. |
| GuardianLiveActivityController.emit (:25-33) | app container `Documents/gen8_la_proof.log` | Live Activity lifecycle strings | Always-on proof instrument in production code |
| FileBackedPersonalShieldStore (:100-110) | app `Application Support/Gen8/shield/personal-shield.store.json` | user shield rules (incl. raw user label text) + derived reference features (typed non-raw, checksummed) | Legitimate feature persistence; atomic write + iOS complete file protection; delete cascades. Raw reference media excluded by type construction. |
| GuardianMedia Synthetic{Video,Audio} | caller-specified URLs | fixture media | compiled into prod lib but callers are tests only; GuardianMedia is not linked into app or extensions |
| TrainingRunner (via its test) | repo `ml/training/runs/` | model/manifest JSON | test-time repo mutation (lab only) |

No OCR transcript, speech transcript, content-title, or watch-history persistence exists anywhere.

### 1.4 App Group / cross-process state
- Suite id `group.com.aymedo.Gen8` (NativeSurfaces.swift:15-20; GuardianControlState.swift:10-15) — **stale "aymedo" prefix mismatched with the actual bundle id family `com.gen8.guardian.dev`**, no `.entitlements` files exist in the repo, and P007B docs admit the group was never provisionable (free team). Both call sites silently fall back to `UserDefaults.standard` — meaning **cross-process state transfer does not actually function**; each process reads its own standard defaults. Payload would be a single Bool (`guardian.enabled`).
- ActivityKit ContentState crossing to the widget: schemaVersion, surface enum, lock-safe label, sequence — no content data.

### 1.5 Device-container sweep claims
No independent artifact of a device-container sweep exists beyond the pulled proof logs themselves. Claims that the container holds no media: PLAUSIBLE (consistent with code) but NOT_TESTABLE_IN_THIS_SESSION (no device access permitted).

### 1.6 Privacy classification summary
- Raw observation lifetime: ephemeral, in-frame-callback only — VERIFIED (code-level)
- Retained derived state: 64-bit signatures/projections in memory; shield rules + derived features on disk — VERIFIED
- Local persistence: two always-on derived proof logs + shield store — VERIFIED (flagged: proof logs should be build-gated before any beta)
- Cloud: none — VERIFIED
- Telemetry: os_log `.public` + local files only — VERIFIED

## 2. RESOURCE / PERFORMANCE

| Metric | Source | Class |
|---|---|---|
| Cheap-path p50/p95 (0.1–2.9 ms per session) | BROADCAST_FINISHED lines, computed in-extension over bounded 4000-sample buffer | DIRECTLY MEASURED on device, summary-only (raw samples not exported) |
| firstTrustworthyMs (p50 0.073 ms, p95 0.192 ms final session — auditor-recomputed) | ITEM lines | DIRECTLY MEASURED, but **semantics = shield-eval on a nil-OCR envelope against one demo rule.** NOT semantic-understanding latency. Any such reading would be misrepresentation. |
| Memory high-water (29.2–30.3 MB across sessions, vs ~50 MB budget) | mach task_info per decision + peak in FINISHED | DIRECTLY MEASURED (resident size proxy) |
| Thermal (nominal; FAIR 45/73 during P009A session) | ProcessInfo.thermalState per decision | DIRECTLY MEASURED (coarse) |
| Queue depth / dropped frames | not logged | NOT CAPTURED |
| CPU / energy | no Instruments/xctrace artifact for any run (docs admit DEVICE_EVIDENCE_INSUFFICIENT) | NOT CAPTURED |
| Model load/unload | no runtime models exist | N/A (nothing to measure) |
| Pack size / bundle size (claimed 18 MB Debug app, 92 KB main exe, 0 model assets) | P009A doc | NOT RECOMPUTED (xcodebuild denied in this session); PLAUSIBLE_NOT_PROVEN |
| Lab micro-benchmarks (shield ~15 µs/eval; durable lookup ~14 µs; cold load 79 ms @10k) | observed live in this audit's own `swift test` run output | DIRECTLY MEASURED (macOS lab, not device) |
| 5,000-swipe soak | headless lab test | SYNTHETIC ONLY |

Explicit check requested by spec: **`firstTrustworthyMs` is NOT currently misrepresented in the milestone docs as semantic-understanding latency** (docs call it first-decision/cheap latency), but the measurement itself is near-vacuous (nil-OCR shield lookup) and must be re-based once any real perception runs in the extension.

## 3. PLATFORM CAPABILITY TRUTH

| Capability | Status |
|---|---|
| ReplayKit user-consented cross-app observation (broadcast upload extension, RPBroadcastProcessModeSampleBuffer) | **Implemented + physically proven** (8 device sessions in SHA-locked logs; Info.plist `com.apple.broadcast-services-upload`; public API only — no private API found) |
| Inability to silently start ReplayKit | Correctly treated as platform-enforced (user gesture via RPSystemBroadcastPickerView); no hidden-start code exists — VERIFIED (absence) |
| Automatic session continuity | Not implemented beyond session-scoped state; each broadcast is one session; no cross-session identity persistence in the extension — PLANNED at best |
| Dynamic Island / Live Activity | Real ActivityKit + DynamicIsland widget code compiled (`NSSupportsLiveActivities=YES` in pbxproj); updates only a static "Guardian on" from the in-app toggle; **no per-content state ever flows from the broadcast extension to any surface**; self-labeled COMPILED_NOT_DEVICE_VERIFIED → implemented but not physically proven, content-wiring missing |
| App Group cross-process transfer | **Blocked/broken**: group never provisioned, stale `group.com.aymedo.Gen8` id, silent `.standard` fallback |
| App/window identity exposure | Not available via ReplayKit samples; code does not pretend otherwise (surface=UNKNOWN) — correctly bounded |
| OCR/speech/audio in the extension | NOT present (by design, Tier-0); exists in GuardianIntelligence/GuardianMedia for the app/lab only; speech device eval limited to prior P007B claims |
| Control Center toggle | Real ControlWidget code (iOS 18 API), bundled; not device-proven |
| ReplayKit extension build/install path | pbxproj: 3 targets (app + 2 appex), both appex embedded in app, GuardianCore linked to all three, GuardianIntelligence app-only, team 47XQMQZLF6, bundle ids com.gen8.guardian.dev[.GuardianBroadcast/.GuardianControl]; **xcodebuild denied in this session → compile-state of the current working tree NOT re-verified by the auditor** (P007B install evidence + device logs imply it built on 2026-10-19) |

## 4. Key corrective actions (privacy/resource/capability)

1. Build-gate or remove the two always-on proof-log writers and the `.public` unified-log mirroring before any non-lab build; fix the misleading `persistToDisk=false` label.
2. Replace the hardcoded `demo-spoiler` shield rule in the extension with the real (read-only) shield store, or stop logging `match=` as if it were meaningful.
3. Fix the app-group id (stale `aymedo`) and remove the silent `.standard` fallback (it fakes success of cross-process transfer).
4. Capture at least one Instruments/xctrace CPU+energy trace per device milestone — currently zero exist.
5. Rename or re-document `analyzed/heavy/firstTrustworthyMs` telemetry so no future reader mistakes shield-lookup latency for understanding latency.
