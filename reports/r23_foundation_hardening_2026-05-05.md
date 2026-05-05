# R23 Foundation Hardening — Provenance + Validation Snapshot Artifacts

Date: 2026-05-05
Branch: `main`
Commit: `f45e2ce`
Parent commit: `203dc61` (validation report 2026-05-05)
MATLAB: 25.2.0.3150157 (R2025b) Update 4
Platform: mac-maca64

This pass adds **lightweight observability and reproducibility hardening
only**. No new RF / system modeling capability was added. The streaming
Monte Carlo invariant is preserved (no raw cube persistence).

## Files added

| Path | Purpose |
| --- | --- |
| `matlab/exportR23ValidationSnapshot.m` | Lightweight reproducibility artifact exporter |
| `matlab/test_r23_validation_artifacts.m` | A1–A8 sub-checks for provenance + snapshot export |

## Files modified

| Path | Change |
| --- | --- |
| `matlab/runR23AasEirpCdfGrid.m` | Stamped four provenance fields on `out.metadata`; added three private helpers |
| `run_all_tests.m` | Registered `test_r23_validation_artifacts` |
| `README.md` | New "Validation Snapshot Artifacts" section |

## Provenance fields (best-effort, never fatal)

Stamped onto `out.metadata` by `runR23AasEirpCdfGrid`:

| Field | Source | Fallback |
| --- | --- | --- |
| `repoCommitSha` | `git -C <repoRoot> rev-parse HEAD 2>/dev/null` | `'unknown'` |
| `matlabVersion` | `version` + `version('-release')` | `'unknown'` |
| `platform` | `ispc / ismac / isunix` + `computer('arch')` | `'unknown'` |
| `validationTimestampUtc` | ISO 8601 UTC string via `datetime` | `datestr(now, ...)` |

All four use `try/catch` so the runner never hard-fails when git is
absent or the platform query fails.

## Exported artifacts (per call to `exportR23ValidationSnapshot`)

```
outputDir/
  metadata.json           - run metadata (provenance + scenario)
  selfcheck.json          - power-semantics self-check struct
  scenario_diff.json      - scenarioPreset / overrides / referenceOnly + core fields
  percentile_summary.csv  - per-percentile min/median/max across the (az,el) grid
  validation_summary.txt  - human-readable provenance + status sheet
```

The full per-draw EIRP cube is **never** written. The streaming
histogram is intentionally not exported. Each artifact stays well
below 256 KiB — A8 enforces this cap. On the demo run,
`metadata.json` was 2161 bytes; the other files were of similar order.

## Tests added: `test_r23_validation_artifacts`

| ID | Assertion |
| --- | --- |
| A1 | `out.metadata` carries all four provenance fields (`repoCommitSha`, `matlabVersion`, `platform`, `validationTimestampUtc`) |
| A2 | Snapshot directory is created when missing |
| A3 | All five expected files written (`metadata.json`, `selfcheck.json`, `scenario_diff.json`, `percentile_summary.csv`, `validation_summary.txt`) |
| A4 | `metadata.json` contains the active `scenarioPreset` (`urban-baseline` for the test run) |
| A5 | `metadata.json` contains a `repoCommitSha` field (presence, not value — `'unknown'` is acceptable for git-less environments) |
| A6 | `selfcheck.json` carries the `powerSemantics` / `status` field |
| A7 | `validation_summary.txt` contains the self-check status text (e.g. `pass` / `warn` / `fail`) |
| A8 | Each artifact ≤ 256 KiB |

All eight sub-checks PASS in this run.

## Test suite result (full `run_all_tests`)

```
total=28   pass=26   fail=0   error=0   skip=2
RESULT: ALL TESTS PASSED
```

The two skips are the external `pycraf` / `numpy` comparison tests
(`test_against_pycraf` and `test_against_pycraf_strict`) — same as the
prior validation pass.

## Sample artifact: `validation_summary.txt`

```
R23 AAS EIRP Validation Snapshot
================================

Provenance
  matlabVersion          : 25.2.0.3150157 (R2025b) Update 4 (R2025b)
  repoCommitSha          : 203dc6129e8e649dd3e3e21338126b8401fa652e
  platform               : mac-maca64
  validationTimestampUtc : 2026-05-05T22:44:25Z

Scenario
  scenarioPreset         : urban-baseline
  environment            : urban
  numUesPerSector        : 3
  maxEirpPerSector_dBm   : 78.3
  splitSectorPower       : true
  cellRadius_m           : 400
  bsHeight_m             : 18
  numMc / numSnapshots   : 5

Power-semantics self-check
  status                 : pass
  observedMaxGridEirp_dBm: 76.88877788
  expectedSectorPeak_dBm : 78.3
  expectedPerBeamPeak_dBm: 73.52878745
  peakShortfall_dB       : -3.359990426
  tolerance_dB           : 1e-06

Scope
  Antenna-face EIRP only. No path loss, no clutter, no
  receiver antenna, no I/N, no propagation, no coordination
  distance, no multi-site aggregation. This snapshot is a
  lightweight reproducibility metadata sidecar, NOT a raw
  Monte Carlo store.
```

## Sample artifact: `percentile_summary.csv`

```
percentile,minAcrossGrid_dBm,medianAcrossGrid_dBm,maxAcrossGrid_dBm,numFiniteCells
1,53.500000,60.500000,73.500000,6
5,53.500000,60.500000,73.500000,6
10,53.500000,60.500000,73.500000,6
20,53.500000,60.500000,73.500000,6
50,61.500000,68.500000,76.500000,6
80,64.500000,71.000000,76.500000,6
90,66.500000,74.500000,76.500000,6
95,66.500000,74.500000,76.500000,6
99,66.500000,74.500000,76.500000,6
```

Per-percentile min / median / max across the (az, el) grid only —
this is a small reproducibility *fingerprint*, not the full
`Naz × Nel × Np` percentile cube.

## Example usage

```matlab
addpath('matlab');
params = r23ScenarioPreset("urban-baseline");
out    = runR23AasEirpCdfGrid(params);
exportR23ValidationSnapshot(out, "artifacts/run001");
```

After running, `artifacts/run001/` contains the five-file snapshot;
`out.metadata` carries the provenance fields for inline inspection.

## Scope guard

Confirmed that this slice does NOT introduce:

* path loss
* clutter, rooftop, below-rooftop modeling
* receiver antenna or receiver gain
* I / N or aggregate compatibility metrics
* propagation
* coordination distance
* multi-site aggregation, 19-site / 57-sector deployment
* network loading or TDD activity behavior (the runner-side modeling
  for these remains absent; `referenceOnly` metadata is still
  reference-only)
* raw cube persistence
* binary blob exports
* database / telemetry / cloud infrastructure

The implementation is plain MATLAB + filesystem I / O, with `git` and
`version` queries that degrade gracefully to `'unknown'` if the
environment lacks them.

## Related commits

* [`f45e2ce`](https://github.com/nicklasorte/imt-matlab/commit/f45e2ce) — provenance metadata + snapshot helper + tests + README
* [`203dc61`](https://github.com/nicklasorte/imt-matlab/commit/203dc61) — prior validation report (2026-05-05)
* [`0c6e5e5`](https://github.com/nicklasorte/imt-matlab/commit/0c6e5e5) — PR #33 (below-rooftop cleanup), parent of the validated foundation
