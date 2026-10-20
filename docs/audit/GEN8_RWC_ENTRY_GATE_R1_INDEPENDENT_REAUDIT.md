# GEN8 — RWC ENTRY GATE R1 — INDEPENDENT CLEAN-SESSION RE-AUDIT (AUDIT11)

**Date:** 2026-10-20 · **Auditor:** fresh-context independent re-auditor (no builder session knowledge; nothing taken on builder word — every claim re-derived from the repository)
**Target:** `06b338640925b6e6df4b4acc2a71bd83052f395d` · tag `gen8-real-world-calibration-entry-gate-r1-audit-candidate` (annotated tag object `2627744a1ae0a7be3e3356af2fe4b0c82d7d3b8b`, type `tag`, dereferences to `06b3386…`)
**Probe family:** `packages/GuardianKit/Tests/GuardianCoreTests/AUDIT11_RWCEntryGateR1ReauditProbes.swift` (25 fresh probes, add-only; own fixtures, own independent math — not copies of the builder R1 tests)

---

## 1. Chain of custody — VERIFIED

- `git status`: clean before audit (afterwards: only the two auditor-added files, untracked).
- Branch `phase/real-world-calibration`; `HEAD` = `origin/phase/real-world-calibration` = tag dereference = `06b3386…` — exact three-way match with the mandate.
- R1 round = exactly 6 commits over the AUDIT10 verdict commit `6f1cff7`:
  `e2d008d` (docs-only pre-declaration, 12:27:12) → `905eab5` (A10-F2-MULTISET, 12:28:39) → `1788ef9` (A10-F2-WIRING, 12:30:39) → `6f5f380` (A10-F3-SIBLINGS + FPEDGE in-file, 12:32:38) → `c7aff5a` (docs: erratum-driven corrections + constitution addendum) → `06b3386` (R1 tests + fix report).
- Diff `6f1cff7..06b3386`: 15 files, +1328/−55. Production sources touched: `CalibrationCoreV1.swift` (+12), `CalibrationIntegrityV1.swift` (+91 net), `CalibrationRunPreparationV1.swift` (NEW, 49). **No F1 production source touched** (ChildAgePolicyEngineV1 / TeenBandFailClosedPolicyV1 absent from the diff) — F1 correctly left alone (no overfix), limitation carried.
- P009E-R1 locked ancestry `f991aba` and prior candidate `28865c3` confirmed present in history. No rewrite signs.

## 2. Suite evidence (counts, exact)

- Full suite on candidate + fresh probes: **704/704, 0 failures — two independent full runs** (704 = 642 pre-AUDIT10 baseline + 19 AUDIT10 probes + 1 wired-gate test + 17 builder R1 tests + 25 AUDIT11 probes).
- Focused AUDIT11 family: 25/25.
- A green suite was given **zero** verdict weight on its own; every closure below is backed by a fresh adversarial probe or git-derived evidence.

## 3. AUDIT10 finding matrix — ORIGINAL → CLAIMED FIX → FRESH PROBE → RESULT

