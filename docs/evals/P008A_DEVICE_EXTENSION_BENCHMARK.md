# P008A — Device Extension-Safe Intelligence Benchmark (§19)
## Status: NOT MEASURED ON DEVICE — `DEVICE_EVIDENCE_INSUFFICIENT`.
The broadcast extension's heads only execute while a broadcast is ACTIVE, which requires the user's Start-Broadcast
gesture (OS consent, one-tap-per-session) — an automated agent cannot trigger it headlessly. So boundary-detector /
optional-OCR / Vision latency, memory high-water, CPU, thermal, and first-trustworthy fast-path time INSIDE the extension
are not yet measured on the iPhone. LAB-host costs of the cheap heads exist (P007/P008 benchmarks) but are NOT the
~50 MB extension runtime. To obtain this: user starts a broadcast, Instruments/signposts attach, pull extension-local
logs. No device numbers are fabricated. The EXTENSION_FAST_PACK membership rule ("remove a head that destabilizes the
extension") is defined and applied once device data exists.
