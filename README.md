# imt-matlab

MATLAB implementation of the ITU-R Rec. M.2101-0 IMT-2020 Active-Antenna-System
(AAS) base-station antenna / EIRP model, with a streaming Monte Carlo harness
for per-direction EIRP statistics.

## Layout

```
matlab/
├── imt2020_single_element_pattern.m   single element gain (M.2101 Table 4)
├── imt2020_composite_pattern.m        composite array gain
├── imt_aas_bs_eirp.m                  conducted-power-to-EIRP mapping
├── sample_aas_beam_direction.m        beam-pointing samplers (uniform/sector/fixed/list)
├── update_eirp_histograms.m           streaming per-cell stats update
├── run_imt_aas_eirp_monte_carlo.m     MC driver, never stores the EIRP cube
├── eirp_percentile_maps.m             per-angle percentile maps from histograms
├── eirp_cdf_at_angle.m                empirical CDF at one (az,el)
├── eirp_exceedance_maps.m             P(EIRP > threshold) maps
├── demo_aas_monte_carlo_eirp.m        end-to-end example
├── test_against_pycraf.m              optional pycraf cross-check via pyenv
└── test_aas_monte_carlo_eirp.m        MATLAB-only self tests
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

## pycraf comparison mode

`test_against_pycraf.m` uses MATLAB's `pyenv` to import `pycraf.antenna`
and `astropy.units`, evaluates `imt2020_composite_pattern` on a small
grid in both languages, and reports max / mean abs error. A reference run
of the underlying equations against pycraf 2.1 reproduces the result to
within ~2.4e-12 dB across a 37x19 (az, el) grid. The test skips cleanly
when Python or pycraf is unavailable.