| Finding | Original (AUDIT10) | Claimed fix | Fresh auditor probe(s) | Result | Residual risk | Classification |
|---|---|---|---|---|---|---|
| **A10-F2-WIRING** (MEDIUM) | Guard had 0 non-test callers; real fit path kept silent `guard … else { continue }`; "structurally unreachable" CONTRADICTED | NEW `CalibrationRunPreparationV1.prepare` (DECLARED→RESOLUTION→GATE→FIT) wired into `P009EScoreTests.setUp`; silent drop deleted; refusal ⇒ zero results, typed error recorded | A11_01 (two real victims → typed refusal, zero records), A11_07 (ghost injection at real entrypoint), A11_24 (source-order truth: prepare precedes fit; `else { continue }` gone; prepare calls `requireFullResolution`; live harness gate-accepted 59/59) | **CLOSED for the current canonical path** | Future rogue callers can still call fit APIs directly (A11_25) — convention + probes only | **VERIFIED_WITH_LIMITATIONS** (see §5 epistemic distinction) |
| **A10-F2-MULTISET** (MEDIUM) | `[a,a,b]`~`[a,b,b]` and `[a,a]`~`[a,b]` ACCEPTED | Guard v2 exact-identity law: 5 typed errors, uniqueness ⇒ set==multiset | A11_02–A11_05 full fresh matrix (below) | **CLOSED** | `#`-separator aliasing collapses to typed duplicate refusal (fail-closed, A11_22) | **VERIFIED** |
| **A10-A9-DISCIPLINE** (LOW) | No dedicated AUDIT9 inversion lock doc; dangling "ENTRY_GATE lock notes" pointer; commit-msg overstatement | `AUDIT9_F3_INVERSION_LOCK.md` + `ENTRY_GATE_LOCK_NOTES.md` (pointer resolved by creating the referenced artefact — evidence file itself untouched) | A11_16 (lock contains original+changed assertions and frozen SHA; notes point to lock; AUDIT9 active still exactly the single declared hunk, net +2 lines, both removed lines in the clamp block) | **CLOSED** | in-file pointer text remains generic by design (evidence immutability wins) | **VERIFIED** |
| **A10-F3-SIBLINGS** (LOW) | `mae` NaN-propagation; `auroc` silent finite miscount; strict-only enforcement was a comment | `validateValues` shared doctrine; `maeStrict`/`aurocStrict` typed; legacy mae → NaN marker (incl. shape mismatch); legacy auroc → nil; pipeline strict-only | A11_08–A11_11 (own fixtures/matrices), A11_12 (pipeline value stability) | **CLOSED for CalibrationMetricsV1** | Legacy non-throwing markers remain (documented); **pre-P009E P008 pilot enum `CalibrationMetrics` NOT hardened** — see A11-LEGACY-P008 | **VERIFIED_WITH_LIMITATIONS** |
| **A10-F3-FPEDGE** (LOW) | "0.3×10 rounds DOWN → bin 2" false in 4 places | Living sources corrected in place; immutable artefacts corrected by erratum preserving original wording verbatim | A11_17 (runtime truth: `0.3*10.0 == 3.0` exactly, `Int == 3`, no k/10 floors down; living source corrected; strict metric lands lone 0.3 in one bin, meanPred 0.3) | **CLOSED** (living) / erratum (historical) | false sentence remains readable in immutable artefacts BY DESIGN, flagged | **VERIFIED** |
| **A10-F1-COVERAGE** (LIMITATION) | 4/4 lexicon-missing paraphrases component-ALIGNED at risk .9 (no end-to-end false-safe) | No code change (correct — mandate forbade overfix) | A11_18 with THREE FRESH paraphrases ("slaughter…", "bloodshed…", "ölümcül saldırı…"): **3/3 still component-ALIGNED at risk .9**; all 3 end-to-end `strongProtection`; covered cue ("massacre…") still reviewed | **OPEN — honestly carried, NOT falsely closed** | real violence detection remains NOT validated | **CARRIED_LIMITATION** (correct state) |
| **A10-F1-FALSETRIGGER** (INFO) | benign cue-bearing educational text → teen review, risk-independent | No change (doctrine-consistent) | A11_18(c,d): fresh benign TR text → teen `unknownReview`, state never escalates; adult unaffected | reproduced | over-restriction carried | **CARRIED (RECORD)** |
| **A10-DOC-CJK** (INFO) | stray "扩展" token | replaced with "extension" | report diff inspected (`c7aff5a`) | **CLOSED** | — | VERIFIED |
| **A10-F2-VACUOUS** (INFO) | tautological success test | replaced by real-ledger/real-resolver pipeline proof | `RealWorldCalibrationEntryGateTests` diff inspected; A11_01/A11_24 independently prove the non-tautological path | **CLOSED** | — | VERIFIED |

**No AUDIT10 finding vanished.** All nine accounted for.

## 4. F2 — call graph (measured by this auditor, repo-wide)

