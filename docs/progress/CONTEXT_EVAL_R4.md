# R4 §5 — Context Stance Evaluation (INDEPENDENT set, honest findings)

**Status:** `TESTED` (synthetic, DEVICE_UNVERIFIED) · **Source of truth:** `ContextEvalR4Tests` (GuardianMediaTests)
**Capability under test:** `ContextEvidenceAdapterV1.assessStance(...)` — the first REAL contextual separation (SPEAKER
STANCE toward the flagged harm), wired live via `GeneralContentCharacterV1.evaluateWithContext(...)` and the
SampleHandler surface mapping.
**Rights:** 100% synthetic strings authored in the test. Does **NOT** touch the RWC/M3 corpus rights gates.
**No tuning on R3 (§5 law):** these are a NEW independent set with DIFFERENT sentences. The R3 §8 corpus
(`ContextCorpusR3Tests`) is kept for REGRESSION ONLY — it is not re-used as the success proof, and no production
threshold was fit to it.

## What is REAL vs what stays UNKNOWN

The adapter infers STANCE from linguistic STRUCTURE — **not** a new word list (mandate §1):
- **Negation scope** (clause-scoped): "şiddet**e karşıyız**" / "no to violence" → CRITICIZES (even though the violence
  word is present).
- **Quotation / reported speech**: a quoted advocacy with a reporting frame ("…" + "dedi/said/according to") →
  REPORTS (the SPEAKER is reporting, not advocating — the §3 hard law).
