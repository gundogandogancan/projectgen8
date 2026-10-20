# RWC-PRE-07 — ADJUDICATION PROTOCOL

TRIGGERS: adjudication PERMITTED on any A/B disagreement; REQUIRED when |A-B| >= 2 on the ordinal scale,
on ANY safety-dimension disagreement, on any abstain-vs-label split, and on sentinel-class items with a
non-protective label (escalation below).
ADJUDICATOR SEES: the item, frozen profile facts, handbook, A and B labels WITH rationales (only after
both are final). MUST NOT SEE: model outputs, split identity, aggregate stats, other items' outcomes.
OUTCOME: adjudicator records adjudicated label (may equal A, equal B, or be a third value) + rationale.
IMMUTABILITY: A and B originals are NEVER rewritten; adjudication is a third layer (the engineering
precedent: CalibrationAnnotationV1 keeps labelA/labelB/adjudicated separately). Ambiguity is retained:
if the adjudicator also abstains, the item is labeled UNRESOLVED_AMBIGUOUS.
UNUSABLE LAW: an item becomes unusable when (a) rights revoked, (b) UNRESOLVED_AMBIGUOUS on a gating
dimension, (c) technical corruption. Unusable items are excluded by typed status - never silently.
SAFETY ESCALATION: any safety disagreement (one annotator protective, one not) routes to adjudication
AND is logged as a safety-disagreement event for the IRR safety report regardless of resolution.

V2 ADDENDUM (A14-F15): RWC final labels follow RWCAnnotationLawV1 - a disagreement crossing the
protection boundary ({0,1} vs {2,3,4}) is NEVER resolved arithmetically (adjudicationRequired);
same-class disagreements resolve to the MORE PROTECTIVE (lower) value. The legacy engineering
.rounded() midpoint stays engineering-scoped only.