Grep census on the candidate:
- `CalibrationRunPreparationV1.prepare` callers: `P009EScoreTests.setUp` (the only execution harness that fits/evaluates), `RealWorldCalibrationEntryGateTests`, `RWCEntryGateR1Tests`, AUDIT11.
- `requireFullResolution` non-test callers: **exactly one — `CalibrationRunPreparationV1.prepare`** (the canonical door). Plus direct test/probe calls.
- `DimensionCalibratorV1.fit` / `SuitabilityFusionModelV1.fit` callers: `P009EScoreTests` (now behind the gate), AUDIT8/AUDIT9 frozen audit harnesses (historical evidence, by design), builder/auditor probes.
- **`CalibrationPilotRunner.run` (P008A lab pilot, `CalibrationPilot.swift`)**: produces a `CalibrationPilotResult` (level LAB_CALIBRATED_LIMITED) from `PilotExample` arrays WITHOUT the integrity gate, using the UNhardened pre-P009E `CalibrationMetrics` enum. Sole caller: `P008ACoreTests`. It does not consume `CalibrationDatasetRegistryV2` and cannot reach the P009E pipeline or production display (gates closed), but it IS a calibration-shaped result producer outside the canonical door → finding **A11-LEGACY-PILOT-PATH** (LOW; the metric half was disclosed by the builder in the R1 fix report §2 as "CalibrationMetrics.swift … untouched — recorded here, not hidden").

**Bypass answer:** on the candidate, every execution path that fits or evaluates against the P009E calibration ledger goes through `CalibrationRunPreparationV1` → `CalibrationRunGuardV1`. The only gate-free calibration-result producer is the legacy P008A lab pilot (test-only caller, separate data type, display-gated). No silent-drop path into the canonical ledger exists: `prepare` returns records only after the gate; a refusal yields zero records (A11_01 proves none escape).

## 5. F2 — epistemic distinction (mandate §2.2)

- **A. Canonical reusable core path:** `CalibrationRunPreparationV1` + `CalibrationRunGuardV1` — EXISTS, hardened, fresh-probe verified.
- **B. Current engineering harness:** `P009EScoreTests` — a TEST HARNESS (XCTest), now wired through A. This is the only fitting/evaluation executor in the repo today.
- **C. Future real-world calibration executor:** DOES NOT EXIST YET. The constitution R1 addendum documents the composite-identity law and opaque asset-ID contract, and the R1 fix report states "real-corpus runs must enter via the same door" — but there is NO structural (compile-time) enforcement; a future executor could call fit APIs directly (A11_25 pins this openly).
- **D. Production runtime:** NOT wired to any calibration fitting; production score display structurally OFF.
- Builder language check: the R1 fix report says "wired into the real fit path", correctly scoped to the harness, and explicitly concedes "enforcement that FUTURE harnesses use the door is convention + probes". **No overclaim found** — "production wired" is not claimed, and must not be claimed. Correct classification for F2 wiring: **VERIFIED_WITH_LIMITATIONS** (current execution path gated; future-executor enforcement is convention, not structure).

## 6. F2 — fresh identity/multiset matrix (A11_01–A11_07, A11_21–A11_23)

