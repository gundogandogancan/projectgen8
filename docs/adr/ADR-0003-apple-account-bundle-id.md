# ADR-0003 — New Apple ID / Team ID / final bundle id

**Status:** PROPOSED (blocked on user providing new account)
**Date:** 2026-10-18

## Context
The existing Xcode project uses `PRODUCT_BUNDLE_IDENTIFIER = com.aymedo.Gen8` and has **no** `DEVELOPMENT_TEAM` set (automatic signing). The user has stated this is their **old Apple account**, no longer used; a **new Apple ID** will be created later. Codename is `Gen8` (D-0001).

## Problem
We must not hard-code or depend on the old account. On-device runs, capability certification, Family Controls / ScreenCaptureKit entitlements, and App Store/TestFlight all require the final Team ID + a final bundle id.

## Options
1. Keep `com.aymedo.Gen8` temporarily for simulator-only work; change on new account. 
2. Pick a provisional reverse-DNS now (e.g. a placeholder) and migrate later.
3. Block all signing work until the new Apple ID exists.

## Decision (proposed)
Adopt **Option 1** for Phase 0/early Phase 1: simulator-only; keep the template bundle id but treat it as **provisional and non-canonical**. Set the **final bundle id + Team ID when the new Apple ID is ready**, then update signing, entitlements, and this ADR to ACCEPTED.

## Why
Simulator work (the available assets today) does not need a team. Blocking everything is unnecessary; hard-coding the old account is risky. Entitlement-gated capabilities (Family Controls, ScreenCaptureKit background, Live Activities) **require verification against current Apple docs** at that time (Prompt 000 §54) — so the signing decision and capability verification happen together.

## Impact
- Security/Privacy: none now (no device data). 
- Cost: none. 
- Migration: one-time bundle-id/team change + provisioning; no code depends on the id except Info/entitlements.
- Rollback: trivial (change build settings).

## Acceptance tests
- Project builds & runs on simulator without a team (today).
- When new account provided: on-device run succeeds; entitlements provisioned; capability matrix items move from RCOV toward VERIFIED with evidence.

## Open risks
- Entitlement approval timelines (Family Controls / data-portability) are outside our control; track in capability matrix.
