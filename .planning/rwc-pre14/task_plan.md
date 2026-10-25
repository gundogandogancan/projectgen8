# RWC PRE-14 — persistent working memory (planning-with-files)
# Untracked local planning state; NOT methodology surface; never committed.

## CURRENT STATE (update every milestone)
- Round: R5 COMPLETE pending final tag (run2 in flight). Chain: 6c78671 disc -> 8134643 rightsV5 -> 119ad0b receipt+runnerV3 -> 6674fea verifierV5 -> docsV6 -> 8597f98 anchor(superseded) -> d5aa050 manifest(superseded) -> b4b4965 report -> 9a253a1 ADDENDUM1 -> 31267a4e INVERSION I-1 = FINAL ANCHOR -> manifest regen (digest 4cc1a7f3) -> report update. Run1 1072/1072 GREEN.
- Fable review gate finding (resolved): makeSyntheticTestRoot public->internal. Late lawful inversion I-1: AUDIT18 test_A18_46 topology guard HEAD->ac91974 (addendum-first discipline).
- SPEED: after tag, measure `swift test --parallel` once; if green+stable, bake into AUDIT19 brief (suite 8min -> ~2-3min).
- HEAD at R5 start: ac91974 (AUDIT18 commit). R5 discipline commit: 6c78671.
- Baseline measured: 1061 tests, EXACTLY 1 lawful failure (R4Tests:678 obsolete absence-pin; pre-declared).
- Opus contractor (agent a44702a1e3f83256d) building: RWCRightsV5 (trust root/registry doc V2/authority V3/scope), ReceiptStoreV1, RunnerV3, VerifierV5, gates V6, schemas V3/V4, onboarding law, generator v6, R5 tests, 2 declared R4Tests edits, master r5 keys.
- NEXT after Opus report: Fable §84 delta review -> commits per §83 (groups 2-5) -> R5 tests commit = ANCHOR V6 -> generator v6 -> manifest commit -> R5 report commit -> suite x2 -> tag gen8-rwc-preregistration-r5-audit-candidate -> push -> §87 return -> STOP. Then AUDIT19 (clean session, FOREGROUND-ONLY law, relay verbatim, commit staged as ONE audit commit).

## INVARIANTS (never violate)
- Frozen: ALL v1..v5 freeze inventories; V5 manifest live==R4-candidate-blob (AUDIT18 probe); Package.swift (V5-frozen).
- Only editable existing files: RWCPreregistrationR4Tests.swift (2 declared changes), master manifest (NEW keys only; pins: candidate_generation R1, r2 R2, r3/r4 BUILDER_COMPLETE, PreparedCalibrationDatasetV2, A14-F6, zeros, visibility false).
- Never create: RWC_PRE14_R5_AUDIT_RESULT.json (AUDIT19 only), RWC_PRE14_PASS_LOCK.yaml, AUDIT* files in Sources, production root/reviewer keys.
- Session grammar rwc-acq-[a-z0-9]{16,64}. RWCAcquisition files in #if os(macOS).
- Audit discipline: auditor sandbox denies git commit -> main session commits staged verbatim as ONE audit commit; machine result path R5 = docs/audit/RWC_PRE14_R5_AUDIT_RESULT.json.

## KEY IDENTITIES
- Governing lock: 2c345b64c720f965b68ec5ee699e1b71fecf0003 (tag gen8-ulu-evren-control-plane-r1-locked-governing)
- R4: candidate 2067830, tag obj 30aa63e, anchor f9c10ff0; AUDIT18 result 0/2/2 (sha 47358f2a... locked copy).
- AUDIT18 frozen originals: 08f396c4/96238489/dcb9881e/6ae90e64 + result 47358f2a + report 73fe0f70.
- Carried CLEAN (never churn): calibration V4 (S=9999, n=800, IRR .60), durable store V3, pre-fetch spy laws.

