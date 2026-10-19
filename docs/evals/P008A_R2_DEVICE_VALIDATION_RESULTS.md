# P008A-R2 — Fresh Device Validation Results

Status: `RUN COMPLETE` → **FIX REQUIRED** (frozen `boundary-policy-v3` over-detects on real content).
Accuracy label: `APPROXIMATE` (manual ground truth; no frame-level labels — not reported as exact P/R).

## Session
- Build: scheme `Gen8` + `GuardianBroadcastExtension`, engine `BoundaryEvidenceAccumulatorV3(policy: .frozenV3)`,
  revision `boundary-policy-v3`, `profile=EXTENSION_FAST`, OCR off.
- Device: iPhone 14 Pro Max (iPhone15,3), iOS 26.6, `com.gen8.guardian.dev`.
- User traversed ~20 distinct feed items (high-motion + low-motion + similar-theme), one app switch + return, then stopped.
- Evidence (immutable): `docs/evals/artifacts/P008A_R2_AFTER_crossapp_device_v3.log`
  SHA-256 `e0f2328440f494ff5d0283e5f606ac8882e6702d6a5bce34488932f1f32f1148`.
  (The container log is append-only and also contains 3 older sessions; the V3 session is the last one,
  the only `policy=boundary-policy-v3` block — `BROADCAST_FINISHED frames=3919 … contentSeq=477`.)

## §16 — Device validation criteria (approximate ground truth)
| field | value | verdict |
|-------|-------|:------:|
| committed NEW count | **477** | — |
| expected distinct items (approx) | ~20 | — |
| count ratio = committed / expected | **≈ 23.9** (target 0.75–1.25) | **FAIL** |
| candidate count (changes) | 657 | — |
| candidate→commit ratio | 657 / 477 ≈ **1.38** (≈73% of candidates commit → no effective debounce) | FAIL |
| obvious burst-spam | **YES** — 343/477 (72%) commits are `strong=false AND agree≤1`; 260/477 (55%) have `agree=0` (no region jumped); long runs of consecutive commits (e.g. seq 200–205, D≈0.15–0.18) | FAIL |
| obvious missed transitions | real ~20 boundaries are buried in spam; cannot isolate cleanly — `APPROXIMATE` | — |
| manual actions / expected items | 1 Start / ~20 ≈ 0.05; **0 per-item** | PASS |
| session interruptions | **0** (one BROADCAST_STARTED + one FINISHED for V3) | PASS |
| app switch forced Gen8 reopen? | **No** (single uninterrupted session across the switch) | PASS |
| privacy / resource gates | green (see RESOURCE_RESULTS, PRIVACY_RECHECK) | PASS |
| score | 477/477 `UNKNOWN` (gating held) | PASS |

## §17 — root-cause error analysis (NOT retuned to this run)
At commit the weighted distance `D` has median **0.137** (just above the `transitionFloor`/`minDynamicThreshold`
0.070) and 352/477 (74%) commit with `D < 0.20`. The adaptive threshold stayed pinned at the 0.070 floor
for **391/477 (82%)** of commits.

Mechanism: `isJump = strong || (contentMoved && D≥dynThr && D≥transitionFloor)` with
`contentMoved = center ≥ centerContentFloor (0.12)`. On REAL video the center region moves ≥0.12 on nearly
every frame, so almost every frame is a "jump". Jump frames are deliberately excluded from the rolling
baseline and the baseline is cleared on commit — therefore the baseline never accumulates samples, so
`dynThr` never rises above its floor. A self-defeating loop: continuous within-item motion is read as a
stream of transitions, throttled only by `refractoryFrames=2` → a commit roughly every other frame.

Why the lab missed it: the owned fixtures modeled within-item motion with small per-frame drift
(0.005–0.10) that mostly stayed BELOW `centerContentFloor`/`transitionFloor`, letting the baseline
accumulate and yielding held-out R=0.917 / P=1.000. **Real-device motion magnitude is far larger than the
synthetic drift, so the lab held-out set was not representative** of real within-item motion. Lab
generalization did NOT transfer to the device.

This is worse than the R1 BEFORE baseline (406) — 477 commits. Per §17 the run is archived as validation
evidence; the policy is NOT retuned to it. A new revision with representative motion fixtures + a fixed
baseline/threshold mechanism is required (see FIX DIRECTION below).

## FIX DIRECTION (for a new tune/eval cycle — NOT applied here)
- The adaptive baseline must include sustained within-item motion even when it exceeds the floor (e.g.
  update the baseline on non-committed frames regardless of the jump flag, or track a separate motion-energy
  estimator), so `dynThr` actually rises under continuous motion.
- `centerContentFloor` alone cannot distinguish motion from a cut; add a true temporal-discontinuity signal
  (e.g. require `D` to exceed a multiple of the recent motion level, not just a fixed floor).
- Rebuild fixtures with motion magnitudes measured from (rights-clear, owned) real-style sequences so the
  TUNE/HELD-OUT split is representative before re-freezing.
