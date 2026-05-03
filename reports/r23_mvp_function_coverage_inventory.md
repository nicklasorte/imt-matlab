# R23 MVP function coverage inventory

_Static-analysis inventory of every MATLAB function under `matlab/`, the test
that exercises it (directly or indirectly), and the residual coverage gaps in
the R23 single-sector EIRP CDF-grid MVP._

This report was produced by `R23-AAS-COVERAGE-01`. It is purely a coverage
inventory: it adds at most one focused test where a clear high-risk gap is
identified, and changes no implementation. Out-of-scope items (path loss,
clutter, FS / FSS modeling, interference aggregation, 19-site / 57-sector
laydown, network-level scheduling) are intentionally not covered here and
remain explicitly out of scope per `CLAUDE.md`.

## Methodology

- Enumerated every `matlab/*.m` file (82 files total: 57 implementation /
  utility / demo / plot files plus 22 test scripts; demo and plot files are
  not unit-tested by design).
- Built a static call-graph: for each function `F`, which `matlab/*.m` files
  reference `F\s*(`. A test that calls `F` directly counts as **direct**
  coverage; a test that calls a function whose call-graph closure includes
  `F` counts as **indirect** coverage.
- Confirmed the MVP core path against the AAS-01 contract enforced by
  `test_r23_mvp_acceptance_contract.c1_public_api_exists` and
  `generate_r23_mvp_readiness_report.check_core_files`.

## MVP core path (the contract)

The R23 single-sector EIRP CDF-grid MVP is defined by this exact set of
public functions (matching `test_r23_mvp_acceptance_contract.c1` and the
`check_core_files` list in `generate_r23_mvp_readiness_report.m`, extended
with the auxiliary primitives listed in the AAS-01 task description):

| MVP function | Role |
| --- | --- |
| `get_r23_aas_params` | R23 7.125-8.4 GHz Extended AAS parameter struct |
| `validate_r23_params` | sanity-check the parameter struct |
| `get_default_bs` | R23-aligned default BS input struct |
| `generate_single_sector_layout` | sector geometry / coverage envelope |
| `sample_ue_positions_in_sector` | seeded UE laydown inside the sector |
| `compute_beam_angles_bs_to_ue` | BS-to-UE pointing angles |
| `clamp_beam_to_r23_coverage` | clamp pointing into +/-60 az and -10..0 el |
| `compute_element_pattern` | M.2101 Table 4 single-element gain (snake_case wrapper) |
| `compute_subarray_factor` | L-element vertical sub-array factor (snake_case primitive) |
| `compute_array_factor` | N_H x N_V outer + L sub-array factor (snake_case wrapper) |
| `compute_bs_gain_toward_grid` | full BS composite gain over a grid |
| `compute_eirp_grid` | per-(az,el) EIRP grid for a beam set |
| `run_monte_carlo_snapshots` | seeded Monte Carlo over UE laydowns |
| `compute_cdf_per_grid_point` | per-cell percentile / CDF maps |
| `runR23AasEirpCdfGrid` | streaming-aggregator CDF runner |
| `update_eirp_histograms` | streaming-aggregator histogram update |
| `eirp_percentile_maps` | percentile maps from streaming stats |
| `estimate_r23_mvp_cube_memory` | memory guardrail estimator |
| `generate_r23_mvp_readiness_report` | one-command readiness artifact |

## Coverage table - MVP core path

Risk legend: **H** = high (own math, no direct or indirect coverage), **M** =
medium (wrapper / argument shuffle, indirect coverage only), **L** = low
(directly tested with strong invariants).

