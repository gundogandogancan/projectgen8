# P008 — Content Identity V2
`ContentIdentityResolverV2` (§13): hierarchical identity = providerID + normalizedMetadata + textSignature +
visualSignature + temporalSignature + audioSignature → confidence EXACT/STRONG/PROVISIONAL/UNKNOWN.
Provider id → EXACT; ≥2 corroborating signals → STRONG; single signal → PROVISIONAL; none → UNKNOWN.
`mayReuseContentDNA` is TRUE only at EXACT/STRONG — **never reuse ContentDNA across weak (PROVISIONAL/UNKNOWN) identity**
as if exact (tested).
