# P008 — Privacy Firewall (§25)
Default: raw cross-app frames = ephemeral memory only; raw audio = ephemeral; transcript = ephemeral unless the user
explicitly enables history; NO cloud; NO external analytics containing content; NO training; NO ad targeting.
Persist ONLY derived, non-reconstructive data: content identity, ContentDNA (non-personal), calibrated dimension outputs,
timestamps/versions, minimal provenance. A materially reconstructive/sensitive derived feature is treated as sensitive
and protected. Enforced structurally: `ModalEvidenceSignal.rawMediaRetention` defaults "none"; the broadcast extension
(P007D) keeps only a 64-bit hash + derived counters; `ContentObservationEnvelope.privacyClass = ephemeral-on-device`.
