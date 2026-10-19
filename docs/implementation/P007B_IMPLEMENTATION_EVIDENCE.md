# P007B — Implementation Evidence

**User approval received** (Team 47XQMQZLF6, dev bundle ids, App Group id, both permissions YES). Applied ONLY approved
values. No production/App-Store identity; no App Store Connect upload.

## Achieved on the physical iPhone (REAL)
- Signing applied: DEVELOPMENT_TEAM `47XQMQZLF6`; app `com.gen8.guardian.dev`; ext `com.gen8.guardian.dev.GuardianControl`.
- Signed device build (app + embedded extension) **SUCCEEDED** (automatic provisioning).
- **Installed + launched** on iPhone 14 Pro Max (iPhone15,3, iOS 26.6, dev mode on).
- **App AND widget-extension processes run on device** (pids 7138 / 7139); extension signed with the team.
- Lab suite **215/215**, simulator build **SUCCEEDED** — no regression from the signing change.

## App Group — honest blocker
`group.com.gen8.guardian.dev` is **not provisionable** on this team (free/personal + pending PLA):
"Provisioning profile doesn't include the App Groups capability." Entitlement reverted; shared cross-process state needs
a paid Apple Developer Program membership. Documented in P007B_DEVICE_INSTALL_EVIDENCE.

## Not completed (require human-operated device / Instruments / on-device test target — an agent cannot perform)
Control Center interactive toggle proof; Live Activity/Dynamic Island live render (also needs attributes unification +
App-Group/paid); lock-screen privacy visual; on-device TR/EN speech (app doesn't link GuardianMedia / no trigger);
device full-pipeline percentiles (no on-device XCTest target); energy/thermal/memory Instruments; 10-min / long-form /
1000-rule timed device runs; 30-min device soak.

## §2 unification (outstanding, justified)
`GuardianActivityAttributes` remains duplicated (app vs extension). Not unified this turn to preserve the working signed
install; it is only exercised when the app actually starts a Live Activity (not wired) and is moot until App Group /
paid membership enables the shared-state architecture. Tracked as the first step before any real Live Activity device test.

## H1 / Shazam
Unchanged, honest: H1 UNAVAILABLE_EVIDENCE_BACKED; Shazam UNAVAILABLE. No substitution.

## Release level
Remains **R1**; R2 is PARTIAL — signed install/launch/extension-run proven on device, but the behavioral/performance/
soak device proofs required by §29 are not captured. Not claimed as R2 certified.
