# imt-matlab

MATLAB implementation of the ITU-R Rec. M.2101-0 IMT-2020 Active-Antenna-System
(AAS) base-station antenna / EIRP model, with a streaming Monte Carlo harness
for per-direction EIRP statistics.

Two pattern paths are supported:

* the **simple M.2101 composite path** (`imt2020_composite_pattern.m`),
  unchanged - this is what the existing `pycraf` parity tests cover at
  `1e-6 dB` tolerance, and
* a new **R23 7.125-8.4 GHz Extended AAS path**
  (`imt2020_composite_pattern_extended.m` +
  `imt_r23_aas_defaults.m` + `imt_r23_aas_eirp_grid.m`) for the macro
  base-station configuration described below.

## Layout

```
run_all_tests.m                        single entry point for the test suite
matlab/
├── imt2020_single_element_pattern.m   single element gain (M.2101 Table 4)
├── imt2020_composite_pattern.m        composite array gain (simple M.2101)
├── imt2020_composite_pattern_extended.m R23 extended AAS composite (sub-array + tilt)
├── imt_aas_mechanical_tilt_transform.m  sector->panel y-axis rotation
├── imt_r23_aas_defaults.m             R23 7/8 GHz macro AAS configuration
├── imt_r23_aas_eirp_grid.m            deterministic R23 EIRP grid
├── demo_r23_aas_eirp_grid.m           R23 EIRP grid demo
├── imt_aas_bs_eirp.m                  conducted-power-to-EIRP mapping (M.2101 + R23)
├── sample_aas_beam_direction.m        beam-pointing samplers (uniform/sector/fixed/list/ue_sector)
├── update_eirp_histograms.m           streaming per-cell stats update
├── run_imt_aas_eirp_monte_carlo.m     MC driver, never stores the EIRP cube
├── runR23AasEirpCdfGrid.m             source-aligned R23 EIRP CDF-grid MVP
├── plotR23AasEirpCdfGrid.m            mean + percentile heatmaps for the R23 MVP
├── eirp_percentile_maps.m             per-angle percentile maps from histograms
├── eirp_cdf_at_angle.m                empirical CDF at one (az,el)
├── eirp_exceedance_maps.m             P(EIRP > threshold) maps
├── export_eirp_percentile_table.m     one-row-per-(az,el) p000:p100 CSV export
├── demo_aas_monte_carlo_eirp.m        end-to-end example
├── demo_export_eirp_percentile_table.m demo for the percentile-table CSV
├── test_against_pycraf.m              optional pycraf cross-check via pyenv
├── test_against_pycraf_strict.m       strict pycraf equivalence gate (3 fixed + 50 random beams)
├── test_aas_monte_carlo_eirp.m        MATLAB-only self tests
├── test_export_eirp_percentile_table.m self tests for the table exporter
├── test_ue_sector_sampler.m           self tests for the ue_sector beam sampler
├── test_r23_aas_defaults.m            self tests for the R23 7/8 GHz defaults
├── test_r23_extended_aas_eirp.m       self tests for the R23 extended AAS path
├── estimate_aas_mc_memory.m           memory estimator for hist / pctile / CSV
├── profile_aas_monte_carlo_runtime.m  runtime profiler + full-grid extrapolation
├── test_runtime_scaling_controls.m    self tests for chunking / memory / progress
└── test_runR23AasEirpCdfGrid.m        self tests for the R23 EIRP CDF-grid MVP
```

## What was ported from pycraf

Source: `pycraf/antenna/imt.py` and `pycraf/antenna/cyantenna.pyx` (commit on
`master` at the time of writing).

The MATLAB code reimplements the same closed-form equations - none of the
pycraf source is copied. The mapping is:

| pycraf entity                                    | MATLAB equivalent                          |
| ------------------------------------------------ | ------------------------------------------ |
| `_A_EH(phi, A_m, phi_3db, k)`                    | inline in `imt2020_single_element_pattern` |
| `_A_EV(theta, SLA_nu, theta_3db, k)`             | inline in `imt2020_single_element_pattern` |
| `_imt2020_single_element_pattern` (cython)       | `imt2020_single_element_pattern.m`         |
| `imt2020_composite_pattern_cython`               | `imt2020_composite_pattern.m`              |
| linear-mW EIRP combination                       | `imt_aas_bs_eirp.m`                        |

The MATLAB composite pattern uses the **same exponent** as pycraf:

```
arg(m,n) = 2π · ( n·d_V·cos(θ)
                + m·d_H·sin(θ)·sin(φ)
                + n·d_V·sin(θ_i)
                - m·d_H·cos(θ_i)·sin(φ_i) )
```

with `m = 0..N_H-1`, `n = 0..N_V-1`, and the rho-weighted recombination

```
A_A = A_E + 10·log10( 1 + ρ·(|S|² / (N_H·N_V) - 1) ).
```

## What was mapped from M.2101-0

Recommendation ITU-R M.2101-0 (`R-REC-M.2101-0-201702-I!!PDF-E.pdf`),
Annex 1 / Table 4 specifies:

* the per-element horizontal cut `A_E,H(φ) = -min(12·(φ/φ_3dB)², A_m)`
* the per-element vertical   cut `A_E,V(θ) = -min(12·((θ-90°)/θ_3dB)², SLA_ν)`
* the combined element pattern `A_E(φ,θ) = G_E,max - min(-(A_E,H + A_E,V), A_m)`
* the array superposition vector and the rho-correlation form (with rho = 1
  giving fully correlated array gain; see 3GPP TR 37.840 §5.4.4.1.4)
* the angle conventions used inside the equations

The MATLAB code uses the same symbol names and units throughout, so
M.2101 readers can step from the document into the source one-to-one.

## R23 7/8 GHz Extended AAS

The R23 macro base-station AAS for the 7.125-8.4 GHz IMT band uses an
*extended* composite pattern: each cell of the horizontal x vertical
sub-array grid contains a fixed-downtilt vertical sub-array, and the
whole panel is mechanically downtilted. Three new files implement this
on top of the existing single-element pattern:

| file | role |
| ---- | ---- |
| `imt_r23_aas_defaults.m`             | reference R23 configuration struct |
| `imt_aas_mechanical_tilt_transform.m`| sector-frame -> panel-frame y-axis rotation |
| `imt2020_composite_pattern_extended.m` | composite gain with sub-array + mechanical tilt |
| `imt_r23_aas_eirp_grid.m`             | deterministic per-direction EIRP grid |

The original simple M.2101 path (`imt2020_composite_pattern.m`) is
unchanged. The strict pycraf parity tests (`test_against_pycraf`,
`test_against_pycraf_strict`) still cover that path at `1e-6 dB`.

### Reference configuration

`imt_r23_aas_defaults('macroUrban')` (or `'macroSuburban'`) returns:

| field                              | value                  |
| ---------------------------------- | ---------------------- |
| `frequencyMHz`                     | `8000`                 |
| `bandwidthMHz`                     | `100`                  |
| `sectorEirp_dBm_per100MHz`         | `78.3`                 |
| `peakGain_dBi`                     | `32.2`                 |
| `txPower_dBm`                      | `46.1`                 |
| `feederLoss_dB`                    | `0`                    |
| `G_Emax`                           | `6.4` (incl. 2 dB ohmic) |
| `phi_3db, theta_3db`               | `90, 65`               |
| `A_m, SLA_nu`                      | `30, 30`               |
| `N_V x N_H` (rows x cols)          | `8 x 16`               |
| `d_H, d_V` (sub-array spacing)     | `0.5, 2.1` wavelengths |
| `subarray.numVerticalElements`     | `3`                    |
| `subarray.d_V`                     | `0.7` wavelengths      |
| `subarray.downtiltDeg`             | `3`                    |
| `mechanicalDowntiltDeg`            | `6`                    |
| `bsHeight_m` (macroUrban / macroSuburban) | `18` / `20`     |
| `numSectors`, `sectorAzimuthsDeg`  | `3`, `[0 120 240]`     |
| `horizontalCoverageDeg`            | `60` (+/-)             |

> The R23 row x column = 8 x 16 array maps to `N_V = 8` (vertical sub-
> arrays / rows) and `N_H = 16` (horizontal columns) in the repo's array
> factor convention.

UE / network metadata (UEs per sector, UE antenna gain, body loss, TDD
activity factors, PCMAX, P0_PUSCH, alpha, network loading factors) are
attached to `cfg` for downstream use but are **not** consumed by this
EIRP-only step.

### Math

Mechanical downtilt is a single y-axis rotation of the observation and
beam directions before the antenna math is evaluated:

```
v        = [cos(EL)*cos(AZ); cos(EL)*sin(AZ); sin(EL)]
v_panel  = Ry(tiltDownDeg) * v
AZ_panel = atan2d(v_panel.y, v_panel.x)   wrapped to [-180, 180]
EL_panel = asind(v_panel.z)
```

So a sector-frame direction at `(0, -tiltDownDeg)` lands at panel
`(0, 0)`. The N_H x N_V sub-array array factor is identical to the
simple M.2101 form, evaluated in the panel frame; the new piece is the
fixed-downtilt vertical sub-array of `L = numVerticalElements` elements
with internal spacing `dSub` wavelengths and steering elevation
`-thetaSub`:

