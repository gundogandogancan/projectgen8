# ADR-0002 — Relocate Xcode app to apps/ios/ and adopt Swift 6 language mode

**Status:** PROPOSED (do NOT execute in Phase 0)
**Date:** 2026-10-18

## Context
The existing default SwiftUI app lives at repo root (`Gen8/` + `Gen8.xcodeproj`). The canonical monorepo (D-0003, CONTAINER_ARCHITECTURE) places the iOS app at `apps/ios/`. The project is set to `SWIFT_VERSION = 5.0` while the toolchain is Swift 6.3.

## Problem
Two deferred reconciliations: (a) physical location of the iOS app vs canonical monorepo; (b) Swift 5 vs Swift 6 language mode (strict concurrency implications).

## Options
- A: Relocate now. (Rejected — Prompt 000 §66 forbids product-code moves in Phase 0.)
- B: Relocate + adopt Swift 6 at the start of Phase 1, before meaningful code exists (cheapest moment).
- C: Never relocate; treat root as `apps/ios`. (Rejected — breaks canonical monorepo consistency for other apps/packages.)

## Decision (proposed)
**Option B.** At the start of Prompt 001 implementation (not Phase 0): move the Xcode project into `apps/ios/`, update the workspace, and evaluate Swift 6 language mode (strict concurrency) adoption. Keep the git history.

## Why
Relocating while the app is still the empty template is near-zero cost and avoids future churn across hundreds of files. Swift 6 strict concurrency is far cheaper to adopt before domain code exists. Both are implementation actions, so they belong to Prompt 001, not Phase 0.

## Impact
- Migration: xcodeproj path + workspace refs; CI paths. Reversible.
- Risk: low (template only).

## Acceptance tests
- After move: `xcodebuild` succeeds for `apps/ios` scheme on simulator.
- Swift 6 mode (if adopted) builds clean or has a documented, scoped exception list.

## Open risks
- Swift 6 strict concurrency may require deliberate actor/Sendable design in domain packages — fold into package design standards.