| Attack | Result |
|---|---|
| `[a,b,c]` / `[c,b,a]` (order only) | ACCEPTED (order-independence preserved; re-verified on the real 59-ledger reversed by builder tests; fresh IDs by this auditor) |
| `[n1..n4]` / `[n1,n2,n3,n9]` same count substitution | REFUSED `unresolvedPairs(4,4,["n4"])` |
| `[a,a,b]` / `[a,b]`-class duplicates (declared) | REFUSED `duplicateDeclaredIDs` (incl. through the REAL pipeline with a duplicated real pair, A11_03) |
| `[m1,m2,m3]` / `[m1,m2,m2]` (resolved dup) | REFUSED `duplicateResolvedIDs(["m2"])` |
| `[a,a,b]` / `[a,b,b]` cancellation | REFUSED (duplicate law; builder + inverted P10 + fresh compound A11_05) |
| missing+extra compound | REFUSED `unresolvedPairs` (missing precedes extra — the safety-relevant class wins) |
| malformed+duplicate compound | REFUSED `malformedIDs` first — precedence malformed → dupDeclared → dupResolved → missing → extra CONFIRMED deterministic (3 repeats) |
| `[]` / `[]` | **ACCEPTED VACUOUSLY** (contract determined, not assumed): empty ledger passes the gate but NOTHING downstream can produce a metric or fitted model — fusion/calibrator abstain, `maeStrict`/`aurocStrict` throw `emptyInput` (A11_21). Documented contract, not a hole. |
| whitespace IDs ("", " ", "\t", NBSP) | REFUSED `malformedIDs` |
| newline-only ID "\n" | **ACCEPTED as well-formed** — `CharacterSet.whitespaces` excludes newlines → finding **A11-F2-IDCHARSET** (LOW). Fail-closed in effect: identity equality still binds it; no substitution window (A11_06). |
| case `ABC` vs `abc` | REFUSED (case-sensitive exact identity; no invented normalization) |
| Cyrillic lookalike `аxe` vs `axe` | REFUSED (distinct identities; missing named exactly) |
| NFC vs NFD (`café`) | treated as ONE identity (Swift canonical equivalence — measured, consistent on both sides; no substitution window). Documented; moot under the opaque-ASCII ID constitution addendum. |
| `itemID` containing `#` (separator aliasing) | distinct pairs CAN alias to one composite string → collapses to `duplicateDeclaredIDs` typed refusal — **fail-closed**, pinned as **A11-F2-COMPOSITE-ALIAS** (INFO): next-phase ID contract should forbid `#` in opaque asset IDs. |

## 7. F3 — fresh independent verification

- **Common validator** (`validateValues(_:domain:)`): single doctrine, finite always + optional domain; ECE/AUROC bind to 0…1 via `validateProbabilities`; MAE domain explicit. INSPECTED + fresh-tested.
- **MAE strict (A11_08):** rubric 0…4 fixture hand-computed (0.75); boundaries 0 and 4 valid inclusive; below/above domain typed `outOfDomain` with index; NaN/±inf typed; shape/empty typed; **no regression forcing MAE to 0…1** — `maeStrict([3.7],[3.7])` fails on default probability domain and passes on explicit 0…4; the pipeline (`P009EScoreTests.evalMAE`) passes `domain: 0...4` explicitly — verified in source.
- **AUROC strict (A11_09, A11_10):** perfect separation 1.0; inversion 0.0; one-pos/one-neg; complete ties 0.5; partial ties hand-computed 0.875; all-pos/all-neg typed `degenerateLabels`; NaN/±inf/<0/>1/shape/empty typed. **Independent Mann-Whitney rank-based AUROC (different algorithm) agrees with the production pairwise implementation to 1e-12.**
- **Legacy behavior (A11_11):** `CalibrationMetricsV1.mae` → NaN marker on non-finite AND shape mismatch; no domain bound by documented design (strict API carries the domain law); `auroc` → nil on invalid preds/shape/degenerate — never a finite miscount; `eceAndBins` → NaN marker + empty bins. No invalid input yields a plausible finite value anywhere in V1.
- **Pre-P009E pilot siblings — finding A11-LEGACY-P008 (LOW, pinned, builder-disclosed):** old `CalibrationMetrics` enum (`CalibrationMetrics.swift`): `mae` truncates to `min(count)` (measured: `mae([0.9,0.1],[0.9]) == 0.0` — silent shape tolerance) and `ece` silently excludes NaN confidences while dividing by full n (measured finite 0.05). Reachable only via `CalibrationPilotRunner` (P008A lab pilot; test-only caller). Must be hardened or retired before any real-corpus use.

## 8. Historical metric reproduction — INDEPENDENT (A11_12)

Recomputed by this auditor with OWN math (plain-loop MAE; own array-bucket ECE/Brier; rank-based AUROC) on the live fitted artefacts:
**TRAIN MAE 0.628 · CAL MAE 0.743 (n=12, abstained 0) · HELD_OUT 0.559 (n=7, abstained 1) · ECE 0.250 · Brier 0.139 · AUROC 0.938 (prints 0.94) · sentinel falseSafe 0/5.**
All match the pre-fix values exactly — the metric/wiring hardening tuned NOTHING. ECE 0.250 ≫ 0.05 target: **UNMET and UNRELAXED** (asserted). Production release gate CLOSED (6/10 unmet, truthful strings).