| MVP function | MVP core | Direct test? | Indirect test? | Test files | Risk | Recommended action |
| --- | --- | --- | --- | --- | --- | --- |
| `get_r23_aas_params` | yes | yes | yes | `test_single_sector_eirp_mvp` (S2), `test_r23_eirp_power_normalization`, `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry`, `test_r23_monte_carlo_and_cdf`, `test_r23_mvp_acceptance_contract` (C2), `test_r23_mvp_runtime_memory_guardrails`, `test_r23_streaming_vs_full_cube_equivalence` | L | no action |
| `validate_r23_params` | yes | yes | no | `test_single_sector_eirp_mvp` (S2) | L | no action |
| `get_default_bs` | yes | yes | yes | `test_single_sector_eirp_mvp` (S1), `test_r23_eirp_power_normalization`, `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry`, `test_r23_monte_carlo_and_cdf`, `test_r23_mvp_acceptance_contract`, `test_r23_mvp_runtime_memory_guardrails`, `test_r23_streaming_vs_full_cube_equivalence` | L | no action |
| `generate_single_sector_layout` | yes | yes | yes | `test_single_sector_eirp_mvp` (S3, S14), `test_r23_eirp_power_normalization`, `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry`, `test_r23_monte_carlo_and_cdf`, `test_r23_mvp_acceptance_contract` | L | no action |
| `sample_ue_positions_in_sector` | yes | yes | yes | `test_single_sector_eirp_mvp` (S4), `test_r23_monte_carlo_and_cdf` (T3) | L | no action |
| `compute_beam_angles_bs_to_ue` | yes | yes | yes | `test_single_sector_eirp_mvp` (S5, S11, S14), `test_r23_eirp_power_normalization`, `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry`, `test_r23_mvp_acceptance_contract` | L | no action |
| `clamp_beam_to_r23_coverage` | yes | yes | yes | `test_single_sector_eirp_mvp` (S6, S14), `test_r23_eirp_power_normalization`, `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry`, `test_r23_mvp_acceptance_contract` | L | no action |
| `compute_element_pattern` | yes | **no** | yes (via `imtAasCompositeGain` -> `imtAasElementPattern`, exercised by `test_imtAasEirpGrid`, `test_imtAasValidationExport`) | _none direct_ | M | **add focused test** (wrapper swaps `(theta, phi)` -> `(az, el)`; a silent argument-order regression would not be caught by composite-gain tests because the R23 default params are nearly square in the boresight cut) |
| `compute_subarray_factor` | yes | **no** | **no** (its math is a parallel implementation of the L-sub-array branch inside `imtAasArrayFactor`; nothing in the codebase calls it) | _none_ | **H** | **add focused test** (own math, zero callers, zero coverage) |
| `compute_array_factor` | yes | **no** | yes (via `imtAasArrayFactor`, exercised by `test_imtAasEirpGrid`, `test_imtAasValidationExport`) | _none direct_ | M | **add focused test** (wrapper swaps `(theta, phi)` -> `(az, el)` and unpacks a struct steering form that is unique to this wrapper) |
| `compute_bs_gain_toward_grid` | yes | yes | yes | `test_single_sector_eirp_mvp` (S7), `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry` | L | no action |
| `compute_eirp_grid` | yes | yes | yes | `test_single_sector_eirp_mvp` (S8, S12), `test_r23_eirp_power_normalization`, `test_r23_grid_rotation_symmetry`, `test_r23_ground_truth_antenna_geometry`, `test_r23_mvp_acceptance_contract` | L | no action |
| `run_monte_carlo_snapshots` | yes | yes | yes | `test_single_sector_eirp_mvp` (S9), `test_r23_monte_carlo_and_cdf`, `test_r23_mvp_runtime_memory_guardrails`, `test_r23_mvp_acceptance_contract`, `test_r23_streaming_vs_full_cube_equivalence` | L | no action |
| `compute_cdf_per_grid_point` | yes | yes | yes | `test_single_sector_eirp_mvp` (S10), `test_r23_monte_carlo_and_cdf`, `test_r23_mvp_acceptance_contract`, `test_r23_streaming_vs_full_cube_equivalence` | L | no action |
| `runR23AasEirpCdfGrid` | yes | yes | yes | `test_runR23AasEirpCdfGrid`, `test_r23_streaming_vs_full_cube_equivalence` | L | no action |
| `update_eirp_histograms` | yes | no | yes (via `run_imt_aas_eirp_monte_carlo` and `runR23AasEirpCdfGrid`; `test_r23_streaming_vs_full_cube_equivalence` pins streaming-vs-full-cube equality, `test_aas_monte_carlo_eirp` pins histogram-count totals, `test_runtime_scaling_controls` pins chunked-vs-unchunked bit-equality) | L | no action (strong streaming invariants already enforced) |
| `eirp_percentile_maps` | yes | yes | yes | `test_aas_monte_carlo_eirp`, `test_r23_streaming_vs_full_cube_equivalence` (E3), `test_ue_sector_sampler` | L | no action |
| `estimate_r23_mvp_cube_memory` | yes | yes | yes | `test_r23_mvp_runtime_memory_guardrails` (G2, G3, G4) | L | no action |
| `generate_r23_mvp_readiness_report` | yes | no | no (it is a reporting utility - it _runs_ the test suite but is not itself under test) | _none_ | L | no action (no math; legacy hygiene scan and core-file inventory are simple file-system reads; intentionally not unit-tested per the "do not add broad tests for every file" rule) |

