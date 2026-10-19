# P009A-R1 — Tier-0 Fixture Manifest
Status: `TESTED`. Source: `Tier0CorpusV1.swift`. Rights: 100% project-generated descriptor streams; nothing
reconstructable; NO captions/speech/audio/app-identity/cloud labels (§4 — exactly the extension's evidence).
REALISM MODEL (the P009A fix): STYLE (histogram/projections/edges = color grade + layout) is DECOUPLED from CONTENT
(center/global signatures). Internal cuts change content but keep style+chrome+cadence; different items change both.
24 §4 scenarios: internal-cut-same, talkinghead-broll, montage, slideshow, music-video, sport-internal-cuts,
pan-then-new, same-theme-internal, same-template-swipe, visually-similar-cut (AMBIGUOUS_OK), cut-presenting-new,
rapid-swipes, slow-swipe, crossfade-new, persistent-chrome, overlay-within, repeated-item, app-surface,
long-dwell-cuts, short-dwell-new, low-motion-internal, bright-to-bright (AMBIGUOUS_OK), dark-to-dark (AMBIGUOUS_OK),
ambiguous-identity (AMBIGUOUS_OK). Labels: ShotID, ItemID, same/new relation, transition mode, **expected SAFE
decision** (NEW / SAME / AMBIGUOUS_OK). STRESS adds 24-cut montage + 8 rapid items.
Splits (no leakage): TUNE seed:0 · HELD-OUT seed:1 · STRESS seed:2 · DEVICE-LIKE (separate generator, seed:3).
Expectation-aware recall: AMBIGUOUS_OK boundaries are excluded from the recall denominator (AMBIGUOUS is their
labeled-correct outcome) but ALWAYS count for precision and false-merge; raw recall is also reported.
