# P008A — Device Privacy Proof (§24)
Structural guarantees (code-enforced): no captured frame files, no captured audio files, no hidden transcript history,
no content analytics upload, no model-training upload. Broadcast extension keeps only a 64-bit perceptual hash + derived
counters; `ModalEvidenceSignal.rawMediaRetention="none"`; `ContentObservationEnvelope.privacyClass=ephemeral-on-device`.
Container inspection after a session: pull app + extension containers via devicectl and verify only declared-schema
derived data (identity, ContentDNA non-personal, calibrated dimension outputs, timestamps/versions, minimal provenance) —
and NO media. This container inspection is performed after a user-run broadcast session (pending the Start gesture).
