# P007 — Device & Signing Environment (audited 2026-10-18)

Detected on the development host (not fabricated). Classified: VERIFIED / AVAILABLE_NOT_USED / PENDING_EXTERNAL_DEPENDENCY / UNSUPPORTED.

| Item | Finding | Classification |
|------|---------|----------------|
| Apple Development signing identities | **2 valid** in keychain ("Dogancan Gundogan ZR9H8H26AG", "gundogandogancan@gmail.com V42D69Y5CK") | **VERIFIED** (present) |
| `DEVELOPMENT_TEAM` in project | **not set** (0 occurrences in project.pbxproj) | AVAILABLE_NOT_USED |
| Provisioning profiles | **none** installed | PENDING_EXTERNAL_DEPENDENCY |
| Physical iPhone connected | **iPhone 14 Pro Max (iPhone15,3) "Dogi (2)" — state: connected** (2 others unavailable) | **VERIFIED** (connected) |
| Device build attempt | `xcodebuild -destination 'platform=iOS,id=…'` → `error: Signing for "Gen8" requires a development team` | PENDING_EXTERNAL_DEPENDENCY |
| Xcode / macOS | Xcode 26.6 (17F113) / macOS 26.4 | VERIFIED |
| App Group entitlement | not provisioned (requires team) | PENDING_EXTERNAL_DEPENDENCY |
| WidgetKit Control extension target | not added (requires team + extension target) | PENDING_EXTERNAL_DEPENDENCY |
| ActivityKit (Live Activity) | adapter compiles in app; runtime requires entitlement + device | PENDING_EXTERNAL_DEPENDENCY |
| Speech on-device assets / locales | probed per-locale at runtime (see P007_SPEECH_EVAL); lab host = not authorized/no asset | PENDING_EXTERNAL_DEPENDENCY |
| ShazamKit entitlement/service | not entitled | PENDING_EXTERNAL_DEPENDENCY |

## What changed since P005/P006
Earlier phases had **no** signing identity at all. Now identities **and a physically connected iPhone exist** — the
only remaining barrier to on-device certification is wiring a `DEVELOPMENT_TEAM` + automatic provisioning + a unique
bundle id (the current `com.aymedo.Gen8` is from the old account, ADR-0003) + on-device trust.

## Exact, verified blocker for device run
`Signing for "Gen8" requires a development team.` Resolving it is an **EXTERNAL_EXECUTION_DEPENDENCY** requiring human
decisions (which team, which bundle id, trust the app on the physical device, push a build to a personal phone). It was
**not** done unilaterally: changing the bundle id + team + installing onto the user's real device is an outward,
account-touching action. It can be completed on explicit request. Until then, **all device-only metrics in this phase
are `NOT_MEASURED`** and nothing claims device certification.
