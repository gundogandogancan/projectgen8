# GEN8 — REAL-WORLD CALIBRATION ENTRY GATE — INDEPENDENT RED-TEAM AUDIT (AUDIT10)

**Date:** 2026-10-20 · **Auditor:** fresh-context independent auditor (no builder session knowledge)
**Mandate:** `docs/audit/prompts/GEN8_RWC_ENTRY_GATE_INDEPENDENT_AUDIT_MANDATE.md` (S1–S15, executed in full)
**Audit target:** `28865c353257b1ea15fb9f740cdb11b90153e96b` · tag `gen8-real-world-calibration-entry-gate-audit-candidate` (annotated tag object `dc47528`, dereferences to `28865c3`)

---

## 1. S1 — Custody & chain integrity — VERIFIED

- Branch `phase/real-world-calibration`; HEAD `db263ef` = exactly one docs-only commit over the target (`git diff 28865c3..db263ef --stat` = `GEN8_RWC_ENTRY_GATE_INDEPENDENT_AUDIT_MANDATE.md | 17 +`). Working tree clean. Audited tree = target tree + mandate doc only.
- Chain matches the mandate exactly: `f991aba` (rollback, P009E-R1 merge) → `b08406c` (RWC constitution, docs-only) → `8c3272b` (F1) → `7bc0f78` (F2) → `6510079` (F3 + AUDIT9 freeze/inversion) → `28865c3` (fresh tests + report).
- Tag object `dc47528` is type `tag`; `rev-parse …^{commit}` = `28865c3`. No rewrite signs observed.
- Changed-file matrix `b08406c..28865c3` (8 files, +982/−3): `ChildAgePolicyEngineV1.swift` (+23), `TeenBandFailClosedPolicyV1.swift` (+6/−? v1→v1.1), `CalibrationCoreV1.swift` (+4), `CalibrationIntegrityV1.swift` (NEW, 53), `AUDIT9_P009ER1Probes.swift` (+4/−2), `RealWorldCalibrationEntryGateTests.swift` (NEW, 125), `AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt` (NEW, 762), implementation report (+6).

## 2. S2 — AUDIT9 EVIDENCE INTEGRITY (hard gate)

**Three-version compare:** file at `0150d06` ≡ file at `b08406c` (byte-identical, `cmp` clean). Candidate `28865c3` differs.
**Frozen copy:** `docs/audit/AUDIT9_P009ER1Probes_ORIGINAL_LOCKED.swift.txt` is **byte-exact** vs the `0150d06` version; SHA-256 `a349a487dc091d444f04939864582175409542f47d6275c6bb0bd8022163bc4e` (matches the builder claim). Re-verified executable from disk by probe P17.
**Exact hunk (the only delta, single hunk, −2/+4, net +2 lines):** original lines
`// out-of-range inputs are clamped, not dropped (INFO: …)` + `XCTAssertEqual(oor.bins…reduce(0,+), 2, "clamped, never silently dropped")` replaced by a 3-line `ENTRY-GATE FIX INVERSION (A9-R1-F3…)` comment + `XCTAssertTrue(oor.ece.isNaN && oor.bins.isEmpty, "A9-R1-F3 FIXED: no silent clamp into the metric")`. Probe P17 asserts the single-hunk shape (exactly 2 lines removed, 4 added, all in the clamp block) from disk on every run.
**Classification:** **green-making inversion of an auditor-pinned defect** — the AUDIT9 report (immutable, `0150d06`) pinned exactly this behavior as finding **A9-R1-F3 (INFO: "silently clamped… harden the domain contract before real-data calibration")** and listed it under "Pre-entry fixes". It is NOT a safety-invariant deletion and NOT an erased historical observation (frozen copy + immutable report preserve the original truth).
**Original probe body vs candidate (S2 step 5):** executed as auditor-owned probe **P16** — the single original expectation (`clamped → count 2`) **fails** against candidate (behavior now NaN-marker refusal); **every other original F3 expectation still passes** (fp-edge count, tiny fixture, top bin, empty input). Delta = exactly the declared inversion, nothing else. P16 is a non-failing characterization that asserts the delta (`XCTAssertFalse(originalExpectationHolds)`), keeping the historical evidence executable without turning the suite red and without `XCTExpectFailure` (rationale documented in the probe).

