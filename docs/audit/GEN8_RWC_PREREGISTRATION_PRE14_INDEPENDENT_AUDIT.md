# GEN8 — RWC PREREGISTRATION (PRE-14) INDEPENDENT CLEAN-SESSION AUDIT

- **Audit ID:** RWC-PRE-14 (AUDIT14) — independent, clean-session, non-builder
- **Date:** 2026-10-20
- **Candidate:** `1c4160b11f807999437f36ae36ad0dc5d63853f3` (branch `phase/rwc-preregistration-preparation`)
- **Candidate tag:** `gen8-rwc-preregistration-audit-candidate` (tag object `228825b71e8e33bc5abad5bdf1e2a564b8fb1487` → `1c4160b…`) — verified
- **Entry / governing lock:** `2c345b64c720f965b68ec5ee699e1b71fecf0003` (`gen8-ulu-evren-control-plane-r1-locked-governing`) — verified
- **Verdict:** **FIX REQUIRED — RWC PREREGISTRATION** (see §10)
- **Audit artifacts (the ONLY writes):**
  - `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT14_RWCPreregistrationPre14Probes.swift` (36 fresh probes, all green against the candidate AS-IS; PINNED findings asserted as current truth)
  - this report
- **Suite evidence:** full suite run twice post-probes: **866/866 ×2, 0 failures** (= 830 builder-final baseline + 36 AUDIT14 probes). Builder claims (817 entry / 830 final ×2 / 13 fresh tests) independently confirmed.

Doctrine applied: trust nothing the builder claims; recompute/attack everything; UNKNOWN > fabricated certainty; a green suite alone is never PASS. All findings are PINNED by probes that are green against the candidate as-is.

---

## 1. Custody (§3)

| Check | Result |
|---|---|
| `git status` | clean at audit start; HEAD unchanged after audit (`1c4160b`) |
| Branch | `phase/rwc-preregistration-preparation`, HEAD == origin |
| Entry lock | `2c345b6` == tag `gen8-ulu-evren-control-plane-r1-locked-governing^{}` — exact |
| Candidate tag | annotated; object `228825b…` dereferences to `1c4160b…` — exact |
| Commits since entry | exactly 5 (`2633c6e` packets → `8f3bb13` core → `fca3e10` artifacts → `f284bd7` tooling/manifests → `1c4160b` report) — matches claim; no force/squash/rewrite indicators |
| Touched files | 41 files; all inside prereg scope. Pre-existing production files touched: `CalibrationMetrics.swift` (+5, deprecation marker only), `CalibrationPilot.swift` (+20/−1: retirement comment, `EngineeringOnlyExecutionContextV1`, defaulted `context` param + deprecation — legacy behavior pinned unchanged by AUDIT11 pins and re-verified by probe). No control-plane audit mutation; no product work outside scope. |

Custody: **VALID**.

## 2. Freeze manifest + boundary (§4, §29, §40)

- **15/15 artifact SHA-256 hashes recomputed by the auditor — all match** (probe `testA14_Custody_FreezeManifest15…`). 13/13 packet hashes in the master manifest recomputed — all match.
- **Byte-flip attack** on a temp copy of `RWC_FROZEN_GATES.yaml`: one flipped bit diverges from the manifest hash; the suite's own drift check re-verifies hashes every run → canonical-file drift is detected.
- **A14-F13 (MEDIUM, PINNED): freeze boundary is docs-only.** None of the code files that *implement* frozen methodology (`RWCStatisticsV1.swift`, `RWCAssetIdentityV1.swift`, `RWCAssetRightsLedgerV1.swift`, `CalibrationRunPreparationV1.swift`, `RealWorldCalibrationExecutorV1.swift`) is hashed anywhere. The invalidation law binds **post-result** changes only; no written law declares COMMIT SHA vs FILE MANIFEST as the binding methodology boundary, and no law requires re-freeze/re-audit for silent methodology-code edits in the **post-PRE-14 / pre-corpus window**. A kappa-formula edit in `RWCStatisticsV1.swift` after PRE-14 PASS would invalidate nothing under the frozen text.

