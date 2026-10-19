# P007 — Soak Test

## Level: LAB LOGIC SOAK (headless). Device energy/thermal soak = NOT_MEASURED (no provisioned device).

Test: `P007SoakTests.testSoakReturnsToBaseline` — 5,000 simulated swipes with cache hits/misses, Shield evaluation,
Guardian ON/OFF churn (toggled every 500 iterations), periodic memory-pressure (`unloadUnderPressure` every 1,000),
Live Activity update decisions, and task/media lifecycle accounting.

## Watched quantities → result
| Watch | Result |
|-------|--------|
| Task accounting | started 5,000; completed+cancelled = 5,000 (every task accounted) |
| Active tasks after churn | **0** (drained to baseline) |
| Retained media objects | **0** (no leak) |
| Model cold-loads | **< 20** over 5,000 iterations (warm reuse + a few pressure reloads — NOT one per item) |
| Shield index growth | **0** (stayed at 50 rules — no stale-candidate accumulation) |
| Live Activity updates | accepted **< requested** (debounce/no-change suppression working — no spam) |
| Guardian OFF | no Shield/surface work performed while off |

`TaskLedger.isAtBaseline == true` after the run. This proves the **logic** has no unbounded task/media/index/cache
growth under sustained churn.

## What this does NOT prove
It does not prove device-level memory high-water, thermal rise, or energy over a 30–60 minute real session — that is a
device measurement (`NOT_MEASURED`, pending signing). The LAB soak is a necessary-not-sufficient gate.
