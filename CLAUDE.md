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

## SSB broadcast sweep option (`opts.ssb`) — never touches the traffic stats

`runR23AasEirpCdfGrid` has an optional, **default-off** SSB broadcast
sweep + 3GPP-time-weighted EIRP layer driven entirely by the nested
`opts.ssb` struct. It is implemented by three new one-function-per-file
modules that reuse the existing antenna engine
(`imtAasSectorEirpGridFromBeams`) — no new antenna math, no Phased Array /
5G Toolbox dependency:

- `imtAasDlFrameTimeBudget.m` — counts TS 38.214 DL OFDM symbols/sec and
  collapses them onto two spatial classes (`sweep`: SSB+SIB1+CSS-PDCCH+TRS;
  `ue`: PDSCH+USS-PDCCH+per-UE CSI-RS), returning `alphaSweep` / `alphaUe`
  / `alphaIdle`.
- `imtAasTimeWeightedGrid.m` — `Pbar = alphaSweep*S + alphaUe*T` (linear),
  with `avg_dBm` (time-average) and `peak_dBm = max(stats.max_dBm,
  ssb.envelope_dBm)` (worst-case envelope, NOT a power sum).
- `imtAasSsbOption.m` — builds the sweep tiers and drives the two above.

**Hard invariant: `opts.ssb` never mutates `stats` or `percentileMaps`.**
The sweep runs *after* the streaming aggregator and the power self-check,
attaches only to NEW output fields (`out.ssb`, `out.timeWeighted`,
`out.metadata.includesSsbSweep` / `.ssbConfig`), and uses deterministic
(non-random) sweep beams. When `opts.ssb` is absent/`[]`, the traffic
`stats` / `percentileMaps` / self-check are byte-identical to before for a
fixed seed (`test_runR23AasEirpCdfGrid_ssb` enforces this). The traffic
`stats` struct — including `stats.max_dBm` — is READ-ONLY to this path.
This is a broadcast duty-cycle model, distinct from the per-UE PMI
codebook selection in `opts.beamSelection = 'codebook'`.

## Per-RE EPRE option (`opts.epre`) — separate per-RE density, never the baseline

`runR23AasEirpCdfGrid` has an optional, **default-off** per-RE EPRE-offset
layer driven by the nested `opts.epre` struct. It applies the 3GPP **TS
38.214 V19.2.0 Clause 4.1** downlink per-resource-element EPRE offsets —
DM-RS power boost (Table 4.1-1), optional PT-RS power boost (Tables 4.1-2 /
4.1-2A), and the CSI-RS-vs-SSB `powerControlOffsetSS` — implemented by two
one-function-per-file modules with no new antenna math:

- `imtAasEpreOffsets.m` — pure, deterministic Clause 4.1 table lookup
  returning `dmrsBoostDb`, `ptrsBoostDb`, `csirsOffsetDb`,
  `hottestBoostDb = max(dmrsBoostDb, ptrsBoostDb)`, plus a resolved config
  and `specReference`. No antenna math, no RNG.
- `imtAasApplyEpreEnvelope.m` — reads the streaming `stats` **read-only** and
  returns the per-RE worst-case envelope
  `perRePeakEnvelope_dBm = stats.max_dBm + hottestBoostDb`, optional
  per-RE-envelope percentile maps (computed on a COPY of `stats` whose bin
  edges are shifted by `hottestBoostDb`), and a CSI-RS-class envelope when a
  sweep envelope is supplied.

**Hard invariant: `opts.epre` never mutates `stats`, `percentileMaps`,
`selfCheck`, or the `opts.ssb` outputs.** DM-RS / PT-RS boosts are
**power-conserving over a slot and over the channel bandwidth**: they do
**NOT** raise the band-integrated EIRP in dBm/100 MHz and are deliberately
kept off the band-integrated CDF and out of the band-integrated sector-peak
self-check. The layer runs *after* the streaming aggregator, the power
self-check, and the SSB sweep, and attaches only NEW fields (`out.epre`,
`out.metadata.includesEpre` / `.epreConfig`). When `opts.epre` is
absent/`[]`, `out.epre = []` and every existing output is byte-identical to
before for a fixed seed (`test_runR23AasEirpCdfGrid_epre` enforces this).

The **ITU band-integrated result (78.3 dBm/100 MHz sector EIRP) is and
remains the baseline.** `out.epre.perRePeakEnvelope_dBm` is a **separate**
per-RE EIRP **density** worst case: it is **NOT additive with the
band-integrated dBm/MHz CDF**, it is **allowed to exceed** the 78.3 dBm
band-integrated sector peak by design, and it is **not** clamped to it nor
fed into the band-integrated self-check. This is distinct from the
`opts.ssb` broadcast duty-cycle model and the `opts.beamSelection` codebook
path.

## Rank / MU-MIMO layering option (`opts.layering`) — reshapes the CDF; ITU rank-1 is the baseline