## 9. AUDIT10 inversion discipline — SECOND HARD GATE — VERIFIED

- **Frozen original:** `AUDIT10_RealWorldCalibrationEntryGateProbes_ORIGINAL_LOCKED.swift.txt` SHA-256 = `a1ffb855…0580` — recomputed from disk by auditor shell AND by probe A11_13; **byte-exact equal to the probe file at `6f1cff7`** (`git show 6f1cff7:…probe.swift | shasum` = same digest). Created at `e2d008d`, never modified since.
- **Commit ordering (git-proven):** manifest `AUDIT10_INVERSION_LOCK.md` introduced at `e2d008d` (2026-10-20 12:27:12, **docs-only commit — 5 doc files, zero code**), and its content at THAT commit (`git show e2d008d:…`) already declared all three inversions I-1/I-2/I-3 with the exact replacement assertions. First inverting code commit: `905eab5` (12:28:39). Manifest file byte-identical today to its introducing commit (SHA `3fb6425c…` both). **Pre-declaration genuinely precedes every fix. NOT retro-written.**
- **Bounded inversion:** full `diff` frozen vs active (auditor-run) shows changes ONLY in the three declared blocks (P08(a) wiring pin → FIXED assertions; P10 both multiset pins → refusal assertions; P14 auroc pin → nil assertion + mae message retune exactly as manifest I-3 allows). Probe A11_15 re-verifies from disk on every run via counted line-accounting against declared markers: **zero undeclared semantic changes**. P08(b,c,d), P09, P11–P13, P15–P19 and the whole F1 block byte-identical.
- **Legitimacy per inversion:** each original probe pinned the defect and pre-authorized exactly this migration in its own failure message; each new assertion asserts the FIXED behavior, which is strictly stronger (refusal where acceptance was pinned); independent fresh tests (this audit + builder R1) prove the fixed behavior at the API level without relying on the probe file. Historical AUDIT10 report: last commit touching it is `6f1cff7` (its creation) — **never mutated**.
- **Ruling: inversion discipline LEGITIMATE.**

## 10. AUDIT9 discipline / FP edge — VERIFIED

- AUDIT9 frozen SHA `a349a487…3bc4e` recomputed from disk (shell + probe). Zero bytes changed in R1 (git log on both AUDIT9 files shows no R1-era commits).
- `AUDIT9_F3_INVERSION_LOCK.md`: consistent with git truth (original assertion, changed assertion, single-hunk −2/+4 shape — re-measured independently by A11_16: net +2 lines, both removed lines in the clamp block).
- `ENTRY_GATE_LOCK_NOTES.md` resolves the dangling pointer by creating the referenced artefact — the pinned evidence file itself untouched (correct resolution under evidence immutability).
- FP edge runtime truth re-measured: `0.3*10.0 == 3.0` exactly; `Int(0.3*10.0) == 3`; no k/10 floors down. Living sources corrected; historical artefacts corrected ONLY by erratum which preserves the original false wording verbatim. Historical AUDIT9/AUDIT10 reports unmodified (git).

## 11. F1 — no false closure — VERIFIED (correctly still open)

Diff `6f1cff7..06b3386` touches NO F1 source. Fresh regression (A11_18, fresh stimuli): covered cue still fail-closed reviewed at strong risk; **3/3 fresh uncovered paraphrases still component-ALIGNED at risk 0.9** (limitation OPEN — pinned so it can never close silently); end-to-end `strongProtection` held in all cases (no false-safe observed); benign cue-only teen review reproduced; adult unaffected. "No end-to-end false-safe observed" ≠ "violence detection validated" — the latter remains **NOT validated** and is a real-corpus-phase question.

## 12. Canonical future calibration door (mandate §12)

