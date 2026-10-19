# P007B — Control Center Device Test

## Automatable evidence (verified headlessly)
- The widget-extension process **runs on the physical iPhone** (pid 7139, `GuardianControlExtension.appex`), signed
  under team 47XQMQZLF6. This proves the extension loads on hardware under the supported widget-extension point.
- ON/OFF logic is backed by `GuardianActivationController` (single source of truth) + `SetValueIntent.perform` →
  `GuardianControlState.setEnabled`; OFF-cancels-work and stale-discard are covered by headless tests (P006/P007).

## Requires manual on-device operation (an automated agent cannot tap Control Center)
The following need a human to operate the device UI and observe; they are NOT yet captured:
1. Control appears in the Control Center gallery → 2. add to Control Center → 3. OFF→ON → 4. ON→OFF →
5. app not running → 6. app running → 7. app killed/relaunched → 8. extension recreated → 9. rapid ON/OFF →
10. OFF during active analysis.

### ⚠️ Shared-state caveat on this team
Because App Groups are not provisionable on team 47XQMQZLF6 (free/personal; see device-install evidence), the control
and the app read/write **separate** `UserDefaults.standard` domains → toggling in Control Center will **not** reflect in
the app (and vice-versa) on this team. Cross-process sync requires a paid membership + App Group. The toggle itself
(intent perform) will run; state propagation across processes is the gap.

## Status
`COMPILED_AND_EXTENSION_RUNS_ON_DEVICE; INTERACTIVE_TOGGLE_PROOF_PENDING_MANUAL_OPERATION`. Cross-process state sync
`BLOCKED_PENDING_PAID_APP_GROUP`.
