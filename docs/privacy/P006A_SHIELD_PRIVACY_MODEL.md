# P006A — Shield Privacy Model

The Personal Shield is among the most sensitive surfaces in Gen8 (what a person does not want to see reveals a lot).
These boundaries are **structural**, not just policy.

## 1. No raw reference media persisted (§5)
- Image/logo references are ingested via `ShieldImageReferenceIngestor`: a Vision **feature print** is extracted and the
  raw `CGImage` goes out of scope immediately — never written to disk, never copied.
- The derived feature vector lives only in an in-memory `ShieldReferenceStore` (session-scoped, `@unchecked Sendable`
  behind a lock). The **durable** `ShieldRuleV2` stores only a hash id (`imgref-…`) + vector byte length — no pixels.
- Audio references use SoundAnalysis **class labels** (`soundEvents`), not stored PCM/waveforms (ContentDNAAudio from
  P006 already forbids raw PCM/lyrics retention).

## 2. No face biometric (§5)
`ShieldImageReferenceIngestor` performs **no** `VNDetectFaceRectanglesRequest` / face landmark / face identity. It runs
only `VNGenerateImageFeaturePrintRequest` (a generic scene/image descriptor). No face template is ever enrolled. This is
a design choice, not a toggle — there is no code path that builds a face biometric.

## 3. No speaker voiceprint (§6)
Audio shield matching is by **sound class** (SoundAnalysis) and, where available, music identity (ShazamKit). There is
**no** speaker-embedding / voiceprint / "who is talking" model. Spoken-phrase references rely on transcription
(on-device Speech, currently UNAVAILABLE in lab) matched as text — never on voice identity.

## 4. Local-first, no silent cloud, no global training (§40)
- Rules, exceptions, corrections, and reference vectors are **local personal state**. Nothing is uploaded.
- `ShieldCorrectionApplier` mutates only the local rule; it never feeds a global training pool. (25 Rules #16: no private
  activity enters a global training pool without explicit consent — the shield adds no such path.)
- There is no shield-derived telemetry that leaves the device by default.

## 5. Abuse / adversarial posture (§44)
- Shield rules are **data, never instruction** — a crafted rule label cannot execute code or change policy (Rule 20).
- A user exception can never override a `systemSafetyFloor` rule, and cannot override a `guardian` (child) rule unless
  explicitly guardian-authorized (`ShieldExceptionEngine`), preventing a child from self-exempting a parental shield.
- Low-confidence/unknown signals never silently hide — an adversary cannot weaponize a vague shield to disappear
  arbitrary content without the user seeing a warn/ask.

## 6. Privacy classification
`ShieldRuleV2.privacyClass = "sensitive-personal"` by default. Reference vectors are `onDeviceOnly`. Any future sync
would require an explicit, separately-consented, encrypted path (not in 006A scope).

## 7. 006B durable storage (update)
Shield rules/exceptions/derived features now persist locally via `PersonalShieldStore` (Application Support, atomic
writes, SHA-256 integrity, iOS `FileProtectionType.complete`, no hard-coded keys). Raw reference image/audio remain
discarded by default — only `DerivedReferenceFeature` vectors persist, and an incompatible engine revision forces
re-authoring rather than a silent stale match. Full detail: `docs/privacy/P006B_SHIELD_LOCAL_STORAGE_SECURITY.md`.
