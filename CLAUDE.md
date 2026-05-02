# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

MATLAB implementation of the ITU-R Rec. M.2101-0 IMT-2020 Active-Antenna-System
(AAS) base-station antenna / EIRP model, plus a streaming Monte Carlo harness
for per-direction EIRP statistics. The math is a clean-room port of
`pycraf.antenna.imt` — no pycraf source is copied. There is no build step;
everything is plain MATLAB functions in `matlab/`.

## Common commands

```matlab
% from the repo root, in MATLAB:
run_all_tests                                  % full suite, prints per-test summary

% individual tests (after addpath('matlab'))
test_against_pycraf_strict                     % <-- regression gate, see below
test_aas_monte_carlo_eirp
test_export_eirp_percentile_table
test_ue_sector_sampler
test_runtime_scaling_controls
test_r23_aas_defaults
test_r23_extended_aas_eirp
test_imtAasEirpGrid
test_imtAasValidationExport
test_runR23AasEirpCdfGrid
test_single_sector_eirp_mvp

% demos
demo_aas_monte_carlo_eirp
demo_r23_aas_eirp_grid
demo_export_eirp_percentile_table
run_single_sector_eirp_demo
% from examples/
runAasEirpGridExample
runAasEirpValidationExport
runSingleSectorEirpDemoExample
```

`run_all_tests.m` adds `matlab/` to the path automatically; individual scripts
need `addpath('matlab')` first when run from the repo root. Skipped tests do
not fail the suite (pycraf tests skip cleanly when Python/pycraf is missing).

## The pycraf strict equivalence gate

`test_against_pycraf_strict` is the authoritative regression gate: it compares
`imt2020_single_element_pattern.m` and `imt2020_composite_pattern.m` against
`pycraf.antenna` on a fixed (az, el) grid plus 3 fixed and 50 seeded-random
beam pointings, with **`max abs error <= 1e-6 dB`**.

**Any change to the antenna math (single-element pattern, composite array
factor, angle conventions, `k` / `rho` handling) MUST keep this test passing.**
Run it in an environment where pycraf is installed
(`pip install pycraf`, then `pyenv('Version', '/path/to/python')` once in
MATLAB) before merging changes to those two files. The strict gate's pass
rule is the contract for the simple M.2101 path; the R23 extended path is
explicitly *not* bit-equivalent to pycraf.

## Three parallel APIs — pick the right one

All three APIs implement the same R23 7.125-8.4 GHz macro reference
(peak 78.3 dBm / 100 MHz = 46.1 dBm txPower + 32.2 dBi peak gain), but
live in different naming conventions and serve different purposes:

| API | Naming | Entry points | Purpose |
| --- | --- | --- | --- |
| Original / Monte Carlo | `imt2020_*`, `imt_aas_*`, `imt_r23_aas_*` (snake_case) | `imt_aas_bs_eirp`, `run_imt_aas_eirp_monte_carlo`, `imt_r23_aas_eirp_grid` | Streaming Monte Carlo, percentile/exceedance maps |
| AAS-01/AAS-02 export | `imtAas*` (camelCase) | `imtAasEirpGrid`, `imtAasCompositeGain`, `imtAasDefaultParams`, `imtAasExportEirpGridCsv`, `runR23AasEirpCdfGrid` | Deterministic per-(az,el) EIRP grid + streaming CDF-grid runner |
| R23 single-sector MVP (AAS-01 BS-driven) | snake_case (`get_default_bs`, `compute_eirp_grid`, ...) | `get_default_bs`, `run_single_sector_eirp_demo`, `run_monte_carlo_snapshots`, `compute_cdf_per_grid_point` | BS-input-driven 1-site / 1-sector / N-UE EIRP CDF MVP |

The Monte Carlo runner dispatches on `cfg.patternModel` (`'m2101'` vs
`'r23_extended_aas'`) via `imt_aas_bs_eirp.m`. Don't conflate
`imt_r23_aas_defaults()` (snake_case, returns the full Monte Carlo cfg with
`patternModel`) with `imtAasDefaultParams()` (camelCase, returns the params
struct used by the `imtAas*` deterministic-grid functions). The R23
single-sector MVP wraps `imtAasDefaultParams()` via `get_r23_aas_params()`
and reuses the `imtAas*` antenna primitives - it does not introduce a
fourth set of antenna math.

When extending: prefer adding to whichever family already owns the function
you're calling. Cross-family changes are easy to make accidentally
inconsistent.

## Streaming-only invariant (Monte Carlo / runR23AasEirpCdfGrid path)

The streaming Monte Carlo path (`run_imt_aas_eirp_monte_carlo`,
`runR23AasEirpCdfGrid`) **never materializes the per-draw `Naz x Nel x
numMc` EIRP cube**. `update_eirp_histograms` keeps a fixed-size
aggregator only:

