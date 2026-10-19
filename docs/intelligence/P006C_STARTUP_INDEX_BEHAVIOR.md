# P006C — Startup / Index Behavior (truthful)

## Correcting the P006B wording
P006B said "no full reindex per launch." That was imprecise. **The truth:** the Shield index is **rebuilt once per
process start** from the durable rules, and is **incremental thereafter within the session**. The index itself is
**not** persisted — it is always derived from the durable rules (the authoritative store). This section supersedes the
earlier wording.

## Why the index is rebuilt, not persisted
- The durable rules + derived signatures ARE the source of truth. An index is a derived accelerator.
- Rebuilding from rules is **crash-safe**: there is no torn/partial index to detect or repair — a half-written index
  simply cannot exist, because we never trust an on-disk index.
- Rebuild is deterministic (`ShieldIndex.rebuilt(from:)` → identical index for identical rules; tested).

## Bounded, off-main, incremental
- `ShieldStoreManager.loadAndRebuild()` is a plain throwing function (NOT `@MainActor`). The app invokes it on a
  background task at launch. Test `testStartupRunsOffMainActor` builds a 200-rule index entirely on a `Task.detached`
  background executor and asserts completion — proving persistence/index setup does not require the main actor.
- Rebuild is O(total tokens) via per-rule reverse maps (not O(N²)); incremental `upsert`/`remove` are O(tokens-of-rule).
- First usable Shield decision immediately follows rebuild (benchmarked below / in P006C_REFERENCE_DURABILITY_BENCHMARK).

## Measured startup (LAB host, 2026-10-18)
| Rules | cold load + rebuild | first usable decision | warm lookup p50 |
|---|---|---|---|
| 10 | 248 µs | 63.8 µs | 13.71 µs |
| 100 | 853 µs | 23.8 µs | 13.38 µs |
| 1,000 | 7.30 ms | 27.8 µs | 13.29 µs |
| 10,000 | 69.3 ms | 34.9 µs | 13.12 µs |

Cold load is O(N); even the 10k synthetic stress (69 ms) runs off-main so the UI is never blocked. Real rule sets are
far smaller. LAB host numbers — not device-certified (device gate `PENDING_EXTERNAL_DEPENDENCY`).

## Guarantee
We will not claim "no reindex per launch." We DO claim: **one bounded, deterministic, off-main rebuild per launch; no
main-thread block; incremental updates within the session; no persisted/trusted on-disk index.**
