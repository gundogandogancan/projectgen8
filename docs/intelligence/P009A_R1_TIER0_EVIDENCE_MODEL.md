# P009A-R1 — Tier-0 Evidence Model

Status: `TESTED`. Source: `ContentItemGroupingEngineV2` + evidence components (ProfileAwareGroupingV2.swift).

## §5 Tier-0 evidence distributions (TUNE, measured via the scan + slice telemetry)
Realized separation on the TUNE corpus (style/content decoupled builder):
- SAME-ITEM transitions: normalized S typically 0.55–0.85 (style stack 0.50–0.75 raw + theme/cadence anchors);
  N ≤ 0.25 (occasional theme-disc on wild montage cuts).
- NEW-ITEM transitions: N 0.35–1.08 (swipe 0.50 / surface 0.40 / style-breaks 0.40 / theme-disc 0.25 / dwell 0.15
  stack); S ≤ ~0.45 (chrome+regional residue).
- OVERLAP ZONE (honest): style-similar different items at edit cadence or after long dwell with weak theme — the
  designed AMBIGUOUS band. Redundancy note: in synthetic data theme/projection/histogram correlate by construction
  (all functions of the content/style scalars); on real content they are partially independent. Recorded, not hidden.

## Channel weights (frozen, both profiles)
SAME: theme 0.20 · projection 0.20 · histogram 0.15 · cadence 0.15 · chrome 0.10 · regional 0.10 · cut-prior 0.05
(+ Tier-1: caption 0.35 · audio 0.30). NEW: swipe 0.50 · surface/chrome-change 0.40 · theme-disc 0.25 ·
projection-break 0.20 · histogram-break 0.20 · dwell 0.15 · crossfade 0.15 (+T1 caption-change 0.30 · audio-break 0.20)
· cache-prior 0.30·conf.

## Anchor rule (the safety core)
SAME requires a CONTENT or CROSS-MODAL anchor: **strong theme (≤0.12) anchors regardless of dwell; weak theme
(≤0.22) anchors only at edit cadence (prev shot < longDwellMs)**; caption/audio anchor in Tier-1. Style-only
continuity (projection/histogram/chrome/regional) and cadence can NEVER be the sole merge basis (§6B/§6C) — this
rule killed both residual false-merge mechanisms found during tuning (burst-anchored similar items; weak-theme
merges after a long watch).

## §9 calibration decision
Evaluated candidates: profile-normalized score + monotonic rules (adopted), bounded logistic / isotonic (REJECTED —
no held-out improvement to buy their complexity; the normalized monotonic rule is deterministic, inspectable, tiny,
versioned, profile-specific, extension-safe). Decision:
```
strongNew (swipe/surface)            → veto merge; NEW if N ≥ confirmNewRaw else AMBIGUOUS
N ≥ confirmNewRaw ∧ S < sameVeto     → NEW
S ≥ confirmSame ∧ N < newVeto ∧ anchored → SAME
otherwise                            → AMBIGUOUS (provisional split, no admission inheritance)
```
