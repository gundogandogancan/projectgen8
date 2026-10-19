# P003 — Dataset Candidate Register

**Doc status:** `CANONICAL` · **Phase:** 3 · **Date:** 2026-10-18 · PROMPT 003 §3. **No dataset downloaded** — rights not yet cleared. No private social-media data, no child private data.

| Dataset | Source | License | Commercial | Redistribute | Train | Content | Langs | Child concern | Vendorable | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| **golden-v0 / v1 (ours)** | synthetic (CoreGraphics + curated TR/EN strings) | OWNED | yes | yes | yes | text/image fixtures | TR+EN | none | yes | **APPROVED** (eval only) |
| TR+EN lexicons (ours) | hand-authored | OWNED | yes | yes | n/a | keyword lists | TR+EN | none | yes | **APPROVED** |
| (public news-topic corpora) | TBD | **must verify** | ? | ? | ? | news text | multi | review | ? | CANDIDATE (not fetched) |
| (open graphic-content safety set) | TBD | **must verify** | ? | ? | ? | images | — | **high** | likely no | CANDIDATE (not fetched; H1 blocked) |

**Rules enforced:** no download until rights clear; every sample carries `rights-provenance.schema.json`; `containsPrivateUserData` must be false. Current real heads use ONLY ours (synthetic + lexicons). External datasets remain `CANDIDATE` until legal review.
