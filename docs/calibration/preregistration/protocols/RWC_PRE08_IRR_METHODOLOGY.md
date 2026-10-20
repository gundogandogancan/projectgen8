# RWC-PRE-08 — IRR METHODOLOGY (frozen pre-data)

ORDINAL (0-4 suitability): quadratic-weighted Cohen kappa (exact formula in RWCStatisticsV1.swift;
weights w_ij = 1 - ((i-j)^2 / (k-1)^2), k=5). BINARY SAFETY dimensions: Krippendorff alpha (nominal,
two coders; Do/De from coincidence matrix - implementation + hand fixtures in RWCStatisticsV1).
THRESHOLD REVIEW (pre-data justification, NOT blind canonization): kappa_w >= 0.60 retained -
'substantial'-boundary on the Landis-Koch-style scale is the minimum at which ordinal labels can
calibrate a 0-4 score without annotator noise dominating rubric signal; alpha >= 0.67 retained -
the conventional minimum for drawing tentative conclusions; SAFETY ADDITION (stricter than the old
candidate constitution): for the strong-protection dimension specifically alpha >= 0.80 is REQUIRED
because false-safe costs are asymmetric. Rejected alternative: percent-agreement (chance-inflated).
MISSING/ABSTENTION: abstain is NOT a scale point; pairs where either annotator abstained are excluded
from kappa/alpha and reported as abstention-rate separately; items missing a label are invalid pairs.
MINIMUM VALID PAIRS: 50 per IRR computation; below -> INSUFFICIENT_DATA (never pooled silently).
CI: bootstrap over items (B=2000, seed=20261020, percentile 95%); reported alongside every IRR value.
SLICES: IRR computed per powered slice (PRE-10) AND overall; weak slices report INSUFFICIENT_DATA -
never pooled into the aggregate to pass.
DEGENERATE LAW: all-same-label or single-class data -> kappa/alpha undefined -> INSUFFICIENT_DATA
(typed), never 0 or 1 by convention.
FAILURE LAW: IRR below threshold = METHODOLOGY_FAILURE for that batch -> handbook/training revision ->
re-annotation of a FRESH batch; failed-batch labels are never fitted on.
