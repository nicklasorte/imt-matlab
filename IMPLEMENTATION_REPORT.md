# R23-AAS-HARDEN-01: Source-Alignment Hardening — Implementation Report

**Date**: 2026-05-03
**Status**: Complete
**MATLAB Execution**: Not available (static review only)

## Summary

This hardening pass strengthens the existing R23 EIRP CDF-grid MVP by:

1. ✅ **Confirmed**: Zero EMBRSS references in the repository
2. ✅ **Fixed**: Corrected vertical elevation-to-global-theta limit conversion in `generate_single_sector_layout.m`
3. ✅ **Documented**: Added explicit vertical angle conventions section to README.md
4. ✅ **Verified**: All convention-related fields already implemented and tested

## Detailed Findings

### A. EMBRSS References Scan

**Command**: `grep -RIn "EMBRSS\|embrss\|Embrss" .`

**Result**: No matches found — the repository is already clean.

### B. Vertical Convention Implementation Status

The implementation already contains comprehensive vertical convention support:

#### In `compute_beam_angles_bs_to_ue.m` (lines 27–38)
- Exposes `rawElDeg` (internal elevation, 0° = horizon)
- Exposes `rawThetaGlobalDeg` (R23 global theta, 90° = horizon)
- Documents conversion: `thetaGlobalDeg = 90 - elDeg`
- Verified by test S5

#### In `clamp_beam_to_r23_coverage.m` (lines 12–20)
- Exposes both `steerElDeg` and `steerThetaGlobalDeg`
- Exposes `thetaGlobalLimitsDeg = [90, 100]`
- Enforces consistency: conversion is one-line (verified by test S6)

#### In `generate_single_sector_layout.m` (lines 23–29)
- Exposes both `elLimitsDeg` and `verticalCoverageGlobalThetaDeg`
- Documents the relationship via the conversion formula
- **Bug identified and fixed** (see below)

#### In `get_r23_aas_params.m` (lines 24–26)
- Documents vertical coverage: global theta 90°–100° = elevation −10°–0°
- Explicitly states conversion formula

### C. Bug Fix: Elevation Limit Conversion

**Location**: `matlab/generate_single_sector_layout.m`, lines 103–104

**Issue**: The original formula was:
```matlab
layout.elLimitsDeg = [params.vCoverageDegGlobalMin - 90, ...
                      params.vCoverageDegGlobalMax - 90];
```

With R23 defaults (`vCoverageDegGlobalMin = 90`, `vCoverageDegGlobalMax = 100`),
this produced `elLimitsDeg = [0, 10]`, which is **wrong**. The correct internal
elevation limits should be `[-10, 0]`.

**Root Cause**: The conversion `elDeg = 90 - thetaGlobalDeg` is **monotonically
decreasing**, so the limit order must flip:
- `elDegMin = 90 - thetaGlobalMax = 90 - 100 = -10`
- `elDegMax = 90 - thetaGlobalMin = 90 - 90 = 0`

**Fix Applied**:
```matlab
layout.elLimitsDeg = [90 - params.vCoverageDegGlobalMax, ...
                      90 - params.vCoverageDegGlobalMin];
```

Now produces the correct `elLimitsDeg = [-10, 0]`.

**Verification**: The fix is consistent with test S14 (lines 429–435 of
`test_single_sector_eirp_mvp.m`), which checks:
```matlab
okElLim = isequal(layout.elLimitsDeg, [-10, 0]);
okThetaLim = isequal(layout.verticalCoverageGlobalThetaDeg, [90, 100]);
okConv = isequal(verticalCoverageGlobalThetaDeg, ...
                 [90 - layout.elLimitsDeg(2), 90 - layout.elLimitsDeg(1)]);
```

All three now hold true.

### D. Test Coverage

Existing test suite is comprehensive and enforces the vertical convention contract:

| Test | Scope | Location |
| ---- | ----- | -------- |
| S1 | Default BS parameters | line 79–91 |
| S2 | Parameter validation | line 94–112 |
| S3 | Layout generation (az/el limits, cell radius) | line 115–144 |
| S4 | UE sampling (reproducibility, limits) | line 147–168 |
| S5 | Raw beam angles (elevation sign, theta conversion) | line 171–200 |
| S6 | Clamp beam (az/el clipping, theta fields) | line 203–227 |
| S7 | Peak gain (R23 32.2 dBi reference) | line 230–246 |
| S8 | Three identical beams (sector EIRP split) | line 249–284 |
| S9 | MC determinism (seed reproducibility) | line 287–305 |
| S10 | CDF monotonicity (percentile ordering) | line 308–327 |
| S11 | BS height override (elevation dependency) | line 330–358 |
| S12 | BS EIRP override (power scaling) | line 361–393 |
| S13 | End-to-end demo execution | line 396–410 |
| **S14** | **Vertical convention contract** | line 413–484 |

Test S14 explicitly verifies (lines 428–435):
- `layout.elLimitsDeg = [-10, 0]`
- `layout.verticalCoverageGlobalThetaDeg = [90, 100]`
- Conversion: `verticalCoverageGlobalThetaDeg = [90 - elLimitsDeg(2), 90 - elLimitsDeg(1)]`

### E. Documentation Updates

**README.md**: Added "Vertical Angle Conventions" section (after "What was mapped from M.2101-0")

New section documents:
- Internal elevation convention (0° = horizon, negative = downtilt)
- R23 global theta convention (90° = horizon, 100° = 10° below)
- One-line conversion formula with test enforcement
- Explicit references to key functions that expose both representations
- Rationale: dual representation allows callers to use natural convention

## Files Modified

1. **matlab/generate_single_sector_layout.m**
   - Fixed `elLimitsDeg` calculation (line 103–107)
   - Clarified comment about monotonic-decreasing flip

2. **README.md**
   - Added "Vertical Angle Conventions" section (52 lines)
   - Links to key functions and test contract

## Testing Status

**MATLAB MCP**: Not available in this environment

**Static Code Review**:
- ✅ Bug fix is mathematically correct
- ✅ Conversion formula verified against test S14 expectations
- ✅ All dual-representation fields in place and consistent
- ✅ No breaking changes to existing callers (all work on internal elevation)
- ✅ No EMBRSS references anywhere
- ✅ Documentation is clear and links to enforcing tests

**Next Steps** (when MATLAB is available):
```matlab
addpath('matlab');
run_all_tests
```

Expected: All 14 subtests (S1–S14) pass in `test_single_sector_eirp_mvp`.

## Scope Compliance

This hardening pass **strictly adheres to scope**:
- ✅ No path loss added
- ✅ No clutter modeling added
- ✅ No FS/FSS receiver modeling added
- ✅ No interference aggregation added
- ✅ No 19-site laydown added
- ✅ No 57-sector simulation added
- ✅ No network scaling added
- ✅ No UE uplink power control added
- ✅ No terrain modeling added
- ✅ No building entry loss added

Only minimal, targeted fixes to make the vertical convention explicit and correct.

## Checklist

- [x] EMBRSS scan complete (zero matches)
- [x] Elevation-to-global-theta bug identified and fixed
- [x] README documentation updated
- [x] Test contract verified (S14)
- [x] All dual-representation fields present
- [x] No breaking changes to existing callers
- [x] Code review complete
- [x] Scope limits respected

## Git Commit

Branch: `claude/harden-r23-eirp-grid-zMhyl`

Changes:
- `matlab/generate_single_sector_layout.m`: Fix elLimitsDeg calculation
- `README.md`: Add Vertical Angle Conventions section

Commit message: "Harden R23 vertical convention: fix elLimitsDeg, document theta↔elev"
