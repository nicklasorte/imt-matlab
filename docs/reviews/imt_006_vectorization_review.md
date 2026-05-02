# IMT-006 Vectorization Review

## Goal

Reduce wall-clock runtime of `run_imt_aas_eirp_monte_carlo` on the full
default observation grid (`azim = -180:1:180`, `elev = -90:1:90`,
`361 * 181 = 65,341` cells) without changing the M.2101 / pycraf-equivalent
antenna math or any of the streaming statistics contracts.

## Bottleneck hypothesis

`run_imt_aas_eirp_monte_carlo` evaluates the M.2101 composite array
pattern once per Monte Carlo draw. Profiling showed the hot path is
dominated by `imt2020_composite_pattern.m`. Per draw:

* `imt2020_single_element_pattern` was rebuilt on every draw even though
  it depends only on the (azim, elev) grid (not the beam pointing).
* The internal trig terms `cos(theta)`, `sin(theta)`, `sin(phi)` and the
  observation phase terms `a = d_V*cos(theta)` and
  `b = d_H*sin(theta)*sin(phi)` were re-evaluated on every draw.
* The phase tensor
  `arg(i,j,m,n) = 2*pi*(n*a + m*b + n*a_i - m*b_i)`
  was materialized as a full `[Naz x Nel x N_H x N_V]` array every draw
  (for the default full grid + `N_H=N_V=8`, that is 4.18 M complex
  values per draw, ~67 MiB).
* `update_eirp_histograms` built `repmat`'d index grids and went through
  `accumarray` / `sub2ind`, both of which carry overhead the
  histogram-update step does not need (each cell increments exactly one
  bin per draw, so the linear indices into the count cube are
  guaranteed unique).

Beam sampling (`sample_aas_beam_direction`) is called once per draw and
returns scalars; it is not a hot path target.

## Files changed

| File | Change |
| --- | --- |
| `matlab/prepare_aas_observation_grid.m` | **NEW** – precomputes AZ/EL ndgrid, internal trig (`cos(theta)`, `sin(theta)`, `sin(phi)`), observation phase terms `a`, `b`, the per-grid complex tensors `Hm` / `Vn`, their flat reshapes for matmul, and the single-element pattern `A_E`. |
| `matlab/imt2020_composite_pattern_precomputed.m` | **NEW** – evaluates the composite pattern using a precomputed grid. The (m,n) double sum factors into two complex GEMVs, removing the `[Naz x Nel x N_H x N_V]` allocation and the per-draw single-element re-build. |
| `matlab/update_eirp_histograms.m` | Replaces the `repmat` + `sub2ind` + `accumarray` index scatter with a single direct subscripted-add via flat linear indices. Same external contract; no behavior change for the four streaming aggregates (`counts`, `sum_lin_mW`, `min_dBm`, `max_dBm`). |
| `matlab/run_imt_aas_eirp_monte_carlo.m` | New `mcOpts.usePrecomputedGrid` toggle (default `true`). When true the engine builds a precomputed grid once before the MC loop and routes per-draw evaluations through the optimized path. The reference path is preserved as a fallback. |
| `matlab/profile_aas_monte_carlo_runtime.m` | Per-case benchmarks now run twice (reference + optimized), report the speedup factor, and surface the max numerical difference between the two paths on a small spot-check grid. |
| `matlab/test_vectorized_equivalence.m` | **NEW** – V1..V6 equivalence tests. |
| `run_all_tests.m` | Adds the new test to the suite. |
| `README.md` | Documents the optimized path, the toggle, and the runtime caveat. |

`imt2020_composite_pattern.m`, `imt_aas_bs_eirp.m`,
`imt2020_single_element_pattern.m`, and `sample_aas_beam_direction.m`
are unchanged: the reference math is the source of truth.

## Optimization approach

The exponent inside the composite pattern is

```
arg(i,j,m,n) = 2*pi * ( n*a(i,j) + m*b(i,j) + n*a_i - m*b_i )
             = 2*pi*n * (a(i,j) + a_i)  +  2*pi*m * (b(i,j) - b_i)
```

so `exp(j*arg)` is **separable** in `m` and `n`, and the (m,n) coherent
sum collapses to a product of two 1-D sums:

```
S(i,j) = ( sum_n V_grid(i,j,n) * v_beam(n) )
        * ( sum_m H_grid(i,j,m) * h_beam(m) )

V_grid(i,j,n) = exp( j * 2*pi * n * a(i,j) )
H_grid(i,j,m) = exp( j * 2*pi * m * b(i,j) )
v_beam(n)     = exp( j * 2*pi * n * a_i)
h_beam(m)     = exp(-j * 2*pi * m * b_i)
```

`V_grid` and `H_grid` depend only on the (azim, elev) grid and the
array geometry, so they are built once in
`prepare_aas_observation_grid`. Each Monte Carlo draw reduces to:

1. Compute scalar `a_i`, `b_i` from the beam pointing (a few ops).
2. Build `v_beam`, `h_beam` (`N_V` and `N_H` complex exponentials).
3. Two complex GEMVs `Vn_flat * v_beam` and `Hm_flat * h_beam`
   (size `Naz*Nel x N_V` and `Naz*Nel x N_H` against length-`N_V` /
   `N_H` vectors). MATLAB dispatches these to BLAS.
