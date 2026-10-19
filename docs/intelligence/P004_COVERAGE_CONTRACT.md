# P004 — Coverage Contract

**Doc status:** `CANONICAL` · **Phase:** 4 · **Date:** 2026-10-18 · PROMPT 004 §5, §6. Coverage is **NOT binary**.

## WholeVideoCoverage (per analyzed track)
`visualPercent · audioPercent · transcriptPercent · semanticPercent · temporalPercent · highRiskRegionPercent · unknownRegionPercent` (implemented in `WholeVideoCoverage`, stored in ContentDNA V3).

## Confidence dimensions (no single magic number)
`signalConfidence · segmentConfidence · videoCoverage · identityConfidence · policyConfidence · finalAdmissionConfidence` (`WholeVideoConfidence`).

## No-score gates (§6)
A numeric overall score is withheld (→ INSUFFICIENT_EVIDENCE / `?`) when **any** of: identity weak · coverage below threshold · critical regions unresolved · model conflict unresolved. Enforced by `WholeVideoConfidence.overallScoreEligible(minCoverage:minIdentity:unresolvedConflict:)` (tested). A final admission/score always records which modalities were covered and which regions remain unknown, and whether regions were coarsely vs deeply analyzed.
