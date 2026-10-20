# RWC-PRE-03 — LEGACY CALIBRATION RETIREMENT (closes BLK-A11-LEGACY-P008)

Inventory: `CalibrationPilotRunner` + `LogisticCalibrator` + `enum CalibrationMetrics`
(CalibrationPilot.swift / CalibrationMetrics.swift); callers = P008/P008A historical tests + AUDIT11
pinned probes only. Strategy chosen: HARDEN + EXPLICIT ENGINEERING-ONLY (not deletion - historical
negative evidence is an asset, FM-014): pilot FAILED (false-safe 0.50), calibration truth CONTRADICTED -
all preserved immutably.
Mechanisms (behavior UNCHANGED - AUDIT11 pins legacy semantics):
1. `EngineeringOnlyExecutionContextV1` - the ONLY context `CalibrationPilotRunner.run` accepts; a
   real-world case does NOT exist in the type, so real-world code cannot even express the call
   (compile-time separation; adding a case is an FM-013/FM-014-class violation).
2. Deprecation markers on the runner and the legacy metrics enum naming the lawful real-world path.
3. Bridgeless type worlds: no API converts PreparedCalibrationDatasetV1 <-> PilotExample;
   RealWorldCalibrationExecutorV1 references zero pilot types (source-surface tested).
Historical tests remain; fresh tests prove the real-world surface cannot enter the pilot.
