# P009A Phase C — C6-Family Adversarial Results
10 variants (`testC6FamilyAdversarial`), all expected NEW or AMBIGUOUS, never unsafe SAME: bright→bright ✓
dark→dark ✓ same-dominant-color ✓ same-template(+swipe veto) ✓ same-layout-different-semantic (anchor rule) ✓
rapid-similar(+veto) ✓ persistent-chrome+replacement ✓ similar-crossfade ✓ low-motion replacement ✓ high-motion
replacement ✓. ALL PASS; zero unsafe SAME; no inheritance anywhere. Plus guard units (`testIndependenceGuardFamilies`):
4 luma channels together ≠ sufficient; luma+structure without burst ≠ sufficient (near-identical different items);
luma+structure+burst = sufficient; cross-modal alone = sufficient; priors never count. strongNew absolute re-proven.