## FINDINGS LOG (R5-relevant)
- A18-F1: trust root — close via root-signed registry docs + verified proofs; NO production root (fail-closed + RWC-REVIEWER-ROOT-ONBOARDING blocker).
- A18-F5: verifier must bind candidate-commit freeze blob (git show candidate:V6path) == result == lock == live.
- A18-F2 scope enforce; A18-F3 durable receipt (PREPARED before promote); F4 tag-name xcheck; F6 reconcile authority fields; F10 manifest dup/empty law.

## AUDIT19 (2026-10-24) — DONE
- Verdict: FIX REQUIRED — 1 CRITICAL (A19-F1 reconcileV3 backdoor) / 2 HIGH (A19-F2 self-mint root, A19-F3 registry replay) / 2 MEDIUM (A19-F4 receipt scalars, A19-F5 intendedUse parse).
- Audit commit 48f9156 (7 add-only files), pushed. Machine result sha 3a72cf04; counts 1072+45=1117 measured BEFORE result creation (serial 543s, 0 failures, 11 env skips).
- Lawful stale pin recorded post-commit: RWCPreregistrationR5Tests:844 absence-pin fails (R5 result now exists); other 10 R5 tests green. R6 must declare this ONE supersession + V6 census re-anchor.
- Fable second-pass: coherent; note 45 probes multi-cover §58's 50-item list; verdict untouched.
- NEXT: await user/ChatGPT R6 remediation mandate (F1 transaction marker, F2 root mint gating, F3 current-registry head, F4/F5 strict parsing) → AUDIT20.

## R6 BUILD (2026-10-24) — DONE, awaiting AUDIT20
- Branch phase/rwc-preregistration-r6 (from 48f9156). Commits: 6cf948e lock-FIRST → e15ce28 surfaces → 7297bda inversions+R6 tests → e40a6ef ANCHOR → 47ca59e manifest V7 (=candidate). Tag gen8-rwc-preregistration-r6-audit-candidate (obj ce5abef), pushed.
- Suite 1125/1125 x2 builder + x2 main. Freeze V7: 299 artifacts, digest 8a1751c3.
- Fable gate: lock anchor fix + R-5 (ledger disk model) + R-6 (authorize→prepare receipt window) residuals.
- NEXT: AUDIT20 mandate from ChatGPT (builder draft at /tmp/RWC_PRE14_R6_AUDIT20_MANDATE_DRAFT.md). Auditor brief MUST include: FOREGROUND-ONLY, custody pre-check, staged-commit protocol, §4-style evidence order (R6 result file docs/audit/RWC_PRE14_R6_AUDIT_RESULT.json created ONLY by auditor AFTER suite), attack R-5/R-6 residuals, no PASS lock.

## AUDIT20 (2026-10-24) — DONE: FIX REQUIRED 1C/1H/2M + §7 blocker
- Audit commit 5185101 on audit/audit20-r6, pushed. 1125+11=1136 x2 (serial authoritative), 0 fail, 11 skips.
- A20-F1 CRITICAL authorize/reconcile without V5 PASS proof; A20-F2 HIGH legacy V1/V3 public; A20-F3 MED use-enforcement; A20-F4 MED stale grant post-revocation; §7 verifier V6 + schema V4 needed.
- NEXT: R7 mandate from ChatGPT (5-item scope above). R7 lock must declare: AUDIT20 probe inversions (the 4 exploit tests flip to refusals) + R6Tests pins if any + verifier V6/schema V4 as NEW surfaces. Then AUDIT21.

