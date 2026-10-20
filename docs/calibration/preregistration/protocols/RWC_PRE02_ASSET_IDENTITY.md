# RWC-PRE-02 — OPAQUE ASSET-ID CONTRACT (closes BLK-A11-IDCHARSET + BLK-A11-COMPOSITE-ALIAS)

Canonical grammar (code twin `RWCAssetIdentityV1.swift`):
- Asset ID: `rwc-asset-` + [a-z0-9]{8,32}. Profile ID: [a-z0-9-]{3,40}, no edge/double dash.
- ASCII-only, byte-validated; NO normalization ever (canonical-input law): NFC/NFD variants,
  Cyrillic/Latin lookalikes, uppercase, space/tab/NEWLINE (the A11-IDCHARSET hole), control chars,
  over/underlength, empty -> TYPED refusals. A repairing validator is an aliasing machine - forbidden.
- Separator law: `#` FORBIDDEN inside every component (chosen over escaping: simpler, safer). A
  composite therefore contains exactly one `#`; parse-compose is the identity; the A11-COMPOSITE-ALIAS
  class is structurally impossible.
- Case law: lowercase-only grammar; byte-exact comparison. Serialization: validated ASCII verbatim.
- Duplicates/same-count substitution remain governed by CalibrationRunGuardV1 v2 exact-identity law.
- Errors carry index/class only; never echo raw junk bytes.
Legacy note: the 59 engineering-pair IDs stay engineering-scoped; REAL corpus assets must use this
grammar from the first registration (rights ledger validates it).
