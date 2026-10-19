# P009B — HELD-OUT Results (seed 1, run once after freeze)

**Harness:** `P009BExpertMeshTests.testHeldOutCorpus`

```
P009B_HELDOUT failures=0 abstentions=18 contradictions=2
```

- Seed 1 renders all surface text in Turkish (seed-parity law) — the same structural expectations pass
  in TR that passed in EN, using the same frozen TR+EN lexicons.
- failures=0 across all 17 scenarios: evidence-family expectations, forbidden-prefix expectations,
  required contradictions (2/2), and required abstentions all satisfied.
- No policy, threshold, lexicon, or expectation was modified after freeze. The audio-brain fix was made
  on TUNE before this run (see P009B_TUNE_RESULTS.md).

**Interpretation limits:** structural/honesty gates on project-authored derived inputs; not a
real-world perception accuracy claim; no numeric P/R is stated because the corpus is synthetic-derived
and approximate ground truth must never be presented as exact.
