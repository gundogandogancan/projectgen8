# P007B — Device Install Evidence (REAL, 2026-10-18)

Applied **only the user-approved values**; verified on the physically connected iPhone.

## Signing applied (approved)
| Setting | Value |
|---------|-------|
| DEVELOPMENT_TEAM | `47XQMQZLF6` (Team A, "Dogancan Gundogan") |
| App bundle id | `com.gen8.guardian.dev` |
| Extension bundle id | `com.gen8.guardian.dev.GuardianControl` |
| Code sign style | Automatic (Xcode-managed), `-allowProvisioningUpdates` |
| App Group | **NOT applied** — not provisionable on this team (see §App Group finding) |

## Device
| Field | Value |
|-------|-------|
| Model | iPhone 14 Pro Max (marketing) |
| Identifier | iPhone15,3 |
| iOS | 26.6 |
| Developer Mode | enabled |
| devicectl id | `C7C6CE6E-B577-558A-8992-DC6C1F492B39` ("Dogi (2)") |
| Build config | Debug, `platform=iOS` device destination |

## Verified steps (actually observed, not claimed)
1. **Signed device build** (app + embedded extension): `** BUILD SUCCEEDED **` with automatic provisioning.
2. Embedded extension signature: `Identifier=com.gen8.guardian.dev.GuardianControl`, `TeamIdentifier=47XQMQZLF6`.
3. App entitlements: `application-identifier = 47XQMQZLF6.com.gen8.guardian.dev`, `get-task-allow = true` (development).
4. **Install**: `xcrun devicectl device install app` → `App installed: bundleID com.gen8.guardian.dev`.
5. **Launch**: `xcrun devicectl device process launch` → `Launched application with com.gen8.guardian.dev`.
6. **Both processes running on device** (`devicectl device info processes`):
   - pid 7138 `…/Gen8.app/Gen8`
   - pid 7139 `…/Gen8.app/PlugIns/GuardianControlExtension.appex/GuardianControlExtension` ← the real widget extension runs on hardware.
7. App install record: `Gen8  com.gen8.guardian.dev  1.0  1`.

## App Group capability finding (honest)
Adding `group.com.gen8.guardian.dev` entitlement caused provisioning to FAIL:
```
error: Unable to process request - PLA Update available: You currently don't have access to this membership resource.
       To resolve this issue, agree to the latest Program License Agreement in your developer account.
error: Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the App Groups capability.
error: … doesn't support the group.com.gen8.guardian.dev App Group.
```
→ Team `47XQMQZLF6` (free/personal, or pending PLA) **cannot provision App Groups**. The entitlement was **reverted**;
the signed build without App Group succeeds and installs. Consequence: the Control Center toggle and the app cannot
share state via an App Group on this team — `GuardianControlState`/`GuardianActivationBridge` fall back to per-process
`UserDefaults.standard`. Enabling shared state requires a **paid Apple Developer Program membership** (+ accepting the
latest PLA). Documented, not worked around.

## Rollback availability
Backups: `/tmp/project.pbxproj.p007a.bak` (pre-007A), `/tmp/project.pbxproj.p007b.bak` (pre-signing),
`/tmp/project.pbxproj.p007b.preappgroup.bak` (pre-App-Group). Restoring the app id to `com.aymedo.Gen8` / removing the
team is a single file restore.
