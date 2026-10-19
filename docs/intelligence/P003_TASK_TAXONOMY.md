# P003 — Task Taxonomy

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §2. Locked before model selection.

| Head | Problem | Observable labels | Inference labels | Policy labels | Output | Confidence | Abstention | Langs | Modalities | FP cost | FN cost | Latency | On-device | Data needed | Legal/ethical |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **H1 Sensitive Visual** | graphic violence/gore/injury | gore/blood present | severity | child-block | categories | calibrated (future) | yes | n/a | image | high (false block) | high (miss) | MEDIUM | pref | labeled graphic set (rights-clear) | no graphic media vendored; **UNAVAILABLE now** |
| **H2 Mortality/Disease/Disaster** | topic presence | death/disease/disaster/accident/war/medical terms | — | positive-exposure | `[label]` | raw only (calib UNAVAILABLE) | yes | TR+EN | text/OCR/transcript | medium | medium | TINY | yes | TR+EN lexicon (have) + future labeled | topic ≠ truth; no medical claim |
| **H3 Semantic Shield** | user concept exclusion | exact/alias | semantic similarity | user hard/soft | `ShieldDecision` | embedding-based | yes | TR+EN | text/OCR | high (over-hide) | low | LIGHT | yes | user rules | low-conf never silent hide |
| **H4 Topic/Message** | topic+intent | topic nouns | core message | — | `TopicMessage` | heuristic | yes | TR+EN | text | low | low | LIGHT | yes | NLTagger | no hidden-intent claims |
| **H5 Attention/Manipulation** | lexical pressure | urgency/scarcity/fear/CTA | — | — | `ManipulationSignals` | count-based | n/a | TR+EN | text | low | low | TINY | yes | lexicon (have) | OBSERVED only; no mind-control claim |
| **H6 Child-Safety** | category→policy | from H1/H2 | — | age/guardian | admission | from heads | yes | TR+EN | mixed | high | high | — | yes | policy fixtures | no private-message surveillance |
| **H7 Personal Benefit** | structured vector | — | dimension estimates | personal-fit | `PersonalBenefitVector` | rules | yes | TR+EN | text | low | low | TINY | yes | rules + future | NOT one universal "healthy" score |

**Locked:** no single good/bad model; specialist heads → structured signals → deterministic policy fusion. H1 & explicit-sexual child category are UNAVAILABLE (no rights-clear validated model) — not improvised.
