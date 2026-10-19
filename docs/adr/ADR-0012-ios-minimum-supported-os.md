# ADR-0012 — iOS minimum supported OS

**Status:** PROPOSED (do NOT change deployment target until reviewer accepts — PROMPT 002 §2)
**Date:** 2026-10-18

## Context
The Xcode project has a **provisional** `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (created by the Xcode template on the latest installed SDK). "Latest installed SDK" must NOT be assumed to be the minimum supported OS — that would exclude most real devices.

## Problem
Choose a minimum iOS version that balances (a) device coverage, (b) availability of the frameworks P0 needs, (c) conditional-availability cost.

## Framework availability (RCOV — verify current official Apple docs at implementation time)
| Capability | Known availability (RCOV) | Notes |
|---|---|---|
| SwiftUI + Observation (`@Observable`) | iOS 17+ | our UI baseline |
| ActivityKit Live Activities | iOS 16.1+ | Dynamic Island iPhone 14 Pro+ hardware |
| Vision text recognition (`VNRecognizeTextRequest`) | long-available; newer APIs iOS 18+ | OCR |
| NaturalLanguage (embeddings/lang-ID) | iOS 13+ (embeddings 14+) | text features |
| Speech recognition | iOS 13+ (on-device varies) | permissioned |
| SoundAnalysis | iOS 15+ | optional |
| Core ML | iOS 11+; newer compute units later | model runtime |
| `ProcessInfo.thermalState` / `isLowPowerModeEnabled` | long-available | ResourceGovernor |

## Options
1. **iOS 17** — `@Observable` + modern SwiftUI/concurrency with wide device coverage.
2. iOS 18 — newest Vision/CoreML niceties, smaller coverage.
3. Keep 26.5 — excludes nearly all real devices (template default) — rejected.

## Decision (proposed)
Adopt **iOS 17 minimum** as the P0 baseline (gives Observation + modern SwiftUI + the needed ML frameworks with good coverage); gate newer APIs with `if #available`. **Not changing the target now** (current 26.5 does not block Prompt 002 from compiling on the simulator). Reviewer accepts before the change lands.

## Why
iOS 17 is the floor for `@Observable` (already used). Vision/NaturalLanguage/CoreML/thermal APIs all predate 17. Dynamic Island remains hardware-gated (iPhone 14 Pro+) and surface-adapter-optional (Pure Bar default).

## Impact / rollback
Changing the target is a one-line build-setting change (reversible). Conditional availability shims isolate newer APIs. No code depends on 26.5 specifically.

## Acceptance tests
- App builds at the chosen minimum on the oldest supported simulator.
- All `if #available` gates compile and have honest fallbacks.
- Capability matrix updated with per-API minimum OS + `last_verified`.

## Open risks
Exact newer-API minimums are RCOV until checked against current Apple docs at implementation time.
