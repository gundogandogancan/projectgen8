# P009A-R1 — DeferredItemCoalescerV1
Status: `TESTED`. §11: an initially-AMBIGUOUS internal cut may merge LATER when subsequent evidence strongly
supports continuity. Requirements enforced: CONTENT anchor mandatory (theme ≤0.22 AND projection ≥0.80 for
≥2 supporting shots — style alone never merges, same rule as the live path); provisional items opened by a
strong-new cue are never coalesced; versioned MERGED revision; DNA invalidated/rebuilt on merge; bounded history
(≤6 recent shots per side); no admission inheritance before confirmation. SANDWICH repair: an outlier provisional
between two runs of the same item chain-merges (cur → prev → prev-prev) only when the far match is content-anchored
and the intermediate is also provisional/non-strong-new. Never forced to hit count targets (§10).
