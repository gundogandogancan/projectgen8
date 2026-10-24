# R7 PRE-AUDIT CANDIDATE SUPERSESSION NOTE (main session, 2026-10-24)

1. The R7-07 commit (3abb24a, the R7 methodology V8 anchor) accidentally tracked 4702 SwiftPM build
   artifacts under `docs/audit/audit20_tools/a20consumer_r7/.build/` (binary .o/.swiftdeps/db; the
   compile-negative test mutates them, dirtying the tree). Commit ef8a68c untracked them and added a
   `.gitignore`. These paths are OUTSIDE every freeze-V8 governed root; the 309 frozen artifacts are
   unaffected.
2. Commit ef8a68c ALSO (incorrectly) appended an addendum to the frozen V8 artifact
   `RWC_PREREGISTRATION_R7_CHANGE_LEDGER.md` — caught by the main session's own anchor-law check
   BEFORE any audit. The commit carrying THIS note restores that ledger byte-identical to its anchor
   blob (`git show 3abb24a:<path>`) and relocates the supersession record here (docs/audit is not a
   governed freeze root; this file is add-only audit history).
3. The initially pushed candidate tag `gen8-rwc-preregistration-r7-audit-candidate`
   (tag object 4a9fb34 -> commit ed2f668) is SUPERSEDED PRE-AUDIT history: no audit was conducted
   against it; it is never deleted or re-pointed. The AUDIT21 target is the NEW annotated tag
   `gen8-rwc-preregistration-r7-audit-candidate-final`.
4. Anchor (3abb24a) and freeze manifest V8 (commit ed2f668; 309 artifacts, inventory digest
   c64f7632) remain VALID: at the -final candidate every frozen artifact is byte-identical to its
   anchor blob (per-path `git diff 3abb24a..<candidate>` empty for all governed paths), the manifest
   itself and the (uncreated) remediation report being the only lawful post-anchor surfaces.
5. Schema V4 / verifier V6 bind `candidate_tag_name` as a RECORDED field cross-checked at audit
   time (A18-F4 law) — the `-final` tag name is therefore fully lawful; no contract pins the
   original name.
