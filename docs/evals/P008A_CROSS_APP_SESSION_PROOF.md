# P008A — Cross-App Session Proof (§21)
## Status: logic BUILT + tested; live device run PENDING user Start-Broadcast gesture (+ App Group for scored surface).
Per new content, the runtime logs derived-only fields: contentSequence, boundaryState, identityConfidence,
modalitiesObserved, headsInvoked, evidenceCoverage, calibrationScope, scoreOrUnknown, scoreBand, confidence, reasons,
firstTrustworthyMs, cacheState — NO raw frame. The broadcast extension (P007D) emits this ephemerally. A ≥20-item live
Instagram session requires the user to tap Start Broadcast and switch content (unautomatable by an agent, by design).
If live Dynamic Island update remains App-Group-blocked, the extension-local result is recorded and surface delivery is
marked `BLOCKED_PENDING_APP_GROUP`. Not faked.
