# P007 — Implementation Evidence

**Scope:** device/native-surface/hard-intelligence certification phase. No subscription/social/cloud/family/marketing.
**Verify:** `swift test` → **214/214**; `xcodebuild … iPhone 17 Pro … CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**.

## 1. Device & signing (§2)
Audited honestly: 2 valid Apple Development identities + a **connected iPhone 14 Pro Max** now exist, but
`DEVELOPMENT_TEAM` is unset → device build fails with the exact blocker `requires a development team`. All device
metrics = `NOT_MEASURED`. Doc: P007_DEVICE_AND_SIGNING_ENVIRONMENT.

## 2. Native surfaces (§3,§5,§6,§24)
- `GuardianActivationBridge` (App-Group-ready shared state), `GuardianActivityAttributes` + `GuardianLiveActivityAdapter`
  (ActivityKit) — compile in the app; drive the headless-tested `LiveActivityUpdatePolicy` + `NativeSurfaceState`.
- `LiveActivityUpdatePolicy` (GuardianCore): debounce, no-change/out-of-order suppression, safety-escalation bypass,
  counters — tested. `NativeSurfaceState`: lock-safe minimal states (no rule text) — tested.
- ControlWidget extension target intentionally not added (needs signing + extension target; would not function and
  risks the build). Its shared-state contract compiles. Docs: P007_CONTROL_CENTER / P007_LIVE_ACTIVITY.

## 3. Speech V3 (§7,§8)
`SpeechTranscriberV3`: on-device-only probe + transcribe over project-owned synthesized TR/EN fixtures. Lab host →
explicit `BLOCKED_*` verdict + honest `.unavailable` abstention (no fabricated transcript). Doc: P007_SPEECH_EVAL.

## 4. General Audio V2 / Music (§9,§10)
Real SoundAnalysis (`GeneralAudioHeadV1`) over project-owned tone/silence fixtures; availability ∈ {available, unknown,
unavailable}, never a fabricated label. Music identity (ShazamKit) remains honest UNAVAILABLE.

## 5. H1 visual safety (§11,§12,§14) — Outcome B
No rights-clear model integrated; `SensitiveVisualHead` stays UNAVAILABLE. Evidence-backed blocker + custom-training /
annotation / dataset-acquisition plan in P007_H1_VISUAL_SAFETY_CANDIDATES. §14 cross-use prevention tested: a visual
**reference** shield match is never read as an H1 **safety** verdict (distinct types/reason codes).

## 6. Full-pipeline admission (§15,§16,§17)
`AdmissionTimeline` (first-trustworthy = non-deep stages only) + 15-case benchmark. Fast path provably excludes deep
time. LAB p95 0.398 ms (media stages MODELED, labelled). Cancelled → no admission. Unsupported language → UNKNOWN.
Doc: P007_FULL_PIPELINE_ADMISSION_BENCHMARK. SLO yaml updated (TARGET/LAB_MEASURED/DEVICE_MEASURED/CERTIFIED separated).

## 7. Device capability + model lifecycle (§23,§26)
`DeviceCapabilityProfile` routes a compute mode from runtime signals (no marketing names); thermal/low-power dominate.
`ModelLifecycleV2`: lazy cold-load once → warm reuse, unload under pressure, checksum-fail, rollback — tested.

## 8. Soak + leak (§21,§22)
`TaskLedger` + headless 5,000-swipe soak → drains to baseline, <20 cold-loads, no index growth, Live Activity spam
suppressed. Device energy/thermal soak = NOT_MEASURED. Docs: P007_SOAK_TEST, P007_DEVICE_RESOURCE_EVIDENCE.

## 9. Global language gate (§28)
TR/EN = labSupported with own calibration state; unassessed language stays `.unassessed`, calibration `UNAVAILABLE`,
no threshold inheritance — tested.

## 10. GuardianLab V5 (§31)
`P007EvidencePanel` — internal disclosure showing compute plan, H1 status, speech/device/admission states (honest
NOT_MEASURED where device-only). Not shown in normal UX.

## 11. Tests (§32) — +14 → 214
GuardianCore: P007CoreTests (7), P007FullPipelineBenchmarkTests (1), P007SoakTests (1). GuardianIntelligence: P007H1Tests
(2). GuardianMedia: P007SpeechAudioTests (3). All prior 200 green.

## 12. Known limitations / honesty
Device metrics, on-device speech transcripts, live Control Center/Dynamic Island, H1 detection, and calibration are all
PENDING/UNAVAILABLE with exact blockers. Release level = **R1**; R2 unblockable on one human signing step. No fabricated
device or accuracy numbers.
