# ADVERSARIAL_PRESSURE_R7 — Where the Targeted-Pressure Heuristic Breaks (honest map)

**Status tier: SYNTHETIC-TESTED (host-run, DEVICE_UNVERIFIED). This is NOT an accuracy claim — it is a FAILURE MAP.**

- Capability under test: `TargetedPressureHeuristicV1` (`targeted-pressure-heuristic-v1`, GuardianMedia) — the R6
  §4 TARGET / ACT / MECHANISM structural dimension. A **declared heuristic / structural evidence** producer, NOT an
  "abuse detector", NOT a sentiment model, NOT a measurement of anyone's psychological state. Every evidence record
  it feeds the world model carries `calibrationStatus: .heuristicSupportOnly`.
- Harness: `Tests/GuardianMediaTests/AdversarialPressureEvalR7Tests.swift` — a **FRESH** R7-authored adversarial set
  (24 sentences, TR + EN + mixed). **No R3/R4/R5/R6 corpus sentences reused.**

## Honesty caveats (read first — binding)

1. **The labels are engineering-authored, not independent ground truth.** The same session that wrote the heuristic
   wrote these sentences and their expected classes. This is adversarial self-probing, not a benchmark. No production
   accuracy is claimed; RWC rights/annotation/calibration gates remain OPEN (P009E closed; no numeric score).
2. The purpose is explicitly to **expose FALSE NEGATIVES / FALSE POSITIVES** and the abstention boundary, so the RWC
   corpus plan knows where to buy real annotation. Failures here are the FINDING, not a regression.
3. Only HARD SAFETY LAWS are asserted (they must hold even when the heuristic misses nuance):
   institution-criticism is never a directed personal attack; a quoted/attributed act is never own-voice; condemnation
   of violence is never incitement. Everything else is a MEASUREMENT.
4. Latency/host: macOS arm64e. Device numbers = DEVICE_UNVERIFIED.

## Results (run 2026-10-26, `swift test --filter AdversarialPressureEvalR7Tests`, measured verbatim)

| TOTAL | TP | FP | FN | TN | abstained(support≠supported) | Precision | Recall |
|---|---|---|---|---|---|---|---|
| 24 | 2 | 0 | 7 | 15 | 0 | 1.00 | 0.22 |

**Headline honest finding: the heuristic is HIGH-PRECISION, LOW-RECALL on fresh adversarial phrasing.** It fired on
0 clean cases (no false positives, no false incitement, no quoted-attack over-claim) but MISSED 7 of 9 labelled
positives. The R6 "9 TP / 0 FP / 0 FN" number did NOT generalise — as warned, it measured designed structures firing
on clean examples, not real-world recall.

### Where it BREAKS (the map — by family)

| Family | Example (truncated) | Expected | Fired | Finding |
|---|---|---|---|---|
| directed-demeaning (TR/EN) | "Sen tam bir aptalsın…" / "You are worthless…" | P | **P** | ✅ caught — explicit 2nd-person + insult lexeme |
| fake-urgency (TR/EN) | "Son 2 dakika! Hemen tıkla yoksa…" | P | — | ❌ FN — deceptive-urgency mechanism not triggered on this phrasing |
| guilt-coercion (TR/EN) | "Beni gerçekten sevseydin…" / "If you really cared…" | P | — | ❌ FN — conditional-guilt structure not matched |
| multi-speaker (TR) | "A: … B: … A: sen zaten her şeyi batırırsın" | P | — | ❌ FN — the insult lexeme in a dialogue line was not isolated |
| mixed-directed (TR/EN) | "You are so aptal, hiçbir işe yaramıyorsun…" | P | — | ❌ FN — mixed-language: target mis-resolved to THIRD_PARTY |
| incitement (TR) | "Herkes gidip onlara haddini bildirsin… saldırın!" | P | — | ❌ FN — provocation mechanism not matched on this phrasing |
| institution-criticism (TR/EN) | "Zarnovil Kurumu… hata yaptı" | — | — | ✅ correctly NOT a directed personal attack (safety law) |
| quote-within-quote (TR/EN) | "…dedi ki: '…beceriksizsin'" | — | — | ✅ quoted → own-voice correctly suppressed (quoted=Y) |
| casual-slang (TR/EN) | "lol bro you're such a disaster haha" | — | — | ✅ no insult lexeme → clean (friendly-ribbing not alarmed) |
| legit-urgency (TR/EN) | "Resmi uyarı: sel riski… boşaltın" | — | — | ✅ real evacuation not mislabelled as fake urgency |
| supportive (TR/EN) | "Üzülme, herkes hata yapar; yanındayız" | — | — | ✅ supportive not alarmed |
| satire (TR/EN) | "Harika bir plan! …ne güzel" | — | — | ✅ irony abstained BY DESIGN (not structurally detectable) |
| ocr-fragment (TR) | "se n ap tal s ın…" | — | — | ✅ fragmented tokens → no false fire (also no detection) |
| condemnation (TR/EN) | "Bu şiddeti şiddetle kınıyoruz…" | — | — | ✅ condemnation ≠ incitement (safety law) |

### Root-cause reading (engineering, honest)

- The heuristic reliably catches **explicit 2nd-person + insult-lexeme** directed demeaning (its strongest structure).
- Its **covert-mechanism detectors** (deceptive-urgency, guilt-shame, provocation) are tuned to specific cue
  combinations that the FRESH phrasings did not hit — so recall on mechanisms collapsed. This is the biggest gap.
- **Mixed-language** target resolution is brittle: an EN "You are" + a TR insult got a THIRD_PARTY target (wrong).
- **Multi-speaker** dialogue hides the directed line; there is no speaker segmentation on this path.
- Abstention count 0 here reflects that the cases carried enough text to run (support=supported); the misses are
  genuine FNs, not abstentions.

### What this does NOT mean

- It does NOT mean the capability is unsafe: FP=0 across the set, and all three hard safety laws held. The honest
  risk is UNDER-detection (silent miss), which the SİLENT-INTELLIGENCE posture already treats as "işaret yok ≠ güvenli".
- It does NOT justify loosening thresholds to chase recall on authored sentences — that would overfit to this set.

## Recommendation → RWC plan

1. The mechanism detectors (deceptive-urgency / guilt-shame / provocation) are the top ANNOTATION priority — they are
   where real recall is lost. They need a **rights-clear, independently-annotated** adversarial corpus, NOT more
   engineering-authored sentences.
2. Mixed-language target resolution and multi-speaker segmentation are named follow-ups (NOT in this round).
3. Until independent held-out evidence exists, the capability stays a **categorical declared heuristic** feeding the
   world model as `heuristicSupportOnly` — never a calibrated score, never an "abuse" verdict (mandate §8 honored).
