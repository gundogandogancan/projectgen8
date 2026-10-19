# P007A — R2 Signing Handoff

Everything below is **required from the user** before physical-device R2 can proceed. Nothing here has been applied.
No signing identity, Team ID, bundle id, or App Group has been changed or created in this prompt (§14).

## Values needed from you
```text
APPROVED_DEVELOPMENT_TEAM             = <your 10-char Team ID>        # e.g. the team behind your Apple Development cert
APPROVED_PRIMARY_BUNDLE_ID            = <new unique app bundle id>    # replaces com.aymedo.Gen8 (ADR-0003, old account)
APPROVED_WIDGET_EXTENSION_BUNDLE_ID   = <primary>.GuardianControl
APPROVED_APP_GROUP_ID                 = group.<primary>
permission_to_modify_signing          = yes / no
permission_to_install_on_connected_iPhone = yes / no   # iPhone 14 Pro Max "Dogi (2)" is connected
```

## PROPOSED mechanical derivations (NOT active — shown for convenience)
If you approve a primary bundle id `X`:
```text
APPROVED_PRIMARY_BUNDLE_ID            = X                       (PROPOSED)
APPROVED_WIDGET_EXTENSION_BUNDLE_ID   = X.GuardianControl       (PROPOSED)
APPROVED_APP_GROUP_ID                 = group.X                 (PROPOSED)
```
Current placeholders in the repo (unchanged app id + a placeholder ext id): app `com.aymedo.Gen8`,
extension `com.aymedo.Gen8.GuardianControl`, app group `group.com.aymedo.Gen8` (fallback to standard defaults).

## What I will do once you approve (R2 prompt, not now)
1. Set `DEVELOPMENT_TEAM` on both targets; set the approved bundle ids; enable automatic provisioning.
2. Add the App Group entitlement to app + extension; unify `GuardianActivityAttributes` into one shared type.
3. Build signed for the connected iPhone; register/trust the device.
4. Run the P007 §18 device performance gate + P007 §4 Control Center state tests + real Dynamic Island on device.
5. Populate DEVICE_RESOURCE_BUDGETS.yaml with real measurements.

No passwords/secrets are requested. I will not touch the Apple Developer portal, signing, bundle id, or your phone
without your explicit `yes` on the permission lines above.
