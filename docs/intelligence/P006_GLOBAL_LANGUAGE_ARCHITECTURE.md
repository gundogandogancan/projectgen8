# P006 — Global Language Architecture

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §12–§15. **Architecture is global; certification is per-language. NEVER claim "all languages supported".**

## LanguageCapabilityRegistry
Per locale tracks: script · languageID · OCR · speech · embedding · topic classifier · sensitive-content · slang/idiom pack · calibration status · eval dataset size · **certification state** ∈ {UNASSESSED, BASIC_SIGNAL_ONLY, LAB_SUPPORTED, CALIBRATED, CERTIFIED, DEGRADED, UNSUPPORTED}. An unknown/uncertified locale returns `UNASSESSED` and **does NOT inherit a certified threshold** (tested).

## Current state
- **EN**: LAB_SUPPORTED (languageID/OCR/embedding/topic/sensitive = yes; calibration UNAVAILABLE; eval ~20). Not CERTIFIED (no production claim).
- **TR**: LAB_SUPPORTED (languageID/OCR/topic/sensitive = yes; embedding availability runtime-dependent; speech UNAVAILABLE in lab). Not CERTIFIED.
- All other locales: UNASSESSED → must be assessed before any quality claim.

## Language quality ≠ translation (§13)
Each language eventually handles script/tokenization/morphology/slang/profanity/euphemism/sarcasm/idioms/code-switching/transliteration/regional+religious+age vocabulary/platform slang. **English thresholds are not mapped to other languages**; machine translation is not ground truth.

## Expansion priority (§15, non-binding)
`priority = demand × reach × systemCapability × dataAvailability ÷ cost` (`LanguageCapabilityRegistry.expansionPriority`). Certification advances incrementally; architecture already supports arbitrary locales.

## Metrics (§38)
Per certified language: sample count · per-task P/R/F1 · abstention · false allow/hide · semantic-shield accuracy · ASR/OCR quality · latency. **No one-number "global accuracy".**
