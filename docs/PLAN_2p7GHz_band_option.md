# Plan: add a 2.7 GHz band option

**Status:** DRAFT // PRE-DECISIONAL. Plan only. No code has changed and no
MATLAB tests have run for this plan.

**Date:** 2026-11-17 (rev 3: ITU BS height and cell radius added)

**Goal:** Let `runR23AasEirpCdfGrid` and `init_run_imt_matlab_rev4.m` produce
the base-station EIRP distribution for a 2.7 GHz IMT deployment in
2700-2800 MHz, without changing any 7 GHz result.

## Summary

- The antenna math in this repo works in wavelengths. Carrier frequency is
  metadata only (`frequencyMHz` is stamped but never enters a pattern
  calculation). A 2.7 GHz option is therefore a **parameter-set change**,
  not new antenna math, and the pycraf strict gate isn't affected.
- **Antenna:** the ITU-R WP 5D AAS table for 1 710-4 990 MHz: a 4 x 8
  sub-array panel with **26.22 dBi** peak gain.
- **Power:** the FCC Part 27 base-station limit of **65 dBm/MHz EIRP**, which
  is **85.0 dBm per 100 MHz** sector peak. That is 12.7 dB above the ITU
  table's 72.28 dBm. The extra power goes into conducted power; the antenna
  geometry stays the ITU geometry.