`runR23AasEirpCdfGrid` has an optional, **default-off** rank / MU-MIMO
layering layer driven by the nested `opts.layering` struct. It replaces the
implicit "N beams = N rank-1 UEs, each at `sectorEirp − 10·log10(N)`"
assumption with a **rank / MU-MIMO layering** model consistent with the
3GPP **TS 38.214 V19.2.0** framework (Clause 5.1.1.1 transmission scheme 1
up to 8 layers on ports 1000-1023; Clause 5.1.6.2 DM-RS port bound; Clause
5.2.2.5.1 RI/rank reporting; Clause 5.2.2.2.x PMI codebook / CSI-RS port
bound). Implemented by one new one-function-per-file module that reuses the
existing antenna engine — **no new antenna math**:

- `imtAasExpandUeLayers.m` — expands the N-UE beam set from
  `imtAasGenerateBeamSet` into an `L = Σ r_u` layer beam set. Each UE is
  served with a rank `r_u` (fixed, or drawn from a rank PMF); `L` is capped
  at `maxTotalLayers` (default 8) via a `greedy` clip rule; the `r_u > 1`
  layers sit in a small Gaussian angular cone (`layerSpreadDeg`, default
  2°) around the UE direction, clamped to the steering envelope via
  `imtAasApplyBeamLimits`. The per-layer power split
  (`sectorEirp − 10·log10(L)`) and the **incoherent linear-mW** sum fall out
  automatically in `imtAasSectorEirpGridFromBeams` from `numel(steerAzDeg)`.

**Unlike `opts.epre`** (a post-hoc per-RE envelope that never touches the
band-integrated CDF), `opts.layering` changes the **per-draw beam set**, so
when enabled it **does reshape `stats` / `percentileMaps` / the EIRP CDF** —
that is the point. It is an explicitly-labelled **alternative scenario** for
sensitivity, not the new default.

**Hard invariants (enforced by `test_imtAasExpandUeLayers` and
`test_runR23AasEirpCdfGrid_layering`):**

- **Byte-identical when off.** When `opts.layering` is absent/`[]` (or
  `enable=false`), `imtAasExpandUeLayers` is **not called at all** → zero
  extra RNG → `stats`, `percentileMaps`, `selfCheck`, `out.ssb`, `out.epre`
  are byte-identical to before for a fixed seed. `out.layering = []`,
  `out.metadata.includesLayering = false`.
- **Rank 1 + `layerSpreadDeg` 0 == off.** Enabling with a fixed rank of 1
  and zero spread is an **identity expansion**: it returns the UE directions
  unchanged and consumes **zero RNG**, so the traffic `stats` are
  byte-identical to the off case. (A *fixed* rank consumes no RNG; a rank
  PMF draws one rank per UE; spread offsets draw only when `sigma > 0`.)
- **Power conserved.** `L` layers at `sectorEirp − 10·log10(L)` sum to
  `sectorEirp`, so the band-integrated sector peak and the power self-check
  are unchanged in **bound** (the observed aggregate max stays
  `≤ sectorEirp`); only the **spatial distribution** of where the power
  lands changes. The traffic `stats` struct (including `stats.max_dBm`)
  feeds the self-check exactly as before.

