# P009A-R1 — EditCadenceContinuityV1
Status: `TESTED`. §6C: a plain CUT arriving within `burstGapMs` (3200) of the previous boundary = edit-burst
continuity (w 0.15). Inputs: time since last boundary, transition mode, shot durations (dwell). Bursts SUPPORT
SAME_ITEM but (a) never override confirmed new-item evidence (veto absolute) and (b) can NOT anchor a merge —
a style-similar DIFFERENT item at burst cadence must not merge (found and fixed during tuning). Long dwell
(≥3800 ms) on the previous shot adds NEW evidence (w 0.15) and demotes a weak theme anchor.