`CalibrationRunPreparationV1` is documented in-source as "the single lawful door between a DECLARED ledger and any fit/metric stage", the constitution R1 addendum records the composite-identity law + opaque asset-ID contract, and the R1 fix report routes "real-corpus runs … via the same door". This is a genuine canonical-door declaration, **but today it is proven only for the current engineering harness migration**; there is no structural enforcement for a future executor. **Next-phase prerequisite (release-blocking invariant to formalize in the Real-World Calibration preregistration):** the real-data executor MUST consume the ledger exclusively through `CalibrationRunPreparationV1`; any gate bypass = release-blocking. PASS is not broken by this today; it is a recorded obligation.

## 13. Privacy / security — VERIFIED

- `CalibrationIntegrityErrorV1` payloads: opaque composite IDs + counts + category only — no content/title/URL/path/PII fields exist in the type (source-inspected; A10 P12 + fresh probes exercise the shapes).
- Constitution R1 addendum: asset IDs must be opaque/non-semantic; mapping never enters errors/logs/reports — consistent with the error type.
- Production diff `6f1cff7..06b3386` scanned: **zero** networking/telemetry/upload/persistence/logging tokens; pure value-type logic (Foundation only). No new I/O surface.

## 14. Regression / historical locks (in-suite, 704/704 ×2)

C6 load-bearing (A9_14) · Tier-0 capability truth · UNKNOWN/abstention behavior (OOD abstains; unsupported locale `ja` abstains with "language-slice-unsupported") · Hard Shield precedence + veto-cannot-be-overridden · strong-risk universal protection (fresh A11_18) · V1/V2 frozen truth (AUDIT8 byte-identical; AUDIT3/5/7 per prior manifests) · no real-data fitting (A11_20: 59 pairs, classes ⊆ {SYNTHETIC_DERIVED, STRUCTURAL_ONLY}, splits 26/12/8/5, split hygiene intact) · no new held-out consumption · production score display blocked (A11_19) · Presentation/Glyph/Motion still BLOCKED (no such implementation in diff; gates closed).

## 15. Fresh findings register (AUDIT11)

| ID | Sev | Finding | Status |
|---|---|---|---|
| A11-F2-IDCHARSET | LOW | Malformed-ID law trims `CharacterSet.whitespaces` only — a newline-only (or other control-char) ID passes as "well-formed". No substitution window (exact identity still binds); fail-closed in effect. Harden the charset (e.g. `.whitespacesAndNewlines` + control chars) with the next guard revision / real-corpus ID validator. | RECORD → fix with next guard rev |
| A11-F2-COMPOSITE-ALIAS | INFO | `itemID#profileID` separator unescaped: distinct pairs can alias to one composite string; today collapses to a typed duplicate refusal (fail-closed). Opaque-ID contract must forbid `#` in asset IDs. | RECORD (constitution already points the right way) |
| A11-LEGACY-P008 / A11-LEGACY-PILOT-PATH | LOW | Pre-P009E pilot path (`CalibrationPilotRunner` + old `CalibrationMetrics` enum) is a calibration-shaped result producer outside the canonical gate with unhardened metrics (mae min-count truncation; ece silent NaN exclusion). Test-only caller; separate data type; display-gated. Builder DISCLOSED the metric half in the R1 report (not hidden). Harden or retire before any real-corpus program. | RECORD → pre-corpus prerequisite |
| A11-F2-APIBYPASS | SCOPE LIMITATION | Fit APIs remain directly callable without the gate (Swift cannot forbid rogue callers). Current canonical path gated; future enforcement = convention + probes + the §12 release-blocking invariant. | CARRIED (pinned so it stays visible) |
| (contract note) | INFO | Empty/empty ledger is VACUOUSLY accepted by the gate; downstream fit/metrics structurally refuse to produce anything from it. Unicode canonical equivalence (NFC==NFD) is the measured identity semantics. | RECORD (documented) |

None of these is CRITICAL or MEDIUM; none contradicts the R1 closures; two were builder-disclosed residuals now pinned executable.

## 16. Truth matrix (single taxonomy)

