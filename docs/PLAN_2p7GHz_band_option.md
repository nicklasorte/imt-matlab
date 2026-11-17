# Plan: add a 2.7 GHz band option

**Status:** DRAFT // PRE-DECISIONAL. Plan only. No code has changed and no
MATLAB tests have run for this plan.

**Date:** 2026-11-17

**Goal:** Let `runR23AasEirpCdfGrid` and `init_run_imt_matlab_rev4.m` produce
the base-station EIRP distribution for a 2.7 GHz IMT deployment, without
changing any 7 GHz result.

## Summary

- The antenna math in this repo works in wavelengths. Carrier frequency is
  metadata only (`frequencyMHz` is stamped but never enters a pattern
  calculation). A 2.7 GHz option is therefore a **parameter-set change**,
  not new antenna math, and the pycraf strict gate isn't affected.
- What changes the result is the array size (4 x 8 sub-arrays, not 8 x 16),
  the conducted power, the deployment geometry (BS height and cell radius
  drive the beam-pointing distribution), and the channel bandwidth used for
  density outputs.
- The proposed baseline is the ITU-R WP 5D AAS table for 1 710-4 990 MHz:
  **72.28 dBm sector EIRP, 26.22 dBi peak gain**. That is about 6 dB less
  gain and 6 dB less EIRP than the 7 GHz baseline, with beams about twice as
  wide.
