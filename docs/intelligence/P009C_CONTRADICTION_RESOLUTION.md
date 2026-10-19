# P009C — Contradiction Resolution (`ContradictionResolverV1`)

Distinguishes true contradiction, modality mismatch, temporal change, sarcasm/satire possibility,
quote-vs-stance, stale evidence, and plain ambiguity. **No majority vote.**

## Outcomes (decision law, in order)

| Condition | Outcome |
|---|---|
| a side has no live evidence (stale/unavailable) | `INSUFFICIENT_EVIDENCE` (risk retained if it existed) |
| risk is MULTIMODAL (≥2 independence families) and strong (≥0.5) | `STRONG_RISK_DOMINANT` — qualifiers cannot erase (§18 law) |
| qualifier tag (quoted/satire/educational/fiction) + risk is lexical-only | `CONTEXT_QUALIFIED` — evidence RETAINED, meaning annotated |
| risk strictly earlier, positive strictly later | `TEMPORAL_REINTERPRETATION` — historical risk retained by law |
| one side ≥2× stronger via INDEPENDENT families | `MODALITY_PRIORITY` (strength asymmetry, never a vote count) |
| otherwise | `UNRESOLVED` — represented, not resolved |

Every resolution carries `riskRetained` (always true when risk existed) + reason + provenance.

## Context tags (§18 — heuristic, qualifier-only)

`ContradictionResolverV1.detectContextTags`: quote cues (quotation marks, "dedi ki", " said "), satire/
humor cues (lol/😂/parody/parodi/şaka…), educational-mention (lesson/ders). HeuristicSupportOnly class —
they QUALIFY lexical evidence and can never erase multimodal risk (tested:
`testSatireCannotEraseMultimodalRisk`, `testQuotedLexicalRiskIsQualifiedNotErased`).
