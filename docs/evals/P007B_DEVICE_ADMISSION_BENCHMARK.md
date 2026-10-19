# P007B — Device Admission Benchmark

## Status: NO `DEVICE_MEASURED_REAL_PIPELINE` SAMPLES CAPTURED
Measuring the full pipeline on the device requires an **on-device XCTest target** that runs the real stages on arm64/iOS
and emits per-route latencies. The project has no such test target wired (the GuardianKit suite runs on the macOS host
via `swift test`). An automated shell agent cannot run those tests on the device without that target.

- The REAL **lab-host** measured pipeline stands (`P007A_REAL_PIPELINE_ADMISSION_BENCHMARK.md`,
  evidence_class LAB_MEASURED_REAL_PIPELINE): real OCR ~218 ms, video ~85 ms, audio ~38 ms, speech
  BLOCKED_NOT_AUTHORIZED, deterministic routes sub-ms.
- **No modeled stage** has been promoted into any device percentile (there are no device percentiles).

## To obtain device percentiles (pending)
Add an app-hosted XCTest target replicating `P007ARealPipelineBenchmarkTests`, run `xcodebuild test -destination
'platform=iOS,id=…'` with multi-run warmup → p50/p95/p99 per route, label `DEVICE_MEASURED_REAL_PIPELINE`.

## Status
`DEVICE_BENCHMARK_PENDING (no on-device test target); LAB real-pipeline evidence stands`.
