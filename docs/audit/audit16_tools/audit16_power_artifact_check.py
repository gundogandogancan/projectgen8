#!/usr/bin/env python3
# AUDIT16 auditor tool (add-only): re-derive the n-selection law minima and detection-limit
# minima from the COMMITTED power artifact (no builder code involved).
import json

d = json.load(open('docs/calibration/preregistration/tools/RWC_CALIBRATION_POWER_RESULTS_V3.json'))
cells = d['cells']
k0 = next(iter(cells))
print('sample cell:', k0, cells[k0])
for n in ['400', '800', '1600']:
    tgt = [(k, v) for k, v in cells.items()
           if ('n' + n) in k and ('over07' in k or 'under07' in k)]
    if tgt:
        rate_key = 'rejection_rate' if 'rejection_rate' in tgt[0][1] else sorted(tgt[0][1])[0]
        mn = min(v[rate_key] for _, v in tgt)
        print('n' + n, 'min(over07,under07) =', mn, 'cells:', len(tgt))
for alt in ['tail07', 'osc05', 'localized07', 'null']:
    t = [(k, v) for k, v in cells.items() if alt in k and 'n800' in k]
    if t:
        rate_key = 'rejection_rate' if 'rejection_rate' in t[0][1] else sorted(t[0][1])[0]
        vals = [v[rate_key] for _, v in t]
        print(alt, 'n800 min/max', min(vals), max(vals))