## 3. Zero-data forensics (§5)

Swept the full diff `2c345b6..1c4160b` and the repo: **no binary/media files, no content URLs, no dataset rows, no corpus registrations, no human labels, no real predictions, no fit weights, no learned thresholds, no held-out IDs, no content hashes of actual assets, no download/cache artifacts, no fit results.** All `rwc-asset-*` literals are synthetic test fixtures (`a1b2c3d4` class); the single media-looking string (`"funny cat video.mp4"`) is a negative fixture in a builder test. Schema `records: []`; master counters corpus/annotator/fit/heldout-open = 0, `data_visibility=false` — suite-asserted and auditor-re-asserted. Gates were authored at `fca3e10` and hashed at `f284bd7`, both before any data existed anywhere in history. **Zero-data: VERIFIED. Gates froze before data visibility: VERIFIED.**

## 4. PRE-01 rights red team (§6)

**Holds:** exactly 2 eligible source classes; 4 refused classes each a typed refusal; unknown/blank/case-variant source class **fails closed at decode** (Swift raw-value Codable throws — probe-verified); unknown/case-variant `use` strings refused; REVOKED/EXPIRED states refused; bad/short/non-hex hash refused; empty provenance refused; whitespace-only evidence/rightsHolder refused; invalid asset ID propagates typed identity error; `revoked()` is monotone with forced-false flags and audit-trail append; no un-revoke API.

**Findings:**
- **A14-F1 (MEDIUM, PINNED): `expiryDate` is NEVER evaluated.** An ACTIVE record with expiry years in the past passes `requireEligible` for training AND evaluation. Malformed expiry, expiry==today, and expiry<acquisition all pass. There is no date logic and no canonical time source in the eligibility path; "caller sets EXPIRED" is convention, not structure — a fail-closed violation against the record's own contract.
- **A14-F2 (MEDIUM, PINNED): contradictory dual truth in use fields.** `allowedUse`/`prohibitedUse` are never consulted; only the booleans decide. `trainingAllowed=true` + `prohibitedUse=["training"]` passes for training; `allowedUse` without evaluation + `evaluationAllowed=true` passes; the same use in both lists is representable. No field is declared authoritative (§49 class: contradictory use-fields authorizing forbidden use).
- **A14-F4 (MEDIUM, PINNED): resurrection.** Monotonicity is a property of one value, not a ledger — no global registry/history exists. A fresh ACTIVE record with the SAME assetID and the SAME old evidence passes after revocation. "New registration + new evidence" is enforced nowhere.
- **A14-F3 (LOW, PINNED): field hygiene prose-only.** Newline-only `licenseEvidence` passes (`.whitespaces` excludes `\n`); raw URLs and filesystem paths pass as "opaque pointers"; `owner` may be EMPTY; `contentHash` accepts UPPER/MIXED-case hex (`isHexDigit`) so byte-distinct aliases of one digest are representable (a near-dup/dedup hazard); `acquisitionDate` unvalidated; duplicate provenance accepted.

## 5. PRE-02 identity (§7)

Grammar independently verified: `rwc-asset-[a-z0-9]{8,32}`, profile `[a-z0-9-]{3,40}` no edge/double dash, composite exactly one `#`. Full auditor adversarial matrix green: CRLF/CR/LF/tab/space (typed `controlOrWhitespace`), zero-width U+200B and BOM U+FEFF (`nonASCII`), emoji, DEL 0x7F, colon/slash/underscore/URL/path syntax, NFC vs NFD (both refused, never unified), Cyrillic lookalikes, uppercase (token `forbiddenCharacter`, prefix `badPrefix`), length bounds 7/33 and 2/41, multi-`#`, empty components. No silent normalization anywhere; `parse∘compose == identity`. **PRE-02 itself: SOUND.**

## 6. PRE-04 executor + PRE-02↔PRE-04 integration (§8–§10)

