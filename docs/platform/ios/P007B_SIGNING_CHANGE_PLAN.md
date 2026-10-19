# P007B — Signing Change Plan (SHOW BEFORE APPLY — nothing applied yet)

Status: **PROPOSED / NOT APPLIED.** No project setting, identifier, provisioning profile, or device was changed.
This document is produced for user review per §1. Apply only the explicitly approved values after sign-off.

## A. Development Teams available on this host (authoritative = certificate OU)
Extracted read-only from the login keychain (`security find-certificate … | openssl x509 -subject`). The Team ID is the
**OU** field — NOT the parenthetical in the common name (that parenthetical, e.g. ZR9H8H26AG, is an individual/cert id).

| Option | Team ID (OU) | Visible Team name (O) | Cert common name | Cert valid until | Type |
|--------|--------------|-----------------------|------------------|------------------|------|
| **Team A** | `47XQMQZLF6` | Dogancan Gundogan | Apple Development: Dogancan Gundogan (ZR9H8H26AG) | 2027-05-05 | Apple Development (individual) |
| **Team B** | `XLW3644XW8` | Doğancan Gündoğan | Apple Development: gundogandogancan@gmail.com (V42D69Y5CK) | 2027-03-27 | Apple Development (individual) |

Both are "Apple Development" (individual) teams. **I cannot determine offline which team the connected iPhone is
already registered under, nor whether either is a paid Apple Developer Program membership vs a free personal team** —
that requires either Xcode automatic provisioning (which registers the device) or the Developer portal, neither of which
is permitted in this pre-apply step.

### Usability for the connected iPhone
- Connected device: **iPhone 14 Pro Max (iPhone15,3), "Dogi (2)", id `C7C6CE6E-B577-558A-8992-DC6C1F492B39`, state=connected.**
  (Also present but **unavailable**: iPhone 16 Pro "Apocan", iPhone 13 Pro Max "Yones".)
- Either team can likely sign & install via Xcode-managed (automatic) signing; the chosen team will register the device
  on the first signed build (that registration is the R2 install step, not this step).
- **Recommendation: Team A `47XQMQZLF6`** — longer cert validity (2027-05-05) and matches the primary account name.
  Final choice is yours.

## B. Proposed DEV identifiers (temporary development identity — NOT production)
| Role | Proposed value | Format valid? | Apple-side uniqueness |
|------|----------------|---------------|-----------------------|
| Primary app bundle id | `com.gen8.guardian.dev` | ✅ valid reverse-DNS | **UNVERIFIABLE offline** (see below) |
| Widget extension bundle id | `com.gen8.guardian.dev.GuardianControl` | ✅ valid (proper child of primary) | UNVERIFIABLE offline |
| App Group id | `group.com.gen8.guardian.dev` | ✅ valid (`group.` prefix) | UNVERIFIABLE offline |

### Uniqueness / conflict check — honest limitation
Explicit App IDs and App Group IDs are **globally unique across Apple** and can only be confirmed available by querying
the Apple Developer portal or by letting Xcode automatic signing attempt registration. **I did not do either** (you asked
me not to create identifiers). So I **cannot certify** these are free of conflict; I can only confirm the format is valid.

- Collision risk for `com.gen8.guardian.dev`: low-to-moderate — "gen8" is a short generic token you don't own as a
  domain, so a prior registration by another account is possible though unlikely.
- **Safe discovery path (no permanent change):** accept the proposed set and let Xcode **automatic signing** attempt it
  at R2 apply-time. If the explicit App ID is already taken, provisioning simply fails with a clear error and **nothing
  is left changed** — we then switch to an alternative. This is the cleanest way to "check availability" without me
  pre-creating anything.
- **Guaranteed-unique alternatives** (if you prefer zero conflict risk up front), pick one:
  - `com.gen8.guardian.dev47` → ext `….GuardianControl`, group `group.com.gen8.guardian.dev47`
  - `com.dogancangundogan.gen8.guardian.dev` (uses your name namespace) → ext/group derived
  - `com.gen8.guardian.dev.<teamid>` embedding `47XQMQZLF6` for global uniqueness

### ⚠️ Capability caveat (must verify at apply-time)
If the chosen team is a **free personal team** (not a paid Apple Developer Program membership), the **App Group
capability is typically unavailable**. In that case the Control extension's shared activation state cannot use an App
Group and falls back to per-process `UserDefaults.standard` — meaning the Control Center toggle and the app would **not
share state on device**. If App Group is unavailable we will either (a) proceed without it (toggle works, cross-process
sync limited) or (b) you enroll in the paid program. This will be surfaced the moment automatic signing reports the
team's entitlements.

## C. Current → proposed signing state
| Setting | Current | Proposed |
|---------|---------|----------|
| DEVELOPMENT_TEAM (app) | *(not set)* | `<APPROVED_TEAM>` (A `47XQMQZLF6` recommended) |
| DEVELOPMENT_TEAM (extension) | *(not set)* | same as app |
| CODE_SIGN_STYLE | Automatic (already) | Automatic (unchanged) |
| App bundle id | `com.aymedo.Gen8` | `com.gen8.guardian.dev` (approved) |
| Extension bundle id | `com.aymedo.Gen8.GuardianControl` | `com.gen8.guardian.dev.GuardianControl` (approved) |
| App Group | *(none)* | `group.com.gen8.guardian.dev` (approved, iff team supports it) |

## D. Targets affected
- `Gen8` (app) — bundle id, DEVELOPMENT_TEAM, (App Group entitlement if used).
- `GuardianControlExtension` (widget extension) — bundle id, DEVELOPMENT_TEAM, (App Group entitlement if used).

## E. Entitlements affected
- New `Gen8.entitlements` + `GuardianControlExtension.entitlements` **only if** App Group is used:
  `com.apple.security.application-groups = [group.com.gen8.guardian.dev]`.
- No other entitlements (no push, no iCloud, no HealthKit, etc.).

## F. Provisioning / capabilities required
- Xcode-managed automatic provisioning under the approved team.
- Register the connected iPhone's UDID under the team (automatic).
- App Group capability on the App ID(s) — paid-program dependent (see caveat).

## G. Exact files / settings to change (at apply-time, after approval)
1. `Gen8.xcodeproj/project.pbxproj` — set `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER` (both targets, Debug+Release),
   and `CODE_SIGN_ENTITLEMENTS` if App Group is used.
2. `Gen8/Gen8.entitlements` + `GuardianControlExtension/GuardianControlExtension.entitlements` — new, only if App Group.
3. Unify `GuardianActivityAttributes` into one shared source (P007B §2) before device install.
4. `GuardianControlState` / `GuardianActivationBridge` — point the App Group suite id at the approved group (already
   coded to fall back safely).

## H. Rollback plan
- Pre-change backup: `/tmp/project.pbxproj.p007a.bak` exists; take a fresh `/tmp/project.pbxproj.p007b.bak` before apply.
- Revert = restore the backup pbxproj + delete any new `*.entitlements` + remove the App Group suite id usage.
- No portal cleanup needed if we use automatic signing and never manually create portal identifiers; automatic
  registrations are harmless/dev-only and can be deleted later in the portal if desired.
- The old identity `com.aymedo.Gen8` is fully restorable from backup.

## I. NOT done in this step (per your instruction)
No DEVELOPMENT_TEAM set · no bundle id changed · no identifier created · no App Group created · no provisioning profile
generated · no device install. Awaiting your approval of: **team choice**, **final identifier set**, and the two
permission flags (`PERMISSION_TO_MODIFY_SIGNING`, `PERMISSION_TO_INSTALL_ON_CONNECTED_IPHONE`).
