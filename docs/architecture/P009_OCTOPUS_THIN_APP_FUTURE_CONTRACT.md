# P009 — OCTOPUS / THIN-APP Future Contract (DOCUMENT ONLY — not implemented)

Status: `CANONICAL DOCTRINE` for the next milestone. Nothing here is built in P008A-R4. Records §24/§25 so the
sensor-layer closeout hands a clear brain-layer contract to P009.

## §24 — THIN SHELL + GROWING INTELLIGENCE MESH
The main app stays small. Future intelligence specialists are modular, versioned, capability-routed PACKS, NOT all
in the base bundle:
Vision · OCR/Language · Speech · Audio · Music · Symbol · Temporal · Safety · Child Age · Personalization ·
Calibration · Observation · Motion/Surface (the R1–R4 content segmenter is the first "Motion/Surface" sensor pack).

Model/data/policy packs must be: signed · versioned · checksum-verified · on-demand · delta-updatable ·
cache-evictable · rollbackable · device-capability aware. Large models/datasets/assets must NOT live in the base bundle.

## §25 — NETWORK INTELLIGENCE FLYWHEEL (every user improves Gen8, private by default)
**LOCAL** — the user's Personal Brain improves from ContentDNA/cache, explicit corrections, preferences, Shield
rules, and (if enabled) local history — WITHOUT raw private content leaving the device by default.

**GLOBAL** — global intelligence may improve only from privacy-preserving DERIVED telemetry, opt-in correction
labels, aggregate FP/FN signals, latency/resource metrics, rights-clear evaluation data, and federated/secure
aggregation where appropriate. **Raw private cross-app media is NOT silently centralized for training.**

Production models/policies never self-modify uncontrolled. Every global update requires:
`offline eval → shadow → canary → calibration → safety/privacy/resource gate → signed release → rollback`.

## Handoff note
The content-segmentation sensor (ContentSegmenterV1–V5, `boundary-policy-v5`) is the "eye." P009 builds the "brain"
on top of it as the first capability-routed pack family. Precedence: LEGAL/SECURITY > CHILD SAFETY > … (ADR-0007)
remains binding. `ChildAgePolicyEngine` stays a future contract (parent-entered age only; never inferred from face/image).
This belongs to P009 architecture — do NOT implement here.
