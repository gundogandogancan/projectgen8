# GEN8 OPEN BLOCKERS (GENERATED VIEW)

> GENERATED_VIEW. The AUTHORITATIVE blocker ledger stays `docs/audit/GEN8_OPEN_BLOCKERS.md`
> (AUDIT_EVIDENCE — never edited by the twin). The twin's `blockers[]` registry adds CURRENCY notes;
> this view is the merged read. Staleness is FLAGGED here, never silently closed (FM-014).

| ID | Sev | Title | Status / currency |
|---|---|---|---|
| BLK-B1 | B | Per-channel Tier-0 telemetry missing | OPEN |
| BLK-B2 | B | Root-cause attribution inference-not-measured | OPEN (gated on B1) |
| BLK-C1 | C | Always-on derived proof logs in production paths | OPEN |
| BLK-C2 | C | App Group broken / silently faked | OPEN |
| BLK-C3 | C | Extension shield evaluation vacuous | OPEN |
| BLK-C4 | C | Calibrated trustworthy score NOT achieved | OPEN **BY_DESIGN** until RWC passes (code gate enforces) |
| BLK-C5 | C | H1 visual honest stub; child policy production wiring pending | OPEN (lab engine exists since P009D) |
| BLK-C6 | C | Tier-0 stress false-merge | OPEN_CONTAINED (load-bearing probe pins it) |
| BLK-H1 | H | "Git anchoring absent" | **STALE_LEDGER** — contradicted by pushed history (origin through `e983b36`); needs explicit ledger resolution record |
| BLK-H2 | H | Gate-softening debt in test suite | OPEN |
| BLK-H3 | H | TrainingRunTests mutates working tree | OPEN |
| BLK-H4 | H | No CPU/energy device artifact | OPEN |
| BLK-H5 | H | Stale env facts in CLAUDE.md | OPEN |
| BLK-ECE-UNMET | GATE | ECE .250 vs .05 | OPEN, UNRELAXED (gate freeze pending RWC-PRE-09/11) |
| BLK-DEVICE-RWC-OPEN | GATE | Device runtime proof of score path | OPEN |
| BLK-A10-F1-COVERAGE | LIM | Violence detection NOT validated (cue-gated) | CARRIED |
| BLK-A10-F1-FALSETRIGGER | INFO | Benign-cue teen over-restriction | CARRIED |
| BLK-A11-IDCHARSET | LOW | Newline-only ID passes malformed law | OPEN → RWC-PRE-02 |
| BLK-A11-COMPOSITE-ALIAS | INFO | Unescaped `#` in composite IDs | OPEN → RWC-PRE-02 |
| BLK-A11-LEGACY-P008 | LOW | P008 pilot calibration path gate-free | OPEN → RWC-PRE-03 |
| BLK-A11-APIBYPASS | SCOPE | Direct fit APIs callable without gate | OPEN → RWC-PRE-04 (release-blocking at prereg) |
| BLK-GH-CREDENTIALS | OPS | gh PR API credentials invalid | OPEN (SSH push works) |
