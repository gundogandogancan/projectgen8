# PROMPT 009A-R2 — MEASURED REAL-DEVICE TIER-0 EVIDENCE DISTRIBUTIONS
## Use only AFTER the independent red-team audit returns GO

**RECOMMENDED MODEL:** Claude Fable
**EFFORT:** High
**PRECONDITION:** Independent audit verdict is:
`GO — CONTINUE TO MEASURED TIER-0 EVIDENCE CALIBRATION`

# PURPOSE

The latest P009A-R1 device run still failed item grouping:
- 73 shots
- 72 grouped items
- ~20 expected items
- ratio ≈3.6
- 1 SAME_ITEM
- 14 AMBIGUOUS
- 0 deferred coalesces
- ~1.4% analyses avoided
- privacy/session/resource gates passed

The current root-cause hypothesis is that current Tier-0 cross-shot continuity features
do not separate internal cuts from item boundaries on real content.

But `evidence=false` means channel-specific per-cut distributions were not fully measured.

This revision MUST MEASURE BEFORE DESIGNING THE NEXT POLICY.

# 1. DO NOT CHANGE GROUPING POLICY YET

Freeze:
- boundary-policy-v5
- item-grouping-policy-v2-extension-tier0
- all existing weights/thresholds

No tuning before measurement.

# 2. BUILD AN EVIDENCE BUILD

Enable `GEN8_EVIDENCE_BUILD` at compile/build-configuration level for the Broadcast Upload Extension.

It must log derived scalars ONLY.

Per shot transition log:
- timestamp
- shot sequence
- transition mode
- current grouped item state
- same score S
- new score N
- theme distance
- projection correlation
- histogram distance
- regional continuity
- edit cadence features
- chrome/layout continuity
- replacement evidence
- swipe/pan evidence
- elapsed item time
- deferred-coalescer state
- decision
- reason codes

NO:
- raw frames
- screenshots
- video
- audio
- OCR text
- captions
- titles
- app-private content

# 3. USER-GATED SCRIPTED PHYSICAL SESSION

Install the evidence build and STOP for the user's gesture.

Ask the user to run ONE structured session with blocks:

A. 10–15 sec on one multi-cut edited Reel WITHOUT swiping
B. another multi-cut Reel WITHOUT swiping
C. one panning/high-motion Reel WITHOUT swiping
D. one slow swipe to a clearly different item
E. stay 5–8 sec
F. one swipe to a visually similar/same-theme different item
G. stay 5–8 sec
H. rapid swipe across 2–3 distinct items
I. one overlay/comments open-close if convenient
J. app switch and return
K. stop broadcast

User should record only approximate block order and counts.

# 4. AFTER USER RUN — DERIVED LOG ANALYSIS

Do not infer labels purely from the detector.

Use the user's scripted block structure as MANUAL_APPROXIMATE labels:
- SAME_ITEM_INTERNAL_CUT block
- PAN_SAME_ITEM block
- NEW_ITEM_SWIPE block
- SIMILAR_NEW_ITEM block
- RAPID_NEW_ITEMS block

Compute per-channel distributions by class:

For SAME_ITEM_INTERNAL_CUT:
- projection corr
- histogram distance
- theme distance
- regional continuity
- cadence
- S/N

For NEW_ITEM:
same metrics.

Report:
- p05/p25/p50/p75/p95
- min/max
- overlap
- ROC-like separability if meaningful
- pairwise redundancy
- which features have real signal
- which features collapse on device

# 5. DECISION GATE

Based on measured distributions choose ONE of three outcomes:

## OUTCOME A — TIER-0 IS SEPARABLE
If cheap derived features show enough separation:
design P009A-R3 using measured distributions.

## OUTCOME B — TIER-0 IS WEAKLY SEPARABLE
If only richer cheap visual signatures may help:
benchmark candidate features WITHOUT shipping them yet:
- dHash
- higher-resolution projection
- color moments
- compact edge histogram
- sparse Vision feature print only on ambiguous shot boundaries if memory/latency allows

## OUTCOME C — TIER-0 IS NOT SAFELY SEPARABLE
If internal cuts and real item boundaries materially overlap:
do not force grouping in the extension.
Define capability truth:
- extension provides shot segmentation + provisional item identity
- full item grouping requires Tier-1 in-process multimodal evidence or future official shared capability

Safety beats count-matching.

# 6. RESOURCE / PRIVACY

Measure evidence-build overhead separately.
Evidence build is debug/audit-only and must not become release behavior.

Re-run container sweep:
- raw media = 0
- OCR text = 0
- uploads = 0

# 7. FINAL REPORT

## 1. AUDIT PRECONDITION
## 2. EVIDENCE BUILD
## 3. PHYSICAL SESSION
## 4. SAME-ITEM DISTRIBUTIONS
## 5. NEW-ITEM DISTRIBUTIONS
## 6. CHANNEL SEPARABILITY
## 7. CHANNEL REDUNDANCY
## 8. TIER-0 INFORMATION CEILING
## 9. RESOURCE OVERHEAD
## 10. PRIVACY RECHECK
## 11. OUTCOME A/B/C
## 12. NEXT ARCHITECTURE DECISION
## 13. STATUS

Status exactly one:
`MEASURED — TIER-0 SEPARABLE`
`MEASURED — TIER-0 WEAKLY SEPARABLE`
`MEASURED — TIER-0 NOT SAFELY SEPARABLE`
`BLOCKED`

Then STOP.
Do not start P009B.
Do not retune policy in the same evidence-measurement turn.
