# P009B — Device Validation Status

**Date:** 2026-10-19 · **Device:** iPhone 14 Pro Max, iOS 26.6 (devicectl C7C6CE6E…, team 47XQMQZLF6)

## Completed (evidence exists)

- Debug build of the Gen8 app WITH `GuardianIntelligenceHUD` (P009B §25) + the full GuardianKit mesh:
  `xcodebuild … -destination 'id=00008120-001A51141A9B401E' build` → **BUILD SUCCEEDED**.
- Installed on the physical device via `devicectl device install app` →
  `installationURL: …/Gen8.app/` (databaseSequenceNumber 2912).
- The HUD is mounted in GuardianLab behind Developer Mode AND `#if DEBUG` — it runs REAL corpus
  scenarios through a live `GuardianMetaBrainV2` (all 10 arms registered), so in-app routing proof is
  one tap away.

## NOT completed (honest status — §30 is user-gated)

- **In-app HUD visual proof run:** requires the user to open GuardianLab → Developer Mode → P009B HUD
  and exercise scenarios on device. NOT_MEASURED yet.
- **Owned/rights-clear real media runs** (user screen content through the broadcast path with mesh
  observation): user-gated; no raw media may be synthesized or scraped by the agent to fake this.
- Consequently: `EXPERT_MESH DEVICE-OPERATIONAL` is **UNVERIFIED**. The device evidence so far proves
  build+install only. This stays an open item in §31 of the final report and may not disappear.

## What would close it

One on-device session: HUD screenshot(s) showing scenario routing (expert statuses, contradictions,
UNKNOWN reasons, cache hits) + optionally one owned-media broadcast run. No retuning allowed from the
results — observe, record, report.