## R7 BUILD (2026-10-24) — DONE, awaiting AUDIT21
- FINAL candidate 104dad4, tag gen8-rwc-preregistration-r7-audit-candidate-final (obj 7674f97), pushed. Anchor 3abb24a; freeze V8 309/c64f7632. Suite 1146/1146 multi-run, tree clean.
- One-boundary convergence: token (package-init) + RunnerV5 sole minter + authorizeAcquisitionV2 (use+currentness) + reconcileV5 reconstruct-or-deficit + legacy public→package + schema V4/verifier V6 (R7 path, V8).
- Superseded pre-audit: first tag (ed2f668, .build junk) + my ledger-addendum anchor-law slip (self-caught; note at docs/audit/R7_CANDIDATE_SUPERSESSION_NOTE.md).
- Device lane assessment delivered (/tmp/GEN8_DEVICE_EVIDENCE_ASSESSMENT.md); scorecard committed in docs/progress/.
- NEXT: AUDIT21 mandate (draft /tmp/RWC_PRE14_R7_AUDIT21_MANDATE_DRAFT.md). Auditor brief musts: FOREGROUND-ONLY, custody of -final tag + supersession note, staged-commit protocol, R7 result path per schema V4, attack the token boundary (in-package reachability = expected/out-of-scope for external threat model, document), census V8 own script, no PASS lock.

## AUDIT21 (2026-10-24) — ★ PASS ★ (0C/0H/0M, 1 LOW A21-F5)
- Audit commit 30c7c7c on audit/audit21-r7, pushed. 1146+28=1174/1174, 0 fail, 0 real skips. Convergence: YES.
- First auditor died (API error) → adopt-verify-complete (2nd proven use).
- NO PASS lock yet (lawful closeout is a SEPARATE phase). Builder absence-pin not staled (repo still lockMissing).
- NEXT: ChatGPT closeout mandate (PASS-lock schema V4 creation + independent verification) → onboarding → product lane full speed. A21-F5 LOW fix folds into closeout or next builder round.

## PASS CLOSEOUT (2026-10-24) — ★ DONE — PRE-14 METHODOLOGY AUTHORITY BOUND ★
- Commit e437036 on phase/rwc-pre14-r7-pass-closeout, pushed. PASS lock field-verified byte-exact; verify(realRepo) GREEN; negatives 10/10 fail-closed; snapshot 1174/1174.
- Post-closeout lawful state: 13 stale absence-pins red (census recorded; +2 cwd-sensitive). Next builder round declares ~15 supersessions + A21-F5 fix.
- OPEN: PRE-14 methodology authority ONLY. CLOSED: root/corpus/annotation/fit/heldout/score/release.
- NEXT: ChatGPT'den LANE A (onboarding) mandası; LANE C (device) owner aksiyonlarıyla paralel.

## LANE A + LANE C (2026-10-24 akşam) — DONE
- LANE C: f1ba037 (App Group repair; simulator OK; device BLOCKED on PLA/account — owner Apple ID sorunu, enroll önerildi).
- LANE A: candidate ec89a5b, tag gen8-rwc-lane-a-onboarding-candidate (anchor 314b7e8, freeze V9 315/fe4cd1a4). ONBOARDING_ENGINEERING_READY — ACTIVATION_BLOCKED (gate G1-G9). A21-F5 FIXED (declared supersession). VerifierV6 V8-pinned → V9 lock henüz tüketilemez; targeted verification + verifier versioning sonraki tur.
- NEXT: (1) ChatGPT: targeted verification mandası; (2) owner: Apple hesabı (enroll) → device oturumu; (3) sonra LANE B ingress.

## OWNER REQUIREMENT (2026-10-24): LIVE Dynamic Island
- "Müzik çalar gibi canlı" Island. Plan: Text(timerInterval:) system-animated session timer (always-moving, zero-update) + state-transition animations + NSSupportsLiveActivitiesFrequentUpdates entitlement + expanded live mini-summary. Honest limit: background state-update cadence is OS-budgeted (device-measure); the ticking timer keeps the Island visibly alive regardless. NEXT micro-iteration right after Controlled Player lands (same file field — no parallel edit).

## OWNER REQUIREMENT (2026-10-24): Island HEAT-MAP live indicator
- Heat-map bar on Dynamic Island: marker slides to the watched content's band INSTANTLY on content switch (<1s; infra measured 0.2-0.5ms). Bands = REAL decision states + evidence confidence (green clear / gray UNKNOWN / amber caution / red shield). NO fabricated 0-100 number (constitution rule 8; score gate CLOSED until calibration) — the SAME bar hosts the real number the day M3 calibration passes. Ships in the live-Island micro-iteration (timer + heat bar + frequent-updates entitlement + transition animations).