- **Band:** TDD, 2700-2800 MHz, center frequency 2 750 MHz, 100 MHz channel.
- **Deployment:** BS height and cell radius from the ITU deployment table
  for bands between 2 and 3 GHz: 20 m and 0.4 km urban, 25 m and 0.8 km
  suburban. No other deployment parameters are added. See
  [Deployment](#deployment).

## Decisions (settled 2026-11-17)

| ID | Decision | Setting |
| --- | --- | --- |
| D1 | Antenna source | ITU-R WP 5D 1 710-4 990 MHz AAS table. |
| D2 | Deployment geometry | BS height and cell radius from the ITU 2-3 GHz deployment table. All other deployment fields inherited. |
| D3 | Power and bandwidth | Part 27 limit, 65 dBm/MHz EIRP, over a 100 MHz channel (2700-2800 MHz). |
| D4 | Duplex and frequency | TDD; `frequencyMHz = 2750`. |

### Interpretation to confirm

"65 dBm max" is read as **65 dBm/MHz EIRP**. Part 27 base-station limits
for the comparable bands are set per megahertz: 1640 W/MHz (62.15 dBm/MHz)
in general and 3280 W/MHz (65.16 dBm/MHz) in counties with 100 or fewer
persons per square mile. 65 dBm/MHz is the rounded 3280 W/MHz value.

If you meant 65 dBm total sector EIRP over 100 MHz, that is 20 dB lower
(about 45 dBm/MHz). Only the two power values in the preset change; the
rest of this plan stands.

## Parameters

### Antenna (ITU table)

Source: ITU-R WP 5D, Document 5D/716, Annex 4.4, table "Beamforming antenna
characteristics for IMT in 1 710-4 990 MHz." The values were read from a
public WP 5D working document that reproduces the table (5D/TEMP/628(Rev.2),
Table 5). Confirm them against your copy of 5D/716 Annex 4.4 before the
preset is frozen.

| Row | Parameter | 2.7 GHz preset | 7 GHz (`r23_1x3_default`) |
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
| 1.8 | Array ohmic loss | 2 dB (absorbed in element gain) | 2 dB |
| 1.10 | Horizontal coverage | +/-60 degrees | +/-60 degrees |
| 1.11 | Vertical coverage | 90-100 degrees | 90-100 degrees |
| 1.12 | Mechanical downtilt | 6 degrees | 6 degrees |

### Power (Part 27)

| Quantity | 2.7 GHz preset | ITU table value (reference only) | 7 GHz |
| --- | --- | --- | --- |
| Peak EIRP density | **65.0 dBm/MHz** | 52.28 dBm/MHz | 58.3 dBm/MHz |
| Sector peak EIRP per 100 MHz | **85.0 dBm** | 72.28 dBm | 78.3 dBm |
| Peak gain | 26.22 dBi | 26.22 dBi | 32.2 dBi |
| Conducted power per 100 MHz | **58.78 dBm** | 46.06 dBm | 46.1 dBm |
| Conducted power per sub-array | 40.72 dBm | 28 dBm | 22 dBm |

Derivation (run for this plan):

- Peak gain = 6.4 + 10·log10(3) + 10·log10(4·8) = 26.22 dBi
- Sector EIRP = 65 + 10·log10(100) = 85.0 dBm per 100 MHz
- Conducted power = 85.0 - 26.22 = 58.78 dBm, or 40.72 dBm per sub-array
  across 32 sub-arrays and 2 polarizations

This follows the same override pattern as `rev_num = 33`, which raised the
7 GHz case to 90.8 dBm through `sectorEirpDbm`, `conductedPowerDbm`, and
`maxEirpPerSector_dBm`.

### Derived beam values

| Quantity | 2.7 GHz | 7 GHz |
| --- | --- | --- |
| Physical elements, both polarizations | 192 | 768 |
| Approximate vertical beamwidth | 6.0 degrees | 3.0 degrees |
| Approximate horizontal beamwidth | 12.7 degrees | 6.3 degrees |
| Vertical grating-lobe offset (2.1 lambda) | About 28 degrees | About 28 degrees |
| Panel size at 2 750 MHz | About 0.92 m x 0.44 m | Not applicable |

### Band and duplex

| Parameter | Value |
| --- | --- |
| `bs.frequency_MHz` | 2750 |
| `bs.channelBandwidth_MHz` | 100 (2700-2800 MHz) |
| Duplex | TDD |
| `bs.tddActivityFactor` | 0.75 (unchanged) |
| `bs.networkLoadingFactor` | 0.20 (unchanged) |

Because the channel is 100 MHz, the existing "per 100 MHz" field names stay
correct at 2.7 GHz.

## Deployment

Source: ITU-R WP 5D, Document 5D/716, Annex 4.4, table "Deployment-related
parameters for bands between 1 and 3 GHz," urban/suburban macro column,
rows for bands between 2 and 3 GHz (values drawn from Report ITU-R M.2292).
The values were read from ECC Report 348 (Annex 1, Table 6), which
reproduces the table. Confirm them against your copy of 5D/716.

| Field | 2.7 GHz urban | 2.7 GHz suburban | 7 GHz urban (current) | 7 GHz suburban (current) |
| --- | --- | --- | --- | --- |
| `deployment.bsHeight_m` | **20** | **25** | 18 | 20 |
| `deployment.cellRadius_m` | **400** | **800** | 400 | 800 |
| `deployment.interSiteDistance_m` (derived, sqrt(3) x radius) | 693 | 1 386 | 693 | 1 386 |

Only BS height and cell radius change. The runner uses just these two
deployment fields to sample UE directions (`runR23AasEirpCdfGrid.m`, lines
982-983), so they are the only deployment values that affect the EIRP
result. Cell radius matches the 7 GHz values, so the change at 2.7 GHz is
the taller BS: 2 m higher urban and 5 m higher suburban, which steers UE
beams slightly further below the horizon.

Everything else in the deployment block is inherited unchanged from
`r23DefaultParams(environment)`, including `minUeDistance_m = 35`,
`sectorHalfWidthDeg = 60`, and three sectors. BS density and below-rooftop
share are metadata only in this code; they stay at the inherited values and
aren't pulled from the ITU table. Metadata records
`deploymentSource = 'ITU 5D/716 Annex 4.4, 2-3 GHz macro (height, radius)'`.

For reference, the same ITU table lists below-rooftop deployment of 50%
urban and 0% suburban for 2-3 GHz, and a 75% TDD activity factor, which
matches the inherited value.

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
opts.numMc       = 1000;
result = runR23AasEirpCdfGrid(opts);
```

`opts.band = '2p7ghz'` selects the 2.7 GHz nested parameters and makes the
`itu_2p7ghz_4x8` geometry preset the default. An explicit
`opts.aasGeometryPreset` or `opts.sectorEirpDbm` still wins, so sensitivity
runs (for example the ITU 72.28 dBm power) stay possible. A band and preset
from different bands is allowed but stamped in
`result.metadata.bandPresetMismatch`.

### New files

| File | Purpose |
| --- | --- |
| `matlab/imtBandDefaultParams.m` | `params = imtBandDefaultParams(band, environment)`. For `'7ghz'`, returns `r23DefaultParams(environment)` unchanged. For `'2p7ghz'`, starts from that struct and overrides `bs.*` (power, frequency), `aas.*` (4 x 8 table), `deployment.bsHeight_m` and `deployment.cellRadius_m` (and the derived inter-site distance), and `metadata.*`. Leaves every other `deployment.*` field untouched. |
| `matlab/test_imtBandDefaultParams.m` | Field values, the 58.78 + 26.22 = 85.0 identity, and `isequal` with `r23DefaultParams` for `'7ghz'`. |
| `matlab/test_runR23AasEirpCdfGrid_band2p7.m` | Runner-level invariants. See [Acceptance tests](#acceptance-tests). |
| `matlab/test_band2p7_phased_crosscheck.m` | Optional independent pattern check. Skips cleanly without Phased Array System Toolbox. |
| `examples/runBand2p7EirpCdfGridExample.m` | Short worked example. |
| `artifacts/golden/band2p7_urban_small_grid_v1/` | Frozen golden reference, created after the power interpretation is confirmed. |

### Files to edit

| File | Change |
| --- | --- |
| `matlab/aasGeometryPreset.m` | Add preset `itu_2p7ghz_4x8` (aliases `2p7ghz_4x8`, `2p7ghz`): 4 x 8, 3 x 1 sub-array, 0.7 / 0.5 / 2.1 lambda, 3 degree sub-array tilt, 6 degree mechanical tilt, 6.4 dBi, `sectorEirpDbm = 85.0`, `conductedPowerDbm = 58.78`. Update the help text and the unknown-preset error message. |
| `matlab/runR23AasEirpCdfGrid.m` | In the argument-resolution block (near lines 2175-2240), read `band` from flat opts or name-value pairs, call `imtBandDefaultParams` in place of `r23DefaultParams` when it's set, and pick the band's default geometry preset. Stamp `metadata.band`, `metadata.powerBasis = '47 CFR Part 27, 65 dBm/MHz EIRP'`, `metadata.deploymentSource`, and the source string. Add `band` to the help text. |
| `matlab/r23ScenarioPreset.m` | Add `2p7ghz-urban` and `2p7ghz-suburban` with their own seeds and source strings. |
| `matlab/r23GoldenReferenceScenario.m`, `freezeR23GoldenReference.m`, `verifyR23GoldenReference.m` | Register the new golden name. |
| `matlab/imtAasSubbandEnvelope.m` | Line 125 falls back to `defSectorEirp = 78.3`. Confirm the runner always passes the real sector EIRP so the fallback never applies at 2.7 GHz. Add a test for it. |
| `matlab/imtAasApplyEpreEnvelope.m` | A note string hard-codes "78.3 dBm". Build it from the actual sector EIRP. Keep the 7 GHz string byte-identical. |
| `matlab/imtAasDlFrameTimeBudget.m`, `imtAasSsbOption.m` | Add band defaults for the SSB layer. See [Optional layers](#optional-layers-at-27-ghz). |
| `matlab/imtAasAssumptionsTable.m` | Add the band, power-basis, and deployment-source rows. |
| `run_all_tests.m` | Register the new tests. |
| `init_run_imt_matlab_rev4.m` | Add `rev_num` blocks 34 and up. See [Entry-script runs](#entry-script-runs). |
| `README.md`, `CLAUDE.md` | Add a "Band option" section stating the invariants and the Part 27 power basis. |

### Audit of hard-coded 7 GHz values

A search of the function bodies (tests and comments excluded) found band
constants in these files:

- `aasGeometryPreset.m`, `r23DefaultParams.m`, `r23ScenarioPreset.m`,
  `imtAasDefaultParams.m`: defaults. Leave as is; the band layer overrides
  them.
- `imtAasSubbandEnvelope.m`, `imtAasApplyEpreEnvelope.m`: fallback and note
  string. Fix as listed above.
- `get_default_bs.m`, `imt_r23_aas_defaults.m`: the single-sector MVP and
  snake_case Monte Carlo families. **Out of scope for the first pass.** The
  entry script uses only `runR23AasEirpCdfGrid`.

### Optional layers at 2.7 GHz

- **`opts.ssb`:** keep 30 kHz sub-carrier spacing (100 MHz TDD). For
  unpaired spectrum with SSB case C, TS 38.213 clause 4.1 gives a maximum
  of 8 SSB beams above its frequency threshold, and 2 750 MHz is above that
  threshold. Set the 2.7 GHz default to 8 and confirm against the 38.213
  release you cite. The sweep tiers were sized for the narrower 8 x 16
  beams; re-tile them for the 12.7 by 6.0 degree beams.
- **`opts.beamSelection = 'codebook'`:** take the port layout from the
  4 x 8 geometry (32 ports, (N1, N2) = (8, 2) per polarization). Confirm it
  is a supported pair in TS 38.214 Table 5.2.2.2.1-2 and add a test.
- **`opts.subband`:** the headline peak becomes exactly 85.0 - 20 =
  **65.0 dBm/MHz**, the Part 27 limit. This is a built-in check.
- **`opts.epre`, `opts.prbWeighting`, `opts.layering`:** no change expected.
  `maxTotalLayers = 8` is still valid for 32 ports.

## Implementation phases

| Phase | Work | Exit criterion |
| --- | --- | --- |
| 0 | Confirm the 65 dBm/MHz reading and the ITU table against 5D/716 Annex 4.4. | Parameter table signed off. |
| 1 | Add the `itu_2p7ghz_4x8` preset and `imtBandDefaultParams`, with unit tests. | `run_all_tests` passes; 7 GHz goldens verify unchanged. |
| 2 | Wire `opts.band` into `runR23AasEirpCdfGrid`; fix the fallback and note string; add the runner test. | Acceptance tests 1-7 pass. |
| 3 | Add scenario presets, the golden reference, and the optional Phased Array cross-check. | Golden frozen and verified; cross-check within tolerance or skipped with a stated reason. |
| 4 | Set SSB and codebook defaults for 2.7 GHz. | Tests for each layer pass with `band = '2p7ghz'`. |
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
3. **Power identity.** Conducted power plus peak gain equals 85.0 dBm within
   0.01 dB, and `max(stats.max_dBm(:))` is at most 85.0 dBm. The existing
   power self-check passes.
4. **Part 27 compliance.** With `opts.subband` on, the per-subband density
   never exceeds 65.0 dBm/MHz in any cell, and the headline peak equals
   65.0 within 1e-9.
5. **Single-beam peak.** One UE at the nominal boresight direction reaches
   85.0 dBm within the same grid-miss tolerance the 7 GHz test uses.
6. **Existing invariants hold at 2.7 GHz.** Percentile-map monotonicity,
   histogram count totals, CDF endpoints, seed reproducibility, and chunked
   versus unchunked equality.
7. **Metadata.** `metadata.band`, `frequencyMHz = 2750`, the geometry preset
   name, `powerBasis`, `deploymentSource`, and `bsHeight_m` (20 urban,
   25 suburban) and `cellRadius_m` (400, 800) report the 2.7 GHz values.
8. **Independent pattern check (optional).** A Phased Array System Toolbox
   model of the same 4 x 8 array with 3-element sub-arrays agrees with
   `imtAasCompositeGain` on the main lobe and first sidelobes for three
   steering directions. Test-only dependency; the core path stays
   toolbox-free.
9. **Pycraf strict gate.** Unchanged and still passing, because no antenna
   math files are edited.

## Entry-script runs

Proposed new blocks for `init_run_imt_matlab_rev4.m`, each with the same
grid, bin edges, and percentile list as `rev_num = 33`:

| `rev_num` | Configuration | Purpose |
| --- | --- | --- |
| 34 | `band = '2p7ghz'`, urban, `outputDomain = 'both'`, pointing histogram on | 2.7 GHz baseline EIRP and gain heatmaps at 85.0 dBm |
| 35 | Same, suburban | Deployment sensitivity (25 m, 0.8 km) |
| 36 | Same as 34, with `opts.subband` on | Narrowband density; checks the 65 dBm/MHz ceiling |
| 37 | Same as 34, with `sectorEirpDbm = 72.28` and `conductedPowerDbm = 46.06` | ITU-power sensitivity, to show the Part 27 versus ITU difference |

The script's plot code uses fixed axis and color limits in places. Check
them against the 2.7 GHz EIRP range when the first run completes.

## What to look at for radar victims

These points are about using the output, not about the code change:

- **Above-horizon cells matter most.** With 6 degree mechanical tilt and
  beams steered at or below the horizon, a radar near the horizon sits in
  the upper sidelobes. The vertical grating lobe sits about 28 degrees from
  the steered beam, and the main beam is twice as wide as at 7 GHz. Report
  percentile maps for elevations from 0 to about +30 degrees separately.
- **Narrowband density may be the binding metric.** If the radar receiver
  bandwidth is narrow compared with 100 MHz, the band-integrated EIRP
  understates what one receiver sees. `opts.subband` models this, and its
  peak lands on the Part 27 limit. Take the receiver bandwidths from the
  link budget paper and check the `subbandMHz <= bandwidthMHz / N` validity
  flag.
- **Downstream handoff.** `export_eirp_percentile_table` writes the
  per-angle percentile table. Confirm the column layout the aggregate Monte
  Carlo expects for its base-station EIRP input before you export a 2.7 GHz
  table for it.

## Out of scope

Unchanged from `CLAUDE.md`: path loss, clutter, frequency-dependent
rejection, receiver I/N, victim antennas, multi-site aggregation, and
out-of-band or spurious emissions. Also out of scope: deployment fields
other than BS height and cell radius, and the single-sector MVP and
snake_case Monte Carlo API families.

## Risks

| Risk | Mitigation |
| --- | --- |
| The 65 dBm figure is misread (per MHz versus per sector). | Confirm in phase 0; stamp `powerBasis` in metadata; acceptance test 4 checks the per-MHz ceiling directly. |
| Part 27 power on an ITU-sized panel is a mixed assumption: the ITU panel was sized for 72.28 dBm, so reaching 85.0 dBm takes 12.7 dB more conducted power per sub-array. | State it in metadata and the README; keep run 36 as the ITU-power comparison. |
| The ITU 2-3 GHz deployment values are generic IMT sharing-study values, not US 2.7 GHz deployments. | Stamp `deploymentSource`; `bsHeight_m` and `cellRadius_m` stay overridable. |
| A hidden 7 GHz constant leaks into a 2.7 GHz result. | The audit above, plus a test that runs every optional layer with `band = '2p7ghz'` and checks no power-conserving output exceeds 85.0 dBm. |
| A 7 GHz regression. | Byte-identical tests and the three existing goldens. |

## Review status

- Arithmetic for the gain, power, and density values was run for this plan.
- The file audit is a static read of the repo at commit `f1adb8d`.
- MATLAB wasn't run. No tests were executed.

## References

- ITU-R WP 5D, Document 5D/716, Annex 4.4, *Characteristics of terrestrial
  component of IMT for sharing and compatibility studies in preparation for
  WRC-23*.
- ITU-R WP 5D, Document 5D/TEMP/628(Rev.2), Table 5 (public copy used to
  read the 1 710-4 990 MHz values):
  <https://iafi.in/system/libraries/static/uploads/contribution/File-%201229.pdf>
- ECC Report 348, *Usage of aerial UE in 1.8 GHz, 2 GHz and 2.6 GHz
  frequency bands with MFCN AAS base stations* (2022), Annex 1, Table 6
  (public copy used to read the 2-3 GHz deployment values):
  <https://docdb.cept.org/download/4169>
- Report ITU-R M.2292-0, *Characteristics of terrestrial IMT-Advanced
  systems for frequency sharing/interference analyses*.
- 47 CFR 27.50 and 24.232 (per-MHz base-station EIRP limits, 1640 and
  3280 W/MHz).
- Recommendation ITU-R M.2101-0, Annex 1, section 5.
- 3GPP TS 38.213 clause 4.1 and TS 38.214 Table 5.2.2.2.1-2.
