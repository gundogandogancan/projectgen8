# P009C-R1 — World-Model Cache Purity (F-5 closeout)

`WorldModelEvidencePurityGateV1` — the cache-side mirror of the DNA finalizer's foreign-evidence law.
Checked on WRITE (reject + counted) and re-checked on READ (invalidate, never serve):
- evidence item IDs ⊆ claimed item; evidence generations ⊆ model generation
- no provisional-marked evidence; identity confirmed
- world-model + taxonomy version compatibility
(existing bindings — identityRevision, generation match, TTL, collision reports, split invalidation —
unchanged). Status correction (audit F-5/doc truth): the cache now HAS a purity gate; it remains
production-unwired (no production writer exists — consumer is DEBUG HUD/lab), stated as-is.
