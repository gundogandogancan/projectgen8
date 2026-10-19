# P009A Phase C — Release Resource Results
Evidence-build overhead (measured, Phase B): cheap 3.181/5.278 ms + THERMAL_SERIOUS 89/89 — caused by 7,844
per-frame MOTION writes; NOT release behavior. Release-equivalent reference (last non-evidence device run):
cheap 1.372/2.887 ms, peak 30.2 MB, thermal nominal. §10 enforcement: `EvidenceBuildPolicyV1` — release builds are
structurally OFF (env ignored: `testReleaseDisablesEvidenceLogging`); evidence logging requires the compile flag
(audit builds) or DEBUG+env. Shot-commit identity path unchanged (O(≤6) comparisons + guard set-arithmetic);
handoff ring bounded (64); graph/evidence/cache bounds unchanged (suite-verified). The always-on derived proof log
(audit C1) remains for evidence continuity in dev builds — flagged for the beta-gate privacy pass.