```
argSub(l) = 2*pi * l * dSub * ( cos(theta_panel) + sin(thetaSub) )
AFsub     = | sum_l exp(j*argSub(l)) |^2 / L
```

The full extended composite is

```
A_ext = A_E + 10*log10( 1 + rho*(AF_array - 1) ) + 10*log10(AFsub)
```

with the same `A_E`, `phi`, `theta`, and `theta_i = -elev_i` conventions
as the simple path.

Setting `cfg.normalizeToPeakGain = true` (the default) renormalises the
raw extended gain so the panel-frame main-lobe peak equals
`cfg.peakGain_dBi` exactly:

```
gain_dBi = rawGain_dBi - rawPeak_dBi + cfg.peakGain_dBi
```

`rawPeak_dBi` is the raw extended gain evaluated at the (panel-frame)
beam direction.

### EIRP grid

```matlab
addpath('matlab');
cfg = imt_r23_aas_defaults('macroUrban');
out = imt_r23_aas_eirp_grid(-180:1:180, -90:1:30, cfg);
% out.gain_dBi              [Naz x Nel]   composite gain [dBi]
% out.eirp_dBm_per100MHz    [Naz x Nel]   EIRP per 100 MHz [dBm]
% out.eirp_dBW_perHz        [Naz x Nel]   EIRP spectral density [dBW/Hz]
%   = eirp_dBm_per100MHz - 30 - 10*log10(cfg.bandwidthMHz * 1e6)
```

The default beam pointing places the peak at the combined sub-array +
mechanical downtilt direction, i.e. `(azim_i, elev_i) = (0, -9)` for the
R23 defaults. With those defaults the grid peaks at exactly
`78.3 dBm/100 MHz` (= `46.1 + 32.2`) on directions where the panel-frame
main lobe lands.

`demo_r23_aas_eirp_grid.m` runs end-to-end and produces an EIRP map.

### Scope of this step

This is a deterministic / Monte-Carlo-compatible **base-station EIRP
grid only**. It does *not* implement:

* free-space or terrain path loss
* clutter loss
* FS / FSS victim antennas
* frequency-dependent rejection (FDR)
* network aggregation across base stations
* I/N or SEAMCAT-style aggregate compatibility

`run_imt_aas_eirp_monte_carlo` accepts the R23 cfg without modification
- the per-iteration beam pointing is drawn by
`sample_aas_beam_direction`, the per-direction EIRP is computed via
`imt_aas_bs_eirp(..., cfg)` (which dispatches on `cfg.patternModel`), and
the streaming histogram update is unchanged.

## Exporting the R23 AAS EIRP grid

