# P006 — Catastrophe & Degraded-Mode Matrix

**Doc status:** `CANONICAL` · **Phase:** 6 · **Date:** 2026-10-18 · PROMPT 006 §29, §30. **NEVER fail open as "safe". Never stale green.** Allowed safe states: UNKNOWN · CAUTION · HOLD(strict) · capability-limited.

| Scenario | Detection | Safe state | User-visible | Telemetry | Recovery/Rollback |
|---|---|---|---|---|---|
| No network | reachability/offline | local-only; cloud OFF (already default) | normal | offline flag | auto on return |
| Apple service unavailable | API error | degrade head → UNAVAILABLE | unchanged | provider-fail | retry/backoff |
| Shazam unavailable | adapter | UNAVAILABLE (honest) | no music id | flag | n/a |
| Speech asset missing | adapter | transcription UNAVAILABLE | no transcript | flag | explicit asset install later |
| Unsupported language | LanguageRegistry UNASSESSED | BASIC_SIGNAL_ONLY/UNKNOWN; no certified threshold | caution | locale | certify later |
| Corrupted / checksum-mismatch model | `ModelPackManifest.verify` | reject → fallback engine | unchanged | incident | rollback artifact |
| Poisoned / stale cache | version/TTL mismatch | invalidate → recompute | unchanged | cache-fail | rebuild |
| Wrong identity candidate / alternate cut | I0–I4 gate / version mismatch | **refuse auto-skip** → WARN/UNKNOWN | caution | alignment-fail | re-identify |
| Corrupt media | decode error | `.unreadable` → coverage UNKNOWN 100% | unknown | media-fail | skip asset |
| 4K/8K / 10-hour video | complexity class | coarse-first bounded sampling | normal | budget | deepen selectively |
| Rapid swipe burst | scheduler | cancel stale; bounded tasks | result-ready | cancellations | — |
| Live stream | live mode | rolling + coverage-lag/unknown-ahead | caution | lag | — |
| Memory pressure | OS signal | shrink cache/lookahead/sampling | unchanged | pressure | reclaim |
| Low power / thermal serious-critical | ProcessInfo | ECO degrade; defer deep | battery-saver | thermal | resume on normal |
| OS suspends / process killed | lifecycle | activation state persists (store); re-establish coverage truthfully | unchanged | lifecycle | relaunch-safe |
| Control Center state stale | reload | re-read single source of truth | correct toggle | — | reload |
| Extension crash | — | in-app toggle fallback | unchanged | crash | restart |
| Permission revoked | permission check | PAUSE; explain | permission needed | perm | request/fallback |
| Entitlement unavailable | check | restrictedByCapability | limited | entitlement | — |
| Classifier disagreement | council | conflict→lower confidence | caution | disagreement | deepen |
| Adversarial OCR / silent/noisy audio / code-switching | heads | abstain→UNKNOWN | caution | adversarial | — |
| Model rollback required | sentinel | QUARANTINE→FALLBACK→ROLLBACK | unchanged | incident | rollback |
| Data deletion/takedown | request | propagate; invalidate DNA | — | audit | delete |
