# P009B — Resource / Thermal Results

**Source:** `ResourceGovernorV2` (OctopusRuntimeV2.swift) · tests `testThermalFairDefersOptionalDeep`,
`testThermalSeriousMinimumSafePath`, `testNoDuplicateHeavyExpert`, `testBoundedRuntimeContainers`

## Thermal routing law (implemented + lab-tested)

| Thermal | Behavior (verified) |
|---|---|
| NOMINAL | all permitted experts may run (cheapest-sufficient order) |
| FAIR | optional deep experts (cost ≥ 5, non-safety-critical) DEFERRED (`thermal-deferred:` reasons); safety-critical cheap path continues |
| SERIOUS / CRITICAL | only safety-critical experts with cost < 3 run (temporal, safetyEvidence); everything else deferred; UNKNOWN reasons recorded — the system degrades to honesty, not to silence |

## Cost model (frozen)

symbol=1 · temporal=1 · benefit=1 · attention=1 · music=2 · languageOCR=3 · audioEvent=4 · vision=5 ·
speech=6. Routing executes in ascending cost (`testCheapestSufficientOrderAndCache` asserts cheap
precedes vision).

## Waste controls (verified)

- Cache: confirmed-item evidence cached per (item, domain, modelVersion); second route → HIT, expert not
  re-run. Provisional items NEVER cache.
- Deep dedupe: cost ≥ 5 experts run at most once per (item, domain) even without cache (provisional case).
- Cancellation honored before work; stale-generation results discarded (no wasted attachment).
- Bounded containers: evidence bus ≤ 2048, ledger ≤ 4096, health latency rings ≤ 512, handoff buffers bounded.

## NOT measured (honest)

On-device CPU/GPU/battery/thermal cost of the mesh under real load — requires the §30 user-gated device
session. Lab tests prove the CONTROL LAWS, not the device cost. Dual-evidence rule (D-0016)
device-health side remains OPEN for P009B.