`examples/runAasEirpValidationExport.m` is the AAS-02 validation /
export layer on top of the AAS-01 sector-EIRP grid (PR #10). It builds
the deterministic R23 macro AAS antenna-face EIRP distribution for the
nominal (broadside, -9 deg) beam, plots the grid plus horizontal /
vertical 1-D cuts, and writes a long-form CSV with a JSON metadata
sidecar. It does **not** model path loss, receiver geometry, or
coordination - the payload is *antenna-face EIRP only*.

### How to run

```matlab
addpath('matlab');
runAasEirpValidationExport
```

(or `cd examples; runAasEirpValidationExport`).

The example uses the AAS-01 default grid:

```
azGridDeg  = -180:1:180;
elGridDeg  =  -90:1:90;
steerAzDeg =  0;
steerElDeg = -9;
```

and the R23 reference parameters from `imtAasDefaultParams()` (8 x 16
sub-array layout, 3 vertical elements per sub-array, 0.7 lambda
intra-sub-array spacing, 2.1 lambda sub-array spacing, 0.5 lambda
horizontal spacing, 3 deg sub-array downtilt, 6 deg mechanical downtilt,
6.4 dBi element gain). The peak EIRP of the grid is **78.3 dBm /
100 MHz**, matching the R23 macro reference.

### Where artifacts are written

All under `examples/output/`:

| file | content |
| ---- | ------- |
| `aas_eirp_grid_r23_macro.csv`               | long-form `az_deg, el_deg, eirp_dbm_per_100mhz`, one row per (az, el) cell |
| `aas_eirp_grid_r23_macro_metadata.json`     | sidecar metadata (params + steering + notes); plain-text fallback if `jsonencode` is unavailable |
| `aas_eirp_grid_r23_macro.png`               | EIRP heatmap (2-D az/el) |
| `aas_eirp_horizontal_cut_r23_macro.png`     | horizontal cut at the steering elevation |
| `aas_eirp_vertical_cut_r23_macro.png`       | vertical cut at the steering azimuth |

`imtAasExportEirpGridCsv` uses base MATLAB only; PNG export uses
`exportgraphics` when available and falls back to `saveas` otherwise.

### Files added in this slice

| file | role |
| ---- | ---- |
| `matlab/imtAasPatternCuts.m`             | nearest-grid horizontal / vertical 1-D cuts + peak summary |
| `matlab/imtAasExportEirpGridCsv.m`       | long-form CSV + JSON / text metadata sidecar |
| `matlab/plotImtAasPatternCuts.m`         | two-figure plot of the cuts |
| `examples/runAasEirpValidationExport.m`  | end-to-end validation / export driver |
| `matlab/test_imtAasValidationExport.m`   | self tests, wired into `run_all_tests` |

### Angle convention

* `az_deg`  - azimuth relative to sector boresight; positive to the
  left of boresight, range `[-180, 180]`. `0 deg` is the sector
  boresight.
* `el_deg`  - elevation relative to the horizon; range `[-90, 90]`.
  `0 deg` is the horizon. **Negative elevation means downtilt /
  below the horizon**, so the nominal R23 main beam at -9 deg sits
  below the horizon as expected.
* The mechanical downtilt and sub-array downtilt are applied internally
  by `imtAasCompositeGain` / `imtAasEirpGrid`; the export uses the
  sector-frame angles as written above.

### Scope (what this slice is NOT)

This is labelled a **deterministic R23 macro AAS MVP export**. It is
intentionally limited to one base-station sector's antenna-face EIRP
distribution. It does **not** implement, and does not claim equivalence
with:

* IMT laydown / UE laydown
* path loss / propagation models
* receiver I / N
* CDF / CCDF aggregation
* coordination distance
* FS / FSS receiver logic
* full ITU-R M.2101 / pycraf parity (separate strict tests cover the
  simple M.2101 path; the extended R23 path is not bit-equivalent)

The peak normalization is preserved from AAS-01:

```
eirpGridDbm = sectorEirpDbm + compositeGainDbi - max(compositeGainDbi(:))
```

so `max(eirpGridDbm(:)) == sectorEirpDbm == 78.3 dBm / 100 MHz` exactly.

## Reference validation for AAS cuts

`examples/runAasReferenceValidation.m` is the AAS-03 reference-validation
harness on top of the AAS-01 / AAS-02 cuts. It compares the
MATLAB-generated horizontal and vertical EIRP pattern cuts against
optional reference CSVs and reports bounded dB error metrics with a
deterministic pass / fail gate. It does **not** model path loss,
receiver geometry, or coordination - it is still *antenna-face EIRP
only*.

### How to run

```matlab
addpath('matlab');
runAasReferenceValidation
```

(or `cd examples; runAasReferenceValidation`).

### Where reference CSVs live

```
references/aas/r23_macro_horizontal_cut.csv   (optional)
references/aas/r23_macro_vertical_cut.csv     (optional)
```

The CSV format is documented in `references/aas/README.md`. Required
columns are `angle_deg` and `eirp_dbm_per_100mhz`; optional columns are
`gain_dbi` and `notes`. Reference values can come from pycraf, ITU
validation material, or frozen MATLAB-reviewed outputs. Bit-perfect
parity is **not** the AAS-03 target - bounded dB error metrics are.

### Skip behavior when references are absent

If neither CSV is present, `runAasReferenceValidation` prints a clear
"skipped" message and returns a summary with `summary.skipped = true`
(without failing). The accompanying `test_imtAasReferenceComparison`
test exercises this path so that MATLAB-only environments without any
reference artifacts still pass `run_all_tests`.

### Where artifacts are written

When at least one reference CSV is present, all under
`examples/output/`:

| file | content |
| ---- | ------- |
| `aas_reference_validation_summary.csv`        | one row per cut: max / RMS / main-lobe error metrics, applied thresholds, pass/fail flag |
| `aas_reference_horizontal_comparison.png`     | two-panel actual-vs-reference + error plot for the horizontal cut |
| `aas_reference_vertical_comparison.png`       | two-panel actual-vs-reference + error plot for the vertical cut |

### Pass / fail tolerances

`imtAasComparePatternCut` defaults (overridable via opts):

| field                       | default | meaning                                  |
| --------------------------- | ------- | ---------------------------------------- |
| `maxAbsErrorDb`             | `1.0`   | global max absolute error gate           |
| `rmsErrorDb`                | `0.5`   | global RMS error gate                    |
| `mainLobeMaxAbsErrorDb`     | `0.5`   | main-lobe max absolute error gate        |
| `mainLobeWindowDeg`         | `20`    | main-lobe window centered on actual peak |
| `ignoreBelowDbm`            | `-80`   | ignore points where actual & ref both below this floor |
| `interpolateReference`      | `true`  | linearly interpolate ref onto actual grid|

A comparison passes only when all three error gates are met. Failures
are reported with explicit reasons in `cmp.failReasons` and printed by
`runAasReferenceValidation`.

### Files added in this slice

| file | role |
| ---- | ---- |
| `matlab/imtAasLoadReferenceCutCsv.m`         | base-MATLAB CSV loader for reference pattern cuts |
| `matlab/imtAasComparePatternCut.m`           | actual-vs-reference comparison + pass/fail gates |
| `matlab/plotImtAasReferenceComparison.m`     | two-panel comparison plot (cuts + error) |
| `examples/runAasReferenceValidation.m`       | end-to-end reference-validation driver |
| `references/aas/README.md`                   | reference CSV format + angle conventions |
| `matlab/test_imtAasReferenceComparison.m`    | self tests, wired into `run_all_tests` |

### Scope (what this slice is NOT)

Same scope envelope as AAS-01 / AAS-02. This slice is still **antenna-face
EIRP only**: it does not add path loss, propagation, receiver I / N,
CDF / CCDF aggregation, coordination distance, FS / FSS receiver
geometry, or IMT / UE laydown.

## UE-driven beam angles for one AAS sector

`examples/runAasBeamDrivenEirp.m` adds the minimal **UE-geometry layer**
needed to generate physically consistent AAS beam steering angles for a
**single base-station sector**. The pipeline is:

```
UE positions  ->  raw beam (az, el)  ->  clipped beam (az, el)  ->  EIRP grid
                  imtAasUeToBeamAngles  imtAasApplyBeamLimits     imtAasEirpGrid
```

This layer is **not** a network laydown, **not** a multi-site cluster,
and **not** a received-power model. It only answers: *given UE positions
around one sector, what AAS beam steering angles should be used?*

### How to run

```matlab
addpath('matlab');
runAasBeamDrivenEirp
```

(or `cd examples; runAasBeamDrivenEirp`).

The driver prints the number of beams, min / max raw and clipped
steering angles, and how many beams were clipped in azimuth / elevation.
For three representative beams (boresight, sector edge, and a clipped
or closest UE) it computes the per-(az, el) EIRP grid via
`imtAasEirpGrid` and reports the peak EIRP. With the R23 reference
parameters the peak is `78.3 dBm / 100 MHz` for every beam, including
the clipped ones.

### Reference deployment defaults

`imtAasSingleSectorParams(deployment)` returns the per-deployment
geometry envelope:

| deployment      | bsHeight_m | cellRadius_m | minUeDistance_m | sector |
| --------------- | ---------- | ------------ | --------------- | ------ |
| `macroUrban`    | 18         | 400          | 35              | +/-60 deg |
| `macroSuburban` | 20         | 800          | 35              | +/-60 deg |

UE height defaults to `1.5 m` and the BS sits at the origin with a
sector boresight of `0 deg` azimuth.

### Angle convention

* `steerAzDeg` is **relative to sector boresight**. `steerAzDeg = 0`
  points along boresight; positive is to the left of the boresight in
  the sector frame, matching the rest of the repo.
* `steerElDeg` is **relative to the horizon** (0 deg = horizon).
  **Negative elevation = downtilt** (UE below the BS antenna).
* The raw fields `rawSteerAzDeg` and `rawSteerElDeg` always carry the
  un-clamped pointing angles so callers can distinguish a beam that
  *fits* the steering envelope from one that *was clipped* via
  `wasAzClipped` / `wasElClipped`.

### R23 steering envelope (clipping)

`imtAasApplyBeamLimits` clamps raw steering angles to the R23 envelope:

| axis      | limit      |
| --------- | ---------- |
| azimuth   | `[-60, 60]` deg |
| elevation | `[-10, 0]` deg  |

The vertical limit reflects the R23 vertical coverage of 90-100 deg in
the M.2101 global-theta convention, which maps to elevation
`[-10, 0]` in this repo's `(az, el)` convention.

### Sampling rules

`imtAasSampleUePositions` draws UE positions inside one sector with:

* **azimuth uniform** in `sector.azLimitsDeg` (default `+/-60 deg`).
* **radial uniform-in-area** so 2-D UE density is uniform on the
  annulus:

  ```
  r = sqrt(r_min^2 + u * (r_max^2 - r_min^2)),  u ~ U(0, 1)
  ```

  with `r_min = 35 m` and `r_max = sector.cellRadius_m`.

The sampler accepts an optional `seed` for deterministic draws, and
saves / restores the global RNG state on entry / exit so it does not
perturb a caller-managed Monte Carlo stream. Explicit `azRelDeg` /
`r_m` / `ueHeight_m` overrides are also supported (and validated
against the sector envelope).

### Files added in this slice

| file | role |
| ---- | ---- |
| `matlab/imtAasSingleSectorParams.m`     | per-deployment geometry + steering limits |
| `matlab/imtAasSampleUePositions.m`      | uniform-in-area UE sampler with explicit overrides |
| `matlab/imtAasUeToBeamAngles.m`         | UE position -> raw beam (az, el) |
| `matlab/imtAasApplyBeamLimits.m`        | clamp raw angles to sector / R23 limits |
| `matlab/imtAasGenerateBeamSet.m`        | one-shot wrapper: sample -> raw -> clipped |
| `examples/runAasBeamDrivenEirp.m`       | end-to-end histogram + EIRP-grid demo |
| `matlab/test_imtAasBeamAngles.m`        | self tests, wired into `run_all_tests` |

### Scope (what this slice is NOT)

This is geometry only. There is no path loss, no propagation, no
receiver, no I / N, no CDF / CCDF aggregation, no multi-site / 19-site
cluster, no IMT / UE scheduling, no FS / FSS receiver geometry, and no
coordination-distance logic.

## UE-driven sector EIRP grid

`examples/runAasUeDrivenSectorEirpGrid.m` combines the antenna-face
EIRP model with the AAS-04 UE-driven beam generator to produce the
**sector-level EIRP distribution** when one IMT AAS macro sector is
simultaneously serving `N_UE` UEs. The pipeline is:

```
UE geometry  ->  beam (az, el)  ->  per-beam EIRP grids  ->  aggregate sector EIRP grid
imtAasSampleUePositions
imtAasUeToBeamAngles
imtAasApplyBeamLimits     imtAasEirpGrid     imtAasSectorEirpGridFromBeams
```

### How to run

```matlab
addpath('matlab');
runAasUeDrivenSectorEirpGrid
```

(or `cd examples; runAasUeDrivenSectorEirpGrid`).

The driver prints `numBeams`, `sectorEirpDbm`, `perBeamPeakEirpDbm`,
the peak aggregate / envelope EIRP, and a per-beam steering table; it
saves PNG heatmaps and CSV exports under `examples/output/`.

### Power semantics (R23 macro 7.125-8.4 GHz)

`imtAasDefaultParams` carries the R23 power split explicitly:

| field                                       | value | meaning |
| ------------------------------------------- | ----- | ------- |
| `txPowerDbmPer100MHz`                       | 46.1  | conducted BS transmit power [dBm / 100 MHz] |
| `peakGainDbi`                               | 32.2  | peak composite antenna gain [dBi] |
| `sectorEirpDbm`                             | 78.3  | **sector peak** EIRP [dBm / 100 MHz] (= 46.1 + 32.2) |
| `numUesPerSector`                           | 3     | simultaneously served UEs per sector |
| `sectorEirpIncludesTwoPolarizations`        | true  | sector EIRP sums both orthogonal polarizations |
| `elementGainIncludesOhmicLoss`              | true  | the 6.4 dBi element gain already absorbs the 2 dB ohmic loss |
| `defaultSplitSectorPowerAcrossBeams`        | true  | per-beam peak EIRP = sectorEirpDbm - 10*log10(numBeams) |

Key point: **78.3 dBm / 100 MHz is the sector peak EIRP, not a
per-simultaneous-beam allowance.** A single reference beam may peak at
the full 78.3 dBm / 100 MHz, but in a 3-UE simultaneous snapshot the
sector power is split across the three BS-UE links:

```
perBeamPeakEirpDbm = sectorEirpDbm - 10*log10(numBeams)
                   = 78.3 - 10*log10(3)
                   ~ 73.53 dBm / 100 MHz
```

The aggregate sector EIRP grid is built by linear-mW power summation
over the per-beam EIRP grids:

```
aggregateEirpDbm = 10*log10(sum(10.^(perBeamEirpDbm / 10), 3))
```

When the three simultaneous beams point in identical directions, the
aggregate peak EIRP returns to ~78.3 dBm / 100 MHz (three -4.77 dB
peaks summing in linear power). When the beams point in different
directions, the aggregate peak is below 78.3 dBm / 100 MHz because each
beam contributes its own steered main lobe.

`maxEnvelopeEirpDbm` (the per-cell `max` over beams) is the
worst-direction envelope - it is **not** the aggregate; for the split
path its peak equals `perBeamPeakEirpDbm` exactly.

### Files added in this slice

| file | role |
| ---- | ---- |
| `matlab/imtAasSectorEirpGridFromBeams.m`        | aggregate sector EIRP grid from a beam set (linear-mW sum) |
| `matlab/imtAasCreateDefaultSectorEirpGrid.m`    | one-shot helper (defaults + UE-driven beams + aggregate grid) |
| `matlab/plotImtAasSectorEirpGrid.m`             | aggregate / envelope / per-beam heatmaps |
| `examples/runAasUeDrivenSectorEirpGrid.m`       | end-to-end demo + CSV / PNG export |
| `matlab/test_imtAasSectorEirpGridFromBeams.m`   | self tests, wired into `run_all_tests` |

### Scope (what this slice is NOT)

This is **antenna-face EIRP only**. No path loss, no receiver antenna
gain, no I / N, no CDF / CCDF, no coordination-distance logic, no TDD
activity factor, no network loading factor, no multi-site / 19-site
cluster, no FS / FSS receiver geometry, and no IMT / UE scheduling.

## R23 7/8 GHz Extended AAS EIRP CDF-grid MVP

`runR23AasEirpCdfGrid(opts)` is the **source-aligned MVP** for the
R23 7.125-8.4 GHz Extended AAS per-(az, el) **EIRP CDF-grid generator**.
It is `imtAasDefaultParams` + `imtAasGenerateBeamSet` +
`imtAasSectorEirpGridFromBeams` driven by a streaming Monte Carlo loop:
each draw samples `numBeams` UE-driven beam steering angles, builds the
aggregate antenna-face sector EIRP grid by linear-mW summation across
the simultaneous beams, and updates a fixed-size per-cell histogram.
The full per-draw EIRP cube is **never** materialised.

This is **antenna-face EIRP only**. There is **no path loss**, **no
receiver antenna**, **no receiver gain**, **no I / N**, **no
propagation**, **no coordination distance**, and **no 19-site
laydown** in this slice.

### How to run

```matlab
addpath('matlab');

% Default 1000-draw run on the full grid, urban macro, 3 simultaneous UEs
out = runR23AasEirpCdfGrid();

% End-to-end example: 100 draws, plots, CSV + metadata under examples/output/
runR23AasEirpCdfGridExample
```

`opts` (all fields optional):

| field | default | meaning |
| ----- | ------- | ------- |
| `numMc`              | `1000`                          | Monte Carlo draws |
| `azGridDeg`          | `-180:1:180`                    | azimuth grid [deg] |
| `elGridDeg`          | ` -90:1:90`                     | elevation grid [deg] |
| `binEdgesDbm`        | `-100:1:120`                    | histogram bin edges [dBm] |
| `percentiles`        | `[1 5 10 20 50 80 90 95 99]`   | percentile maps to compute |
| `seed`               | `1`                             | RNG seed (set once at start) |
| `deployment`         | `'macroUrban'`                  | `'macroUrban'` or `'macroSuburban'` |
| `numBeams`           | `params.numUesPerSector` (= 3) | simultaneous UE beams per sector |
| `splitSectorPower`   | `true`                          | split sector EIRP across simultaneous beams |
| `progressEvery`      | `0`                             | print progress every N draws |
| `mcChunkSize`        | `min(numMc, 500)`               | (reserved for forward compatibility) |
| `outputCsvPath`      | `''`                            | optional `p000:p100` table CSV |
| `outputMetadataPath` | `''`                            | optional JSON / text metadata sidecar |

`out.stats` is the streaming aggregator (counts, sum_lin_mW, min/max,
mean_dBm, plus `perBeamPeakEirpDbm`, `sectorEirpDbm`, `numBeams`,
`deployment`). `out.percentileMaps` is the struct from
`eirp_percentile_maps`. `out.metadata` carries the explicit
no-path-loss / no-receiver / no-I-N caveats and the source-aligned R23
power semantics.

### UE-driven 3-beam sector snapshots

Each Monte Carlo draw represents one *sector snapshot* of `numBeams`
simultaneously served UEs. `imtAasGenerateBeamSet`:

```
imtAasSampleUePositions  ->  imtAasUeToBeamAngles  ->  imtAasApplyBeamLimits
```

samples UE positions uniformly in area within the sector annulus, maps
each to a raw beam steering angle, and clamps to the R23 steering
envelope (`az ∈ [-60, 60]`, `el ∈ [-10, 0]` deg). The per-beam EIRP
grids are produced by `imtAasEirpGrid` and combined into the aggregate
grid by `imtAasSectorEirpGridFromBeams`:

```
aggregateEirpDbm = 10*log10(sum(10.^(perBeamEirpDbm / 10), 3))
```

### Power semantics (R23 macro 7.125-8.4 GHz)

| field                       | value | meaning |
| --------------------------- | ----- | ------- |
| `txPowerDbmPer100MHz`       | `46.1` | conducted BS transmit power [dBm / 100 MHz] |
| `peakGainDbi`               | `32.2` | peak composite antenna gain [dBi] |
| `sectorEirpDbm`             | `78.3` | **sector peak** EIRP [dBm / 100 MHz] = 46.1 + 32.2 |
| `numUesPerSector`           | `3`    | simultaneously served UEs per sector |
| `defaultSplitSectorPowerAcrossBeams` | `true` | per-beam peak EIRP split across simultaneous beams |

Key points:

* A **single reference beam** may peak at the full sector EIRP,
  `78.3 dBm / 100 MHz`.
* In a **3-UE simultaneous snapshot** the sector power is split across
  the three BS-UE links:
  ```
  perBeamPeakEirpDbm = sectorEirpDbm - 10*log10(numBeams)
                     = 78.3 - 10*log10(3)
                     ~ 73.53 dBm / 100 MHz
  ```
* The aggregate sector EIRP grid is a **linear power sum** across the
  simultaneous beams (not an envelope). When the three beams point in
  identical directions the aggregate peak returns to ~78.3 dBm/100 MHz
  (three -4.77 dB peaks summing in linear power); when they point in
  different directions the aggregate peak is below 78.3 dBm/100 MHz.

### Streaming histograms / percentile maps

`runR23AasEirpCdfGrid` reuses `update_eirp_histograms` and
`eirp_percentile_maps`, so a 65,341-cell `(az, el)` grid with
`numMc = 1e4` runs without materialising the ~5.2 GiB raw EIRP cube.
The streaming aggregator is the only state that grows with grid size,
not with `numMc`.

### CDF semantics

`out.percentileMaps` is the source-side Monte Carlo CDF over UE-driven
beam pointings, **not** a time-probability distribution. There is no
TDD activity factor, no network loading, and no propagation in this
slice; do not interpret percentiles as the probability that a victim
receiver sees a given EIRP unless those layers are added downstream.

### Files added in this slice

| file | role |
| ---- | ---- |
| `matlab/runR23AasEirpCdfGrid.m`        | source-aligned R23 EIRP CDF-grid runner |
| `matlab/plotR23AasEirpCdfGrid.m`       | mean + per-percentile heatmaps |
| `examples/runR23AasEirpCdfGridExample.m` | small deterministic end-to-end demo |
| `matlab/test_runR23AasEirpCdfGrid.m`   | self tests, wired into `run_all_tests` |

### Scope (what this slice is NOT)

This slice is **antenna-face EIRP only**. It does **not** add path
loss, propagation, receiver antennas, receiver gain, I / N, FS / FSS
receiver geometry, coordination-distance logic, multi-site / 19-site
aggregation, IMT / UE scheduling, TDD activity factor, network loading
factor, or full SSB / CSI-RS / PMI beam acquisition. The UE-driven
beam pointing is a first approximation; SSB / PDSCH / PMI is a
follow-up PR and lives below the streaming aggregator.

## R23 single-sector EIRP CDF MVP (BS-input-driven)

A minimal, R23-aligned MVP for generating per-(azimuth, elevation) EIRP
CDFs from one base station / one sector / N (default 3) UE-driven beams.
The module is a clean, BS-input-driven API that lives alongside the
streaming `runR23AasEirpCdfGrid` runner: every function accepts the
`bs` struct returned by `get_default_bs`, so any field on `bs` can be
overridden without editing simulator code.

What this MVP **does** implement:

* 1 site / 1 sector / 3 UEs (R23 default; configurable)
* UE-driven beamforming - the BS beam is steered toward each UE
* full Extended AAS array math (8 x 16 sub-arrays, 3 elements per
  vertical sub-array, 0.7 lambda intra-sub-array spacing, 0.5 lambda
  horizontal / 2.1 lambda vertical sub-array spacing, 3 deg fixed
  sub-array downtilt, 6 deg mechanical downtilt)
* azimuth coverage clamp +/- 60 deg, elevation coverage 90..100 deg
  global theta (= elevation -10..0 deg)
* Monte Carlo snapshots returning EIRP(grid_point, snapshot)
* per-cell empirical CDF and percentile maps
* deterministic outputs for a fixed RNG seed
* optional PNG / CSV export of per-cell CDF maps

What it explicitly **does NOT** implement (out of scope for this MVP):

* path loss (free-space, terrain, clutter, atmospheric)
* receiver antennas, receiver gain, I / N, FDR
* FS / FSS coordination geometry
* multi-site / 19-site aggregation, IMT-IMT aggregation
* full SSB / CSI-RS / PMI beam acquisition (UE-driven steering only)

### Vertical convention (internal elevation vs. R23 global theta)

The MVP carries two equivalent vertical-angle representations side by
side. Neither is silently substituted for the other; the conversion is
exposed in code (and tested in `test_single_sector_eirp_mvp`):

* **internal elevation** (used by every existing antenna call):
  `elevationDeg`, range `[-90, 90]`, `0 deg = horizon`,
  **negative = downtilt** (below the horizon). The R23 nominal beam at
  -9 deg elevation sits below the horizon, as expected.
* **R23 global theta** (M.2101 / WP5D vertical convention):
  `thetaGlobalDeg`, range `[0, 180]`, `90 deg = horizon`,
  `100 deg = 10 deg below horizon`.
* **conversion** (one-line, exact):
  `thetaGlobalDeg = 90 - elevationDeg`.

Both forms appear on the beam structs returned by the MVP:

| internal field   | R23 global-theta field   | source                           |
| ---------------- | ------------------------ | -------------------------------- |
| `rawElDeg`       | `rawThetaGlobalDeg`      | `compute_beam_angles_bs_to_ue`   |
| `steerElDeg`     | `steerThetaGlobalDeg`    | `clamp_beam_to_r23_coverage`     |
| `elLimitsDeg`    | `thetaGlobalLimitsDeg`   | `clamp_beam_to_r23_coverage` / layout |

The R23 source vertical coverage envelope is `thetaGlobal ∈ [90, 100]`
deg, equivalent to `elevation ∈ [-10, 0]` deg. Both forms are exposed on
the layout struct via `elLimitsDeg = [-10, 0]` and
`verticalCoverageGlobalThetaDeg = [90, 100]`. The MVP remains one site,
one sector, three UEs, and continues to exclude path loss, clutter, FS /
FSS modeling, interference aggregation, and network laydown.

### Default base-station input (override-friendly)

```matlab
bs = get_default_bs();
% bs =
%   id                  = "BS_001"
%   position_m          = [0, 0, 18]
%   azimuth_deg         = 0
%   sector_width_deg    = 120
%   height_m            = 18
%   environment         = "urban"        ("urban" or "suburban")
%   eirp_dBm_per_100MHz = 78.3           (R23 sector peak)
```

Every function in the MVP takes `bs` as input - **no values are
hardcoded internally**. Any field can be overridden:

```matlab
bs = get_default_bs();
bs.height_m       = 25;          % taller BS
bs.position_m(3)  = 25;          % keep position_m / height_m in sync
bs.azimuth_deg    = 30;          % rotate sector boresight 30 deg
bs.eirp_dBm_per_100MHz = 76.0;   % de-rated sector EIRP
```

If `bs.height_m` and `bs.position_m(3)` disagree,
`generate_single_sector_layout` issues a warning and `bs.height_m`
wins.

### Function map

| function                              | role                                            |
| ------------------------------------- | ----------------------------------------------- |
| `get_default_bs()`                    | R23 default BS struct                           |
| `get_r23_aas_params()`                | R23 antenna params (matches `imtAasDefaultParams`) |
| `validate_r23_params(params)`         | sanity-check antenna params                     |
| `generate_single_sector_layout(bs, params)` | sector geometry + steering envelope       |
| `sample_ue_positions_in_sector(bs, params, seed, N)` | uniform-area UE draws inside sector |
| `compute_beam_angles_bs_to_ue(bs, ue, params)` | raw geometric BS->UE pointing angles    |
| `clamp_beam_to_r23_coverage(bs, beams, params)` | clip to +/- 60 az / [-10, 0] el        |
| `compute_element_pattern(theta, phi, params)` | M.2101 single-element gain (dBi)         |
| `compute_subarray_factor(theta, phi, params)` | L-element vertical sub-array factor (dB) |
| `compute_array_factor(theta, phi, steering, params)` | N_H x N_V + L sub-array factor (dB) |
| `compute_bs_gain_toward_grid(bs, beams, grid, params)` | composite BS gain per beam (dBi)  |
| `compute_eirp_grid(bs, ue, grid, params, opts)` | one-snapshot per-direction EIRP grid (dBm) |
| `run_monte_carlo_snapshots(bs, grid, params, simConfig)` | MC EIRP cube `[Naz Nel numSnapshots]` |
| `compute_cdf_per_grid_point(eirpGrid, percentiles)` | per-cell CDF + percentile maps     |
| `plot_or_export_results(mc, cdf, opts)` | optional PNG / CSV export                     |
| `run_single_sector_eirp_demo(opts)`   | end-to-end demo                                 |

### How to run

```matlab
addpath('matlab');

% Default R23 single-sector demo (urban, 100 snapshots, 3 UEs).
out = run_single_sector_eirp_demo();

% Override the BS height + azimuth, save artifacts:
out = run_single_sector_eirp_demo(struct( ...
    'bsOverrides', struct( ...
        'height_m',    25, ...
        'position_m',  [0, 0, 25], ...
        'azimuth_deg', 30), ...
    'numSnapshots', 200, ...
    'seed',         42, ...
    'savePlot',     true, ...
    'saveCsv',      true, ...
    'plotPath',     'output/eirp_p95.png', ...
    'csvPath',      'output/eirp_pcts.csv'));

out.summary.peakAggregateEirpDbm     % ~ 78.3 dBm/100 MHz
out.cdfOut.percentileEirpDbm          % Naz x Nel x P
out.mcOut.eirpGrid                    % Naz x Nel x numSnapshots
```

A standalone example wrapper that writes artifacts under
`examples/output/` is in `examples/runSingleSectorEirpDemoExample.m`.

### Default grid and memory

The demo uses a coarse default grid (`az = -90:5:90`, `el = -30:5:10`)
and 100 snapshots (`numSnapshots = 100`). At those defaults the cube
size is 37 x 9 x 100 = ~33k doubles (~260 KB). For larger grids prefer
`runR23AasEirpCdfGrid`, which uses the streaming histogram aggregator
and never materializes the EIRP cube.

### Power semantics

`bs.eirp_dBm_per_100MHz = 78.3` is the **sector peak EIRP**. When the
sector simultaneously serves N UEs, the sector power is split across
the simultaneous BS-UE links by default
(`simConfig.splitSectorPower = true`):

```
perBeamPeakEirpDbm = bs.eirp_dBm_per_100MHz - 10*log10(N)
```

So with N = 3 the per-beam peak is 78.3 - 10*log10(3) ~ 73.53
dBm / 100 MHz. The aggregate peak across the 3 simultaneous beams (when
they happen to overlap perfectly) is 78.3 dBm / 100 MHz, conserving the
sector budget. Setting `splitSectorPower = false` lets each beam peak at
the full sector EIRP - use only for single-reference-beam diagnostics.

### R23 MVP acceptance contract

`test_r23_mvp_acceptance_contract` is a narrow, fast acceptance gate
that pins the R23 single-site / single-sector / N-UE EIRP CDF-grid MVP
as a **product contract**, not as a math regression. It complements
`test_single_sector_eirp_mvp` (which owns antenna math) and exists to
catch drift that would silently break callers or smuggle out-of-scope
modeling into the MVP core.

What it locks down:

* **Public API surface**: every MVP function file exists and is callable
  on the path (`get_r23_aas_params`, `validate_r23_params`,
  `get_default_bs`, `generate_single_sector_layout`,
  `sample_ue_positions_in_sector`, `compute_beam_angles_bs_to_ue`,
  `clamp_beam_to_r23_coverage`, `compute_bs_gain_toward_grid`,
  `compute_eirp_grid`, `run_monte_carlo_snapshots`,
  `compute_cdf_per_grid_point`, `run_single_sector_eirp_demo`).
* **R23 defaults**: 3 UEs / sector, 120 deg sector width, 35 m min UE
  distance, 18 m BS height, 78.3 dBm / 100 MHz BS EIRP, 8 x 16 Extended
  AAS array, +/- 60 deg horizontal coverage, `[90, 100]` global-theta
  vertical coverage and `[-10, 0]` internal elevation coverage.
* **Vertical convention**: `rawThetaGlobalDeg` on
  `compute_beam_angles_bs_to_ue`, `steerThetaGlobalDeg` and
  `thetaGlobalLimitsDeg` on `clamp_beam_to_r23_coverage`,
  `thetaGlobalDeg = 90 - elevationDeg`, horizon -> 90 deg, 10 deg
  downtilt -> 100 deg.
* **Determinism**: a small `numSnapshots = 5` MC run with a fixed seed
  is bit-equal across reruns; `eirpGrid` shape is `[Naz, Nel,
  numSnapshots]`; per-cell percentile maps are non-decreasing.
* **Input-driven BS**: overriding `bs.height_m`, `bs.azimuth_deg`, and
  `bs.eirp_dBm_per_100MHz` propagates to downstream beam angles, global
  theta, azimuth offset, and per-beam peak EIRP without mutating the
  defaults returned by `get_default_bs()`.
* **Scope guard**: a static token scan over the MVP core MATLAB files
  (the ten functions consumed by `run_single_sector_eirp_demo`) refuses
  out-of-scope tokens (`p2001`, `p2108`, `pathLoss`, `clutterLoss`,
  `fsReceiver`, `fssReceiver`, `victimReceiver`,
  `interferenceAggregation`, `nineteenSite`, `fiftySevenSector`,
  `numSites = 19`, `numSectors = 57`).
* **Legacy hygiene**: best-effort repo-wide scan finds no `EMBRSS` /
  `embrss` / `Embrss` occurrences. The shell equivalent is

  ```sh
  grep -RIn "EMBRSS\|embrss\|Embrss" .
  ```

How to run:

```matlab
addpath('matlab');
test_r23_mvp_acceptance_contract
```

It is also wired into `run_all_tests` after `test_single_sector_eirp_mvp`,
so `run_all_tests` covers it automatically. The gate exists to prevent
drift beyond the one-site, one-sector, three-UE EIRP CDF-grid MVP - it
deliberately does not assert anything about path loss, FS / FSS
receivers, interference aggregation, or 19-site / 57-sector laydown,
none of which are part of this MVP.

### Deterministic ground-truth antenna geometry tests

`test_r23_ground_truth_antenna_geometry` is a small set of "known
answer" geometry checks that anchor the R23 single-sector EIRP CDF-grid
MVP to behaviour that is independent of any tuning choice in the
antenna model. The tests are deterministic - no Monte Carlo, no random
seeds - and use fixed UE / grid geometries so a flipped elevation sign
or a swapped azimuth-clamp side cannot pass.

It covers:

* **Boresight peak**: a UE directly in front of the sector at default
  height (1.5 m, 200 m range) gives a small natural downtilt that sits
  inside the R23 envelope, so no clamp occurs. The composite BS gain
  evaluated at the steered direction is the max among coarse azimuth-
  offset comparison points at the same elevation.
* **Off-axis gain drop**: with the same steered beam, the composite
  gain decreases monotonically across azimuth offsets `{0, 30, 60}`
  deg from boresight at the steered elevation.
* **R23 global-theta convention**: a UE at the same height as the BS
  yields `rawElDeg ~ 0` and `rawThetaGlobalDeg ~ 90`; a UE 10 deg
  below the horizon yields `rawElDeg ~ -10` and
  `rawThetaGlobalDeg ~ 100` (matching `thetaGlobalDeg = 90 - elevationDeg`).
* **Beam clamp behaviour**: `rawElDeg = +5` clamps to
  `steerElDeg = 0` / `steerThetaGlobalDeg = 90`; `rawElDeg = -20`
  clamps to `steerElDeg = -10` / `steerThetaGlobalDeg = 100`;
  `rawAzDeg = +/-90` and `-75` clamp to `+/-60` while a `+45` raw
  azimuth is left untouched.
* **EIRP finite / relative sanity**: with the boresight setup the
  per-beam EIRP at the aligned grid point is finite and exceeds the
  off-axis comparison points; output dimensions match the documented
  `[Naz, Nel, numBeams]` shape.

How to run:

```matlab
addpath('matlab');
test_r23_ground_truth_antenna_geometry
```

It is wired into `run_all_tests` after
`test_r23_mvp_acceptance_contract`, so `run_all_tests` covers it
automatically.

## Angle conventions

Matched to pycraf:

* external azimuth `azim` ∈ [-180°, 180°]
* external elevation `elev` ∈ [-90°, 90°]
* internal polar angle `θ = 90° - elev`
* beam tilt convention `θ_i = -elev_i` (M.2101 / pycraf convention; see
  `imt2020_composite_pattern.m` for the inline note)

## Assumptions

* Conducted `txPower_dBm` is the total power radiated by the array. The
  composite pattern returned in dBi already aggregates the array factor,
  so no additional `10·log10(N_H·N_V)` term is added on top of the gain.
* Element separation `d_H`, `d_V` are in wavelengths, no out-of-band
  scaling is applied automatically; if needed scale `d` for OOB
  frequency exactly as pycraf documents.
* The default multiplication factor `k = 12` matches M.2101. The 3GPP
  measurement-fitted value `k = 8` is supported by passing `cfg.k = 8`.
* Monte Carlo: per-cell statistics use the central limit on uniform
  draws; the linear-mW mean is the appropriate "average power" estimator.
* Per-cell histogram bin edges are user-supplied; out-of-range samples
  are clipped to the first / last bin (consistent with empirical-CDF
  conventions).

## Limitations

* Only the M.2101 base-station AAS antenna and EIRP piece is implemented.
  No path loss, no SINR, no scheduling, no UE mobility, no aggregation
  across multiple base stations, no spurious-domain scaling.
* The IMT advanced (LTE) sectoral peak / average side-lobe patterns
  from F.1336 are not ported.
* No GPU / parallel acceleration is built in. `parfor` can be wrapped
  around the Monte Carlo loop in `run_imt_aas_eirp_monte_carlo.m` but
  the streaming update is not yet thread-safe for shared state.
* **This is not ITU-certified.** It is a research / engineering port for
  internal use. Always cross-check against M.2101 and 3GPP TR 37.840
  before using results in regulatory or compliance contexts.

## Quick start

```matlab
addpath('matlab');

% 1. Self tests
test_aas_monte_carlo_eirp();

% 2. Pycraf cross-check (if pyenv + pycraf available)
test_against_pycraf();

% 2b. Strict pycraf equivalence gate (3 fixed + 50 randomized beams,
%     max abs error <= 1e-6 dB).
test_against_pycraf_strict();

% 3. Demo
out = demo_aas_monte_carlo_eirp();
```

## Testing

There is one entry point that runs the full suite and prints a pass / fail
summary:

```matlab
% from the repository root
run_all_tests
```

`run_all_tests.m` adds `matlab/` to the path, runs the test functions
below, and prints a single per-test summary line plus a final
`pass / fail / skip / error` count. Skipped tests do not fail the suite.

### MATLAB-only tests

These run with no Python dependency:

```matlab
addpath('matlab');
test_aas_monte_carlo_eirp();          % antenna sanity + Monte Carlo stats
test_export_eirp_percentile_table();  % p000..p100 table exporter
test_ue_sector_sampler();             % UE-driven sector beam sampler
test_single_sector_eirp_mvp();        % R23 single-sector / 3-UE MVP
```

`test_single_sector_eirp_mvp` covers the BS-input-driven MVP end to
end:

* `get_default_bs` returns the R23 baseline (h=18, az=0, 120 deg sector,
  78.3 dBm/100 MHz, urban)
* `validate_r23_params` accepts `get_r23_aas_params` and rejects bad
  overrides (`numColumns = -1` -> `validate_r23_params:badType`)
* `generate_single_sector_layout` returns +/- 60 az / [-10, 0] el
  envelopes, 35 m min UE distance, env-driven cell radius (urban 400 m
  / suburban 800 m), and `bs.height_m` wins on `position_m(3)` mismatch
* `sample_ue_positions_in_sector` keeps UEs inside [35, cellRadius] m,
  inside `azLimitsDeg`, at 1.5 m height, with seeded reproducibility
* `compute_beam_angles_bs_to_ue` matches `atan2d` analytically and gives
  negative elevation (downtilt) for default UE / BS heights
* `clamp_beam_to_r23_coverage` clips az to +/- 60 and el to [-10, 0]
  and flags clipping
* `compute_bs_gain_toward_grid` peak gain is within 0.1 dB of the R23
  reference 32.2 dBi
* `compute_eirp_grid` aggregate peak for three identical beams equals
  `bs.eirp_dBm_per_100MHz` exactly, with per-beam peak
  `78.3 - 10*log10(3) = 73.53` dBm/100 MHz
* `run_monte_carlo_snapshots` is deterministic for a fixed seed and
  produces an `[Naz Nel numSnapshots]` cube
* `compute_cdf_per_grid_point` percentile maps are non-decreasing along
  the percentile axis
* BS overrides change behaviour: `bs.height_m = 25` increases downtilt,
  `bs.eirp_dBm_per_100MHz = 70` lowers per-beam and aggregate peak by
  exactly 8.3 dB
* `run_single_sector_eirp_demo` runs end to end and produces non-empty
  per-cell CDF maps
* `sample_aas_beam_direction` `ue_sector` mode draws UE heights uniformly
  from `ue_height_range_m` (and reports them in `dbg.ueHeight_m`);
  scalar `ue_height_m` mode still works
* same-seed reruns produce identical `stats.counts` and `stats.mean_dBm`;
  a different seed changes at least some counts or means
* `stats.counts` sums to `numMc` at every `(az, el)` cell, percentile
  maps are finite at populated cells and monotonic non-decreasing in
  percentile, and the returned struct never carries a raw EIRP cube
* the optional CSV export round-trips via `readtable`

`test_ue_sector_sampler` covers:

* `ue_sector` returns azimuths inside `[sector_az - W/2, sector_az + W/2]`
* `ue_sector` returns elevations equal to `atan2d(ue_height_m - bs_height_m, range_m)`
* `uniform_area` produces a larger average BS-to-UE range than
  `uniform_radius` over the same `[r_min_m, r_max_m]`
* a fixed RNG seed produces repeatable UE-driven beam draws
* the existing `uniform`, `sector`, `fixed`, and `list` sampler modes
  still pass unchanged
* the Monte Carlo runner accepts `mode='ue_sector'` without changing the
  downstream histogram, CDF, percentile maps, exceedance maps, or
  per-(az,el) percentile-table exporter behavior

`test_aas_monte_carlo_eirp` covers:

* single-element boresight equals `G_Emax`
* single-element off-axis gain is lower than boresight
* composite pattern returns finite values over an az/el grid
* composite gain changes when beam pointing changes
* `rho = 0` collapses the array contribution toward the single-element
  pattern
* `rho = 1` gives the full coherent composite result (boresight =
  `G_Emax + 10*log10(N_H * N_V)`)
* azimuth symmetry around boresight (`rho = 1`)
* fixed-beam mode is repeatable across runs with the same seed
* histogram counts sum to `numMc` at every `(az, el)` cell
* the empirical CDF is monotonic non-decreasing at every populated cell
* the final CDF value equals 1 at every populated cell
* `mean_lin_mW` and `mean_dBm` reflect averaging in linear mW (not dBm),
  cross-checked against an independent recomputation of the EIRP cube
* per-percentile maps are monotonic non-decreasing in `p`
* exceedance probability `P(EIRP > thr)` is non-increasing in threshold

`test_export_eirp_percentile_table` covers:

* default `azGrid = -180:1:180`, `elGrid = -90:1:90` produces a 65,341 x
  103 table
* the first two columns are `azimuth_deg` and `elevation_deg`
* percentile columns are named `p000` through `p100` in order
* per-row monotonicity of `p000:p100`
* `p000` equals the minimum occupied EIRP bin center, `p100` equals the
  maximum occupied EIRP bin center
* cells with zero samples produce `NaN` across `p000:p100`
* the function operates on the streaming histogram only (no raw EIRP
  sample cube required)
* CSV is written when `outputCsvPath` is provided
* the function returns the table when `outputCsvPath` is omitted or
  empty

### Pycraf comparison test (optional)

`test_against_pycraf` cross-checks the MATLAB single-element and
composite patterns against pycraf, evaluated on the same input grid
(`azim = -180:10:180`, `elev = -90:10:90`) with identical parameters
(`G_Emax = 8`, `A_m = SLA_nu = 30`, `phi_3db = theta_3db = 65`,
`d_H = d_V = 0.5`, `N_H = N_V = 8`, `rho = 1`, `k = 12`) and three
beam-pointing cases:

| `azim_i` | `elev_i` |
| -------- | -------- |
| 0        |   0      |
| 30       |  -5      |
| -45      | -10      |

Each comparison prints max abs error and mean abs error in dB and passes
when `max abs error <= 1e-6 dB`.

Install pycraf if you want to run this comparison:

```bash
pip install pycraf
```

Then point MATLAB at the right Python interpreter (one-time):

```matlab
pyenv('Version', '/path/to/python')   % only if MATLAB hasn't picked it up
test_against_pycraf();
```

If `pyenv`, Python, or pycraf is not available the test prints a clear
`SKIP` message with the reason and does not fail the MATLAB-only test
runs. Pycraf validation is **optional but recommended** for any change
that touches the antenna math.

### Strict pycraf equivalence gate

`test_against_pycraf_strict` is the authoritative regression gate for
the antenna math. It directly compares the MATLAB
`imt2020_single_element_pattern.m` and `imt2020_composite_pattern.m`
against `pycraf.antenna.imt2020_single_element_pattern` and
`pycraf.antenna.imt2020_composite_pattern` on the spec input grid
(`azim = -180:10:180`, `elev = -90:10:90`) with identical parameters
(`G_Emax = 8`, `A_m = SLA_nu = 30`, `phi_3db = theta_3db = 65`,
`d_H = d_V = 0.5`, `N_H = N_V = 8`, `rho = 1`, `k = 12`).

Beam-pointing cases:

| `azim_i`   | `elev_i`   |
| ---------- | ---------- |
| 0          |   0        |
| 30         |  -5        |
| -45        | -10        |
| 50 random  | 50 random  |

The 50 randomized cases are drawn from a fixed `RandStream` seed
(`mt19937ar`, seed `20240501`) so the same beam directions are exercised
on every run. `azim_i` is uniform in `[-180, 180]` deg and `elev_i` is
uniform in `[-90, 90]` deg.

**Pass rule:** `max abs error <= 1e-6 dB` across every (az, el) point and
every beam-pointing case.

Run it from MATLAB:

```matlab
addpath('matlab');
test_against_pycraf_strict();          % standalone
% or via the suite:
run_all_tests
```

Like `test_against_pycraf`, the strict variant skips cleanly when
`pyenv`, Python, or pycraf is unavailable - it prints a clear `SKIP`
message with the reason and does not fail MATLAB-only test runs.

> **Any change that touches the antenna math (single-element pattern,
> composite array factor, angle conventions, `k` / `rho` handling) MUST
> leave `test_against_pycraf_strict` passing.** Treat this as the
> regression gate for pycraf parity. Do not merge changes to
> `imt2020_single_element_pattern.m` or `imt2020_composite_pattern.m`
> without rerunning this test in an environment where pycraf is
> installed.

## Beam-pointing samplers

`sample_aas_beam_direction(opts)` is the only entry point for choosing the
AAS beam pointing(s) used by every Monte Carlo iteration. It supports two
families of sampling, controlled by `opts.mode`.

### Direct beam-direction sampling

The original modes draw beam azimuth / elevation directly, without any
implicit UE geometry:

| `opts.mode` | What it draws                                                                        |
| ----------- | ------------------------------------------------------------------------------------ |
| `uniform`   | `azim ~ U(opts.azim_range)`, `elev ~ U(opts.elev_range)`                             |
| `sector`    | uniform within a 3-sector cell of width `opts.sector_az_width` centered on `opts.sector_az`; elevation uniform within `opts.elev_range` |
| `fixed`     | deterministic `opts.azim_i` / `opts.elev_i` (useful for repeatability tests)         |
| `list`      | uniform draws from `opts.azim_list` / `opts.elev_list`                               |

In these modes the sampler does **not** know about the base-station height,
the cell radius, or where any UE actually is - it just hands a `(beamAz,
beamEl)` pair to the Monte Carlo engine.

### UE-driven sector sampling (`ue_sector`)

`mode = 'ue_sector'` is a higher-level wrapper that puts a randomized UE
inside a sector and converts that UE into the beam pointing the BS would
use:

```matlab
beamSampler.mode             = 'ue_sector';
beamSampler.sector_az_deg    = 0;     % sector boresight azimuth   [deg]
beamSampler.sector_width_deg = 120;   % sector opening             [deg]
beamSampler.r_min_m          = 10;    % minimum BS-to-UE range     [m]
beamSampler.r_max_m          = 500;   % maximum BS-to-UE range     [m]
beamSampler.bs_height_m      = 25;    % base-station antenna AGL   [m]
beamSampler.ue_height_m      = 1.5;   % UE antenna AGL             [m]
beamSampler.numBeams         = 1;     % UEs (and beams) per draw

% Optional distribution controls (defaults shown):
beamSampler.radial_distribution = 'uniform_area';   % or 'uniform_radius'
beamSampler.az_distribution     = 'uniform';
beamSampler.elev_clip_deg       = [-90 90];
```

Geometry per UE:

```
beamAz_deg = sector_az_deg + uniform(-sector_width_deg/2, sector_width_deg/2)

if radial_distribution == 'uniform_area':
    r = sqrt( r_min_m^2 + rand() * (r_max_m^2 - r_min_m^2) )
elif radial_distribution == 'uniform_radius':
    r = r_min_m + rand() * (r_max_m - r_min_m)

beamEl_deg = atan2d(ue_height_m - bs_height_m, r)
```

`uniform_area` makes UE locations uniformly distributed over the annulus
between `r_min_m` and `r_max_m` (the natural choice when UEs are spread
uniformly across the sector). `uniform_radius` weighs near-in radii more
heavily and is mostly useful for sensitivity tests.

The sampler optionally returns a third `dbg` struct with the underlying
UE geometry, useful for plotting or debugging:

```matlab
[beamAz, beamEl, dbg] = sample_aas_beam_direction(beamSampler);
% dbg.ueRange_m, dbg.ueAz_deg, dbg.ueEl_deg, dbg.ueX_m, dbg.ueY_m
```

In `ue_sector` mode, Monte Carlo draws randomized UE locations inside the
sector, converts each UE to an AAS beam pointing direction, and then
computes EIRP toward each fixed observation azimuth / elevation bin. The
streaming histogram, percentile maps, exceedance maps and table exporter
are all unchanged - the only thing that changes is how the per-iteration
beam pointing is chosen.

```matlab
mcOpts.beamSampler = struct( ...
    'mode', 'ue_sector', ...
    'sector_az_deg', 0, 'sector_width_deg', 120, ...
    'r_min_m', 10, 'r_max_m', 500, ...
    'bs_height_m', 25, 'ue_height_m', 1.5, ...
    'radial_distribution', 'uniform_area', ...
    'numBeams', 1);
stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
```

## Per-(az,el) EIRP percentile table

`export_eirp_percentile_table(stats, csvPath)` collapses the streaming
histogram into a flat table where each row is one (azimuth, elevation)
observation bin and the columns `p000`, `p001`, ..., `p100` hold the EIRP
in dBm at integer CDF percentiles 0..100.

```
azimuth_deg, elevation_deg, p000, p001, ..., p100
```

The CDF is the empirical distribution over Monte Carlo active-beam
realizations at each fixed observation direction. Bin centers are used
as the EIRP value for each percentile via the smallest histogram bin
whose cumulative probability is at least `q/100`. By convention `p000`
is the first nonzero occupied bin center and `p100` is the last nonzero
occupied bin center, so the `p000:p100` columns are monotonically
non-decreasing across each row. Cells with zero samples emit `NaN`
across all percentile columns.

For the default `azGrid = -180:1:180` and `elGrid = -90:1:90` the table
has `361 * 181 = 65,341` rows and `2 + 101 = 103` columns.

```matlab
addpath('matlab');
out = demo_export_eirp_percentile_table();   % writes eirp_percentile_table.csv
```

The exporter never reconstructs the raw EIRP sample cube; it operates
directly on the streaming histogram (`stats.counts` /
`stats.histCounts`).

## pycraf comparison mode

`test_against_pycraf.m` uses MATLAB's `pyenv` to import `pycraf.antenna`
and `astropy.units`, evaluates `imt2020_single_element_pattern` and
`imt2020_composite_pattern` on the spec grid in both languages, and
reports max / mean abs error per case. A reference run of the underlying
equations against pycraf 2.1 reproduces the result to within ~2.4e-12 dB
across a 37x19 (az, el) grid. The test skips cleanly when Python or
pycraf is unavailable. See the [Testing](#testing) section for the input
grid, parameters, and beam-pointing cases that the test sweeps.

`test_against_pycraf_strict.m` is the strict equivalence gate that
covers the same single-element and composite-pattern checks plus 50
additional randomized beam-pointing cases at a fixed `1e-6 dB`
tolerance; see the
[Strict pycraf equivalence gate](#strict-pycraf-equivalence-gate) section
above. **Any change to the antenna math must keep this test passing.**

## Scaling and runtime

The full default observation grid is `azGrid = -180:1:180` and
`elGrid = -90:1:90`, which is `361 * 181 = 65,341` az/el cells. Runtime
scales roughly with

```
T  ~  numAz * numEl * numMc * N_H * N_V
```

(antenna evaluations dominate; the streaming histogram update scales with
`numAz * numEl` per draw and is independent of `numMc` per call).

### Storage strategy

The Monte Carlo engine never materialises the per-draw `Naz x Nel x numMc`
EIRP cube. Instead, `update_eirp_histograms` keeps a fixed-size streaming
aggregator:

* `stats.counts` ............. `Naz x Nel x Nbin uint32` histogram
* `stats.sum_lin_mW` ......... `Naz x Nel double` running linear-mW sum
* `stats.min_dBm`, `max_dBm` . `Naz x Nel double` running per-cell extrema

For the full default grid with `binEdges = -50:1:120` (170 bins) the
histogram is `~42 MiB`, the percentile table is `~52 MiB`, and the
CSV is on the order of `~80 MiB`. A raw EIRP cube at `numMc = 1e4`
would be `~5.2 GiB` for the same grid - prefer histogram storage.

### Estimating memory before a run

`estimate_aas_mc_memory(numAz, numEl, numBins[, countType[, opts]])` is a
pure-arithmetic estimator. It never allocates the structures it sizes:

```matlab
addpath('matlab');
out = estimate_aas_mc_memory(361, 181, 170, 'uint32', ...
    struct('numMc', 1e4, 'verbose', true));
```

It returns:

* `histCountsBytes`, `streamingSumsBytes`, `perCellExtrasBytes`,
  `totalRunningBytes`
* `percentileTableBytes`, `csvBytes`
* `rawCubeBytesPerDraw`, `rawCubeBytesAtNumMc`, `rawCubeWarning`
  (the warning fires when a hypothetical raw cube exceeds
  `rawCubeWarnThresholdBytes`, default 1 GiB)
* `summary` - a multi-line human-readable string

When `opts.verbose = true` it also prints the summary.

### Profiling runtime

`profile_aas_monte_carlo_runtime` runs benchmark cases and extrapolates
to the full grid. By default it runs:

| case   | azGrid       | elGrid       | numMc |
| ------ | ------------ | ------------ | ----- |
| small  | `-30:5:30`   | `-20:5:10`   | 100   |
| medium | `-90:2:90`   | `-30:2:10`   | 500   |

It then estimates full-grid runtime at `numMc = 1e3`, `1e4`, `1e5` from
the slowest measured per-cell-per-draw time. The full-grid case is a
*dry-run estimate by default*; pass `opts.runFullGrid = true` and
`opts.fullGridNumMc` to actually execute the full grid.

```matlab
addpath('matlab');
out = profile_aas_monte_carlo_runtime();           % small + medium
out = profile_aas_monte_carlo_runtime(struct( ...
    'cases', {{'small'}}, ...
    'verbose', true, ...
    'quiet',   true));                             % minimal output
```

The result struct contains per-case timings (`elapsedSeconds`,
`secondsPerDraw`, `secondsPerCellPerDraw`) plus an `extrapolation`
sub-struct with `numMc1e3 / numMc1e4 / numMc1e5` runtime estimates and a
linked memory estimate from `estimate_aas_mc_memory`.

### Chunking, progress, reproducibility

`run_imt_aas_eirp_monte_carlo` accepts three controls relevant to large
runs:

| field               | type    | default     | meaning                                                  |
| ------------------- | ------- | ----------- | -------------------------------------------------------- |
| `mcOpts.seed`       | scalar  | (unset)     | RNG seed; identical seeds reproduce identical stats.     |
| `mcOpts.mcChunkSize`| integer | `numMc`     | Process MC draws in chunks of this size.                 |
| `mcOpts.progressEvery` | int  | 0 (silent)  | Print `[MC] i / N (..%) elapsed=.. ETA=..` every N draws.|

Chunking does **not** change the RNG sequence, the loop iteration order,
or the streaming aggregator update; chunked and unchunked runs with the
same seed produce **bit-identical** `counts / sum_lin_mW / min_dBm /
max_dBm`. This is exercised by `test_runtime_scaling_controls`.

The driver also reports `stats.elapsedSeconds` (wall-clock seconds spent
inside the MC loop) so callers can record per-run timing without
wrapping `tic / toc` themselves.

### Recommended workflow

1. **Run the test suite** to confirm the antenna math and streaming
   aggregator are healthy in your environment:

   ```matlab
   run_all_tests
   ```

2. **Run the small demo** end-to-end to sanity-check plotting and the
   per-(az,el) summary:

   ```matlab
   addpath('matlab');
   out = demo_aas_monte_carlo_eirp();
   ```

3. **Run the profiler** to measure per-cell-per-draw cost on the local
   machine and to extrapolate to the full grid:

   ```matlab
   prof = profile_aas_monte_carlo_runtime();
   ```

4. **Estimate memory** for the chosen grid / numMc / countType:

   ```matlab
   mem = estimate_aas_mc_memory(361, 181, 170, 'uint32', ...
       struct('numMc', 1e4, 'verbose', true));
   ```

5. **Run the full grid** with the chosen `numMc`, a fixed `seed`, and
   chunking + progress reporting tuned for the run:

   ```matlab
   mcOpts = struct( ...
       'numMc', 1e4, 'azGrid', -180:1:180, 'elGrid', -90:1:90, ...
       'binEdges', -50:1:120, ...
       'seed', 1, 'mcChunkSize', 500, 'progressEvery', 500, ...
       'beamSampler', struct('mode', 'sector', ...
           'sector_az', 0, 'sector_az_width', 120, ...
           'elev_range', [-10, 0], 'numBeams', 1));
   stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
   ```

6. **Export the percentile table** for downstream consumers:

   ```matlab
   export_eirp_percentile_table(stats, 'eirp_percentile_table.csv');
   ```

`test_runtime_scaling_controls` covers:

* the memory estimator returns positive finite estimates and rejects
  unknown `countType`s
* the raw-cube warning fires when the implied raw cube exceeds the
  configurable threshold (and stays quiet otherwise)
* the profiler runs a tiny benchmark without error and reports
  `secondsPerDraw > 0`
* chunked and unchunked runs with the same seed produce bit-identical
  streaming statistics
* identical seeds produce identical stats; different seeds do not
* `progressEvery = 0` emits no progress lines, while `progressEvery > 0`
  emits at least one `[MC] ... ETA=...` line

