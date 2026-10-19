# P002 — Human Labeling Protocol

**Doc status:** `CANONICAL` · **Phase:** 2 · **Date:** 2026-10-18 · PROMPT 002 §13 / 002A §8.

## Principle
For subjective dimensions (e.g. "benefit") there is **no universal objective ground truth** — do not pretend otherwise. Labels preserve the **5-plane ontology firewall** (`ml/schemas/label.schema.json`) and are never collapsed into one good/bad label.

## The five label planes (must stay separate)
1. **OBSERVED_SIGNAL** — directly observable (OCR text present, language, entity mention, visible symbol).
2. **EVIDENCE_BASED_INFERENCE** — supported inference with provenance; never shown as observed fact.
3. **POLICY_CLASSIFICATION** — product/user policy (e.g. Positive Exposure category). Not a truth claim.
4. **PERSONAL_FIT** — alignment to a specific user goal/algorithm; per-user, never global truth.
5. **SPIRITUAL_OR_SYMBOLIC_INTERPRETATION** — interpretive only; never affects Truth/Evidence or the score.

## Separate always (do NOT merge)
content factual properties · safety/sensitive observations · user-policy fit · personal benefit.

## Process
- **Instructions + definitions** per label; a gold-example set per plane.
- **Ambiguity handling:** annotators mark `UNCERTAIN`; never force a binary.
- **Multi-rater:** ≥2 raters for subjective planes; record inter-rater agreement.
- **Disagreement → adjudication** by a third rater / reviewer; record rationale.
- **Prohibited inference:** no medical diagnosis, no metaphysical claim as fact, no secret religion/identity inference, no demographic guessing.
- **Privacy:** no private user screen data, no child private data; synthetic/public-domain/consented only (`rights-provenance.schema.json`).

## Quality
- Gold examples seed each plane; raters calibrated against them before contributing.
- Labels versioned (`labelVersion`) with `annotatorProvenance`.
- Subjective-plane metrics report **agreement + abstention**, never a single accuracy.

## Status (Phase 2)
Protocol + schemas defined. Golden-v0 is synthetic/metadata (no human-subjective labels yet). Human labeling begins when a real (consented/public-domain) dataset exists.