## Coverage table - non-MVP files

These files exist for the AAS-01/AAS-02 export pipeline, the original
streaming Monte Carlo path, demos, plotting, profiling, or pycraf parity.
None of them are required for the R23 single-sector EIRP CDF-grid MVP, so
they are not in scope for this inventory beyond confirming "no missing
coverage that the MVP relies on".

| File | Role | Tested by | Notes |
| --- | --- | --- | --- |
| `imt2020_single_element_pattern` | M.2101 single-element pattern | `test_against_pycraf`, `test_against_pycraf_strict`, `test_aas_monte_carlo_eirp` | strict 1e-6 dB pycraf gate |
| `imt2020_composite_pattern` | M.2101 composite pattern | `test_against_pycraf`, `test_against_pycraf_strict`, `test_aas_monte_carlo_eirp`, `test_r23_extended_aas_eirp` | strict 1e-6 dB pycraf gate |
| `imt2020_composite_pattern_extended` | R23 extended composite pattern | `test_r23_extended_aas_eirp` | not bit-equivalent to pycraf (by design) |
| `imt_aas_bs_eirp` | M.2101 / R23 BS EIRP dispatcher | `test_aas_monte_carlo_eirp`, `test_r23_extended_aas_eirp` | dispatches on `cfg.patternModel` |
| `imt_aas_mechanical_tilt_transform` | sector -> panel-frame rotation | indirectly via `imt2020_composite_pattern_extended`, `imtAasCompositeGain` | exercised in every R23 path |
| `imt_r23_aas_defaults` | R23 Monte Carlo cfg | `test_r23_aas_defaults`, `test_r23_extended_aas_eirp` | snake_case parallel of `imtAasDefaultParams` |
| `imt_r23_aas_eirp_grid` | R23 deterministic grid (snake_case) | `test_r23_extended_aas_eirp` | |
| `run_imt_aas_eirp_monte_carlo` | streaming Monte Carlo runner | `test_aas_monte_carlo_eirp`, `test_runtime_scaling_controls`, `test_ue_sector_sampler`, `test_r23_extended_aas_eirp` | |
| `sample_aas_beam_direction` | UE-sector beam sampler | `test_ue_sector_sampler` | |
| `eirp_cdf_at_angle` | per-angle CDF from streaming stats | demos only | helper utility |
| `eirp_exceedance_maps` | exceedance maps from streaming stats | `test_aas_monte_carlo_eirp`, `test_ue_sector_sampler` | |
| `export_eirp_percentile_table` | percentile-table CSV export | `test_export_eirp_percentile_table`, `test_ue_sector_sampler` | |
| `estimate_aas_mc_memory` | memory estimator (streaming path) | `test_runtime_scaling_controls` | |
| `profile_aas_monte_carlo_runtime` | runtime profiler | `test_runtime_scaling_controls` | |
| `imtAasDefaultParams` | camelCase parameter defaults | `test_imtAasEirpGrid`, `test_imtAasValidationExport`, `test_imtAasSectorEirpGridFromBeams`, `test_runR23AasEirpCdfGrid`, `test_r23_streaming_vs_full_cube_equivalence` | underlies `get_r23_aas_params` |
| `imtAasElementPattern` | camelCase element pattern | indirect via `imtAasCompositeGain` (in `test_imtAasEirpGrid`, `test_imtAasValidationExport`) | |
| `imtAasArrayFactor` | camelCase array factor | indirect via `imtAasCompositeGain` (in `test_imtAasEirpGrid`, `test_imtAasValidationExport`) | |
| `imtAasCompositeGain` | camelCase composite gain | `test_imtAasEirpGrid` | |
| `imtAasNormalizeGrid` | scalar/vector/2-D grid normalizer | indirect via `imtAasArrayFactor`, `imtAasCompositeGain` | utility |
| `imtAasEirpGrid` | per-cell EIRP from composite gain | `test_imtAasEirpGrid`, `test_imtAasValidationExport`, `test_imtAasBeamAngles` | |
| `imtAasGenerateBeamSet` | beam-set generator | `test_imtAasBeamAngles`, `test_imtAasSectorEirpGridFromBeams`, `test_runR23AasEirpCdfGrid`, `test_r23_streaming_vs_full_cube_equivalence` | |
| `imtAasSampleUePositions` | camelCase UE laydown | `test_imtAasBeamAngles` (indirect via `imtAasGenerateBeamSet`) | wraps `sample_ue_positions_in_sector` for camelCase callers |
| `imtAasSingleSectorParams` | camelCase sector geometry | `test_imtAasBeamAngles`, `test_imtAasSectorEirpGridFromBeams`, `test_r23_streaming_vs_full_cube_equivalence` | |
| `imtAasUeToBeamAngles` | UE -> beam steering angles | `test_imtAasBeamAngles` | |
| `imtAasApplyBeamLimits` | clamp beam to sector limits | `test_imtAasBeamAngles` | |
| `imtAasSectorEirpGridFromBeams` | per-(az,el) EIRP grid from beams | `test_imtAasSectorEirpGridFromBeams`, `test_runR23AasEirpCdfGrid` | |
| `imtAasCreateDefaultSectorEirpGrid` | one-call default sector EIRP grid | _no direct test_ | helper that composes already-tested primitives; low risk |
| `imtAasPatternCuts` | extract pattern cuts | `test_imtAasValidationExport` | |
| `imtAasComparePatternCut` | reference-cut comparison | `test_imtAasReferenceComparison` | |
| `imtAasLoadReferenceCutCsv` | reference-cut CSV loader | `test_imtAasReferenceComparison` | |
| `imtAasExportEirpGridCsv` | EIRP-grid CSV export | `test_imtAasValidationExport` | |
| `run_monte_carlo_snapshots` (already MVP) | covered above | | |
| `run_single_sector_eirp_demo` | end-to-end demo | `test_single_sector_eirp_mvp` (S13) | |
| `plotImtAasEirpGrid` | plotting | _none_ | plotting utility, no math |
| `plotImtAasPatternCuts` | plotting | `test_imtAasValidationExport` (smoke) | |
| `plotImtAasReferenceComparison` | plotting | `test_imtAasReferenceComparison` (smoke) | |
| `plotImtAasSectorEirpGrid` | plotting | _none_ | |
| `plotR23AasEirpCdfGrid` | plotting | _none_ | |
| `plot_or_export_results` | plotting / export dispatcher | indirect via `run_single_sector_eirp_demo` | |
| `demo_aas_monte_carlo_eirp` | demo | _none_ | |
| `demo_export_eirp_percentile_table` | demo | _none_ | |
| `demo_r23_aas_eirp_grid` | demo | _none_ | |

