# R23 MVP Local Validation Run — 2026-05-05

Local MATLAB validation of the R23 AAS MVP repository against
`origin/main` after PR #30–#33 merged. This run executed `run_all_tests`
plus the targeted R23 power-semantics and scenario-preset suites and the
end-to-end `runR23AasEirpCdfGrid` example surface. No source files were
modified during this pass.

## Environment

| Field | Value |
| --- | --- |
| Commit SHA tested | `0c6e5e53f4c625f450e19fa1550f75aba9a79b90` |
| Commit message | Merge pull request #33 from nicklasorte/claude/remove-rooftop-metadata-l3CD2 |
| MATLAB version | 25.2.0.3150157 (R2025b) Update 4 |
| Operating System | macOS 26.3.1 (Build 25D2128) |
| Date | 2026-05-05 |
| Runner | MATLAB MCP server (local) |

## Tests executed

* `run_all_tests.m` (full suite, 27 tests)
* `test_r23_power_semantics` (targeted, 7 sub-checks)
* `test_r23ScenarioPreset` (targeted, 13 sub-checks)
* `runR23AasEirpCdfGrid()` (default + small grids; preset paths exercised
  end-to-end inside `test_r23ScenarioPreset` S5)

## Pass / fail summary

```
total=27   pass=25   fail=0   error=0   skip=2
RESULT: ALL TESTS PASSED
```

The two skips are external Python dependency skips, not MATLAB failures:

| Test | Status | Reason |
| --- | --- | --- |
| `test_against_pycraf` | SKIP | `ModuleNotFoundError: No module named 'numpy'` |
| `test_against_pycraf_strict` | SKIP | `ModuleNotFoundError: No module named 'numpy'` |

### Active tests (25 / 25 pass)

| # | Test | Result |
| --- | --- | --- |
| 1 | `test_aas_monte_carlo_eirp` | PASS |
| 2 | `test_export_eirp_percentile_table` | PASS |
| 3 | `test_ue_sector_sampler` | PASS |
| 4 | `test_runtime_scaling_controls` | PASS |
| 5 | `test_r23_aas_defaults` | PASS |
| 6 | `test_r23_extended_aas_eirp` | PASS |
| 7 | `test_imtAasEirpGrid` | PASS |
| 8 | `test_imtAasValidationExport` | PASS |
| 9 | `test_imtAasReferenceComparison` | PASS |
| 10 | `test_imtAasBeamAngles` | PASS |
| 11 | `test_imtAasSectorEirpGridFromBeams` | PASS |
| 12 | `test_runR23AasEirpCdfGrid` | PASS |
| 13 | `test_single_sector_eirp_mvp` | PASS |
| 14 | `test_r23_mvp_acceptance_contract` | PASS |
| 15 | `test_r23_ground_truth_antenna_geometry` | PASS |
| 16 | `test_r23_eirp_power_normalization` | PASS |
| 17 | `test_r23_grid_rotation_symmetry` | PASS |
| 18 | `test_r23_monte_carlo_and_cdf` | PASS |
| 19 | `test_r23_mvp_runtime_memory_guardrails` | PASS |
| 20 | `test_r23_streaming_vs_full_cube_equivalence` | PASS |
| 21 | `test_r23_mvp_antenna_primitives` | PASS |
| 22 | `test_r23DefaultParams` | PASS |
| 23 | `test_r23_parameterized_run` | PASS |
| 24 | `test_r23_power_semantics` | PASS |
| 25 | `test_r23ScenarioPreset` | PASS |

## Targeted detail: `test_r23_power_semantics`

```
PASS  S1: r23DefaultParams: maxEirp=78.300000 (78.3), conducted=46.100000 (46.1),
          peakGain=32.200000 (32.2), 46.1+32.2 = 78.300000 (=78.3)
PASS  S2: imtAasDefaultParams + r23ToImtAasParams agree on 78.3 / 46.1 / 32.2
PASS  S3: maxEirp does not exceed sector peak (deterministic=78.300000 dBm,
          streaming=78.300000 dBm, sectorPeak=78.300000 dBm, tol=1.0e-06)
PASS  S4: +X dB shift in maxEirp gives exactly +X dB shift in EIRP (det median
          delta=-3.300000, stream median delta=-3.300000, peakHi=78.300000,
          peakLo=75.000000)
PASS  S5: no value consistent with double-counted maxEirp+peakGain=110.500
          (streamMax=77.422072, sectorPeak=78.300, gap=33.078 dB)
PASS  S6: split rule perBeamPeak = sectorEirp - 10*log10(N) holds for
          N=[1 2 3 5]; N identical beams sum back to sectorEirp
PASS  S7: pointing heatmap shape [7 3], units=degrees, az circular-mean
          convention, az in [-60,60], el in [-10,0]
ALL TESTS PASSED
```

## Targeted detail: `test_r23ScenarioPreset`

