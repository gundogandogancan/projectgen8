# RWC V10 PASS CLOSEOUT RECORD (main session, 2026-10-24)

AUDIT22T (commit c347ce016b3a2b1949b13f094dc61335b248ae41) returned PASS (0/0/0, 1225+21=1246,
targeted scope) for V10 candidate df952d260567c8ffcdde0fed83f8f36617b94c62
(tag gen8-rwc-lane-a-v10-transition-candidate, object c3174ef; anchor 6cdfb3ff; freeze V10
320 artifacts, manifest blob 1b5198de7637..., inventory digest 464bffe8...).

CANONICAL LOCK SUPERSESSION: RWCCorpusEntryVerifierV7 (like V6) reads the single canonical lock
path docs/audit/RWC_PRE14_PASS_LOCK.yaml (RWCPre14PassLockV4.lockRelPath) — the live-authority
pointer design. The V8-era lock content (R7 closeout, commit e437036) is SUPERSEDED at the
canonical path by the V10 lock and preserved BOTH in git history
(`git show e437036:docs/audit/RWC_PRE14_PASS_LOCK.yaml`) AND as the archived copy
docs/audit/RWC_PRE14_PASS_LOCK_V8_SUPERSEDED_ORIGINAL.yaml.txt. V6 remains byte-frozen and
validates the V8-era authority from historical commits; the LIVE tree's authority is now the
V10 lock, consumable ONLY by V7.

Status after this closeout: LANE_A_SECURITY_ACCEPTED / PRE14_VERSIONED_AUTHORITY_VALID.
OPERATIONAL_ROOT_ACTIVE = FALSE (G1-G9 human gate OPEN; no real key/root; zero-data intact:
corpus=annotator=fit=heldout=0, visibility=false; production score CLOSED; Presentation BLOCKED).

Expected lawful stale set added by this closeout: probes asserting real-repo V7 fail-closed /
V10-result absence (AUDIT22T D01-class, V10 transition real-repo probe) — recorded, not edited;
historical reproducibility at c347ce0 and earlier.
