# P009A — TUNE Results (grouping policy selection)

Status: `TESTED`. Set: `HierarchicalCorpusV1.corpus(seed:0)` ONLY. Source: `testTuneScanExploratory`.

## Candidate scan (recorded)
| candidate | newP | newR | F1 | mergeP | mergeR | xMerge/item | ambiguous |
|-----------|-----:|-----:|---:|-------:|-------:|------------:|----------:|
| default (confirmSame 0.42) | 1.000 | 0.944 | 0.971 | 0.985 | 1.000 | 0.0238 | 0 |
| A (margin 0.10) | 1.000 | 0.944 | 0.971 | 0.985 | 1.000 | 0.0238 | 0 |
| **B strictMerge (confirmSame 0.50) — FROZEN** | 1.000 | 0.944 | 0.971 | **1.000** | 0.970 | **0.0000** | 3 |
| C looseNew | 1.000 | 0.944 | 0.971 | 0.985 | 1.000 | 0.0238 | 0 |

## Selection rationale (§7/§20)
The default/A/C candidates all carry ONE false cross-item merge (0.0238/item — would FAIL the §20 ≤0.01 safety gate):
the deliberately-ambiguous no-caption/no-audio/similar-theme boundary merges across items. Candidate **B** raises the
merge bar so that case returns **AMBIGUOUS (provisional split)** instead — exactly the §7-canonical behavior
("prefer split/UNKNOWN over unsafe merge"; false split = compute waste, false merge = safety error). Cost: merge
recall 1.000→0.970 and 3 AMBIGUOUS events, all in the designed-ambiguous slice. B frozen as
`item-grouping-policy-v1` (`confirmNewThreshold 0.42 · confirmSameThreshold 0.50 · decisionMargin 0.12`).

The only unresolved TUNE miss: the ambiguous-identity slice's true boundary is not CONFIRMED-new (it is AMBIGUOUS) —
the labeled-acceptable outcome for scenario 24. No held-out/stress label was inspected during tuning.