## Identified MVP coverage gaps (high-risk only)

Three MVP-core antenna primitives have **no direct test**:

1. `compute_subarray_factor` (**HIGH risk**): own math, zero callers, zero
   coverage. The L-element vertical sub-array factor is a parallel
   implementation of the corresponding inline branch in `imtAasArrayFactor`
   (lines 113-123). A regression in the closed form (sign of
   `subarrayDowntiltDeg`, M.2101 polar-angle convention, `L = 1` short
   circuit, or `eps`-clamp under nulls) would silently slip through the
   entire MVP because nothing else evaluates it.
2. `compute_array_factor` (**MEDIUM risk**): wrapper around
   `imtAasArrayFactor` that swaps the argument order from `(az, el, ...)`
   to `(theta, phi, steeringAngles, ...)`, plus a struct-form steering
   unpacker that is unique to this wrapper. The wrapped function _is_
   covered indirectly, but the wrapper itself is not.
3. `compute_element_pattern` (**MEDIUM risk**): wrapper around
   `imtAasElementPattern` that swaps `(az, el)` to `(theta, phi)`. A
   silent argument-order regression would not be caught by the
   composite-gain tests because the R23 default beamwidths (90 deg az,
   65 deg el) only differ by ~6 dB at 65 deg off-axis - the bug would
   pass any "rough magnitude" check.

