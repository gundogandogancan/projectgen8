# P008A — Automatic Guardian Runtime (§6,§7,§8,§9,§22,§23,§26)
Canonical: **ZERO-TOUCH WHERE PERMITTED, ONE-TAP PER SESSION WHERE REQUIRED, NEVER HIDDEN CAPTURE.**
Components (GuardianCore, tested): `GuardianRuntimeManager`, `ObservationSessionManager` (state machine), 
`PlatformCapabilityRegistry` (automation truth table), `AppContextResolver`, `SessionRecoveryController`.
## iOS truth (NOT zero-touch cross-app — OS-enforced)
Cross-app capture = ReplayKit system broadcast → **the user taps Start once per session** (red indicator). There is NO
official zero-touch cross-app capture on iOS; achieving it would require private API / hidden capture, which is forbidden.
WHAT IS automatic: once a session is ACTIVE, **app switches + content changes auto-produce observations — the user never
reopens Gen8 per app** (`testAutomaticSessionNoManualReopen`: 20 content transitions, 1 manual start tap). OS termination →
one-tap restart (never a silent claim of observing). AppContext: official bundle id when exposed (iOS does NOT expose it
cross-app), else an inferred source-surface class with its OWN capped confidence, else UNKNOWN_APP — context confidence is
separate from content confidence. macOS (ScreenCaptureKit) / Android (MediaProjection) have their own truthful rows.
