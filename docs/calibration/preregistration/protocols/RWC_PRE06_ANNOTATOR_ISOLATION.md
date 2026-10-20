# RWC-PRE-06 — ANNOTATOR ISOLATION PROTOCOL (design only; zero annotators recruited)

Roles: Annotator A, Annotator B (every item), Adjudicator (triggered items; NEVER A or B of that item).
BLINDNESS MATRIX (MUST NOT see): A<->B labels; A<->B rationales; any model prediction/score/evidence
output; adjudicated label (until their own work is final); split identity (TRAIN/CAL/HELDOUT/SENTINEL -
sentinels are indistinguishable by law); item provenance beyond the rights-cleared viewing surface;
aggregate statistics during an open batch; each other's identity where operationally avoidable.
ALLOWED CONTEXT: the item itself (rights-cleared), frozen profile facts (age band, Shield list), the
frozen handbook v1, nothing else.
ASSIGNMENT: deterministic seeded randomization over annotator pool per batch; A/B pairs balanced per
slice; adjudicator drawn from remaining pool; assignment log is append-only.
LEAKAGE CONTROLS: separate workspaces; no shared chat during open batches; label store write-only for
annotators; rationale fields free-text but PII-forbidden; tooling shows ONE item at a time without
neighboring-item context.
ABSTENTION: first-class per handbook D-15; never penalized; no quotas.
CONFLICT LOGGING: every A/B disagreement persisted verbatim (labels+rationales) BEFORE adjudication.
IDENTITY/PRIVACY: annotators referenced by opaque operational IDs (ann-xx); contracting PII lives
OUTSIDE the repo; no annotator PII ever enters artifacts.