```
PASS  S1:  r23ScenarioPreset("urban-baseline") returns a struct with
           scenarioPreset metadata
PASS  S2:  urban-baseline -> environment=urban, cellRadius=400, bsHeight=18,
           3 UEs
PASS  S3:  suburban-baseline -> environment=suburban, cellRadius=800,
           bsHeight=20, 3 UEs
PASS  S4:  presets preserve 78.3 dBm sector EIRP, 100 MHz BW, shared Extended
           AAS table
PASS  S5:  runR23AasEirpCdfGrid(params) works for every preset
PASS  S6:  scenarioPreset / scenarioCategory / sourceReference / reproducible
           propagate into out.metadata
PASS  S7:  invalid preset name fails cleanly with the offending name
PASS  S8:  out.selfCheck.powerSemantics is populated with all required fields
PASS  S9a: power self-check status=pass when observed <= sector peak with
           small shortfall
PASS  S9b: power self-check status=warn on large peak shortfall (does not fail)
PASS  S9c: power self-check status=fail and the runner-equivalent error id
           maps to FAIL
PASS  S10: compareR23ScenarioMetadata diff includes core fields and flags
           expected differences
PASS  S11: overrides ("numUesPerSector"=10, "maxEirpPerSector_dBm"=75) are
           applied and recorded
PASS  S12: referenceOnly metadata is stamped and explicitly marked NOT active
PASS  S12b: preset metadata does NOT expose belowRooftop/rooftop/clutter fields
ALL TESTS PASSED
```

## End-to-end runner sanity

`runR23AasEirpCdfGrid(opts)` (small grid: `azGridDeg = -60:20:60`,
`elGridDeg = -10:2:0`, `numSnapshots = 20`):

```
numBeams                = 3
sectorEirpDbm           = 78.3
perBeamPeakEirpDbm      = 73.5288
selfCheck.powerSemantics.status = pass
elapsed                 = 3.10 s
```

Urban / suburban presets are exercised by `test_r23ScenarioPreset` S5
(`runR23AasEirpCdfGrid(params)` works for every preset).

## Invariant confirmation

| Invariant | Source of evidence | Result |
| --- | --- | --- |
| 1. EIRP semantics — no double-counting (`EIRP = maxEirp + relativeGainOffset`, not `EIRP + gain`) | `test_r23_power_semantics` S5: 33.078 dB gap from the double-counted `78.3 + 32.2 = 110.5 dBm` value | OK |
| 2. Sector peak bound (`observedMaxGridEirp_dBm <= maxEirpPerSector_dBm + tol`) | `test_r23_power_semantics` S3: observed 78.300000 dBm = sector peak within 1e-6 tol | OK |
| 3. Peak miss → warn, not fail | `test_r23ScenarioPreset` S9a/S9b/S9c: pass / warn / fail status returned correctly; FAIL only on exceedance | OK |
| 4. Scenario preset scope (no rooftop / below-rooftop / clutter exposure) | `test_r23ScenarioPreset` S12b: `metadata.referenceOnly` excludes all banned fields | OK |
| 5. Reference-only metadata stamped, not active | `test_r23ScenarioPreset` S12: `networkLoadingFactor` and `bsTddActivityFactor` marked NOT active | OK |
| 6. MVP scope guard (no path loss / clutter / receiver / I/N / aggregation / 19-site / 57-sector) | `test_r23_mvp_acceptance_contract` C6 / C7: scope guard clean across MVP core, no legacy tokens | OK |

## Files changed

None. The merged HEAD is healthy as-is; no fix commits were required
during this validation pass.

## Notes

* The default-grid `runR23AasEirpCdfGrid()` example with the full
  `325 x 103` percentile table exceeded the MATLAB MCP request timeout
  when invoked over a single MCP call. The same surface is exercised
  end-to-end by `test_r23ScenarioPreset` S5 (which sweeps both urban and
  suburban presets through `runR23AasEirpCdfGrid`) and by
  `test_runR23AasEirpCdfGrid` T1–T10. Smaller-grid invocations
  completed in under 4 s and returned `selfCheck.powerSemantics.status = pass`.
* `test_against_pycraf` and `test_against_pycraf_strict` skipped
  cleanly because `numpy` / `pycraf` is not installed in the local
  Python environment. These are external comparison checks; their skip
  status does not gate the MATLAB MVP.

## Confirmations

* No new modeling features were added.
* No path loss, clutter, receiver antenna, I/N, aggregation, or
  19-site / 57-sector behaviour was introduced.
* Preset layer does not expose `belowRooftop` / `rooftop` / `clutter`
  fields anywhere in metadata, referenceOnly metadata, inputs, or docs
  (only as explicit "NOT exposed" doc-comment notes).
* `runR23AasEirpCdfGrid()`, `r23DefaultParams("urban")`,
  `r23ScenarioPreset("urban-baseline")`, and
  `r23ScenarioPreset("suburban-baseline")` all work end-to-end.
