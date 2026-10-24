# RWC RIGHTS REVIEW CHECKLIST V1 (LANE A)

Ungoverned operational doc (`docs/operations/rwc/`). Mandate §6 / deliverable **D**. An ENFORCEABLE
checklist for the legal/rights source of real content. This is an operational checklist, **NOT legal
advice**; items marked **[LEGAL REVIEW]** require review by a qualified person before real activity.

## 0. Hard rule (CLAUDE.md immutable rule 16/17; mandate §6)

GEN8 NEVER accepts real content as training/calibration data merely because it exists on the internet.
Every asset needs a verified, signed rights review bound into the ledger. License ≠ lawful basis for
personal-data processing; an asset being usable does NOT mean every person's personal data in it may be
processed without limit.

## 1. Per-asset required bindings (each must be present + verified before acceptance)

| # | Field | Verification |
|---|---|---|
| 1 | Source identity | `rwc-source-ref-*` grammar; traceable to a real origin |
| 2 | Rights holder | named; matches the grant's `rightsHolder` |
| 3 | License / usage authority | explicit license or authorization document on file |
| 4 | Permitted use | `allowedUse` (training / evaluation) matches intended use |
| 5 | Prohibited use | `prohibitedUse` enumerated; intended use ∉ prohibited |
| 6 | Geographic / temporal limits | recorded; grant `effectiveDate`/`expiryDate` respected |
| 7 | Required attribution | recorded; downstream display obligation captured |
| 8 | Original source reference | provenance chain non-empty, duplicate-free |
| 9 | Content integrity | `contentHash` (SHA-256) bound; `trustedExpectedChecksum` matches if supplied |
| 10 | Reviewer decision | `APPROVED` in a signed `RWCSignedRightsReviewV1` |
| 11 | Digital signature | verifies against the reviewer's registered key (scope `rwc-corpus`, ACTIVE) |
| 12 | Revocation status | asset not tombstoned; reviewer not revoked in the current registry head |
| 13 | Privacy / personal-data assessment | **[LEGAL REVIEW]** lawful basis recorded SEPARATELY from license |

## 2. Privacy & personal data (mandate §6 — recorded, not decided here)

- A license covering the content does NOT by itself provide a lawful basis to process the **personal data**
  of people appearing in the content. These are separate legal questions.
- **[LEGAL REVIEW]** For each target market, record the applicable framework and the lawful basis:
  - **Turkey:** KVKK (6698) — lawful basis, explicit consent where required, special-category data rules.
  - **EU/EEA:** GDPR — lawful basis (Art. 6), special categories (Art. 9), data-subject rights, DPIA where
    high-risk.
  - **Other target markets:** recorded per market as scope expands.
- These items are CAPTURED as checklist obligations with a status; GEN8 does not assert legal conclusions
  here. No real personal data is processed until the lawful-basis items are closed by qualified review.

## 3. How the checklist is enforced in code (already present, AUDIT21-PASS)

- The grant chain (`RWCVerifiedRightsGrantV6`) binds grant ID, revision, review record, reviewer, source
  authorization, registry digest, root.
- `RWCPreAcquisitionEvaluatorV3.authorize` enforces source membership (manifest canonicality law),
  intended-use ∈ allowed ∧ ∉ prohibited, temporal validity, owner, checksum shape — BEFORE any byte moves.
- `authorizeAcquisitionV2` re-checks intended-use + current reviewer authority at commit time (A20-F3/F4).
- Items 1–12 are machine-enforced. **Item 13 (privacy/personal-data) is a human [LEGAL REVIEW] gate** — it
  is NOT yet a machine law and MUST be closed operationally before real acceptance.

## 4. Governance record template

See `RWC_GOVERNANCE_RECORD_TEMPLATE_V1.json` (a template with placeholder values; NOT a real record).
