# P006A — Cross-Modal Shield Contract

How a single personal shield rule binds across text, image, audio, source, and time — and how evidence from
different modalities is combined **deterministically**.

## 1. One concept, many modalities
A rule carries a `rawUserLabel` (+ optional `canonicalConceptID`) and may be matched by evidence from:
`TEXT` (structured / OCR / transcript), `IMAGE`/`LOGO` (Vision feature print), `AUDIO` (SoundAnalysis class),
`SOURCE` (publisher/channel), `MUSIC` (identity — currently UNAVAILABLE).

## 2. Fusion rule (deterministic, no model emits the final action)
1. Run every allowed matcher; each returns a `ShieldMatchResult` with an ordered `ShieldMatchState`.
2. The evaluator takes the **strongest** state across modalities as `bestState`
   (`NO_MATCH < UNAVAILABLE < UNKNOWN < CONFLICTING < LOW < MEDIUM < HIGH < EXACT`).
3. `ShieldActionControllerV2` maps `(rule.action, bestState, controlledSurface, strict)` → final `ShieldAction`.
4. The LLM / ML heads never emit the final action; they only contribute matcher signal (Rule 8, §4).

## 3. Confidence is per-modality and never averaged into a fake number
Each modality reports its own `rawConfidence` / `calibratedConfidence` (nil = UNAVAILABLE). We do not blend them
into one "AI confidence." The controller consumes the discrete state, not a fused scalar.

## 4. Conflict handling
When modalities disagree in a way that cannot be ordered (e.g. one HIGH shield vs one strong benefit), the state is
`CONFLICTING` → controller yields **ASK** on a destructive rule. This reuses the P006 `MultimodalDisagreementCouncil`
posture: disagreement is surfaced, not silently resolved.

## 5. Modality availability is truthful
- Text (exact/alias/source/sound-class): REAL and always available on-device.
- Semantic text: REAL where an NLEmbedding exists for the locale; else UNAVAILABLE.
- Image/logo: REAL via Vision feature print.
- Music identity: UNAVAILABLE (no ShazamKit catalog/auth in lab) — never faked.
- Speaker identity / face identity: **out of scope by privacy design** (§5/§6).

## 6. Temporal binding
For long content, a matched modality is attached to the `TemporalGraph` segment that produced it (provider/version
attribution from P004/P005). A time-scoped shield match therefore targets the offending segment, not the whole asset,
and an alternate-cut/version mismatch refuses to reuse a stale segment match (P004 temporal refusal).

## 7. Contract invariants
- No single modality can silently hide on LOW/UNKNOWN.
- Missing modality ≠ NO_MATCH (missing data ≠ zero; Rule 6).
- Every outcome carries a `reason` code for the explanation engine.

## 8. 006B CORRECTION (binding — supersedes any contrary wording above)
- The strongest-state fusion ranks **actual matches only** (`matchRank`). `MATCHABILITY_UNKNOWN` /
  `MATCHER_UNAVAILABLE` are NOT matches and never win, never equal "safe", never auto-hold.
- Matchers are routed per rule (`effectiveMatchers` + `handles(inputType)`); an unavailable matcher for one modality
  contributes to `missingMatchers`/`coverage` only, and cannot affect rules of other modalities.
- The Shield layer MAY ABSTAIN (`NO_SHIELD_DECISION`). Strict HOLD originates solely from `GlobalAdmissionController`
  under `STRICT_NO_EXPOSURE_IF_UNVERIFIED`. See `docs/intelligence/P006B_SHIELD_DECISION_SEMANTICS.md`.
