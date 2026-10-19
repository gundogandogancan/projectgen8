# P007 — H1 Sensitive-Visual Safety: Candidate Analysis

**Outcome: B — NO ACCEPTABLE RIGHTS-CLEAR MODEL INTEGRATED. H1 remains UNAVAILABLE (evidence-backed blocker).**

H1 = "contains graphic violence / gore / blood / severe injury / (child-safety) explicit imagery." This is distinct
from the visual-reference Shield (see §Visual Shield vs Visual Safety).

## Why Outcome B (not a fake heuristic)
A production safety classifier for graphic content must come with clear commercial-use rights, a model card, dataset
disclosure, and Core ML feasibility. Without network/registry access to *verify* a specific model's license and
provenance at implementation time, integrating any such model would violate the repo rule: **"Do NOT download/integrate
anything with unclear rights"** (§11) and **"Do NOT fake H1 with color/red-pixel heuristics"** (§12). A red-pixel/skin-tone
heuristic is explicitly forbidden and would be dishonest safety theatre. Therefore H1 stays UNAVAILABLE.

## Candidate categories assessed (requirements per §11, none integrated)
For any candidate we would require ALL of: exact source/version · license · commercial-use rights · model card ·
dataset disclosure · size · Core ML feasibility · expected latency · memory · known bias · text-conditioned languages ·
content categories · safety limitations. Representative candidate *types* and their blocking issues:

| Candidate type | Typical blocking issue (why not integrated now) |
|----------------|-------------------------------------------------|
| Apple Vision "sensitive content analysis" (Sensitive Content Analysis framework) | Scoped to nudity/adult by the OS; **not** a general gore/violence classifier; entitlement + opt-in; cannot be repurposed as a graphic-violence detector. Assess properly on-device before any claim. |
| Open-source NSFW/violence CNNs (e.g. community nsfw/violence models) | Licenses vary (some non-commercial / unclear training-data rights); dataset provenance often undisclosed → rights **unclear** → excluded by §11. |
| Cloud moderation APIs | Would require silent cloud upload of private imagery → violates local-first + no-silent-cloud. Excluded. |
| Custom-trained Core ML model | Feasible but requires a legally-acquired, annotated dataset we do not yet have (see plan below). |

**No model was downloaded, converted, or vendored.** `SensitiveVisualHead` continues to return `UNAVAILABLE`
(`sensitive-visual-unavailable-v0`).

## Custom-training plan (the honest path to close H1)
- **Dataset acquisition (legal):** partner/licensed datasets or commissioned annotation; NO scraping; documented rights.
- **Annotation protocol:** multi-rater severity labels (none/mild/graphic), category (violence/gore/injury/medical),
  inter-rater agreement thresholds, trauma-aware reviewer policy.
- **Architecture:** small on-device vision backbone → Core ML; calibrated per-category thresholds; abstain-first.
- **Eval:** legally-safe eval set (§13) — synthetic/non-graphic proxies can test the *plumbing* but **cannot validate
  real gore detection**; real validation needs licensed graphic material under controlled handling.
- **Governance:** ACTIVE_LAB only on integration; checksum + registry + rollback; ResourceGovernor gating on
  `DeviceCapabilityProfile.allowsHeavyModels`.

## Current protection posture while H1 is UNAVAILABLE
The system never claims visual safety it cannot deliver: sensitive-visual signals report UNAVAILABLE and admission
treats them as non-determinable (never stale-safe). Text/OCR/transcript/sound-class paths remain active and real.