| Row | Class |
|---|---|
| Chain of custody | VERIFIED |
| F2 canonical preparation (`prepare`+guard v2) | VERIFIED |
| F2 current execution wiring (engineering harness) | VERIFIED |
| F2 future-executor enforcement | VERIFIED_WITH_LIMITATIONS (convention + probes; no structure yet — §12 obligation) |
| F2 identity integrity (exact, case-sensitive, typed) | VERIFIED (charset edge: A11-F2-IDCHARSET LOW) |
| F2 duplicate protection (declared/resolved) | VERIFIED |
| F2 silent-drop prevention (current path) | VERIFIED |
| F3 common validation doctrine | VERIFIED |
| F3 MAE (strict + legacy marker) | VERIFIED (V1) / legacy P008 pilot sibling: LAB_ONLY leftover, pinned |
| F3 AUROC (strict + legacy nil channel) | VERIFIED (independent-math agreement) |
| F3 ECE/Brier | VERIFIED (value-stable; ECE target honestly UNMET) |
| AUDIT10 evidence integrity (frozen+manifest+bounded inversion) | VERIFIED |
| AUDIT9 evidence integrity | VERIFIED |
| FP-edge documentation truth | VERIFIED (living corrected; historical by erratum) |
| F1 safety invariant (no loosening, no false-safe observed) | VERIFIED_WITH_LIMITATIONS |
| F1 violence coverage | LAB_ONLY / CARRIED_LIMITATION (3/3 fresh paraphrase misses still component-aligned) |
| Historical calibration stability | VERIFIED (independent recomputation, §8) |
| Privacy (diff + error payloads) | VERIFIED |
| Security (no new surface) | VERIFIED |
| Physical-device runtime | UNVERIFIED (build-only claims; carried blocker §23/D-0016) |
| Real-world corpus | OPEN (zero data — correctly not started) |
| Human annotation | OPEN |
| Sealed held-out | OPEN |
| Production score | BLOCKED (gate CLOSED 6/10 — correct) |
| Presentation/Glyph/Motion | BLOCKED (correct) |

## 17. Verdict

**PASS — REAL-WORLD CALIBRATION ENTRY GATE ENGINEERING LOCKABLE; ULU EVREN EXECUTION CONTROL PLANE + REAL-WORLD CALIBRATION PREREGISTRATION NEXT; NO CORPUS/FITTING YET**

Grounds: both MEDIUM findings genuinely closed under fresh adversarial probing at the real entrypoint; no silent calibration drop exists in the current canonical path; identity integrity exact (multiset cancellation structurally refused); F3 siblings hardened with independent-math agreement and zero historical value drift; AUDIT10 inversion discipline proven legitimate by git-ordered pre-declaration + byte-exact frozen original + bounded diff; F1 limitation honestly open and freshly re-pinned; no new hidden CRITICAL/MEDIUM finding (fresh findings are LOW/INFO, two of them builder-disclosed).

**Claim ceiling:** "REAL-WORLD CALIBRATION ENTRY GATE ENGINEERING READY/LOCKABLE." Forbidden, still structurally false: "production wired", "real-world validated", "production calibrated", "violence detection validated".

**Carried blockers (none vanished):** ECE 0.250 ≫ 0.05 target (UNMET, unrelaxed) · real-world violence detection NOT validated (A10-F1-COVERAGE) · benign-cue over-restriction (A10-F1-FALSETRIGGER) · physical-device runtime evidence missing (§23/D-0016) · real corpus/annotation/IRR/held-out seal not started (correctly gated) · legacy non-throwing V1 markers + P008 pilot metrics (A11-LEGACY-P008) · future-executor gate enforcement structural gap (A11-F2-APIBYPASS → §12 release-blocking invariant) · `gh` PR flow credentials-blocked.

**Next action (single):** GEN8 ULU EVREN MASTER EXECUTION DAG + GEN8 PROJECT TWIN / CANONICAL STATE GRAPH control-plane kurulumu; Real-World Calibration preregistration/corpus programı onun üzerinden. (Not implemented in this session — audit-only.)

*After this audit: STOP. No fixes applied by the auditor; no corpus work, no fitting, no presentation. Auditor writes: this report + `AUDIT11_RWCEntryGateR1ReauditProbes.swift` only, left uncommitted for the supervising session.*