The **ITU M.2101 reference remains the baseline.** The ITU assumption (IMT
characteristics Table A-2, Note 1: "the AAS BS beamforms towards each UE
using the entire array", 3 UEs, equal split) is exactly the current default
— 3 UEs, rank-1 each, equal power split — and is recovered by leaving
`opts.layering` off. The scheduler / rank / power-split model is
**statistical** (gNB co-scheduling, power split and rank selection are
implementation-defined in TS 38.214), **not a normative 38.214 algorithm**;
the SU-MIMO layer angular spread is a stand-in for channel angular spread
(no channel model). With layering on, the scalar
`metadata.perBeamPeakEirpDbm` (computed pre-loop from the fixed `N`) is no
longer the realized per-layer power — the realized distribution is surfaced
in `out.layering.perLayerPeakEirpDbm`. This is distinct from the `opts.ssb`
broadcast duty-cycle model, the `opts.epre` per-RE density, and the
`opts.beamSelection` codebook path.

## PRB / bandwidth weighting option (`opts.prbWeighting`) — SENSITIVITY ONLY, departs from ITU

`runR23AasEirpCdfGrid` has an optional, **default-off** per-UE PRB /
bandwidth weighting layer driven by the nested `opts.prbWeighting` struct.
It replaces the uniform per-beam power split (`sectorEirp − 10·log10(N)`,
every beam equal) with an **unequal per-UE bandwidth (PRB) weighting**:
each co-scheduled UE gets a fractional bandwidth share `f_u` (Σ f_u = 1),
and at constant EPRE (3GPP **TS 38.214 V19.2.0 Clause 4.1**) its
band-integrated power is proportional to its PRB share, so
`perBeamEirp_u = sectorEirp + 10·log10(f_u)`. Implemented by one new
one-function-per-file module that reuses the existing antenna engine — **no
new antenna math**:

- `imtAasPrbWeights.m` — pure-except-for-RNG weight generator. Returns the
  per-beam linear power-fraction `wBeam` (Σ = 1), the per-UE share vector
  `ueShares` (Σ = 1), a `participationRatio = 1/Σ f_u²` (effective number of
  UEs), the resolved `config`, and a `specReference`. `mode` `'fixed'`
  (normalized `weights`, no RNG) or `'random'` (toolbox-free **log-normal
  softmax**: `e = exp(sigma·randn(1,Nue)); f = e/Σe`, exactly `Nue` `randn`
  draws when `sigma > 0`, **no** `gamrnd` / Dirichlet). `spread = 0` → equal
  shares (no RNG). Composes with `opts.layering` via `layerUeIndex`: a UE's
  share is divided equally across its `r_u` layers
  (`wBeam(l) = f_u / r_u`). The dB conversion happens at the call site, not
  in the helper.

**Unlike `opts.epre`** (a separate per-RE envelope) **and unlike
`opts.layering`** (which reshapes the CDF but keeps the ITU power-split
*philosophy*), `opts.prbWeighting` **deliberately departs from the ITU
M.2101 equal-bandwidth *assumption*** (IMT characteristics Table A-2,
Note 1: *"UEs share equally the channel bandwidth"*). It is therefore an
**explicitly-labelled sensitivity scenario that is NOT ITU-compliant**: it
**must never** become the default, the equal-split ITU case **remains the
reference**, and weighted results are to be presented **alongside** (never
*instead of*) the baseline. This is for a federal regulatory paper — the
divergence from ITU must be unmistakable in `out.prbWeighting.notes` /
metadata.

**Invariants (enforced by `test_imtAasPrbWeights` and
`test_runR23AasEirpCdfGrid_prbWeighting`):**

- **Byte-identical when off.** When `opts.prbWeighting` is absent/`[]` (or
  `enable=false`), `imtAasPrbWeights` is **not called at all** → zero extra
  RNG → `stats`, `percentileMaps`, `selfCheck`, `out.ssb`, `out.epre`,
  `out.layering` are byte-identical to before for a fixed seed.
  `out.prbWeighting = []`, `out.metadata.includesPrbWeighting = false`.
- **Equal shares == off WITHIN TOLERANCE (NOT byte-identical).** The off
  path computes the scalar `sectorEirp − 10·log10(N)`; the enabled-equal
  path computes the per-beam vector `sectorEirp + 10·log10(1/N)`.
  Mathematically equal but a **different floating-point expression**, so
  they can differ in the last ULP. Asserted as `percentileMaps.values`
  within `1e-6` dB **and** `sum_lin_mW` within relative `1e-9` — do **not**
  assert `isequal` on `stats.counts` (integer histogram counts can differ
  by ±1 at a bin boundary). Equal shares consume zero RNG.
- **Power conserved.** Σ f_u = 1, so total power is conserved — only the
  **spatial distribution** of where the power lands changes. The
  band-integrated sector peak and the power self-check (observed aggregate
  max `≤ sectorEirp`) are unchanged in **bound**.
- **Band-integrated only.** Frequency-selective occupancy (a narrowband
  victim seeing only the beams present on its sub-band) is the **separate
  subband / PRG item** and is out of scope; the channel bandwidth and the
  dBm/MHz normalization basis are unchanged.

Like `opts.layering`, enabling `opts.prbWeighting` **does reshape `stats` /
`percentileMaps` / the EIRP CDF** — that is the point. With it on, the
scalar `metadata.perBeamPeakEirpDbm` is the fixed-N equal-split nominal, not
the realized per-beam power; the realized distribution is in
`out.prbWeighting.perBeamPeakEirpDbm`. The scheduler / PRB-allocation model
is **statistical** (PRB allocation is implementation-defined in TS 38.214),
**not a normative algorithm**. This is distinct from the `opts.ssb`
broadcast duty-cycle model, the `opts.epre` per-RE density, the
`opts.layering` rank/MU-MIMO model, and the `opts.beamSelection` codebook
path.

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

## MATLAB EXECUTION REQUIREMENT

Future Claude Code / MATLAB MCP runs MUST follow this protocol.

Use the MATLAB MCP tool if available.

Before editing:

- Check that MATLAB MCP is connected.
- Check that MATLAB can see the repo.
- Add the repo and `matlab/` folder to the MATLAB path if needed.

After editing, run:

- `run_all_tests`

If a focused test was added, also run that test directly.

If MATLAB MCP is unavailable or MATLAB cannot run, do NOT claim tests
passed. State clearly:

- MATLAB MCP unavailable, or MATLAB execution failed
- the exact error
- which tests were not run

Do not skip failing tests. Do not loosen assertions just to pass. Fix
only the failing implementation or test issue.

### Readiness report

`generate_r23_mvp_readiness_report` is a one-command readiness artifact
for the R23 MVP. It runs `run_all_tests` and writes
`reports/r23_mvp_readiness_report.md`. Run it after substantive R23 MVP
changes:

```matlab
addpath('matlab');
generate_r23_mvp_readiness_report();
```

If MATLAB is unavailable:

- perform static inspection only
- state clearly that MATLAB execution was unavailable, and that the
  readiness report was not generated
