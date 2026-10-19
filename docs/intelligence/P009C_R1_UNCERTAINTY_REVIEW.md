# P009C-R1 — Uncertainty Combiner Review (audit F-7)

## Audited combiners + changes
- **Episode uncertainty:** was per-record MIN (one confident expert masked nine uncertain ones —
  optimistic). Now `1 − combined strength` (family-law bounded: correlated evidence can't stack).
- **Epistemic axis:** same change (`1 − strength` over available evidence).
- **Modality coverage axis:** OOD readings no longer count as trusted coverage — adding an
  out-of-distribution record can never lower missing-modality uncertainty.
- **Overall:** stays MAX over axes (blocking-uncertainty law).
- Intent-hypothesis uncertainty floor (0.2) and contradiction/identity/language axes unchanged (already
  monotone).

## Property tests (`testUncertaintyMonotonicity`)
Adding (a) an unavailable-modality record, (b) a contradiction, (c) an OOD record, (d) identity
ambiguity NEVER reduces `overall`. Evidence can reduce epistemic uncertainty only through the bounded
family-max law — never via averaging or voting.
