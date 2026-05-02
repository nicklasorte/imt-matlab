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
└── test_runtime_scaling_controls.m    self tests for chunking / memory / progress
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

## EMBRSS-style EIRP CDF-grid first step

`run_embrss_eirp_cdf_grid(category, opts)` is the first step of an
EMBRSS recreation: a per-(az, el) **EIRP CDF-grid generator** for an IMT
AAS base station, organised by deployment category. It is *only* the
antenna / EIRP piece. It explicitly does **not** implement:

* full Quadriga SSB acquisition / CSI-RS / PMI selection (the per-draw
  beam pointing is a UE-driven sector approximation; SSB/PDSCH/PMI is a
  follow-up PR)
* free-space or terrain path loss, clutter loss, atmospheric loss
* frequency-dependent rejection (FDR)
* FS / FSS receiver antennas or boresight pointing
* multi-site (e.g. 19-site) base-station aggregation
* aggregate I / N
* separation-distance search

The wrapper resolves a category preset, builds an AAS config, drives
`run_imt_aas_eirp_monte_carlo` with `beamSampler.mode = 'ue_sector'`,
and collapses the streaming histograms into mean / percentile maps.

### Categories

`embrss_category_model(category)` returns geometric / UE-density
defaults for one of:

| `category`         | `bs_height_m` | `sector_radius_m` | `ue_height_range_m` |
| ------------------ | ------------- | ----------------- | ------------------- |
| `urban_macro`      | 20            | 400               | `[1.5  35]`         |
| `suburban_macro`   | 25            | 800               | `[1.5  17]`         |
| `rural_macro`      | 35            | 1600              | `[1.5   5]`         |

All three categories use `sector_width_deg = 120`,
`min_ue_range_m = 35`, and `num_ues_per_sector = 3`. Numeric fields can
be overridden with name-value pairs.

### Conducted power vs peak EIRP

`embrss_aas_config(category, ...)` returns an antenna config compatible
with `imt_aas_bs_eirp` / `run_imt_aas_eirp_monte_carlo`. Because

```
eirp_dBm = txPower_dBm + gain_dBi - feederLoss_dB
```

`txPower_dBm` is **conducted** power, not peak EIRP. To avoid
double-counting antenna gain, the wrapper exposes two power modes:

| `powerMode`     | meaning                                                                                   |
| --------------- | ----------------------------------------------------------------------------------------- |
| `'conducted'`   | `cfg.txPower_dBm` is taken at face value (default 20 dBm for safe demos).                  |
| `'peak_eirp'`   | Caller passes `peakEirp_dBm` (and optionally `peakGain_dBi`); conducted power is back-computed so `txPower + peakGain - feederLoss = peakEirp`. |

In `peak_eirp` mode, if `peakGain_dBi` is omitted it defaults to
`G_Emax + 10*log10(N_H * N_V)` (the rho = 1 boresight gain of the
composite pattern). Passing both `txPower_dBm` and `peakEirp_dBm`, or
passing `peakEirp_dBm` while `powerMode = 'conducted'`, raises an error
- the most common way to accidentally double-count antenna gain.

### How to run

```matlab
addpath('matlab');

% Quick demo: small grid, 200 MC draws, urban_macro
out = demo_embrss_eirp_cdf_grid();

% Full grid for a category, conducted power
out = run_embrss_eirp_cdf_grid('urban_macro', struct( ...
    'numMc',        1000,           ...
    'azGrid',       -180:1:180,     ...
    'elGrid',        -90:1:90,      ...
    'binEdges',      -80:1:120,     ...
    'seed',          1,             ...
    'progressEvery', 100,           ...
    'numBeams',      3));

% EMBRSS-style high-power example: peak EIRP = 72 dBm at array boresight
out = run_embrss_eirp_cdf_grid('urban_macro', struct( ...
    'numMc',        1000,           ...
    'powerMode',    'peak_eirp',    ...
    'peakEirp_dBm', 72,             ...
    'seed',         1));

out.stats.counts        % Naz x Nel x Nbin uint32 histogram
out.stats.mean_dBm      % Naz x Nel       linear-mW averaged mean EIRP
out.percentileMaps      % struct from eirp_percentile_maps
out.cfg                 % AAS cfg passed to imt_aas_bs_eirp
out.metadata            % step + caveat string + ISO timestamp
```

The driver never reconstructs or returns a raw EIRP cube of shape
`Naz x Nel x numMc`; it inherits the streaming aggregator from
`run_imt_aas_eirp_monte_carlo`.

If `opts.outputCsvPath` is non-empty the wrapper also writes the
`p000:p100` per-(az, el) percentile table via
`export_eirp_percentile_table`.

### Modeling caveat

This step is an **EMBRSS-style antenna / EIRP CDF-grid generator**, not a
full Quadriga / CSI / PMI implementation. The per-iteration beam
pointing is drawn by `sample_aas_beam_direction(..., 'ue_sector')`,
which places a UE uniformly in the sector annulus and converts that UE
to a beam direction. A later PR can replace the beam-state sampler with
a true SSB / PDSCH / PMI model **without touching this driver**: the
streaming histogram, percentile maps, and exporter all live below the
beam sampler.

The current default uses the existing repo M.2101 / pycraf-parity
composite pattern (`cfg.patternModel = 'm2101'`). The R23 7/8 GHz
extended sub-array variant is available via `cfg.patternModel =
'r23_extended_aas'` but is not enabled by `embrss_aas_config` defaults.

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
test_embrss_eirp_cdf_grid();          % EMBRSS first-step CDF-grid wrapper
```

`test_embrss_eirp_cdf_grid` covers:

* category presets (urban / suburban / rural macro) return the expected
  BS heights, sector radii, and UE-height ranges; invalid category names
  throw `embrss_category_model:badCategory`
* `embrss_aas_config` `'conducted'` mode preserves `txPower_dBm` and the
  end-to-end boresight EIRP equals `txPower + peakGain - feederLoss`
* `embrss_aas_config` `'peak_eirp'` mode back-computes conducted power so
  `txPower + peakGain - feederLoss = peakEirp_dBm` (no antenna-gain
  double-count); supplying `peakEirp_dBm` while `powerMode='conducted'`
  is rejected
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