**S2.1 judgment (default NO, overcome?):**
- Non-mutation of historical evidence: **proven.** Frozen original byte-exact and committed atomically with the inversion; the pinned finding survives in the immutable AUDIT9 report; the inversion *strengthens* the assertion (clamp-tolerance → hard refusal); no probe deleted/weakened.
- Predefined discipline: **substantially, not fully, applied.** The repo's established pattern (P009B_R1/P009C_R1 lock docs, P009E_ENTRY_LOCK "the auditor PINNED the defects; fixes flip exactly these"; `464c79d` even locked *before* the fix; `38280f8` froze+inverted atomically) is a genuine predefined versioned-migration discipline, and the behavior change was pre-declared in a committed doc **before** the code change (`b08406c` constitution, F3 plan: "typed invalid-input REJECT … never silently clamped … no silent clamp"). **Gaps:** (a) no dedicated AUDIT9 inversion-manifest lock doc (every prior inversion had one); (b) the in-file comment cites "docs/calibration/ENTRY_GATE lock notes" — a **dangling reference** (the actual artefact is the ENTRY GATE section of `REAL_WORLD_CALIBRATION_CONSTITUTION_v1.md`); (c) `b08406c`'s commit message implies separate execution-plan docs that do not exist as such; (d) the constitution pre-declared "typed REJECT" only — the legacy-path NaN-marker split appears first in the fix commit itself.
- **Ruling: NOT a confirmed mandate violation / NOT historical-evidence mutation → not BLOCKED.** Finding **A10-A9-DISCIPLINE (LOW, FIX REQUIRED item):** formalize the AUDIT9 inversion manifest in a lock doc and fix the dangling pointer. 642-green was given zero weight in this ruling.

## 3. S3 — F1 audit (age law)

