# AAS reference pattern cuts

This directory holds 1-D EIRP pattern-cut CSVs used by the AAS-03
reference-validation harness (`runAasReferenceValidation`). The harness
compares MATLAB-generated cuts from `imtAasPatternCuts` against the
reference CSVs and reports max / RMS / main-lobe dB errors with a
deterministic pass / fail gate.

If no reference CSVs are present, the harness skips cleanly without
failing - reference validation is intentionally optional.

## Filenames the harness looks for

```
references/aas/r23_macro_horizontal_cut.csv
references/aas/r23_macro_vertical_cut.csv
```

Both are for the nominal R23 7.125-8.4 GHz macro AAS configuration
(8 rows x 16 columns, 3 vertical elements per sub-array, 0.7 lambda
intra-sub-array vertical spacing, 2.1 lambda vertical sub-array spacing,
0.5 lambda horizontal spacing, 3 deg fixed sub-array downtilt, 6 deg
mechanical downtilt, element gain 6.4 dBi, peak composite gain ~32.2 dBi,
peak sector EIRP 78.3 dBm/100 MHz) with the default steering
(`steerAzDeg = 0`, `steerElDeg = -9`).

## CSV format

The loader (`imtAasLoadReferenceCutCsv`) is intentionally minimal and
uses base MATLAB only. It expects:

* one comma-separated header line
* one comma-separated row per data point
* lines starting with `#` or `%` are treated as comments and ignored
* blank lines are ignored
* whitespace around field values is trimmed
* fields must not contain commas (no quoted-CSV escaping is supported)

### Required columns

| column                | meaning                                                 |
| --------------------- | ------------------------------------------------------- |
| `angle_deg`           | cut angle in degrees (see "Angle conventions" below)    |
| `eirp_dbm_per_100mhz` | reference EIRP at that angle, in dBm per 100 MHz        |

### Optional columns

| column      | meaning                                                       |
| ----------- | ------------------------------------------------------------- |
| `gain_dbi`  | composite array gain in dBi (loaded but not compared today)   |
| `notes`     | free-form text per row (no commas; preserved as-is)           |

Header column names are matched case-insensitively. Required columns
must contain finite numeric values; the loader fails clearly otherwise.

## Angle conventions

* **Horizontal cut** (`r23_macro_horizontal_cut.csv`):
  `angle_deg` is azimuth in degrees (sector frame, 0 = sector
  boresight, range +/- 180 deg) at a fixed elevation near
  `steerElDeg`. The harness extracts the MATLAB cut at the elevation
  grid point closest to `steerElDeg`, so a reference generated at
  exactly `steerElDeg` will line up.

* **Vertical cut** (`r23_macro_vertical_cut.csv`):
  `angle_deg` is elevation in degrees (sector frame, 0 = horizon,
  negative = below horizon, range +/- 90 deg) at a fixed azimuth near
  `steerAzDeg`. The harness extracts the MATLAB cut at the azimuth
  grid point closest to `steerAzDeg`.

The repo's elevation convention matches the M.2101 global-theta range
90..100 deg (horizon to 10 deg below horizon) via elevation -10..0 deg.

## Where reference values can come from

* **pycraf**: see the optional `tools/generate_pycraf_aas_reference.py`
  generator. pycraf must be installed locally, and the generated
  artifacts must be reviewed for angle-convention consistency before
  being treated as authoritative.
* **ITU validation material**: directly transcribed reference cuts
  from a WP5D / M.2101 validation table.
* **Frozen MATLAB-reviewed outputs**: a previously reviewed run of
  `imtAasEirpGrid` / `imtAasPatternCuts`, frozen as a regression
  baseline. This is useful for catching unintended changes in the
  MATLAB pattern math but is not an external check.

> **Caveat**: do *not* claim "pycraf parity" unless pycraf-generated
> artifacts are in this directory and the harness reports a pass with
> the unmodified default tolerances. Bit-perfect parity is not the
> AAS-03 target - bounded dB error metrics are.

## Pass / fail thresholds

`imtAasComparePatternCut` defaults (overridable via opts):

| field                       | default | meaning                                  |
| --------------------------- | ------- | ---------------------------------------- |
| `maxAbsErrorDb`             | 1.0     | global max absolute error gate           |
| `rmsErrorDb`                | 0.5     | global RMS error gate                    |
| `mainLobeMaxAbsErrorDb`     | 0.5     | main-lobe max absolute error gate        |
| `mainLobeWindowDeg`         | 20      | main-lobe window (centered on peak)      |
| `ignoreBelowDbm`            | -80     | drop points where actual & ref both <    |
| `interpolateReference`      | true    | linearly interpolate ref onto actual grid|

A comparison passes only if all three error gates are met. Failures
are reported with explicit reasons in `cmp.failReasons` (and printed
by `runAasReferenceValidation`).

## Example minimal CSV

```
angle_deg,eirp_dbm_per_100mhz
-90.0,15.2
-45.0,42.7
0.0,78.3
45.0,42.7
90.0,15.2
```