- **Subject-action-object role** (POS via Apple `NLTagger .lexicalClass`, on-device): first-person imperative/optative
  advocacy ("gebertin/vurun/kill them/let's") → ADVOCATES; third-person event-report verbs ("yaşandı/öldürüldü/were
  killed/reported") → REPORTS.
- **Explicit anti-stance** ("kınıyoruz/karşıyız/condemn/against") and **victim support** ("yanındayız/stand with").
- **Sarcasm / irony** and **bare topic mentions** → **UNKNOWN by design** (structure cannot disambiguate; we never
  guess intent we cannot read). UNKNOWN **keeps the plain R3 marker** — it never softens a real risk.

The linguistic backbone is Apple **NaturalLanguage** (`NLTagger .lexicalClass` for POS verb confirmation,
`NLLanguageRecognizer`-class language gating via prefix) — the same on-device framework
`GuardianIntelligence.NLTextSignalProvider` already uses. **Sentiment is never claimed to be stance.**

## Per-language stance accuracy (INDEPENDENT examples; ground truth authored per fixture)

| Language | Examples | Stance accuracy | Abstention (UNKNOWN) | p50 latency | p95 latency* |
|----------|----------|-----------------|----------------------|-------------|--------------|
| Turkish  | 9        | **100% (9/9)**  | 33% (3/9)            | ~1.4 ms     | ~72 ms*      |
| English  | 9        | **100% (9/9)**  | 33% (3/9)            | ~0.9 ms     | ~65 ms*      |

\* **p95 latency is dominated by the FIRST `NLTagger` invocation (cold-start model load) in the process.** Steady-state
per-call cost is sub-millisecond (p50 ~1 ms). On the live extension the adapter runs ONCE per fresh item (inside
`mustEvaluate`), never per frame — so the cold start is amortised across the session. DEVICE_UNVERIFIED (macOS run).

The 33% abstention is CORRECT behaviour, not a failure: it is exactly the sarcasm + bare-topic + neutral-education
fixtures, which have no decisive stance structure. Abstaining on them (keeping the plain marker) is the honest law.

## Category coverage (both languages, per-example result)

| Category                         | TR | EN | Expected effect on caution |
|----------------------------------|----|----|----------------------------|
| condemn (anti-stance)            | ✓  | ✓  | SOFTEN_TO_NOTE |
| first-person advocacy            | ✓  | ✓  | **KEEP_OR_RAISE** (never softened) |
| news / event report              | ✓  | ✓  | SOFTEN_TO_NOTE |
| negation over harm clause        | ✓  | ✓  | SOFTEN_TO_NOTE |
| quotation (speaker reports)      | ✓  | ✓  | SOFTEN_TO_NOTE (quoted advocacy ≠ speaker advocacy) |
| neutral education                | ✓ (UNKNOWN) | ✓ (UNKNOWN) | KEEP_PLAIN (honest abstention) |
| victim support                   | ✓  | ✓  | SOFTEN_TO_NOTE |
| sarcasm / irony                  | ✓ (UNKNOWN) | ✓ (UNKNOWN) | KEEP_PLAIN (by design) |
| bare topic (missing context)     | ✓ (UNKNOWN) | ✓ (UNKNOWN) | KEEP_PLAIN |

## The 5 R3-inseparable PAIRS, re-tested on INDEPENDENT examples

The R3 §8 finding was that 5 context families were inseparable by the context-blind lexicon. On NEW independent
examples (not the R3 sentences), the STANCE capability now separates:

| R3 Pair | On independent examples | How |
|---------|--------------------------|-----|
| 1. death-news / violence-glorify | **SEPARATED ✓** | glorify → ADVOCATES (KEEP_OR_RAISE); news → REPORTS (SOFTEN). |
| 5. anti-violence / pro-violence  | **SEPARATED ✓** | pro → ADVOCATES (KEEP_OR_RAISE); anti → CRITICIZES (SOFTEN). |
| 2. disease-education / disease-fear | **partial / HONEST gap** | education abstains (UNKNOWN, keep-plain); fear-speech has no *stance* structure toward a harm → also kept-plain. Stance does NOT model emotional register. |
| 3. sports-debate / targeted-insult | **NOT addressed** | targeted-insult is an H1 open capability (no detector); out of scope for the stance slice. |
| 4. earthquake-info / panic-creation | **one-sided only** | info → REPORTS (SOFTEN, a real false-alarm reduction); panic/sensation is NOT detected as a harmful stance (it has no advocacy structure) → kept-plain. The *info* side is correctly calmed; panic is NOT flagged as harmful. |

### HONEST non-separations (the finding, not hidden)
- **Pair 2 (education vs fear) and Pair 4 (info vs panic)** are only partially / one-sidedly separated. The STANCE
  capability models **speaker stance toward a harm** (advocate / report / criticise / support). It does **NOT** model
  **emotional register / fear-speech / sensationalism** — "panic-creation" and "fear-exploitation" are not a stance
  toward a harm, they are a manipulation of the reader's emotion. Closing those needs a *different* capability
  (an emotional-register / manipulation model) with its own calibration gate. This is the honest remaining gap.
- **Pair 3 (targeted insult)** needs a target-directed-abuse detector (H1 open). Untouched here.

## Safety-critical direction (missed-risk)

The dangerous failure is **softening a real advocacy**. The eval asserts (and all pass):
- Every ADVOCATES example → effect `KEEP_OR_RAISE`, **never** `SOFTEN_TO_NOTE` (`testNeverSoftensAdvocacy_noMissedRisk`).
- Sarcasm / bare topic → `UNKNOWN` + `KEEP_PLAIN`, **never** softened (`testSarcasmAndBareTopic_abstain_notSoften`).
- Quoted advocacy with a reporting frame → `REPORTS`, **never** `ADVOCATES` promoted (§3 law).
- The real lexicon **marker is NEVER dropped** — a softened verdict still carries `markers` (the risk signal persists;
  only the surface framing is calmed to an examined-with-context note, explicitly NOT a "safe" claim).

## No fabricated calibration (§9)

No numeric 0–100 score anywhere. The output is categorical (stance + effect) + evidence cues. The P009E calibration
gate stays closed. "Accuracy 100% on 9 synthetic examples" is a SYNTHETIC, DEVICE_UNVERIFIED result on a hand-authored
set — it is NOT a production-calibrated generalisation claim. Real generalisation requires a rights-cleared, held-out,
independently-labelled corpus through the RWC/M3 gates (future work).