Implementation: `ChildAgePolicyEngineV1.evaluate` A9-R1-F1 block (only runs when `outcome == .aligned`; escalates to `unknownReview` on `strongRiskUnbandable` (maxRisk ≥ 0.6 AND unavailable+unbanded dimension's sentinel-context cue present) OR `presentUnbanded`; never loosens). `TeenBandFailClosedPolicyV1` bumped v1 → v1.1 adding `violenceGore` routing cues (EN war/airstrike/bombing/gore/violence/massacre; TR savaş/bombardıman/katliam/şiddet/çatışma).

- **Paraphrased adversarial (P01):** TR "silahlı çatışma…", EN "war footage"/"bombing aftermath"/"graphic violence", ages 13/14/17, risk .85 → never `aligned`, always `unknownReview`, state `strongProtection`. PASS.
- **Coverage truth (P02, pinned LIMITATION A10-F1-COVERAGE):** 4/4 lexicon-missing paraphrases ("kanlı görüntüler…", morphology "şiddetli kavga" ≠ token "şiddet", "violent assault…", "deadly armed raid…") at risk 0.9 stay **component-ALIGNED** for teen 14. End-to-end state stays `strongProtection` in all 4 (**no false-safe**). The engineering invariant is **cue-gated**; synonym/morphology/mixed-language misses are real. **Violence detection is NOT validated** — the builder's own residual note says the same (honest).
- **Benign false-trigger (P03, INFO A10-F1-FALSETRIGGER):** "savaş tarihi dersi…" / "violence prevention course…" at risk 0 → teen `unknownReview` on the cue **alone** (risk-independent), state never escalates, adult unaffected (`childOutcome nil`). This is over-restriction by the documented fail-closed doctrine (same semantics as the accepted sexual-sentinel precedent); the lexicon never acts as standalone *detection* (no protection state, no conviction), but the strong-risk+cue interaction exists **only** in the A9-R1-F1 aligned-block — the teen sentinel path is cue-only by design.
- **Preservation (P04–P07):** benign no-cue teen stays `aligned`; banded sensitive-news at risk 0.9 for teen 13 stays `aligned` + `strongProtection` (AUDIT7-P7 semantics intact; banded ≠ unsafe, missing ≠ negative); sub-strong fear aligned; under-13 H1 → review; unsupported jurisdiction + unattested profile fail closed; sexual sentinel + strict-parent overlay intact. **No safety regression found.**

## 4. S4/S5 — F2 audit (declared ≠ resolved)

**Guard logic** (`CalibrationRunGuardV1.requireFullResolution`): containment filter + count equality.
- **Same-count-different-ID-set (P09):** `[a,b,c]` vs `[a,b,x]` → typed refusal naming `c`; the unexpected extra cannot cancel the missing ID. **PASS (the critical NO-PASS attack is refused).**
- **Multiset duplicates (P10) — FINDING A10-F2-MULTISET (MEDIUM, pinned):** `[a,a,b]` vs `[a,b,b]` **ACCEPTED** (counts equal, declared ⊆ resolved as sets); `[a,a]` vs `[a,b]` also accepted (duplicate declared masked by an unexpected extra). The mandate contract says these MUST FAIL. Precondition is a duplicate-bearing declared ledger (today's 59 registry IDs appear unique; uniqueness is not structurally enforced for future real-corpus ledgers).
- **Injection matrix (P11):** 58/59, dangling, duplicate-resolved count inflation, malformed empty ID, alias-to-missing, unexpected extra — all typed refusals; full resolution (order-independent) passes. PASS.
- **Diagnostics (P12/S5):** counts + sorted IDs + category only; no content/PII fields exist in the error type. **Honest caveat:** future real-corpus asset IDs could themselves be sensitive — the corpus-policy ledger must keep IDs opaque (carried as design note, INFO).

**PRODUCTION WIRING — FINDING A10-F2-WIRING (MEDIUM — F2 NOT CLOSED):**
`requireFullResolution` has **zero callers outside `RealWorldCalibrationEntryGateTests`** (repo-wide scan; probe P08 re-asserts it from source on every run). The REAL fit/metric path — `P009EScoreTests.setUp` — still resolves pairs with `guard let sc = tester.scenario(for: pair) else { continue }`: a **silent drop**, exactly the A9-R1-F2 defect shape. P08 demonstrates dynamically that the production control flow reaches the fit stage on a 59-of-60 partial dataset while the unwired guard would have refused the identical input. The builder claims "fit/metrics structurally unreachable on partial datasets" (commit `7bc0f78`) — **CONTRADICTED**: the flag test (`testF2_SilentDropImpossible`) proves only local control flow around a direct guard call, and the builder's `testF2_FullResolutionSucceeds` is a **tautology** (passes the same array as declared and resolved — can never fail; vacuous evidence, INFO). Mitigation acknowledged: AUDIT9 probe `testA9_02` independently asserts 59/59 resolution (`dropped9 == []`) — that is *detection by a separate test*, not *refusal in the path*; the F2 constitution plan ("fitting/eval REFUSES") is not implemented in the harness.

## 5. S6 — F3 audit (metric domain contract)

- **Strict API matrix (P13):** NaN/±inf/−0.001/`(0.0).nextDown`/1.001/`(1.0).nextUp` → typed `MetricInputErrorV1` with correct case+index; 0, `leastNonzeroMagnitude`, 0.1/0.2/0.3/0.5, `(1.0).nextDown`, 1 accepted exactly-once; shape mismatch both directions typed; bins 0/−7 refused, bins 100 000 lawful; empty input defined (0,0,[]). PASS.
- **Legacy marker (P14):** `eceAndBins` refuses invalid domain via NaN+NaN+empty bins — a marker, **not a typed error**. **S6.1 caller census (repo-wide):** non-test callers of `eceAndBins` = `eceAndBinsStrict` only; test callers = AUDIT8 (valid domain), AUDIT9 (valid + the inverted refusal probe), P009EScoreTests:164 (valid logistic outputs; a NaN would fail its equality assertions). **No production pipeline can propagate the NaN marker today — propagation is not currently reachable.** LIMITATION: enforcement of "pipeline uses strict only" is a comment, not a structure; and **FINDING A10-F3-SIBLINGS (LOW, pinned):** `CalibrationMetricsV1.mae` propagates NaN silently into its aggregate and `auroc` silently *miscounts* NaN (comparison semantics — returns a finite wrong value, worse than a marker). The F3 domain contract does not cover the sibling metrics. → **F3 legacy path: CLOSED_WITH_LIMITATION.**
- **Auditor-owned math (P15):** independent single-pass ECE/Brier implementation agrees with the strict API to 1e-12 on asymmetric fixtures incl. exact boundaries; closed-form hand fixtures match; no loss/double-count anywhere.
- **S6.2 — the actual bin of 0.3×10 — FINDING A10-F3-FPEDGE (LOW):** `Double(0.3) × 10.0` rounds **UP to exactly 3.0** → `Int(0.3*10.0) == 3` → bin [0.3,0.4). Empirical sweep: **no** one-decimal boundary k/10 floors down at bins=10. The claim "0.3*10 rounds DOWN → bin 2" — stated in the candidate's `CalibrationIntegrityV1.swift` doc-comment, the AUDIT9 probe comment (frozen + active), the AUDIT9 report, and the entry-gate implementation report — is **false**. Metrics are unaffected (assignment is deterministic and exactly-once either way), but the documented domain contract contains a wrong statement and must be corrected (never relied upon).

## 6. S7 — Historical stability — VERIFIED

Reproduced on candidate in this audit's full runs (in-suite load-bearing assertions + prints):
`P009E_FIT train=26 trainMAE=0.628 w=[-1.83,1.44,-0.19,-1.00,-1.15]` · `P009E_CALIBRATION n=12 abst=0 MAE=0.743` · `P009E_HELDOUT_FINAL n=7 abst=1 MAE=0.559` · `P009E_RISK_CAL ece=0.250 brier=0.139 auroc=0.94` (AUDIT9 asserts AUROC .94±.02 vs claimed .938) · `P009E_SENTINEL n=5 falseSafe=0` · dataset 59 pairs (`SYNTHETIC_DERIVED:55 / STRUCTURAL_ONLY:4`). Probe P18 independently re-asserts split censuses (26/12/8/5), split disjointness, `supportsRealWorldClaims == false`, and that the only policy version bump is `teen-band-fail-closed-policy-v1.1`. AUDIT9's refit-determinism + held-out-leak counterfactual probes ran green. **No covert change to weights/labels/splits/thresholds/gates.** ECE 0.250 remains honestly UNMET-UNRELAXED (≫ .05 target).

## 7. S8 — Regression & preservation

- Full suite (pre-AUDIT10): clean, exit 0 — builder baseline confirmed at **642** tests. With AUDIT10: **661 = 642 + 19**, 0 failures (see §9 for counts evidence).
- AUDIT8 active file **byte-identical** to `AUDIT8_P009EProbes_ORIGINAL_LOCKED.swift.txt` (cmp clean). AUDIT9-ORIGINAL preserved byte-exact (§2). AUDIT3/5/7 actives differ from their frozen originals only per their pre-declared lock-doc manifests (prior-audit-accepted).
- C6 bright-to-bright load-bearing (AUDIT9 `testA9_14`, green), Tier-0 capability truth (Tier0 tests + AUDIT9 resolver probe: `extensionFastTier0 = [.temporal]` only, Tier1/shared empty), production score gate CLOSED (6/10 unmet, truthful strings), `productionDisplayAllowed()==false`, P009B skeleton refusing (probe P19). No fitting/held-out artefacts added anywhere in the candidate diff.

## 8. S10 — Security / privacy / resource diff — VERIFIED (clean)

Production diff `b08406c..28865c3` adds **no** networking, telemetry, logging, persistence, secrets, or entitlement changes: F1 block + lexicon entries + NaN marker are pure logic; `CalibrationIntegrityV1.swift` is pure functions over value types (Foundation only). F2 diagnostics carry IDs/counts only. Device evidence: the report's `xcodebuild SUCCEEDED` is **build-only classification** (builder-claimed; not re-run by this auditor); physical-device runtime evidence remains absent (§23/D-0016 open — carried).

## 9. S9 — Fresh probe family AUDIT10 (add-only)

`Tests/GuardianCoreTests/AUDIT10_RealWorldCalibrationEntryGateProbes.swift` — **19 probes**, non-copy (fresh stimuli/item IDs/helpers), **no existing source or test modified**. P01–P07 F1 (paraphrase, coverage pin, false-trigger pin, benign control, banded preservation, H1/jurisdiction/attestation, sentinel/parent). P08 production-callgraph enforcement (static + dynamic unwired pin). P09 same-count/different-ID. P10 multiset pin. P11 injection matrix. P12 diagnostics privacy. P13 strict matrix. P14 legacy marker + unguarded siblings pin. P15 auditor math + fp-edge truth. P16 ORIGINAL-AUDIT9-vs-candidate delta (recorded, non-failing by design — rationale in-code). P17 frozen-copy SHA + single-hunk shape from disk. P18 historical dataset/split stability. P19 gates blocked. **Result: 19/19 green; full suite 661/661 green.** No probe required a source change (a probe needing one would itself have been a finding — none did; the defects are pinned behaviorally instead).

## 10. Findings register

| ID | Sev | Finding | Status |
|---|---|---|---|
| A10-F2-WIRING | **MEDIUM** | `requireFullResolution` unwired; real fit path (`P009EScoreTests.setUp`) keeps the silent `continue` drop; "structurally unreachable" claim CONTRADICTED; builder's success test is a tautology | **FIX REQUIRED (F2 NOT closed)** |
| A10-F2-MULTISET | **MEDIUM** | `[a,a,b]`~`[a,b,b]` and `[a,a]`~`[a,b]` pass the guard (set-containment + count hides duplicate cancellation) | **FIX REQUIRED** |
| A10-A9-DISCIPLINE | LOW | AUDIT9 inversion lacks the dedicated lock-doc manifest used by every prior inversion; in-file "ENTRY_GATE lock notes" pointer dangles; `b08406c` message overstates its docs | FIX REQUIRED (docs) |
| A10-F3-FPEDGE | LOW | "0.3×10 rounds down → bin 2" documented in 4 places is false (truth: exactly 3.0 → bin 3; no k/10 floors down) — metrics unaffected | FIX REQUIRED (docs) |
| A10-F3-SIBLINGS | LOW | `mae`/`auroc` have no domain guard (NaN propagates / silently miscounts); legacy NaN marker untyped, enforcement by comment | CLOSED_WITH_LIMITATION → harden before real data |
| A10-F1-COVERAGE | LIMITATION | Violence invariant is cue-gated; 4/4 paraphrase misses stay component-ALIGNED at risk .9 (no end-to-end false-safe) | CARRY as real-world limitation (honestly declared by builder) |
| A10-F1-FALSETRIGGER | INFO | Teen review on benign cue-bearing educational text (risk-independent routing); doctrine-consistent over-restriction | RECORD |
| A10-DOC-CJK | INFO | Stray "扩展" token in the implementation report | RECORD |
| A10-F2-VACUOUS | INFO | `testF2_FullResolutionSucceeds` cannot fail (same array both sides) | RECORD (fold into F2 fix) |

Carried (unchanged, correct state): production score gate CLOSED (6/10 unmet); Presentation/Glyph/Motion BLOCKED; ECE .250 target UNMET-UNRELAXED; no real corpus/annotation/held-out; no device runtime evidence; A9-R1 INFO items other than F3 remain as recorded.

## 11. S13 — Truth matrix (single taxonomy; gate-state separate)

| Row | Class | Gate/Note |
|---|---|---|
| Chain integrity | VERIFIED | — |
| F1 semantic invariant (UNAVAILABLE/UNBANDED ≠ ALIGNED) | VERIFIED_WITH_LIMITATIONS | cue-gated for the no-finding case |
| F1 routing coverage | LAB_ONLY | lexicon-limited; misses pinned (P02) |
| F1 safety preservation (no loosening) | VERIFIED | matrix + fresh probes green |
| F2 resolution contract (typed refusal) | VERIFIED_WITH_LIMITATIONS | logic correct for named set attacks |
| F2 production wiring | CONTRADICTED | guard unwired; silent drop remains in fit path |
| F2 identity/multiset | CONTRADICTED | duplicate multisets accepted |
| F3 strict validation | VERIFIED | full matrix typed |
| F3 legacy compatibility | VERIFIED_WITH_LIMITATIONS | untyped marker; siblings unguarded; no reachable propagation today |
| F3 ECE math | VERIFIED_WITH_LIMITATIONS | math exact to 1e-12; fp-edge *documentation* false |
| Historical AUDIT9 integrity | VERIFIED_WITH_LIMITATIONS | frozen byte-exact; single pinned-finding inversion; manifest-doc gap |
| Historical calibration stability | VERIFIED | .628/.743/.559/.250/.139/.94/falseSafe=0 reproduced |
| Tier-0 truth | VERIFIED | in-suite |
| C6 load-bearing | VERIFIED | in-suite (A9_14) |
| Privacy | VERIFIED | no new I/O/telemetry/persistence |
| Security | VERIFIED | pure-logic diff; no new surface |
| Physical-device runtime | UNVERIFIED | build-only classification (builder claim not re-run) |
| Real-world corpus readiness | OPEN | policy locked; zero data |
| Annotation readiness | OPEN | architecture declared; no handbook/annotators |
| Held-out readiness | OPEN | split law declared; no sealed set |
| Production score | BLOCKED | gate CLOSED 6/10 — correct |
| Presentation/Glyph/Motion | BLOCKED | correct |

## 12. S11 — Claim ceiling

Maximum permissible claim after fixes: **"REAL-WORLD CALIBRATION ENTRY GATE ENGINEERING READY."** Forbidden (and structurally false today): "real-world validated", "production calibrated". With F2 unwired and the multiset hole open, even the ceiling claim is **not yet grantable**.

## 13. S14 — VERDICT

**FIX REQUIRED — ENTRY GATE**

Triggered by: **F2 unwired** (A10-F2-WIRING, MEDIUM — mandate NO-PASS trigger) and **multiset MUST-FAIL violated** (A10-F2-MULTISET, MEDIUM). Not BLOCKED: custody, frozen evidence, historical metrics and methodology all verified intact; the AUDIT9 inversion is a substantiated pinned-finding migration, not evidence mutation. Not PASS: the F2 contract ("fitting/eval REFUSES; structurally unreachable") is contradicted by the actual call graph, and the critical cancellation class survives in the guard.

**Required before re-audit:** (1) wire `requireFullResolution` (or an equivalent typed refusal) into the actual resolution→fit→metrics path and delete the silent `continue`; (2) multiset-exact comparison (e.g., sorted-array or counted-multiset equality); (3) replace the tautological success test; (4) AUDIT9 inversion manifest lock doc + fix the dangling pointer; (5) correct the fp-edge documentation in all four places; (6) optionally extend the domain guard to `mae`/`auroc` before any real-data metrics.

*After this audit: STOP. No fixes applied by the auditor; no corpus work, no fitting, no presentation.*
