# GEN8 — INDEPENDENT P009B-R1 RE-AUDIT

**RECOMMENDED MODEL:** Claude Fable
**SESSION:** NEW CLEAN SESSION
**MODE:** READ-ONLY FIRST
**EFFORT:** High / maximum practical reasoning

Prior verdict: `FIX CRITICAL P009B FINDINGS`.

Independently verify that F1/F2/F5/F6/F7 and all additional integrity gaps were truly closed.

## Mandatory checks

1. Re-run all original AUDIT3 probes unchanged.
2. F1: transient unavailable can retry; permanent unavailable bounded; cancel/stale retry; meaningful result dedupes.
3. F2: canonicalize/hash all splits; check exact duplicate, near-template leakage, seed aliasing, translation-only held-out, calibration contamination.
4. F5: classify every expert from actual wiring/evidence:
   - REAL_RUNTIME_DEVICE_PROVEN
   - REAL_RUNTIME_NOT_DEVICE_PROVEN
   - REAL_IN_PROCESS_LAB_ONLY
   - CONTRACT_ONLY
   - UNAVAILABLE
5. Trace at least one real path:
   real provider → adapter → ExpertInput → expert → MetaBrain → graph → ContentUnderstandingState.
   If no real path exists, P009B cannot lock as a real expert mesh.
6. F6 cache probes: stale generation, identity revision mismatch, split, collision, model/schema mismatch, TTL expiry, session reset.
7. F7 DNA probes: spoofed confirmed flag, stale snapshot, split-pending identity, malformed revision, provisional evidence.
8. Fuzz ExpertInput with NaN/∞, extreme density, invalid confidence, negative duration, malformed locale, oversized arrays, timestamp disorder.
9. Verify latency values are monotonic measurements; no-sample HUD state is NOT_MEASURED.
10. Verify deadline affects scheduling and late-result handling.
11. Verify complete asset ledger; no invented licensing/provenance.
12. Verify missing corpus families exist and are split-independent.
13. Verify docs/counts/availability labels match code.
14. If device proof is claimed, verify artifact/log/screenshot proves REAL input rather than corpus replay.
15. Verify P009A artifacts unchanged, C6 still passing, score/glyph OFF, H1/child honest, no network/raw persistence, release evidence logging OFF.

## Fresh auditor probes

At minimum:
- unavailable→available provider
- stale cache same item ID
- DNA mint spoof
- NaN editDensity
- deadline race
- HUD real-vs-synthetic mislabel attempt
- corpus near-duplicate detector
- duplicate heavy expert scheduling
- malformed provenance
- FAIR thermal + deadline pressure

## Final report

1. AUDITOR SESSION
2. REPO / BUILD INTEGRITY
3. ORIGINAL PROBE REGRESSION
4. F1 VERDICT
5. F2 VERDICT
6. F5 EXPERT REALITY MATRIX
7. REAL RUNTIME TRACE
8. F6 CACHE VERDICT
9. F7 DNA VERDICT
10. INPUT SANITIZATION
11. LATENCY / DEADLINE
12. ASSET AUDIT
13. CORPUS / SPLIT METHODOLOGY
14. DEVICE / HUD EVIDENCE
15. PRIVACY / RESOURCE
16. P009A REGRESSION
17. AUDITOR FRESH PROBES
18. OPEN LIMITATIONS
19. VERIFIED PROGRESS
20. GO / NO-GO

Final verdict exactly one:
`PASS — P009B MULTIMODAL EXPERT MESH LOCKED; GO TO P009C`
`FIX CRITICAL P009B-R1 FINDINGS`
`BLOCKED`

Then STOP.
Do not implement P009C in the audit session.