- `stats.counts` — `Naz x Nel x Nbin uint32` histogram
- `stats.sum_lin_mW` — running linear-mW sum (the linear-mW mean is the
  correct "average power" estimator; do not average dBm)
- `stats.min_dBm`, `stats.max_dBm` — running per-cell extrema

Downstream consumers (`eirp_percentile_maps`, `eirp_cdf_at_angle`,
`eirp_exceedance_maps`, `export_eirp_percentile_table`) all operate on
this aggregator. **Do not add code paths that reconstruct the raw EIRP
cube** in the streaming path — for the default 65,341-cell grid with
`numMc = 1e4` the cube would be ~5.2 GiB. Use `estimate_aas_mc_memory`
to size structures before allocating.

Chunking is bit-exact: chunked and unchunked runs with the same seed produce
identical `counts / sum_lin_mW / min_dBm / max_dBm`
(`test_runtime_scaling_controls` enforces this). New code that changes the
RNG sequence, loop order, or aggregator update must preserve that property.

The R23 single-sector MVP (`run_monte_carlo_snapshots` /
`compute_cdf_per_grid_point`) intentionally returns the full
`Naz x Nel x numSnapshots` EIRP cube because the AAS-01 contract is
explicit about exposing `EIRP(grid_point, snapshot)`. Defaults are kept
modest (37 x 9 x 100 ~= 33k doubles); for large grids prefer the
streaming `runR23AasEirpCdfGrid` runner.

## Angle conventions (matched to pycraf and M.2101)

- External `azim ∈ [-180°, 180°]`, `elev ∈ [-90°, 90°]`
- Internal polar `θ = 90° - elev`
- Beam tilt `θ_i = -elev_i` (sic — see the inline note in
  `imt2020_composite_pattern.m`; this is the M.2101 / pycraf convention)
- Negative elevation means **below the horizon / downtilt**. The R23 nominal
  beam at -9° elevation sits below the horizon as expected.
- For the R23 extended path, `imt_aas_mechanical_tilt_transform` rotates the
  sector frame into the panel frame via a single y-axis rotation; the array
  factor is then evaluated in the panel frame.

## Power / gain accounting (don't double-count)

`eirp_dBm = txPower_dBm + gain_dBi - feederLoss_dB`. `txPower_dBm` is
**conducted** power. The composite pattern returned in dBi already aggregates
the array factor — **do not add `10*log10(N_H * N_V)` on top of the gain**.

For the R23 single-sector MVP, `bs.eirp_dBm_per_100MHz` is the **sector
peak EIRP** (default 78.3). When the sector simultaneously serves N UEs,
`compute_eirp_grid` / `run_monte_carlo_snapshots` split the sector
budget across simultaneous beams via
`perBeamPeakEirpDbm = sectorEirpDbm - 10*log10(N)` when
`splitSectorPower = true` (default). The aggregate peak across N
identical beams equals `sectorEirpDbm` exactly - the test
`test_single_sector_eirp_mvp` enforces this invariant.

For the R23 extended path, `cfg.normalizeToPeakGain = true` (default)
renormalises the raw extended gain so the panel-frame main lobe peak equals
`cfg.peakGain_dBi` exactly. Toggling this off changes EIRP magnitudes.

## Scope (what this codebase intentionally does NOT do)

This is the antenna / EIRP piece only. None of the following are implemented
and adding them is out of scope unless the task explicitly asks:

- path loss (free-space, terrain, clutter, atmospheric)
- frequency-dependent rejection (FDR), receiver I/N, SINR
- FS / FSS victim antennas, coordination distance
- multi-site / 19-site aggregation, SEAMCAT-style aggregate compatibility
- IMT/UE laydown, scheduling, mobility
- full SSB / CSI-RS / PMI selection (the `ue_sector` beam sampler is a
  UE-driven approximation, not Quadriga)
- spurious-domain scaling, F.1336 sectoral patterns
- GPU / `parfor` acceleration (the streaming aggregator is not thread-safe
  for shared state)

## Conventions worth preserving

- Symbol names follow M.2101 / pycraf one-to-one (`G_Emax`, `A_m`, `SLA_nu`,
  `phi_3db`, `theta_3db`, `d_H`, `d_V`, `N_H`, `N_V`, `rho`, `k`).
- `N_V = 8` rows, `N_H = 16` columns for the R23 8x16 sub-array layout.
- `k = 12` is M.2101 default; `k = 8` (3GPP measurement-fitted) is supported
  via `cfg.k`.
- Tests assert percentile-map monotonicity, histogram-count totals, CDF
  endpoints, exceedance-probability monotonicity, and seed reproducibility.
  These invariants tend to catch subtle aggregator bugs — keep them.
- This is **not ITU-certified**. Cross-check against M.2101 and 3GPP TR
  37.840 before using results in regulatory contexts.