- Executor truths verified: `preregistrationAuditPassed == false`; valid token → `preregistrationNotPassed(RWC-PRE-14)`; empty token → `emptyDataset`; hypothetical flag-flip → the `fitPhaseNotAuthorized(RWC-FIT)` refusal is the unconditional source tail (position-verified); no metric/fit body exists on the surface; zero pilot-type references.
- **A14-F5 (MEDIUM, PINNED): PRE-02 is NOT wired into the canonical PRE-04 door.** `prepareDataset` enforces only non-emptiness/uniqueness/set-equality. Every garbage-but-consistent string — `"not-a-valid-rwc-id#profile"`, `"funny cat video#abc"`, `"../../secret#abc"`, `"rwc-asset-ABCDEFGH#abc"`, Unicode composites, `"a#b#c###"`, strings with no `#` at all — **mints a `PreparedCalibrationDatasetV1` token** (probe-proven). The frozen PRE-04 protocol claims "bad asset ID … → no PreparedCalibrationDatasetV1 ever exists" — false for consistent garbage. Exploitability is bounded (executor still refuses; rights ledger validates grammar at registration), but the canonical door is exactly where grammar should bind, and the frozen doc overclaims.
- **A14-F6 (LOW, PINNED): token binds IDs only.** Mirror census: stored state is exactly `compositeIDs + category + guardRevision` — no features/labels/content-hash binding. CLOSED for the current no-fit surface; an ID↔record/payload binding invariant is **REQUIRED at RWC-FIT**. (The builder stated the ID-only payload honestly.)
- **A14-F6b (LOW, PINNED): fit-surface census / A11-F2-APIBYPASS residue.** `DimensionCalibratorV1.fit`, `LogisticCalibrator.fit`, `SuitabilityFusionModelV1.fit` remain public and directly callable with raw arrays, wholly outside the token door (probe-proven on synthetic arrays). Nothing in the type system distinguishes real-world numbers from engineering numbers at these entrypoints — the separation is governance (rights law + zero data + process), not structure. "Closes A11-F2-APIBYPASS structurally" is true only for the executor door itself.

## 7. PRE-03 legacy (§11)

Whole-module findings: legacy pinned behavior unchanged (AUDIT11 mae-truncation pin re-verified); `EngineeringOnlyExecutionContextV1` has one case, no real-world case expressible; **but** the new `context` parameter is **defaulted** so every old call site still compiles — probe calls `CalibrationPilotRunner.run` directly with no context argument. Enforcement classification: **deprecation + defaulted param = warning-only**; the actual laws are (a) no real-world case in the type, (b) bridgelessness (no `PreparedCalibrationDatasetV1`↔`PilotExample` API — source-verified), (c) level cap `LAB_CALIBRATED_LIMITED` (probe-verified). Pilot results cannot touch the production registry/gate (display false, gate closed — §9 below). Historical FAILED/0.50/CONTRADICTED evidence intact. **Acceptable with honest classification; no new finding beyond the warning-only note (folded into A14-F6b residue class).**

## 8. PRE-05..07 human ground truth (§12–§16)

