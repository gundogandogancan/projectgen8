# P008 — Content Boundary V2
`ContentBoundaryDetectorV2` (§12): verdicts SAME_CONTENT / LIKELY_SAME_CONTENT / NEW_CONTENT / AMBIGUOUS from cheap
signals only — perceptual signature (hamming) + layout/color signature + OCR/text-token persistence + hysteresis.
Rules: layout jump + large perceptual change → NEW; small drift → SAME; persistent text + moderate drift → LIKELY_SAME
(motion WITHIN a Reel, not a new item); large drift + no text overlap → NEW; otherwise AMBIGUOUS (needs a light
embedding — DEEP path only). Heavy analysis starts ONLY on NEW_CONTENT (or policy-approved AMBIGUOUS). `BoundaryBenchmark`
computes false-boundary / missed-boundary rates on labeled sequences (tested: a 2-item sequence does not over-fire).
Honest limit: tuned on synthetic sequences; real Instagram false/missed rates need the user-consented device run.