## OWNER REQUIREMENT (2026-10-24): Display-style preference (3 modes)
- User-selectable indicator style across Island + Live Insight + Reels: (1) ISI HARİTASI (heat bar, live today), (2) EMOJİ (🟢😊 / ⬜️🤔 / 🟡⚠️ / 🔴🛡️ mapped to the SAME real bands, live today), (3) SAYI (numeric 0-100) — option VISIBLE but LOCKED with honest copy "Gerçek skor kalibrasyon tamamlanınca aktif" until the calibration gate opens (constitution rule 8; no fake numbers). Internal band position already continuous → number slots in with zero redesign on M3 day. Implement in the micro-round right after the live-Island agent lands (same file field).
- ISLAND ADDENDUM (owner): Island outer layer tinted by content band — implement via official .keylineTint(bandColor) + band-colored minimal dot + compact accents. Black pill body is system/hardware (cannot be painted — honest limit). Folds into the post-Island follow-up round with the 3-mode preference.
- OWNER REQ (2026-10-25): AUTO SESSION INTELLIGENCE — single broadcast stays alive; extension auto-IDLES analysis when foreground app (via ReplayKit sample-buffer bundle-ID attachment) is not in user's watch-list (social apps), auto-RESUMES when it is; near-zero idle cost (battery/thermal first); NO auto-restart of broadcast itself (iOS law: start always needs user tap — honest). Minimal notifications.
- OWNER REQ: Control Center Gen8 control (iOS 18+ ControlWidget API) — toggle/open; user can enable/disable anytime; emblem in Control Center.
- OWNER REQ (2026-10-25): PREFETCH PRE-EXPOSURE PIPELINE — own player: pre-evaluate N+1 (and optionally N+2) while N plays (decision ready BEFORE swipe; richer temporal sampling while queued; thermal-aware; cancellation via existing generation guards). 3rd-party surfaces: structurally IMPOSSIBLE to see next video (ReplayKit = current pixels only; no private API) — honest ceiling = minimize exposure-to-warning latency (instant first-frame analysis on transition + pipeline pre-warm). Next iteration's BUILD centerpiece.
- OWNER REQ (2026-10-25): OCTOPUS CONTINUOUS LEARNING — "main brain improved by every user". Three-tier lawful ladder: TIER1 on-device personal adaptation loop (override/rule-edit/ASK answers as local learning signals; no consent needed; data never leaves device) — buildable NOW; TIER2 opt-in anonymized aggregate telemetry (derived stats only; consent infra + KVKK/GDPR review from LANE A checklist) → central default improvements via app updates; TIER3 global brain training via the rights-cleared RWC corpus chain (M3) + optional federated learning later. Constitution rule 16 is the hard boundary. OCTOPUS=20 arms already locked in architecture; arms being lit one by one (4 live this week). TIER1 = candidate next-next iteration BUILD.

## LEARNING R2 + LONGFORM-600 (2026-10-25) — DONE (943b607 + 31bbc57)
- Agent stalled on AVAssetWriter deadlock (multi-input video-first starvation) — MAIN SESSION diagnosed + fixed (requestMediaDataWhenReady pump, once-guarded bounded wait). Known agent-stall pattern: 4th occurrence, 4th successful adopt-verify-complete.
- MEASURED on real 600s asset: cold first-valid p50 41.3ms / p95 334.5ms; warm p50 1.4ms. VISION NUMBER PROVEN (10-min video, first valid decision well under 1s).
- Learning R2: atomic accept (CAS), safe undo, durable aggregates (install-salted pseudonymization), conflict policy, My Shield sync. Long-form: 3-level analysis + AdaptiveEvidencePlanner (user-rule-driven expert selection) + Uzun Video tab (120s demo + evidence strip + FAST badge).
- Tests 182→200 GuardianMediaTests; core census stable 13. NEXT candidates: device gate P0 (owner's Apple account), Self-Evaluation arm (Sessiz Zekâ anayasası), speech capability day.
