# P009B — Rights-Clear Multimodal Eval Corpus

**File:** `packages/GuardianKit/Sources/GuardianCore/P009BCorpusV1.swift` · 17 scenarios × 4 seeds

## Rights status

100% project-authored derived-input bundles (`ExpertInputV2` values written in this repository).
No third-party media, no scraped text, no private production content. Provenance = the source file
itself. Registered in the §19 asset audit ledger as PROJECT_AUTHORED.

## Scenario families (§26 minimums)

| Family | Scenarios |
|---|---|
| single-modality | image-only, text-only, speech-only, audio-event-only, music-only, symbol-heavy |
| agreement | educational-agreement (text+visual+speech), nature-calm-agreement (text+visual+audio) |
| conflict | benign-caption-risky-text, educational-plus-sensitive (contradiction required), urgency-manipulation |
| temporal | benign-then-risky (contradiction required), rapid-cuts-pressure |
| ood/missing | unsupported-language (ja), noisy-ocr, absent-audio, all-unavailable (empty input), unsupported-audio-classes |

TR/EN surface text alternates by seed parity (seed 0/2 = EN, seed 1/3 = TR) — the same structural
expectations must hold in both languages.

## Split discipline

| Split | Seed | Use |
|---|---|---|
| TUNE | 0 | development; the only split used to fix defects |
| HELD-OUT | 1 | run once after freeze |
| STRESS | 2 | run once after freeze |
| OOD | 3 | run once after freeze |
| CALIBRATION-RESERVED | 9 | **untouched in P009B** — reserved for P009C calibration |

Expectations are STRUCTURAL (which evidence families must/must-not appear, contradiction/abstention
required), not surface-text matches — no template leakage across the boundary.

## Honesty limits

This corpus validates mesh ROUTING/HONESTY/STRUCTURE semantics on derived inputs. It does NOT measure
real-world perception accuracy (that requires device validation with owned media — §30, user-gated) and
it carries no exact P/R claims.