- Four decisions need your input before coding starts. See
  [Decisions needed](#decisions-needed).

## Source parameters

### Antenna table (proposed baseline)

Source: ITU-R WP 5D, *Characteristics of terrestrial component of IMT for
sharing and compatibility studies in preparation for WRC-23* (Document
5D/716, Annex 4.4), table "Beamforming antenna characteristics for IMT in
1 710-4 990 MHz." The values below were read from a public WP 5D working
document that reproduces the table (5D/TEMP/628(Rev.2), Table 5). Confirm
them against your copy of 5D/716 Annex 4.4 before the preset is frozen.

| Row | Parameter | 2.7 GHz (1 710-4 990 MHz table) | 7 GHz (current `r23_1x3_default`) |
| --- | --- | --- | --- |
| 1.2 | Element gain | 6.4 dBi | 6.4 dBi |
| 1.3 | Element H/V 3 dB beamwidth | 90 / 65 degrees | 90 / 65 degrees |
| 1.4 | Front-to-back ratio | 30 dB | 30 dB |
| 1.5 | Polarization | Linear +/-45 degrees | Linear +/-45 degrees |
| 1.6 | Array (rows x columns of sub-arrays) | **4 x 8** | 8 x 16 |
| 1.7 | H/V sub-array spacing | 0.5 / 2.1 lambda | 0.5 / 2.1 lambda |
| 1.7a | Element rows per sub-array | 3 | 3 |
| 1.7b | Element spacing in sub-array | 0.7 lambda | 0.7 lambda |
| 1.7c | Sub-array downtilt | 3 degrees | 3 degrees |
| 1.8 | Array ohmic loss | 2 dB | 2 dB |
| 1.9 | Conducted power per sub-array | **28 dBm** | 22 dBm |
| 1.10 | Horizontal coverage | +/-60 degrees | +/-60 degrees |
| 1.11 | Vertical coverage | 90-100 degrees | 90-100 degrees |
| 1.12 | Mechanical downtilt | 6 degrees | 6 degrees |
| 1.13 | Maximum sector EIRP | **72.28 dBm** | 78.3 dBm |

### Derived values (checked by arithmetic for this plan)

The repo's power convention reproduces the ITU number:

- Peak gain = 6.4 + 10·log10(3) + 10·log10(4·8) = **26.22 dBi**
- Conducted power = 28 + 10·log10(32) + 10·log10(2) = **46.06 dBm**
- Sector EIRP = 46.06 + 26.22 = **72.28 dBm** (matches row 1.13)

The same formula gives 32.24 dBi and 78.33 dBm for the 8 x 16 case, which
matches the existing 7 GHz preset.

| Quantity | 2.7 GHz | 7 GHz |
| --- | --- | --- |
| Physical elements, both polarizations | 192 | 768 |
| Approximate vertical beamwidth | 6.0 degrees | 3.0 degrees |
| Approximate horizontal beamwidth | 12.7 degrees | 6.3 degrees |
| Vertical grating-lobe offset (2.1 lambda) | About 28 degrees | About 28 degrees |
| Panel size at 2 750 MHz | About 0.92 m x 0.44 m | Not applicable |

### Deployment table (not yet confirmed)

The 2.7 GHz deployment values come from the 1-3 GHz deployment table in
5D/716 Annex 4.4, which this plan could not read from a public copy. The
3-6 GHz table in the same working document lists, for AAS macro: cell radius
0.4 km urban and 0.8 km suburban, BS density 10 and 2.4 per km^2, antenna
height 20 m and 25 m, below-rooftop 50% and 0%, 3 UEs per sector, TDD
activity 75%, and network loading 20% or 50%. Treat these as placeholders
until decision D2 is settled.

## Decisions needed

| ID | Decision | Options | Why it matters |
| --- | --- | --- | --- |
| D1 | Antenna and power source | (a) ITU 1 710-4 990 MHz table above. (b) A Cellular LOE or industry-supplied set. (c) Both, with (a) as baseline and (b) as a labeled sensitivity preset, like `ctia_7ghz_1x6`. | Sets peak gain and sector EIRP. Recommend (c) if an LOE set exists, else (a). |
| D2 | Deployment geometry | BS height, cell radius, density, and below-rooftop share for urban and suburban, from the ITU 1-3 GHz table or the Cellular LOE. | BS height and cell radius set the UE elevation angles, which shape the EIRP CDF near the horizon. |
| D3 | Channel bandwidth and EIRP reference | The ITU value is per channel. Pick the bandwidth (for example 20, 40, or 100 MHz) that 72.28 dBm applies to. | Every dBm/MHz output depends on it. The 7 GHz code labels EIRP "per 100 MHz" in several field names. |
| D4 | Duplex and center frequency | TDD or FDD, and the stamped center frequency (for example 2 750 MHz). | TDD activity factor, SSB burst size, and metadata. Frequency doesn't change the pattern. |

## Design

### Principles

1. **Byte-identical when off.** With no band option set, every existing
   output, golden reference, and test is unchanged for a fixed seed. This
   matches the rule already used for `opts.ssb`, `opts.epre`,
   `opts.layering`, `opts.prbWeighting`, and `opts.subband`.
2. **No new antenna math.** Reuse `imtAasCompositeGain`,
   `imtAasSectorEirpGridFromBeams`, and the extended sub-array path. Don't
   edit `imt2020_single_element_pattern.m` or `imt2020_composite_pattern.m`.
3. **One function per file**, in the camelCase `imtAas*` and `r23*` family
   that owns `runR23AasEirpCdfGrid`.
4. **Don't rename the `r23*` functions.** Add a band layer beside them.

### User-facing interface

```matlab
opts = struct();
opts.band        = '2p7ghz';      % new; default '7ghz' when absent
opts.environment = 'urban';       % or 'suburban'
opts.numMc       = 1000;
result = runR23AasEirpCdfGrid(opts);
```

`opts.band = '2p7ghz'` does two things: it selects the 2.7 GHz nested
parameters, and it makes the 4 x 8 geometry preset the default. An explicit
`opts.aasGeometryPreset` still wins, so sensitivity cases stay possible. A
band and preset from different bands is allowed but stamped in
`result.metadata.bandPresetMismatch`.

### New files

| File | Purpose |
| --- | --- |
| `matlab/imtBandDefaultParams.m` | `params = imtBandDefaultParams(band, environment)`. For `'7ghz'`, returns `r23DefaultParams(environment)` unchanged. For `'2p7ghz'`, starts from that struct and overrides `bs.*`, `aas.*`, `deployment.*`, and `metadata.*`. |
| `matlab/test_imtBandDefaultParams.m` | Field values, the 46.06 + 26.22 = 72.28 identity, and `isequal` with `r23DefaultParams` for `'7ghz'`. |
| `matlab/test_runR23AasEirpCdfGrid_band2p7.m` | Runner-level invariants. See [Acceptance tests](#acceptance-tests). |
| `matlab/test_band2p7_phased_crosscheck.m` | Optional independent pattern check. Skips cleanly without Phased Array System Toolbox. |
| `examples/runBand2p7EirpCdfGridExample.m` | Short worked example. |
| `artifacts/golden/band2p7_urban_baseline_small_grid_v1/` | Frozen golden reference, created only after D1-D4 are approved. |

### Files to edit

| File | Change |
| --- | --- |
| `matlab/aasGeometryPreset.m` | Add preset `itu_2p7ghz_4x8` (aliases `2p7ghz_4x8`, `2p7ghz`): 4 x 8, 3 x 1 sub-array, 0.7 / 0.5 / 2.1 lambda, 3 degree sub-array tilt, 6 degree mechanical tilt, 6.4 dBi, 72.28 dBm, 46.06 dBm. Update the help text and the unknown-preset error message. |
| `matlab/runR23AasEirpCdfGrid.m` | In the argument-resolution block (near lines 2175-2240), read `band` from flat opts or name-value pairs, call `imtBandDefaultParams` in place of `r23DefaultParams` when it's set, and pick the band's default geometry preset. Stamp `metadata.band`, `metadata.eirpReferenceBandwidthMHz`, and the source string. Add `band` to the help text. |
| `matlab/r23ScenarioPreset.m` | Add `2p7ghz-urban-baseline` and `2p7ghz-suburban-baseline` with their own seeds and source strings. |
| `matlab/r23GoldenReferenceScenario.m`, `freezeR23GoldenReference.m`, `verifyR23GoldenReference.m` | Register the new golden name. |
| `matlab/imtAasSubbandEnvelope.m` | Line 125 falls back to `defSectorEirp = 78.3`. Confirm the runner always passes the real sector EIRP so the fallback never applies at 2.7 GHz. Add a test for it. |
| `matlab/imtAasApplyEpreEnvelope.m` | A note string hard-codes "78.3 dBm". Build it from the actual sector EIRP. Keep the 7 GHz string byte-identical. |
| `matlab/imtAasAssumptionsTable.m` | Add the band row and check the table reads the 2.7 GHz values, not constants. |
| `run_all_tests.m` | Register the new tests. |
| `init_run_imt_matlab_rev4.m` | Add `rev_num` blocks 34 and up. See [Entry-script runs](#entry-script-runs). |
| `README.md`, `CLAUDE.md` | Add a "Band option" section stating the invariants below. |

### Audit of hard-coded 7 GHz values

A search of the function bodies (tests and comments excluded) found band
constants in these files. Each needs a decision of "parameterize" or "leave
as the 7 GHz default":

- `aasGeometryPreset.m`, `r23DefaultParams.m`, `r23ScenarioPreset.m`,
  `imtAasDefaultParams.m`: defaults. Leave as is; the band layer overrides
  them.
- `imtAasSubbandEnvelope.m`, `imtAasApplyEpreEnvelope.m`: fallbacks and note
  strings. Fix as listed above.
- `get_default_bs.m`, `imt_r23_aas_defaults.m`: the two other API families
  (single-sector MVP and snake_case Monte Carlo). **Out of scope for the
  first pass.** The entry script uses only `runR23AasEirpCdfGrid`.

### Frequency-dependent options to review

These default-off layers carry 3GPP assumptions that were chosen for 7 GHz:

- **`opts.ssb`:** `imtAasDlFrameTimeBudget` defaults to 30 kHz sub-carrier
  spacing. The SSB burst size depends on the SSB case, the duplex mode, and
  the carrier frequency (TS 38.213 clause 4.1), and the sweep tiers were
  sized for the narrower 8 x 16 beams. Set band defaults after D4.
- **`opts.beamSelection = 'codebook'`:** the DFT codebook must take its
  port layout from the 4 x 8 geometry, and the layout must be a supported
  (N1, N2) pair in TS 38.214 Table 5.2.2.2.1-2. Add a test.
- **`opts.subband`, `opts.epre`, `opts.prbWeighting`:** all use the channel
  bandwidth from D3. No code change expected.
- **`opts.layering`:** `maxTotalLayers = 8` is still valid for 32 ports.

## Implementation phases

| Phase | Work | Exit criterion |
| --- | --- | --- |
| 0 | Settle D1-D4. Confirm the antenna table against 5D/716 Annex 4.4. | Parameter table signed off. |
| 1 | Add the `itu_2p7ghz_4x8` preset and `imtBandDefaultParams`, with unit tests. | `run_all_tests` passes; 7 GHz goldens verify unchanged. |
| 2 | Wire `opts.band` into `runR23AasEirpCdfGrid`; fix the two hard-coded strings and fallback; add the runner test. | Acceptance tests 1-6 pass. |
| 3 | Add scenario presets, the golden reference, and the optional Phased Array cross-check. | Golden frozen and verified; cross-check within tolerance or skipped with a stated reason. |
| 4 | Review `opts.ssb` and codebook defaults for 2.7 GHz. | Tests for each layer pass with `band = '2p7ghz'`. |
| 5 | Add entry-script runs, the example, and the README and `CLAUDE.md` sections. Regenerate the readiness report. | Baseline 2.7 GHz heatmaps produced; report written. |

Each phase follows the MATLAB execution rule in `CLAUDE.md`: run
`run_all_tests` after editing, and don't claim a pass without a run.

## Acceptance tests

1. **Off is byte-identical.** With `opts.band` absent, and with
   `opts.band = '7ghz'`, `stats`, `percentileMaps`, and `selfCheck` are
   `isequal` to the current output for a fixed seed. All three existing
   goldens verify.
2. **Gain identity.** `aasGeometryPreset('itu_2p7ghz_4x8')` returns
   `calculatedAntennaGainDbi` within 0.01 dB of 26.22 and 192 total
   elements.
3. **Power identity.** Conducted power plus peak gain equals the sector
   EIRP within 0.01 dB, and `max(stats.max_dBm(:))` is at most 72.28 dBm.
   The existing power self-check passes.
4. **Single-beam peak.** One UE at the nominal boresight direction reaches
   the sector EIRP within the same grid-miss tolerance the 7 GHz test uses.
5. **Existing invariants hold at 2.7 GHz.** Percentile-map monotonicity,
   histogram count totals, CDF endpoints, seed reproducibility, and chunked
   versus unchunked equality.
6. **Metadata.** `metadata.band`, `frequencyMHz`, the geometry preset name,
   and the source string all report the 2.7 GHz values.
7. **Independent pattern check (optional).** A Phased Array System Toolbox
   model of the same 4 x 8 array with 3-element sub-arrays agrees with
   `imtAasCompositeGain` on the main lobe and first sidelobes for three
   steering directions. This is a test-only dependency; the core path stays
   toolbox-free.
8. **Pycraf strict gate.** Unchanged and still passing, because no antenna
   math files are edited.

## Entry-script runs

Proposed new blocks for `init_run_imt_matlab_rev4.m`, each with the same
grid, bin edges, and percentile list as `rev_num = 33`:

| `rev_num` | Configuration | Purpose |
| --- | --- | --- |
| 34 | `band = '2p7ghz'`, urban, `outputDomain = 'both'`, pointing histogram on | 2.7 GHz baseline EIRP and gain heatmaps |
| 35 | Same, suburban | Deployment sensitivity |
| 36 | Urban, with `opts.subband` enabled | Narrowband-victim density (see the next section) |
| 37 | Urban, D1 option (b) preset, if one is supplied | Industry-case sensitivity |

The script's plot code uses fixed axis and color limits in places. Check
them against the lower 2.7 GHz EIRP range when the first run completes.

## What to look at for radar victims

These points are about using the output, not about the code change:

- **Above-horizon cells matter most.** With 6 degree mechanical tilt and
  beams steered at or below the horizon, a radar near the horizon sits in
  the upper sidelobes. The 2.1 lambda sub-array spacing puts a vertical
  grating lobe about 28 degrees from the steered beam, the same as at
  7 GHz, but the main beam is twice as wide. Report percentile maps for
  elevations from 0 to about +30 degrees separately.
- **Narrowband density may be the binding metric.** If the radar receiver
  bandwidth is narrow compared with the IMT channel, the band-integrated
  dBm per channel understates what one receiver sees. `opts.subband`
  already models this. Take the receiver bandwidths from the link budget
  paper and check the `subbandMHz <= bandwidthMHz / N` validity flag.
- **Downstream handoff.** `export_eirp_percentile_table` writes the
  per-angle percentile table. Confirm the column layout that the aggregate
  Monte Carlo expects for its base-station EIRP input before you export a
  2.7 GHz table for it.

## Out of scope

Unchanged from `CLAUDE.md`: path loss, clutter, frequency-dependent
rejection, receiver I/N, victim antennas, multi-site aggregation, and
out-of-band or spurious emissions. This plan also leaves the single-sector
MVP and snake_case Monte Carlo API families at 7 GHz.

## Risks

| Risk | Mitigation |
| --- | --- |
| The ITU table is a WRC-23-era generic set, not a 2.7 GHz-specific or US-specific one. | Decision D1; keep it labeled as the ITU baseline and add other sets as named presets. |
| EIRP reference bandwidth is misread (per channel versus per 100 MHz). | Decision D3; stamp `eirpReferenceBandwidthMHz` in metadata; test the dBm/MHz conversion. |
| A hidden 7 GHz constant leaks into a 2.7 GHz result. | The audit above, plus a test that runs every optional layer with `band = '2p7ghz'` and checks no output exceeds 72.28 dBm where the layer conserves power. |
| A 7 GHz regression. | Byte-identical tests and the three existing goldens. |

## Review status

- Arithmetic for the derived values was run for this plan.
- The file audit is a static read of the repo at commit `f1adb8d`.
- MATLAB wasn't run. No tests were executed.
- Parameter choices (D1-D4) need your review before any preset is frozen.

## References

- ITU-R WP 5D, Document 5D/716, Annex 4.4, *Characteristics of terrestrial
  component of IMT for sharing and compatibility studies in preparation for
  WRC-23*.
- ITU-R WP 5D, Document 5D/TEMP/628(Rev.2), Table 5 (public copy used to
  read the 1 710-4 990 MHz values):
  <https://iafi.in/system/libraries/static/uploads/contribution/File-%201229.pdf>
- Recommendation ITU-R M.2101-0, Annex 1, section 5.
- 3GPP TS 38.213 clause 4.1 and TS 38.214 Table 5.2.2.2.1-2.
