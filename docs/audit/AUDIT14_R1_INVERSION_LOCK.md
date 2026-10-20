# AUDIT14 R1 INVERSION LOCK — pre-declared probe migration manifest

**Status:** IMMUTABLE MIGRATION RECORD. Committed BEFORE every inverting commit.
**Created:** 2026-10-20 on `phase/rwc-preregistration-preparation`, start HEAD `2b2c344`
(AUDIT14 verdict commit; audit target `1c4160b`).

## Frozen original

`docs/audit/AUDIT14_RWCPreregistrationPre14Probes_ORIGINAL_LOCKED.swift.txt`
SHA-256: `18ac2633dd55e6073cf80be309db75af3f07c96a2bedd62cf8a360c246186886`
(byte-exact copy of the active AUDIT14 probe file at HEAD `2b2c344`.)

## Law

AUDIT14 probes pin candidate `1c4160b` defects. R1 remediation (nine MEDIUM-labelled rows + coupled
LOWs) necessarily inverts exactly the pinned assertions below — each inversion asserts the FIXED
contract, strictly stronger than the pinned defect. Everything else stays byte-identical and green.
**Explicitly NOT inverted (historical math/truth that remains valid):** `testA14_PINNED_F7_…` and the
Monte-Carlo half of `testA14_PINNED_F8_…` (self-contained simulations proving the OLD design's bias —
permanent negative evidence, FM-014); `testA14_PINNED_F6_…` and `…F6b_…` (token payload binding and
generic fit surfaces remain honestly-scoped FUTURE RWC-FIT invariants this round);
`testA14_Pre13…PINNED_F16…` (floor-device/budget pins stay — the SELECTION RULE is added in the PRE-13
addendum without touching `DEVICE_RESOURCE_BUDGETS.yaml`; the finding stays OPEN blocking RWC-DEVICE);
`testA14_Pre05_LabelDirection…PINNED_F15…` (legacy `CalibrationAnnotationV1` behavior is deliberately
UNCHANGED — engineering-scoped; the protective law lands as a NEW `RWCAnnotationLawV1` for RWC);
`testA14_PINNED_F13_…`'s freeze-v1 pins (the v1 manifest file is preserved untouched as the failed
candidate's historical record — only its gates-file invalidation-law pin inverts, below);
`testA14_FailEvidenceLaw…`, `testA14_Pre01_RefusalsThatHold`, `testA14_Pre01_SourceClasses…`,
`testA14_Pre11_GateRegistry…` (gates-v2 PRESERVES every pinned substring for
falseSafe/MAE/AUROC/Brier/OOD/data_visibility/rejected≥4) and all other probes.

## Declared inversions — exhaustive

### I-1 · `testA14_PINNED_F1_ExpiredButActive_PassesEligibility`
Record-internal DATE LAWS land in the legacy 2-arg `requireEligible` (deterministic, no hidden clock):
strict `yyyy-MM-dd` well-formedness for acquisition/expiry/revocation; cross-field `expiry >= acquisition`,
`revocation >= acquisition`. asOf-dependent expiry (valid THROUGH the expiry date; expired when
`asOf > expiry`) lands in the canonical STORE path with injectable `asOf` (no `Date()`).
- `NoThrow(expired "2020-01-01" … training)` and `(… evaluation)` → **Throws** (cross-field: expiry <
  acquisition `2026-10-20`) — typed date error.
- `NoThrow("not-a-date")` → **Throws** malformed-date.
- `NoThrow(expiry "2026-10-20")` → **STAYS NoThrow** at record level (valid-through law; message
  updated to state the law) — asOf expiry is a store check.
- `NoThrow(acquisition 2026-10-20, expiry 2025-01-01)` → **Throws** cross-field.
- `.expired` state throw: unchanged.

### I-2 · `testA14_PINNED_F2_ContradictoryUseFields_Pass`
ONE authoritative use truth: typed `RWCUseV1 {training, evaluation}`; the string lists and booleans must
be CONSISTENT (allowedUse == exactly the uses whose boolean is true; prohibitedUse disjoint from
allowedUse; only known lowercase use strings) — any contradiction/unknown entry is a typed refusal in
the 2-arg validator. All three `NoThrow` pins → **Throws** (use-consistency error).

### I-3 · `testA14_PINNED_F3_FieldHygiene_ProseOnlyLaws`
- newline-only evidence → **Throws** `.missingLicenseEvidence` (trim set upgraded to
  whitespacesAndNewlines) [2-arg].
- raw URL / filesystem-path evidence → **Throws** opaque-pointer-grammar refusal via the CANONICAL
  STORE registration (`rwc-rights-ref-…` / `rwc-source-ref-…` grammar); the inverted lines exercise the
  store door.
- empty owner → **Throws** missing-owner [2-arg].
- UPPER/MIXED-case hash → **Throws** `.invalidContentHash` (canonical lowercase-hex law) [2-arg].
- `acquisition "someday"` → **Throws** malformed-date [2-arg].
- duplicate provenance → **Throws** duplicate-provenance [2-arg].

### I-4 · `testA14_PINNED_F4_Resurrection_SameIDOldEvidence_Passes`
Append-only `RWCAssetRightsLedgerStoreV1` becomes the canonical eligibility authority (register →
state machine → tombstone; relicense ONLY via explicit reauthorize event with NEW evidence identity).
The final resurrection block inverts: registering/eligibility-checking the same assetID with the SAME
old evidence after revocation → **Throws** resurrection-refused; an explicit reauthorize with NEW
evidence succeeds (auditable event). Earlier value-level assertions stay.