- **Structural parity:** 17×17 section IDs identical/ordered, 7 fields per dimension in both languages (builder test + auditor spot anchors).
- **Independent bilingual semantic audit (all 17 dimensions × 7 fields, meaning-level):** no divergence that would systematically shift labels. Direction identical (0 protect … 4 aligned); strong-protection 4-element definition identical; sentinel laws identical (protective-only; abstention on sentinel NOT false-safe; never revealed); abstention first-class, no quotas; age law "never infer from imagery" both; D-11 channel-conflict "never average" both; D-13 fail-closed both. Minor items — **A14-F14 (INFO, PINNED):** EN D-02 contains Cyrillic lookalike bytes ("авудible" typo; probe asserts their presence); TR "toplulukta" (D-11) and "genelde" (D-15) are slightly ambiguous renderings of "aggregate/overall" — not label-shifting.
- **Label direction vs code:** `finalLabel<=1` = unsuitable class, score = rubric×25 (0–4 ↔ 0–100), no inversion. **A14-F15 (LOW, PINNED):** unadjudicated |A−B|=1 odd-sum pairs round half-away-from-zero → systematically toward the LESS protective label (1/2→2 is an unsuitable→caution class flip), and adjudication is only REQUIRED at |A−B|≥2.
- **Isolation (§14):** blindness matrix covers model outputs, split identity, sentinel indistinguishability, A↔B labels/rationales, aggregates-during-batch, provenance; seeded assignment with per-slice A/B balance; append-only logs; opaque annotator IDs. **Limitation (honest classification, not a fix-class finding): no annotation UI/schema exists yet — "sentinels indistinguishable", filename/metadata/ordering leakage channels and assignment-confounder controls are implementable-as-written but currently prose; they must be re-audited when the annotation tooling exists.**
- **Adjudication matrix (§16):** A=0/B=1 → permitted (not required — both in the protective class); A=0/B=2 → REQUIRED; abstain-vs-label → REQUIRED; any safety split → REQUIRED + logged as safety-disagreement event regardless of resolution; both-abstain → not a disagreement, excluded from IRR and reported as abstention; strong-protection split → REQUIRED + escalation. A/B originals immutable (third layer; type precedent holds A/B/adjudicated separately); adjudicator is never A or B; UNRESOLVED_AMBIGUOUS preserved and excludes the item from gating dimensions by typed status. **Coherent.**

## 9. PRE-08..13 statistics, gates, splits, device (§17–§39)

**IRR math (§17–18):** auditor implemented his OWN quadratic-weighted kappa and Krippendorff nominal alpha from first principles and differential-tested against `RWCStatisticsV1` across seeded random matrices (k=2/3/5 × n=10/37/120) plus perfect/systematic/constant-vs-variable/imbalanced fixtures: **all agree to 1e-9.** Alpha is true alpha — the (n..−1) coincidence denominator is witnessed by the separation case (systematic disagreement: kappa=−1 vs alpha=−0.75) and an independent hand fixture (0.64). Degenerate laws correct: nil (INSUFFICIENT_DATA), never 0/1-by-convention; out-of-scale and shape mismatch refused.