Action: add **one** focused test file - `test_r23_mvp_antenna_primitives.m`
- that pins:

- `compute_element_pattern` boresight peak at `params.elementGainDbi`,
  asymmetric off-axis values that detect a swapped `(theta, phi)` wrapper,
  and exact equality against the underlying `imtAasElementPattern` call.
- `compute_subarray_factor` peak at `theta = -params.subarrayDowntiltDeg`
  with value `10 * log10(L)` (= ~4.77 dB at L = 3), drop below peak at
  `theta = 0`, and the `L = 1` short-circuit returning zero.
- `compute_array_factor` peak gain (panel frame) of ~25.84 dB at
  `(theta, phi) = (-3, 0)` with steering `[0, -3]` for the R23 defaults,
  exact equality against `imtAasArrayFactor` for both vector and
  struct-form steering inputs, and a pure-shape check that the wrapper
  does not introduce a transposition.

This single test file is the entirety of new test code added by this
inventory pass. No implementation files are modified.

## Non-gaps explicitly considered and dismissed

- `update_eirp_histograms`: indirect coverage is strong
  (`test_r23_streaming_vs_full_cube_equivalence` enforces streaming-vs-full
  -cube equality, `test_runtime_scaling_controls` enforces chunked-vs-
  unchunked bit-equality, `test_aas_monte_carlo_eirp` enforces histogram-
  count totals). Adding a direct test would duplicate coverage.
- `generate_r23_mvp_readiness_report`: pure reporting utility, no math, no
  effect on antenna or EIRP outputs. Out of scope for "meaningful MVP
  coverage gaps".
- `imtAasCreateDefaultSectorEirpGrid`: composes already-tested primitives;
  low risk and outside the MVP core path.
- All `plot*` and `demo_*` files: no math; the readiness gate intentionally
  skips them.

## MATLAB execution status

MATLAB was **not available** in this environment (no `matlab` on `PATH`,
no `/usr/local/MATLAB`, and no MATLAB MCP tool surfaced). Per `CLAUDE.md`,
this report does **not** claim that `run_all_tests` or
`generate_r23_mvp_readiness_report` were executed in this pass. The
coverage analysis above is purely static (file enumeration, call-graph
extraction, and reading test source).

The most recent on-disk readiness artifact
(`reports/r23_mvp_readiness_report.md`, generated 2026-05-03 17:27:34 on
MATLAB R2025b Update 4) records 22 tests with 20 PASS / 2 SKIP (pycraf
SKIP) and "READY". The new
`test_r23_mvp_antenna_primitives.m` added in this pass needs to be run by
a follow-up MATLAB-enabled session via:

```matlab
addpath('matlab');
test_r23_mvp_antenna_primitives    % focused test
run_all_tests                      % full suite (will now report 23 tests)
generate_r23_mvp_readiness_report  % refresh the readiness artifact
```

Until that run happens, do not treat the new test as green.
