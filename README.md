# imt-matlab

MATLAB implementation of the ITU-R Rec. M.2101-0 IMT-2020 Active-Antenna-System
(AAS) base-station antenna / EIRP model, with a streaming Monte Carlo harness
for per-direction EIRP statistics.

## Layout

```
run_all_tests.m                        single entry point for the test suite
matlab/
├── imt2020_single_element_pattern.m   single element gain (M.2101 Table 4)
├── imt2020_composite_pattern.m        composite array gain
├── imt_aas_bs_eirp.m                  conducted-power-to-EIRP mapping
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
├── test_aas_monte_carlo_eirp.m        MATLAB-only self tests
├── test_export_eirp_percentile_table.m self tests for the table exporter
└── test_ue_sector_sampler.m           self tests for the ue_sector beam sampler
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
* The `imt2020_composite_pattern_extended` (sub-array / electronic
  downtilt) variant from pycraf is *not* ported - it was not requested
  in the task scope.
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

`run_all_tests.m` adds `matlab/` to the path, runs the four test
functions below, and prints a single per-test summary line plus a final
`pass / fail / skip / error` count. Skipped tests do not fail the suite.

### MATLAB-only tests

These run with no Python dependency:

```matlab
addpath('matlab');
test_aas_monte_carlo_eirp();          % antenna sanity + Monte Carlo stats
test_export_eirp_percentile_table();  % p000..p100 table exporter
test_ue_sector_sampler();             % UE-driven sector beam sampler
```

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
