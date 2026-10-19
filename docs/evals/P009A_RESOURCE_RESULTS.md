# P009A — Resource Results

Status: lab `TESTED` · device `CAPTURED` (fresh item-group run 2026-10-19) — resource PASS, grouping economy FAIL.

## CAPTURED device telemetry (P009A_AFTER_crossapp_device_itemgroup.log)
| field | V5 ref | P009A observed | verdict |
|-------|-------:|---------------:|:------:|
| cheap path p50 / p95 (ms) | 1.338 / 2.748 | **1.294 / 2.856** | bounded (grouping adds ~nothing per frame) |
| downstream firstTrustworthyMs p50 / p95 | — | 0.076 / 0.142 | cheap |
| peak memory (MB) | 30.0 | **30.3** (24.4–30.3, no growth) | under ~40 ✓ |
| thermal | nominal | **fair 45/73, nominal 28/73** — first non-nominal run; no serious/critical | acceptable |
| shots / items / analyses / reuse | 57 shots→57 analyses | **73 / 73 / 73 / 0** | §26 economy FAIL (no merges fired — see DEVICE_VALIDATION root cause) |
| session survival | yes | **yes** (1 start / 1 finish, app-switch survived) | PASS |

## The economy change (§26 goal: many shot events collapse into fewer item analyses)
Before P009A the extension invoked downstream analysis per committed SEGMENT (V5 device run: 57 analyses). Now
analysis runs ONCE PER ITEM (`decision.openedNewItem`); same-item shots are cheap reuse (`stats.cacheReuse`,
governor cache-hit). Expected on-device effect: analyses ≈ item count (~20-ish), not shot count (~57) — to be
measured on the fresh run, not asserted.

## Bounded-by-construction (lab-proven)
- Grouping per shot boundary: O(recent-shots≤6) signature distances + fixed evidence arithmetic — runs only on shot
  commits (~1/1.6 s on device), not per frame. Per-frame cost unchanged from V5 (p50/p95 1.338/2.748 ms ref).
- `HierarchicalTemporalGraphV1`: ≤ maxActiveShots nodes; history compacts into summaries (`testBoundedGraphMemory`).
- `ContentIdentityEvidenceGraphV1`: ≤ maxEdges (tested). `ContentIdentityCacheV1`: ≤ maxEntries, FIFO eviction.
- `ResourceGovernorV1`: counts shots/items/deep-escalations/cache-hits; DEDUPES deep inference per (item, domain)
  (`testResourceGovernorDedupesDeepInference`) — no new universally-running expensive layer was added.

## Device telemetry to capture on the fresh run
`BROADCAST_FINISHED frames … shots=<n> items=<m> cheapP50ms … cheapP95ms … peakMemoryMB … thermal …` + per-decision
`ITEM … firstTrustworthyMs … memoryMB …` + signposts `frame`/`segment`/`itemgroup` (Instruments). V5 refs: cheap
1.338/2.748 ms, peak 30.0 MB, thermal nominal. NOT INSTRUMENTED (honest): queue depth, dropped samples, CPU/energy
xctrace (only if actually captured).

## §29 base-shell footprint (measured 2026-10-19, Debug)
App bundle 18 MB total (Debug incl. 6.9 MB debug dylib) · main executable 92 KB · two extensions 5.2 + 5.3 MB ·
embedded model/data assets **0**. See P009A_THIN_APP_INTELLIGENCE_PACKS for budgets doctrine.
