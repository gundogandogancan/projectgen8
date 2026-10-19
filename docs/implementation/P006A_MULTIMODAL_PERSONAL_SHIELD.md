# P006A — Multimodal Personal Shield

> "I do not want to see / hear this." Gen8 detects related content **before exposure where capable** and produces a
> truthful **warn / hide / ask / skip** — as a *personal preference*, never as a claim of global truth.

## 1. Rule model — `ShieldRuleV2` (`GuardianCore/ShieldV2.swift`)
Durable, versioned (`shield-rule-v2`), `Codable` personal state. Fields: `ruleID`, `ownerScope`, `authority`
(`user` / `guardian` / `systemSafetyFloor`), `inputType`, `rawUserLabel`, `canonicalConceptID`, `locale`,
`aliases`, `referenceFeatureIDs` (derived fingerprints — **no raw media**), `allowedMatchers`, `action`,
`sourceScope`, `enabled`, `privacyClass`, `version`.

### Input types (`ShieldInputType`)
`TEXT_EXACT`, `TEXT_PHRASE`, `SEMANTIC_CONCEPT`, `ENTITY`, `SOURCE`, `IMAGE_REFERENCE`, `LOGO_REFERENCE`,
`AUDIO_REFERENCE`, `SPOKEN_REFERENCE`, `MUSIC_TRACK`, `MUSIC_ARTIST`, `SOUND_CLASS`, `CUSTOM_MULTIMODAL`.

## 2. Matchers = signal only (never action)
Every matcher returns a `ShieldMatchResult` (`state`, `rawConfidence`, `calibratedConfidence`, `reason`,
`modality`, `engineVersion`). Matchers **never** hide/skip anything — the deterministic controller does.

| Matcher | Modality | Backing | Status |
|---------|----------|---------|--------|
| `ExactTextMatcher` | text / OCR / transcript | diacritic+case-insensitive substring | REAL, tested |
| `AliasEntityMatcher` | text | alias/entity list | REAL, tested |
| `SourceMatcher` | source | contentID surface scope | REAL, tested |
| `SoundClassMatcher` | audio | SoundAnalysis class labels in `soundEvents` | REAL, tested |
| `SemanticTextMatcher` | text | injected distance (NLEmbedding via `ShieldSemanticDistance`) | REAL where embedding available, else **UNAVAILABLE** |
| `ShieldVisualReferenceMatcher` | image / logo | Vision feature-print distance (`GuardianIntelligence`) | REAL, tested |
| speaker-voiceprint / face-biometric | — | — | **NOT IMPLEMENTED by design** (§5/§6 privacy) |
| music identity (Shazam) | music | ShazamKit | honest **UNAVAILABLE** (no auth/catalog in lab) |

## 3. Match states (ordered)
`NO_MATCH < UNAVAILABLE < UNKNOWN < CONFLICTING < LOW < MEDIUM < HIGH < EXACT`.
`UNAVAILABLE`/`UNKNOWN` **never** collapse to NO_MATCH (never fail open as safe).

## 4. Deterministic action controller (`ShieldActionControllerV2`)
| Match state | Controlled surface, strict | Result |
|---|---|---|
| EXACT / HIGH | — | the rule's configured action (may hide/skip) |
| MEDIUM / CONFLICTING | — | downgrade destructive actions → **ASK**, else **WARN** |
| LOW | — | **ALLOW_WITH_NOTE** (never a silent hide) |
| UNKNOWN / UNAVAILABLE | strict + controlled | **HOLD** · otherwise **WARN** (never claims safe) |
| NO_MATCH | — | ALLOW |

**Invariant:** a low-confidence or unknown signal can never silently hide/skip content.

## 5. Evaluator (`ShieldEvaluatorV2`)
`shortlist (index) → run matchers on candidates → best state → exceptions → controller → ShieldOutcome`.
Composes the bounded index (§13), the exception engine (§14), and the controller. `ShieldOutcome` reports
`ruleID`, `bestState`, `action`, `reason`, `exceptionApplied`, `evaluatedRules`, `matchersRun`.

## 6. Correction loop (`ShieldCorrectionApplier`)
`notWhatIMeant`, `alwaysBlock`, `allowSource/item/session`, `makeNarrower`, `makeBroader`, `pause`, `delete`.
All mutate **local personal state only** — never a global model (see P006A_SHIELD_PRIVACY_MODEL §"no global training").

## 7. Cross-language (§10)
A strong same-concept semantic match is **softened to MEDIUM (ASK-tier)** when the content language differs from the
rule locale, tagged `SHIELD_CROSS_LANGUAGE_MATCH`. We do **not** claim universal cross-language coverage; absent an
embedding for a language, the matcher reports UNAVAILABLE (see `LanguageCapabilityRegistry`).

## 8. Pre-exposure priority
The Shield runs inside the existing pre-exposure path; a HIGH/EXACT personal hard shield sits above PERSONAL
PROTECTION in the ADR-0007 precedence (`USER HARD SEMANTIC SHIELD`), below CHILD SAFETY FLOOR and SECURITY/LEGAL.

## Tests
`GuardianCoreTests/ShieldV2Tests.swift` (12) + `GuardianIntelligenceTests/ShieldBridgeTests.swift` (5). 180/180 total.
