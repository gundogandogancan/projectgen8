# P008 — Prior Evidence Revalidation (§0)
Re-ran before new intelligence work. No invariant regressed.
- Tests (per target): GuardianCoreTests 148, GuardianIntelligenceTests 49, GuardianMediaTests 22 = **219/219** (pre-P008).
- Simulator app build: SUCCEEDED. Signed device build + both extensions (widget + broadcast): SUCCEEDED/installed (P007C/D).
- Live Activity device path: areActivitiesEnabled=true, Activity active (P007C). My Shield persistence + no-raw-reference-media: intact.
- Cross-app change detector invariants: once-per-content, never-reanalyze-unchanged (P007D tests) green.
Post-P008: **231/231** (+11 P008 core, +1 real-evidence). Lineage 200→214→215→219→231.