### I-5 · `testA14_PINNED_F5_GarbageConsistentIDs_MintPreparedToken`
`prepareDataset` validates EVERY declared+resolved composite via `RWCAssetIdentityV1.parseComposite`
BEFORE the guard (new typed `CalibrationIntegrityErrorV1.invalidRWCCompositeIDs(count:firstIndex:category:)`,
no raw echo). The loop inverts: each garbage fixture → **ThrowsError** (token never exists). The
PRE-04 doc overclaim is corrected in place; the pinned phrase "bad asset ID" REMAINS (now true).

### I-6 · `testA14_PINNED_F8_PoweredSliceGate_InternalContradiction` (text pins only; MC stays)
Tri-state law lands: REPORTABLE / GATE_POWERED / UNDERPOWERED. PRE-10 text pin
("POWERED = all minimums met") → new law text; gates slice gate → applies ONLY to GATE_POWERED slices
with power-law n from the v2 methodology (`slice_ECE` gate text/scope change). `min_n==60` stays as the
REPORTABLE minimum (pin survives); PRE-09 "~196 infeasible" line survives.

### I-7 · `testA14_PINNED_F9_NoCoverageGate_AbstentionGamingUnbounded`
Coverage accountability lands in gates-v2 + slices ("coverage" present): the three NOT-contains pins →
**contains** assertions (overall in-distribution decision-coverage gate; slice coverage applicability;
abstention-rate reporting bound). The "never counted as success or failure" calibration-abstention
phrase is preserved.

### I-8 · `testA14_Pre08_BootstrapDeterminism_PINNED_F10_IRRCIRuleUndefined`
IRR decision law lands (PASS iff 95% bootstrap CI LOWER BOUND >= threshold; B=2000 seeded; degenerate
replicates excluded; valid-replicate fraction >= 0.80 else INSUFFICIENT_DATA; κ=.61 CI[.30,.75] ⇒ FAIL
deterministically). The two IRR NOT-contains pins → contains "lower bound"; the PRE-08 NOT-contains pin
→ contains valid-fraction law. The ECE "point estimate" asymmetry witness is preserved via the v2 text
noting the superseded v1 point-estimate rule.

### I-9 · `testA14_PINNED_F13_…` (gates-file pin only)
PRE14→corpus WINDOW LAW + commit-level freeze binding land in gates-v2/freeze-v2: the invalidation-law
NOT-contains("pre-corpus"/"commit") pin → **contains** both. Freeze-v1-manifest pins (15 paths,
docs-only, no .swift) stay — v1 preserved untouched as the failed candidate's record; the NEW
`RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml` hashes normative artifacts AND methodology code.

### I-10 · `testA14_Pre12_SealLaws_PINNED_F11_F12_…`
Opening definition (counts/doesn't-count matrix), authorized-opener/access law, material/non-material
change matrix, post-opening-revocation aggregate law land in the PRE-12 doc: the four NOT-contains pins
→ contains assertions. Present-string pins preserved.

### I-11 · `testA14_PINNED_F17_SentinelConditionalSemantics_…`
Report-semantics law lands ("conditional on sentinel-class sampling; NOT a natural-prevalence
population rate"): the NOT-contains pin → contains.

### I-12 · `testA14_Pre10_SliceRegistry_Complete_PINNED_F18_…`
Multiplicity policy lands (each slice check classified SAFETY_HARD_GATE / CALIBRATION_HARD_GATE /
DIAGNOSTIC / EXPLORATORY + family law): the NOT-contains(multiplicity words) pin → contains.
21-slice census and sentinel/mixed minimum pins survive.

### I-13 · `testA14_Pre05_Handbooks_SemanticAnchors_PINNED_F14_…`
EN D-02 Cyrillic typo fixed ("авудible"→"audible"; internal version note v1.0.1; semantics unchanged):
the typo-presence pin inverts to absence + corrected-token presence.

## Verification hooks
`RWCPreregistrationR1Tests` re-verifies from disk: frozen SHA; declared FIXED markers present in the
active probe file; retired pinned assertions absent; non-inverted probes byte-stable in their pinned
regions.

## ADDENDUM (committed BEFORE the doc-inverting commit — ordering law preserved)

The mandated artifact edits (gates v2, slices v2, protocol addenda, handbook typo) necessarily drift
from the PRESERVED freeze-v1 manifest. Declared consequences:

### I-14 · `testA14_HashAttack_TempCopyByteFlip_Diverges`
The "canonical file matches before the attack" precondition re-anchors to the NEW
`RWC_PREREGISTRATION_FREEZE_MANIFEST_V2.yaml` (same attack semantics; v1 stays as the FAILED
candidate's historical record whose drift is EXPECTED and documented in the change ledger).

### I-15 · builder `RWCPreregistrationTests.testZeroDataGuarantee_AndLocksHold`
(Builder-owned test, not an AUDIT14 probe — listed for completeness): freeze-hash drift check
re-anchors to the V2 manifest.

### Doc-pin inversions already declared in I-6..I-13 are executed against the edited artifacts; the
pinned PRESENT-strings (e.g. "never counted as success or failure", "~196 is infeasible",
sentinel min_n 150, 21-slice census, PRE-13 fixed strings) are PRESERVED by construction.

### I-16 · `testA14_Custody_FreezeManifest15_AllHashesRecomputedValid` (addendum, pre-inversion-commit)
The v1-manifest FULL-hash recomputation necessarily drifts after the mandated artifact edits. Inverts
to the v2 truth: v1 manifest FILE itself remains byte-preserved (count 15, paths), its listed hashes are
EXPECTED to drift from the edited artifacts (FAILED-candidate history), and the V2 manifest's hashes
must all recompute valid (the live drift check re-anchors to v2).
