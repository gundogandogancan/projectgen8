# P008 — Multimodal Adversarial Eval (§29)
No single modality gets unconditional authority except explicit safety/policy floors.
Representation/handling (contract + tests):
- meme (benign image topic + harmful text topic) → cross-modal CONFLICT recorded + both penalized (not averaged).
- harmful image + benign caption → conflict; safety/Shield precedence can still force protection band.
- music-only / symbol-only / silent clip → few modalities → low coverage → score UNKNOWN (no fabricated number).
- sarcasm / euphemism / coded language → weak-signal evidence class; never promoted to high confidence without corroboration.
- late text overlay, audio-contradicts-subtitle → cross-modal conflict + temporal alignment.
- rapid swipe / same-video-motion-as-new / comments overlay / autoplay / ad transition → ContentBoundaryV2 distinguishes
  (SAME/LIKELY_SAME/NEW/AMBIGUOUS) so motion is not mistaken for a new item.
Proven at the evidence-graph/score/boundary level with synthetic fixtures (P008CoreTests). Full real-content adversarial
scoring awaits the rights-clear calibration dataset + the user-consented device run (not fabricated here).
