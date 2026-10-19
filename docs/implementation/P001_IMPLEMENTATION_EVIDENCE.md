# P001 IMPLEMENTATION EVIDENCE

**Doc status:** `CANONICAL` · **Phase:** 1 · **Date:** 2026-10-18 · PROMPT 001 §30. No fabricated values.

## Build & test results (real)
- **GuardianKit package:** `swift test` → **37 tests, 0 failures** (macOS arm64, Swift 6.3 toolchain, tools-version 5.9). Deterministic; runs headless (no signing).
- **iOS app:** `xcodebuild build -scheme Gen8 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO` → **`** BUILD SUCCEEDED **`**. Local SwiftPM package `GuardianKit` resolved & linked (`@ local`).
- Simulator/device: **iOS Simulator (iPhone 17 Pro, iOS 26.x)**. No physical device (no Team — EXTERNAL_EXECUTION_DEPENDENCY).

## Architecture / modules
- `packages/GuardianKit` — local SwiftPM package.
  - `Sources/GuardianCore` (13 files, **no SwiftUI/UIKit**): ContentTypes, ScoreTypes, PersonalAlgorithm, Preflight (HEURISTIC_V0 + ScoreEngine), LocalCache (actor), AdmissionController, Scheduler (actor), Temporal, Pipeline, Events, Diagnostics, DecisionTrace, Fixtures.
  - `Tests/GuardianCoreTests` (5 files): ScoreAndAdmission, Cache, Scheduler, Temporal, PipelineBenchmark.
- iOS app `Gen8/Gen8/` (SwiftUI, depends on GuardianCore): Gen8App, ContentView(RootView), OnboardingView, GuardianLabView, PureBarView, DesignSystem, GuardianLabModel.
- Wiring: `Gen8.xcodeproj` gains `XCLocalSwiftPackageReference packages/GuardianKit` + `XCSwiftPackageProductDependency GuardianCore` (ADR-0002 relocation to `apps/ios` still pending).

## Pre-exposure pipeline (real code, §4)
`CandidateDiscovered → ContentIdentityResolved → LocalCacheLookup → FastPreflight(HEURISTIC_V0) → PersonalPolicyFusion(deterministic) → AdmissionDecisionReady → GuardianSurfaceUpdate`. Local cache real; admission deterministic; identity = fixture (I0–I4); scores from an explicit versioned formula — **no fabricated scores**; event timestamps + latency real (monotonic clock).

## Device-health strategy (P0-B)
`Diagnostics` records cache hit/miss, preflight runs, cancellations, duplicate-prevented, peak concurrent tasks, decision latency (real), network bytes (0 on fixture path). Protocol `P001_DEVICE_MEASUREMENT_PROTOCOL.md` governs external Instruments measurement for CPU/GPU/energy/thermal (not faked). `os_signpost` markers to be added in the app layer.

## GuardianLab — short-form
Deterministic feed (beneficial/low-value/disease-factual/shielded/unknown). Pure Bar updates per decision; chips expose **cached vs fresh vs unknown**; bounded NEXT+1/+2/+3 scheduler preloads look-ahead.

## GuardianLab — long-form
Deterministic `TemporalGraphStub` (correct v1) + a **wrong-version** graph (v2 alt-cut). Playhead slider; warning lead (20s); ASK sheet (continue/skip); strict auto-skip; **wrong-version & weak-identity ⇒ skip refused (WARN/UNKNOWN), never blind-seek**; skip ≠ delete (resume after segment); analysis-ahead state surfaced.

## Pure Bar / UX (P0-Q)
Ultra-thin adaptive color bar (refined teal/blue/amber/coral/grey — no neon); **color never the only signal** (symbol + text label + score + coverage); tap → status, expand → why/protection/evidence; reduced-motion honored; 44pt touch targets; accessibility labels/hints; UNKNOWN shows grey + "?".

## Dynamic Island capability spike
`docs/platform/ios/DYNAMIC_ISLAND_LIVE_ACTIVITY_CAPABILITY_REPORT.md` — marked RCOV (no live Apple-doc fetch this session) + prototype DEFERRED (needs signing). Pure Bar implemented as a controlled in-app surface; a Live Activity adapter can be added behind the surface abstraction.

## Tests (§23) — all passing
Score states (verified/provisional/insufficient→`?`/conflicting, reproducible); admission precedence (threshold, hard-shield-outranks-threshold, low-confidence-concept-not-hidden, positive-exposure-vs-truth-separation, child-safety-floor-wins, unknown-not-safe); cache (miss/store/hit, version-mismatch, TTL, clear, bounded eviction); scheduler (bounded≤3, dedupe, stale cancellation=3, no-redundant-analysis, idle-no-work); temporal (upcoming, warn-lead, strict auto-skip, normal ask, wrong-version refuse, weak-identity refuse, analysis-ahead states).

## Benchmark scenarios (§31) — covered by tests
S1 cached · S2 fresh · S3 unknown · S4 semantic shield · S5 positive-exposure-vs-truth · S6 long-form warn · S7 auto-skip · S8 wrong-version-blocked · S9 scheduler cancellation · S10 idle-no-loop. All assert as specified.

## Latency / cache / task results (real, sim)
Decision latency recorded via monotonic clock (`decisionCount` increments; exact ns is environment-dependent, **sim only**, not a device SLO). Cache: S1 shows 1 miss + 1 hit, preflightRuns==1 across two identical decides. Scheduler: cancellations==3 on advance; peak concurrent ≤3.

## Privacy / security (§28)
No secrets in source; no raw-frame storage; no screenshots saved; no analytics/network SDK; network bytes==0 on fixture path (asserted); logs are privacy-safe (DecisionTrace: ids/versions/states only, no raw content/CoT).

## Known limitations / unverified claims
- Scores/preflight are **HEURISTIC_V0 / TEST_FIXTURE**, not production AI (labelled in code).
- Identity is fixture-based (no real perceptual hashing yet).
- Latency/energy are **simulator-level**; device baselines + Instruments energy/thermal pending (needs Team / ADR-0003).
- Dynamic Island capability is RCOV (live Apple docs not fetched this session).
- Swift language mode still 5.0 (ADR-0002 Swift-6 adoption pending; not silently changed).
- Xcode app not yet relocated to `apps/ios/` (ADR-0002).
