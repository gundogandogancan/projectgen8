# P008A — Session Recovery Matrix (§23) — iOS
| Interruption | iOS classification | UI behavior |
|--------------|--------------------|-------------|
| app switch (within live broadcast) | AUTO_RESUMABLE | session continues; content auto-observed; no reopen |
| foreground/background | ONE_TAP_RESTART (if OS drops the broadcast) | show "observation paused — tap to resume" |
| lock / unlock | ONE_TAP_RESTART (if dropped) | same |
| broadcast stopped / OS terminated | ONE_TAP_RESTART | one-tap restart; never claim observing |
| device reboot | ONE_TAP_RESTART | one-tap restart |
`ObservationSessionManager` enforces: `.active` (isObserving) only after `osConfirmedActive`; on termination → iOS goes
`.restartRequired` (never `.recoverable`, because iOS cannot auto-resume a system broadcast). UI must clearly state when
observation is NOT active. macOS (ScreenCaptureKit) would be AUTO_RESUMABLE for several of these (different platform row).
Tested in `P008ACoreTests`.