**Findings:**
- **A14-F10 (MEDIUM, PINNED): IRR CI pass rule UNDEFINED.** The ECE gate explicitly says "gate evaluated on point estimate, CI reported"; the IRR gates say nothing. κ=.61 with CI [.30,.75] is undecidable under the frozen text. Degenerate bootstrap replicates (nil kappa inside a replicate) and a valid-fraction minimum are also unspecified. Must be unambiguous pre-data.
- **A14-F7 (MEDIUM, PINNED): the frozen ECE ≤ .05 point-estimate gate at n=400 is noise-dominated.** ECE is not a single binomial proportion: with 10 bins (~40/bin, per-bin SE ≈ .08 at p=.5), binned |gap| aggregates pure sampling noise. Deterministic seeded Monte Carlo (in-probe, and cross-checked independently): a PERFECTLY calibrated model has **E[ECE] ≈ .050** and passes the gate only **≈52%** of the time (uniform confidences; ≈64% for mid-range confidences). The PRE-09 planning computation (single-proportion n≥385 at h=.05) used the wrong statistic for a 10-bin ECE. The rule is explicit (point estimate — that part is preregistered and unambiguous) but statistically unsupported at n=400: the gate cannot distinguish a calibrated model from luck. PRE-14 exists to reject bad prereg BEFORE corpus — n=400/point-estimate must be fixed (larger n, debiased ECE estimator, adaptive binning, or a CI-based rule), not preserved because frozen.
- **A14-F8 (MEDIUM, PINNED): "POWERED" is internally contradictory.** PRE-10: POWERED = minimums met (default 60/15/15). PRE-11: hard slice-ECE ≤ .07 on POWERED slices. PRE-09 itself: h=.07 needs ~196. Monte Carlo at n=60: perfect model has E[ECE] ≈ .128 and passes ≤ .07 ≈2% of the time — the gate is essentially unpassable on a minimum-POWERED slice. "POWERED" at 60/15/15 is mislabeled; it is REPORTABLE.
- **A14-F9 (MEDIUM, PINNED): abstention gaming unbounded.** No coverage/decision-rate gate or abstention-rate bound exists anywhere in the frozen gates or slice registry (probe-asserted absence). A model that abstains on all hard items inherits excellent ECE/MAE with no accountability beyond "honestly reported".
- **False-safe (§24): exact math verified.** UB(n)=1−0.05^(1/n); auditor recomputation: minimal n for UB≤2% is **149** (UB(148)=2.0038% fails, UB(149)=1.9905% passes); the frozen n≥150 is conservative-safe (INFO; the builder's "n≥150 ⇒ UB≤2%" is true). Zero-observed never claims zero rate ✓. **A14-F17 (LOW, PINNED):** the bound is **conditional on sentinel-class content** (targeted sampling, prevalence ≥.80 by design), not a natural-prevalence population false-safe rate; no frozen artifact carries a report-semantics law making this distinction — one is required before any external claim.
- **MAE ≤ .80 (§25):** rationale explicitly labeled pre-data hypothesis ✓; per-slice MAE/CI in slice defaults ✓; falseSafe precedence holds structurally (separate zero-observed gate cannot be averaged away) ✓.
- **AUROC/Brier (§26):** REPORT-only with CI everywhere; AUROC hard gate REJECTED with FM-007 reason, preserved in `rejected_or_modified_candidates` ✓.
- **Slices (§27–28):** 21 definitions, unique ids, non-empty rules; sentinel min 150 consistent with rule-of-three; mixed-language pre-declared scarce; underpowered → UNKNOWN never aggregate-hidden. Rules are implementable but several ("dominant or safety-relevant channel language") need operationalization at annotation time (INFO). **A14-F18 (LOW, PINNED):** no multiple-comparison policy for the 21 overlapping slice gates (family-wise vs descriptive vs safety undeclared — the policy, not Bonferroni, is what's required).
- **OOD circularity (§30):** none — OOD slice membership = handbook D-16 HUMAN label, independent of model prediction; any scored OOD item is a finding ✓.
- **Split/held-out (§32–34):** near-duplicate procedure covers re-encode/trivial-edit/re-upload via content-hash + perceptual screen + human spot check, and creator/series/template clusters; deterministic enough as a pre-data procedure but perceptual-screen thresholds are not yet pinned (INFO, to be fixed at RWC-SPLIT time). **A14-F11 (LOW, PINNED):** what COUNTS as "opening" HELD_OUT_FINAL (listing IDs — which are in the sealed in-repo manifest by design — hash recomputation, metadata inspection, annotation, debug run, partial inference?) is undefined; no authorized-opener/access-control law; code-unenforceable → honest procedural limitation that must be defined before sealing. **A14-F12 (LOW, PINNED):** "changes materially" is discretionary — no material/non-material change matrix (threshold tweak vs metric bug fix vs locale fix vs handbook clarification…); and for revocation discovered AFTER opening, the status of already-computed aggregates is not predefined (the set loses FINAL status, but the computed numbers' status is silent) (§39).
- **Device (§35–38):** protocol complete as protocol (full-path metrics with p50/p95/p99, run discipline, cold/warm/≥3 repeats/10-min thermal, UNKNOWN-never-imputed, debug/release separation both directions preserved — "release logging stays structurally OFF" + "evidence-build cell can never stand in for the release cell"). **A14-F16 (LOW, PINNED):** the floor device is NOT concretely named anywhere (`DEVICE_RESOURCE_BUDGETS.yaml` says "lowest supported device" without a model; `DEVICE_CERTIFICATION_MATRIX.md` rows are NOT_TESTED) → cherry-pickable later; and every budget is `UNSET_PENDING_BASELINE`, so "any exceedance = FAIL" cannot bind yet — an explicit budget-freeze-before-RWC-DEVICE law is required to prevent post-measurement threshold setting. Carried as BLK-DEVICE-RWC-OPEN/BLK-H4 (pre-declared protocol-only; not corpus-blocking).

## 10. Packets, FAIL-evidence, sequencing, locks (§41–§46)

- 13/13 packets: all 23 mandatory fields present, zero placeholders (scripted scan); hashes match; every packet carries the global forbidden-action law; sequencing chain 05→06→07→08→09→10→11→12 and terminal nodes (01/02/03/04/12/13) authorize ONLY "RWC-PRE-14 (gate)" — no packet authorizes beyond its node (probe-verified).
- **FAIL-evidence law (§42):** encoded — "an audit/evidence reference whose verdict is FAIL/FIX-class may NEVER count as satisfactory evidence for any PRE node closure" — in the builder report + packet audit_requirements ("builder cannot self-PASS"). **Encoding is PROCEDURAL, not mechanical** (no machine registry enforces it); acceptable for this phase, noted.
- **Corpus (§43):** BLOCKED now; no acquisition workflow, downloader, or registration code exists. **Sequencing (§44):** PRE-14 → RWC-CORPUS → annotation preserved. **Fit (§45):** blocked even post-PRE-14 — the fit body does not exist; `fitPhaseNotAuthorized(RWC-FIT)` is the unconditional tail; needs corpus+annotation+IRR+splits+canonical door.
- **Production truths (§46), all probe-verified unchanged:** `supportsRealWorldClaims == false`; `calibrationClass == .engineeringOnly`; `ProductionScoreReleaseGateV1.evaluate().0 == false` (CLOSED); `productionDisplayAllowed() == false`; 59 engineering pairs (no growth); Presentation remains forbidden by every packet's forbidden-action law; `preregistrationAuditPassed == false`. A PRE-14 PASS changes none of these automatically.

## 11. Fresh findings (all PINNED by AUDIT14 probes; none fixed by the auditor)

| ID | Severity | Finding (evidence = pinned probe + file/line) |
|---|---|---|
| A14-F1 | **MEDIUM** | `requireEligible` never evaluates `expiryDate`: ACTIVE+expired passes training/eval; malformed/past/today/inverted dates pass; no time source (`RWCAssetRightsLedgerV1.swift:93-110`) |
| A14-F2 | **MEDIUM** | `allowedUse`/`prohibitedUse` never consulted — `prohibitedUse=["training"]`+`trainingAllowed=true` passes for training; dual truth with no authoritative field |
| A14-F3 | LOW | Opaque-pointer/field hygiene prose-only: newline-only evidence passes (`.whitespaces`), raw URL/path evidence passes, empty `owner` passes, UPPER/MIXED-case `contentHash` accepted (`isHexDigit`), dates unvalidated, duplicate provenance accepted |
| A14-F4 | **MEDIUM** | Resurrection: no ledger store exists; fresh ACTIVE record with same assetID + OLD evidence passes post-revocation — monotonicity is convention-only |
| A14-F5 | **MEDIUM** | PRE-02 grammar NOT wired into the canonical PRE-04 door: garbage-but-consistent IDs mint `PreparedCalibrationDatasetV1`; frozen PRE-04 doc overclaims "bad asset ID → no token" |
| A14-F6 | LOW | Prepared token binds opaque IDs only (3 stored fields, Mirror census) — ID↔payload binding invariant REQUIRED at RWC-FIT |
| A14-F6b | LOW | A11-F2-APIBYPASS residue: `DimensionCalibratorV1.fit` / `LogisticCalibrator.fit` / `SuitabilityFusionModelV1.fit` publicly callable with raw arrays outside the token door; real-world vs engineering separation at these entrypoints is governance, not structure; legacy deprecation is warning-only (defaulted context param) |
| A14-F7 | **MEDIUM** | ECE ≤ .05 point-estimate gate statistically unsupported at n=400/10 bins: perfect model E[ECE] ≈ .050, pass rate ≈ 52% (seeded MC, in-probe); PRE-09 planning used a single-proportion statistic for a binned ECE |
| A14-F8 | **MEDIUM** | "POWERED" contradiction: 60/15/15 = POWERED + hard slice-ECE ≤ .07 vs PRE-09's own n≈196; perfect model passes ≈2% at n=60 (E[ECE]≈.128) — mislabeled, actually REPORTABLE |
| A14-F9 | **MEDIUM** | Abstention gaming unbounded: no coverage/decision-rate/abstention-rate bound anywhere in frozen gates or slices |
| A14-F10 | **MEDIUM** | IRR gate CI pass rule undefined (ECE declares point-estimate; IRR silent → κ=.61 CI [.30,.75] undecidable); degenerate bootstrap replicates / valid-fraction minimum unspecified |
| A14-F11 | LOW | HELD_OUT_FINAL "opening" act undefined (IDs/hashes are in-repo by design); no authorized-opener/access-control law — procedural limitation to define before sealing |
| A14-F12 | LOW | "Materially" discretionary (no material/non-material change matrix); status of already-computed aggregates after post-opening revocation not predefined |
| A14-F13 | **MEDIUM** | Freeze boundary excludes ALL methodology code (nothing `.swift` hashed; no commit-SHA binding law); invalidation law is post-result-only → post-PRE-14/pre-corpus silent code edits invalidate nothing |
| A14-F14 | INFO | EN handbook D-02 contains Cyrillic lookalike bytes ("авудible"); TR "toplulukta"/"genelde" mildly ambiguous — no systematic label shift |
| A14-F15 | LOW | Unadjudicated |A−B|=1 tie-rounding is half-away-from-zero → systematically less-protective final labels (1/2→2 class flip) while adjudication is required only at |A−B|≥2 |
| A14-F16 | LOW | Floor device never concretely named; all budgets UNSET_PENDING_BASELINE → PRE-13 FAIL semantics cannot bind; budget-freeze-before-RWC-DEVICE law required (carried BLK-DEVICE-RWC-OPEN) |
| A14-F17 | LOW | Sentinel falseSafe bound is conditional-on-sentinel-class; no report-semantics law distinguishes it from a population false-safe rate |
| A14-F18 | LOW | No multiple-comparison policy declared for 21 overlapping slice gates |
| A14-F19 | INFO | Minimal n for zero-event UB≤2% is exactly 149; frozen n≥150 is conservative-safe. FAIL-evidence law procedural, not mechanical. Isolation/sentinel-blindness implementable but prose until annotation tooling exists. |

**Severity tally: 0 CRITICAL / 0 HIGH / 8 MEDIUM / 8 LOW / 3 INFO.** §49 hard-no-pass items triggered: contradictory use-fields authorizing forbidden use (F2); expired-asset acceptance contrary to contract (F1); invalid RWC composite minting prepared token where grammar should bind the canonical door (F5); ECE/sample-size statistically unsupported (F7); contradictory "powered" definition (F8); abstention gaming without coverage accountability (F9); IRR CI pass rule undefined (F10); freeze boundary drifting materially undetected in the pre-corpus window (F13).

## 12. Truth matrix

| Claim (builder) | Audit result |
|---|---|
| Entry 817 / final 830×2 / 13 fresh tests | CONFIRMED (830 baseline re-measured; 866/866 ×2 with probes) |
| 15 artifacts SHA-256 frozen, drift-checked | CONFIRMED (recomputed; byte-flip attack detected) |
| Zero data / zero corpus / zero labels / zero fits / zero heldout opens | CONFIRMED (forensic sweep + counters) |
| Gates frozen before data visibility | CONFIRMED |
| PRE-01 fail-closed eligibility | **PARTIAL** — fails closed on source/state/use/hash/provenance, but expiry (F1), use-lists (F2), resurrection (F4), field hygiene (F3) are open |
| PRE-02 closes IDCHARSET + COMPOSITE-ALIAS | CONFIRMED for the identity module itself |
| PRE-04 "bad asset ID → token never exists" | **REFUTED** — garbage-but-consistent IDs mint tokens (F5) |
| "Closes A11-F2-APIBYPASS structurally" | **PARTIAL** — true for the executor door; generic fit surfaces remain public (F6b) |
| TR/EN semantic parity | CONFIRMED at meaning level (INFO typos, F14) |
| Kappa/alpha/Wilson/rule-of-three/planning-n correct | CONFIRMED by independent implementations (1e-9 agreement) |
| "ECE gate honest, not optimistic" | The gap is honest, but the gate is statistically unsupported at n=400 (F7) — honesty about .250 does not repair the n=400 design |
| 13 packets complete, no placeholder | CONFIRMED |
| Production locks unchanged | CONFIRMED |

## 13. Verdict

> **FIX REQUIRED — RWC PREREGISTRATION**

8 MEDIUM findings are unresolved; several (F1, F2, F4, F5, F7, F8, F9, F10, F13) fall in the mandate's hard no-pass classes. The preregistration program is close: identity grammar, executor refusals, freeze/drift machinery, zero-data discipline, IRR mathematics, adjudication design and bilingual handbook are sound. What blocks PASS is (a) a rights ledger whose expiry/use-list/resurrection laws are prose rather than code, (b) a canonical door that does not enforce the canonical grammar it was built to carry, (c) three statistically unsupported or ambiguous gate rules (ECE n=400 point-estimate, POWERED-at-60 slice gate, undefined IRR CI rule, uncovered abstention), and (d) a freeze boundary that leaves all methodology code un-hashed in the post-PRE-14/pre-corpus window. Every one of these must be fixed BEFORE corpus acquisition — fixing them after data exists would itself be outcome-aware methodology change.

**Corpus acquisition remains BLOCKED. Annotation, fitting, held-out population, production score, display, and Presentation remain BLOCKED regardless of this verdict.**

### Required fixes (minimum, before a PRE-14 re-audit can PASS)
1. **F1/F2/F4** — enforce expiry against an explicit canonical time source at eligibility; declare one authoritative use-authorization source and refuse contradictory records; introduce a real ledger (append-only store keyed by assetID) so revocation history structurally blocks same-evidence resurrection; tighten evidence/owner/hash hygiene (F3) while there.
2. **F5** — `prepareDataset` validates every declared composite with `RWCAssetIdentityV1.parseComposite` (or a declared RWC-mode flag), matching the frozen PRE-04 claim.
3. **F7/F8/F9/F10** — re-freeze the statistical gates pre-data: a debiased/CI-aware ECE rule (or n sized for a binned estimator), a mathematically defined POWERED (or rename to REPORTABLE and make slice-ECE report-only until powered), an explicit coverage/abstention-rate accountability rule, and an explicit IRR CI pass rule + degenerate-replicate/valid-fraction law. Document every change in `rejected_or_modified_candidates` — this is lawful now (pre-data) and unlawful later.
4. **F13** — extend the freeze manifest (or a commit-SHA binding law) to the methodology code files, and add a between-window law: any change to frozen artifacts or their code twins after PRE-14 PASS and before corpus requires explicit re-freeze version + re-audit.
5. LOW items (F11, F12, F15, F16, F17, F18) must be scheduled: F11/F12/F17/F18 before RWC-SPLIT/first evaluation; F15 before annotation; F16 before RWC-DEVICE.

### Next action
Builder fixes the 8 MEDIUM findings (plus scheduled LOWs) under a fresh evidence-bearing commit series on the same branch, then requests an independent PRE-14 **re-audit** of a new candidate tag. No corpus acquisition until that re-audit returns PASS.

---
*AUDIT14 probes: `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT14_RWCPreregistrationPre14Probes.swift` — 36 tests, green against the candidate as-is; PINNED tests assert current truth and must be revisited (never deleted) when findings are fixed. Artifacts left UNCOMMITTED for the supervisor.*
