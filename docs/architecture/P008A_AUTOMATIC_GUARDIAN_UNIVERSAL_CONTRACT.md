# P008A — Automatic Guardian Universal Contract (§26)
Common layers: GuardianRuntimeManager · ObservationSessionManager · PlatformCapabilityRegistry · ObservationAdapter ·
AppContextResolver · ContentBoundaryDetector(V2) · MultimodalUnderstanding · ContentIdentity(V2) · ContentDNA(V5) ·
PersonalAlgorithm(V2) · ScoreContract · SurfaceAdapter · PrivacyFirewall · ResourceGovernor.
Each platform DECLARES: required initial consent · consent/session persistence · auto-resume ability · app-context
visibility · pixels/audio/text/metadata access · protected-content behavior · background execution · surface update.
iOS row (truthful): consent=system picker per session; session persistence=none (OS); auto-resume=NO (one-tap restart);
app-context=not exposed cross-app; pixels/audio=yes during broadcast; protected-content=DRM never bypassed (metadata
fallback); background=limited; surface update (Dynamic Island from cross-app state)=BLOCKED_PENDING_PAID_APP_GROUP.
No implementation beyond iOS this turn. One brain; many official bodies.
