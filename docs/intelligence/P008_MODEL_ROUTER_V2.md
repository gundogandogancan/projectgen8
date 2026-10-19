# P008 — Model Router V2 + Compute Tiers + Model Packs
Tiers (§23): T0 identity/cache (near-immediate) · T1 cheap fast heads (aHash/change-detect, metadata, text, light OCR,
basic Vision/Sound) · T2 moderate (visual embedding, semantic model, selected audio/speech windows) · T3 deep
(compact VLM/deeper temporal/extended transcript). **T3 never blocks first-trustworthy admission unless policy requires.**
Model packs (§24), budget-separated — iOS extension ≠ full app:
- EXTENSION_FAST_PACK: broadcast-extension-safe (≤~50 MB): cheap boundary detector, deterministic Shield/admission,
  optional light OCR/Vision only if device benchmark permits. NO heavy VLM on broadcast frames.
- APP_FAST_PACK: richer models when the app process is available.
- APP_DEEP_PACK: selective heavier models (T3).
- DESKTOP_PACK: more compute.
Router selects cheapest sufficient path by content type, available evidence, cache, device capability, thermal,
low-power, deadline, uncertainty, policy strictness. (Builds on P007 DeviceCapabilityProfile + ModelLifecycleV2 + ResourceGovernor.)
