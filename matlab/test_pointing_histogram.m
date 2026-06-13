function results = test_pointing_histogram()
%TEST_POINTING_HISTOGRAM Self tests for the pointing-angle histogram output.
%
%   RESULTS = test_pointing_histogram()
%
%   Exercises the non-breaking opts.computePointingHistogram knob added to
%   runR23AasEirpCdfGrid (plus its binning helper imtAasPointingHistogram).
%   The histogram is the joint 2-D Monte Carlo distribution of the antenna
%   POINTING ANGLES (steering az/el across all beams and all snapshots),
%   distinct from the per-cell MEAN-pointing heatmap (out.pointing).
%
%   Covered:
%     Helper ground truth (imtAasPointingHistogram):
%       - known angles land in their discretize bins; nothing dropped.
%       - out-of-range samples are COUNTED (numOutOfRange), not silently
%         dropped.
%     Driver level (runR23AasEirpCdfGrid):
%       - enabling the histogram populates counts/pmf/marginals.
%       - numInRange + numOutOfRange == numBeams * numMc (no silent drops).
%       - pmf sums to 1; marginals equal the row/column sums.
%       - physical sanity: default clampElevation keeps el in ~[-10, 0].
%       - back-compat: histogram is additive; EIRP percentileMaps are
%         identical at the same seed, and the default run leaves the
%         histogram empty.
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  false
%       .reason   ''

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_pointing_histogram ---\n');

    % ===== helper-level ground truth =====
    azE = -60:2:60;
    elE = -50:1:5;
    saz = [0; 30; -45];
    sel = [-5; -5; -2];
    h = imtAasPointingHistogram(saz, sel, azE, elE);
    assert(sum(h.counts(:)) == h.numInRange && h.numInRange == 3 && ...
           h.numOutOfRange == 0, ...
        'helper: 3 in-range samples must all be counted, none dropped');
    for k = 1:3
        ia = discretize(saz(k), azE);
        je = discretize(sel(k), elE);
        assert(h.counts(ia, je) >= 1, ...
            'helper: sample %d must land in its discretize bin', k);
    end
    fprintf('  [OK] helper bins known angles correctly (az=rows, el=cols)\n');

    % out-of-range is counted, not dropped:
    h2 = imtAasPointingHistogram([0; 999], [-5; -5], azE, elE);
    assert(sum(h2.counts(:)) == 1 && h2.numOutOfRange == 1, ...
        'helper: out-of-range sample must be counted in numOutOfRange');
    fprintf('  [OK] helper counts out-of-range samples (no silent drop)\n');

    % ===== driver level =====
    base = struct( ...
        'aasGeometryPreset', 'r23_1x3_default', ...
        'numMc',             50, ...
        'seed',              7, ...
        'azGridDeg',         -30:10:30, ...
        'elGridDeg',         -10:5:5, ...
        'binEdgesDbm',       -80:5:120, ...
        'percentiles',       [5 50 95]);

    r  = runR23AasEirpCdfGrid(setfield(base, ...
        'computePointingHistogram', true)); %#ok<SFLD>
    PH = r.pointingHistogram;

    assert(~isempty(PH.counts), 'driver: PH.counts must be populated');
    assert(PH.numInRange + PH.numOutOfRange == ...
           r.metadata.numUesPerSector * 50, ...
        'driver: numInRange + numOutOfRange must equal numBeams * numMc');
    assert(abs(sum(PH.pmf(:)) - 1) < 1e-9, ...
        'driver: pmf must sum to 1');
    assert(isequal(sum(PH.counts, 2), PH.azMarginalCounts), ...
        'driver: azMarginalCounts must equal the row sums');
    assert(isequal(sum(PH.counts, 1).', PH.elMarginalCounts), ...
        'driver: elMarginalCounts must equal the column sums');
    fprintf('  [OK] driver populates joint counts/pmf/marginals; nothing lost\n');

    % physical sanity (default clampElevation=true => el in [-10, 0]):
    popEl = PH.elCenters(sum(PH.counts, 1) > 0);
    assert(max(popEl) <= 0 + 1 && min(popEl) >= -10 - 1, ...
        'driver: populated elevation bins must sit in ~[-10, 0] (clamp on)');
    fprintf('  [OK] populated elevation bins respect the clamp gate\n');

    % back-compat: histogram is additive, EIRP identical at same seed:
    rDef = runR23AasEirpCdfGrid(base);
    assert(isempty(rDef.pointingHistogram.counts), ...
        'driver: default run must leave pointingHistogram.counts empty');
    assert(isequal(rDef.percentileMaps.values, r.percentileMaps.values), ...
        'driver: EIRP percentileMaps must be identical with/without histogram');
    fprintf('  [OK] additive + byte-identical EIRP at same seed\n');

    results.passed = true;
    fprintf('--- test_pointing_histogram PASSED ---\n');
end