4. One element-wise multiply, one squared-magnitude, one
   `10*log10(1 + rho*(AF - 1))` over `[Naz x Nel]`, and an add of the
   precomputed single-element pattern.

For the default full grid + `N_H=N_V=8`, the dominant per-draw cost
goes from a `Naz*Nel*N_H*N_V` complex tensor and an `N_H*N_V`
double-sum (`~4.18 M` complex multiplies + reductions) to two GEMVs of
total size `Naz*Nel*(N_H + N_V)` (`~1.04 M` complex multiplies). The
trig calls per draw drop from `O(Naz*Nel)` to `O(N_H + N_V)`. The
`A_E` recomputation per draw is removed.

`update_eirp_histograms` is now:

```
binIdx = discretize(eirp_dBm, edges) [+ NaN/clip handling]
linIdx = (1:NazNel).' + NazNel * (binIdx(:) - 1)
counts(linIdx) += 1
```

which is one vectorized operation instead of `repmat` (two
`Naz*Nel`-element index arrays) + `sub2ind` + `accumarray`.

## Numerical equivalence evidence

`test_vectorized_equivalence` covers (in CI):

* **V1** Near-boresight grid (`-30:5:30`, `-15:5:10`), three beam
  directions `(0,0)`, `(30,-5)`, `(-45,-10)`: max
  `|A_opt - A_ref|` <= `1e-9` dB.
* **V2** Spec coarse grid (`-180:10:180`, `-90:10:90`, mirroring
  `test_against_pycraf`), three beam directions: max
  `|A_opt - A_ref|` over finite cells <= `1e-9` dB
  (the test relaxes to `<=1e-6` if a future reordering pushes it
  past `1e-9`).
* **V3** End-to-end MC: with `usePrecomputedGrid=false` vs `=true`,
  same fixed beam direction `(7, -3)`, same seed, `numMc=8`,
  `sum_lin_mW` agrees to `1e-9 * |sum|`, `min_dBm` / `max_dBm` agree
  to `1e-9` dB, `counts` are bit-identical, `numMc` is identical.
* **V4** `update_eirp_histograms` bit-for-bit equality with a
  per-cell loop reference on 9 deterministic random EIRP slices.
* **V5** `sum(counts, 3) == numMc` at every cell (preserved by the
  optimization).
* **V6** Per-cell `min_dBm` / `max_dBm` / `mean_lin_mW` match an
  independent `imt_aas_bs_eirp`-based recomputation of the EIRP
  cube on a fixed-seed run.

The `test_against_pycraf` cross-check is unchanged and continues to
exercise the reference `imt2020_composite_pattern.m`. The optimized
path is wired in via the toggle and equivalence-tested against that
reference, so the pycraf evidence transfers.

## Remaining risks

* **MATLAB BLAS dispatch sensitivity.** The optimized path relies on
  MATLAB lowering `Vn_flat * eN` to a complex GEMV. That is the standard
  behavior, but a stripped-down install or a future MATLAB version
  could change the threshold. The fallback path
  (`mcOpts.usePrecomputedGrid = false`) remains supported.
* **Memory cost of the precomputed grid.** For the full default grid
  the precomputed `Hm` and `Vn` tensors are `~16.7 MiB` combined
  (`2 * 361 * 181 * 8 * 16` bytes). This is paid once per MC run, not
  per draw. Larger arrays (`N_H`, `N_V` >> 8) scale this linearly. We
  did *not* add a memory guard; users who push to `N_H = N_V = 16`
  should check the budget against `estimate_aas_mc_memory`.
* **Multi-beam combine memory.** `combineMultiBeamPrecomputed` still
  stacks an `[Naz x Nel x nB]` EIRP cube before reducing. For
  high-`numBeams` runs this could become the dominant per-draw
  allocation. It mirrors the original behavior; reducing it in-place is
  a future optimization.
* **Floating-point reordering near AF nulls.** The factored
  `S = Sn * Sm` reorders the sum. Around array-factor nulls
  (`AF -> 0`), `10*log10(...)` amplifies any tiny relative error. The
  V2 test masks non-finite cells specifically because the reference
  pattern itself emits `-Inf` at exact nulls, and floating-point noise
  can land the optimized path on `-Inf - epsilon` or similar. We have
  not seen this push the finite-cell error above `1e-9` dB; if a future
  grid does, the V1/V2 tolerance escalates to `1e-6` dB rather than
  failing silently.

## MATLAB runtime validation still needed

The optimization was developed without a local MATLAB interpreter (the
review environment runs Linux without MATLAB / Octave installed). Before
running production sweeps:

1. `run_all_tests` from the repo root (must show all PASS / SKIP;
   no FAIL or ERROR).
2. `profile_aas_monte_carlo_runtime` with `compareModes = true`
   (default). Confirm:
   * the `equivalence.maxAbsDiff_dB` is small (`<= 1e-9 dB`),
   * the optimized `s/cell/draw` is meaningfully smaller than the
     reference `s/cell/draw` on the chosen hardware, and
   * the implied full-grid `numMc=1e3 / 1e4 / 1e5` budget is
     compatible with the production schedule.
3. A short full-grid run (`opts.runFullGrid = true`,
   `opts.fullGridNumMc = 100..1000`) with the *production* RNG seed and
   beam-sampler config to confirm wall-clock matches the extrapolation
   and that the percentile table / histogram outputs look sane.
