function results = test_runR23AasEirpCdfGrid_band2p7()
%TEST_RUNR23AASEIRPCDFGRID_BAND2P7 opts.band = '2p7ghz' integration tests.
%
%   RESULTS = test_runR23AasEirpCdfGrid_band2p7()
%
%   Covers the band option on runR23AasEirpCdfGrid.
%       T1.  Off is unchanged: band absent and band = '7ghz' give
%            byte-identical aggregator stats (counts, sums, extrema,
%            means), percentileMaps, and selfCheck for a fixed seed; band
%            absent adds no metadata.band field.
%       T2.  2.7 GHz run selects itu_2p7ghz_4x8 (4x8), 2750 MHz, 100 MHz,
%            85 dBm sector EIRP, 20 m / 400 m (urban) and stamps band,
%            power-basis, and deployment-source metadata.
%       T3.  Power: max(stats.max_dBm) <= 85 dBm; self-check never fails;
%            with one beam on a fine grid the self-check passes (observed
%            peak within 3 dB of 85 dBm).
%       T4.  Part 27: opts.subband headline peak == 65 dBm/MHz (1e-9) and
%            no per-subband density cell exceeds 65 dBm/MHz.
%       T5.  Explicit aasGeometryPreset wins over the band default and sets
%            bandPresetMismatch; band = '7ghz' with the 2.7 GHz preset also
%            flags a mismatch.
%       T6.  Invocation styles: nested params (imtBandDefaultParams,
%            suburban 25 m / 800 m), name-value ('band','2.7GHz'), and
%            r23ScenarioPreset('2p7ghz-urban') all resolve to the 2.7 GHz
%            configuration.
%       T7.  Aggregator invariants at 2.7 GHz: histogram counts == numMc
%            per cell, percentile maps monotone, seed reproducibility, and
%            chunked == unchunked.
%       T8.  opts.epre notes quote the 2.7 GHz sector peak (85 dBm); the
%            7 GHz (band absent) notes keep the historical 78.3 dBm text.
%       T9.  Unknown band raises imtBandName:unknownBand.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    baseOpts = struct();
    baseOpts.numMc       = 20;
    baseOpts.azGridDeg   = -60:5:60;
    baseOpts.elGridDeg   = -14:1:6;
    baseOpts.binEdgesDbm = -100:0.5:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 2750;
    baseOpts.numBeams    = 3;

    % ---- T1: off is unchanged --------------------------------------------
    off = runR23AasEirpCdfGrid(baseOpts);
    o7  = baseOpts; o7.band = '7ghz';
    on7 = runR23AasEirpCdfGrid(o7);
    % stats.elapsedSeconds is wall-clock and stats.opts echoes the inputs
    % (which differ by opts.band), so compare the aggregator fields.
    ok1 = sameAggregator(off.stats, on7.stats) && ...
          isequaln(off.percentileMaps, on7.percentileMaps) && ...
          isequal(off.selfCheck, on7.selfCheck) && ...
          ~isfield(off.metadata, 'band') && ...
          strcmp(on7.metadata.band, '7ghz') && ~on7.metadata.bandPresetMismatch && ...
          strcmp(off.metadata.aasGeometryPreset, 'r23_1x3_default');
    results = check(results, ok1, ...
        'T1: band absent == band ''7ghz'' (stats / percentileMaps / selfCheck byte-identical)');

    % ---- T2: 2.7 GHz configuration ------------------------------------------
    o2 = baseOpts; o2.band = '2p7ghz';
    r2 = runR23AasEirpCdfGrid(o2);
    m  = r2.metadata;
    ok2 = strcmp(m.aasGeometryPreset, 'itu_2p7ghz_4x8') && ...
          m.numRows == 4 && m.numColumns == 8 && ...
          m.frequencyMHz == 2750 && m.bandwidthMHz == 100 && ...
          abs(m.sectorEirpDbm - 85) <= 1e-9 && ...
          m.bsHeight_m == 20 && m.cellRadius_m == 400 && ...
          strcmp(m.band, '2p7ghz') && ~m.bandPresetMismatch && ...
          contains(m.powerBasis, 'Part 27') && ...
          contains(m.deploymentSource, '2-3 GHz') && ...
          strcmp(m.duplex, 'TDD') && isequal(m.frequencyRange_MHz, [2700 2800]) && ...
          m.eirpDensityLimit_dBmPerMHz == 65 && ...
          abs(m.peakEirpDensity_dBmPerMHz - 65) <= 1e-9 && ...
          abs(m.aasGeometry.calculatedAntennaGainDbi - 26.22) <= 0.01 && ...
          m.aasGeometry.totalPhysicalElementsAcrossPolarizations == 192 && ...
          contains(m.model, '2.7 GHz');
    results = check(results, ok2, 'T2: band ''2p7ghz'' selects 4x8 / 2750 MHz / 85 dBm / 20 m / 400 m');

    % ---- T3: power ----------------------------------------------------------
    obsMax = max(r2.stats.max_dBm(isfinite(r2.stats.max_dBm)));
    o1 = o2;
    o1.numBeams  = 1;
    o1.azGridDeg = -60:1:60;
    o1.elGridDeg = -20:0.5:5;
    r1 = runR23AasEirpCdfGrid(o1);
    obs1 = max(r1.stats.max_dBm(isfinite(r1.stats.max_dBm)));
    ok3 = obsMax <= 85 + 1e-6 && ...
          ~strcmp(r2.selfCheck.powerSemantics.status, 'fail') && ...
          obs1 <= 85 + 1e-6 && obs1 >= 85 - 3 && ...
          strcmp(r1.selfCheck.powerSemantics.status, 'pass');
    results = check(results, ok3, sprintf( ...
        'T3: max EIRP %.2f dBm (3 beams), %.2f dBm (1 beam) <= 85 dBm; self-check %s / %s', ...
        obsMax, obs1, r2.selfCheck.powerSemantics.status, r1.selfCheck.powerSemantics.status));

    % ---- T4: Part 27 per-MHz ceiling ----------------------------------------
    o4 = o2; o4.subband = struct('subbandMHz', 1);
    r4 = runR23AasEirpCdfGrid(o4);
    sm = r4.subband.stats.max_dBm;
    smax = max(sm(isfinite(sm)));
    ok4 = abs(r4.subband.perSubbandPeak_dBmPerMHz - 65) <= 1e-9 && ...
          smax <= 65 + 1e-6 && ...
          sameAggregator(r4.stats, r2.stats) && ...
          isequaln(r4.percentileMaps, r2.percentileMaps);
    results = check(results, ok4, sprintf( ...
        'T4: per-subband peak %.4f dBm/MHz, max cell %.2f dBm/MHz <= 65 (Part 27)', ...
        r4.subband.perSubbandPeak_dBmPerMHz, smax));

    % ---- T5: explicit preset wins -------------------------------------------
    o5 = o2; o5.aasGeometryPreset = 'r23_1x3_default';
    r5 = runR23AasEirpCdfGrid(o5);
    o5b = baseOpts; o5b.band = '7ghz'; o5b.aasGeometryPreset = 'itu_2p7ghz_4x8';
    r5b = runR23AasEirpCdfGrid(o5b);
    ok5 = r5.metadata.numRows == 8 && r5.metadata.numColumns == 16 && ...
          r5.metadata.bandPresetMismatch && ...
          r5.metadata.frequencyMHz == 2750 && ...
          r5b.metadata.numRows == 4 && r5b.metadata.bandPresetMismatch;
    results = check(results, ok5, 'T5: explicit aasGeometryPreset wins; mismatch flagged both ways');

    % ---- T6: invocation styles ----------------------------------------------
    np = imtBandDefaultParams('2p7ghz', 'suburban');
    np.sim.numSnapshots = 5;
    np.sim.azGrid_deg   = -60:10:60;
    np.sim.elGrid_deg   = -14:2:6;
    np.sim.binEdges_dBm = -100:1:120;
    np.sim.percentiles  = [50 95];
    r6a = runR23AasEirpCdfGrid(np);
    r6b = runR23AasEirpCdfGrid('band', '2.7GHz', 'numMc', 5, ...
        'azGridDeg', -60:10:60, 'elGridDeg', -14:2:6, 'percentiles', [50 95]);
    sp = r23ScenarioPreset('2p7ghz-urban', 'numSnapshots', 5);
    sp.sim.azGrid_deg = -60:10:60;
    sp.sim.elGrid_deg = -14:2:6;
    sp.sim.percentiles = [50 95];
    r6c = runR23AasEirpCdfGrid(sp);
    ok6 = strcmp(r6a.metadata.aasGeometryPreset, 'itu_2p7ghz_4x8') && ...
          strcmp(r6a.metadata.band, '2p7ghz') && ...
          r6a.metadata.bsHeight_m == 25 && r6a.metadata.cellRadius_m == 800 && ...
          abs(r6a.metadata.sectorEirpDbm - 85) <= 1e-9 && ...
          strcmp(r6b.metadata.band, '2p7ghz') && r6b.metadata.numRows == 4 && ...
          abs(r6b.metadata.sectorEirpDbm - 85) <= 1e-9 && ...
          strcmp(r6c.metadata.band, '2p7ghz') && r6c.metadata.numRows == 4 && ...
          strcmp(r6c.metadata.scenarioPreset, '2p7ghz-urban') && ...
          r6c.metadata.bsHeight_m == 20 && abs(r6c.metadata.sectorEirpDbm - 85) <= 1e-9;
    results = check(results, ok6, ...
        'T6: nested params, name-value, and scenario preset invocations resolve to 2.7 GHz');

    % ---- T7: aggregator invariants ------------------------------------------
    counts = sum(double(r2.stats.counts), 3);
    pv = r2.percentileMaps.values;
    dpv = diff(pv, 1, 3);
    r2b = runR23AasEirpCdfGrid(o2);
    oc = o2; oc.mcChunkSize = 7;
    r2c = runR23AasEirpCdfGrid(oc);
    ok7 = all(counts(:) == o2.numMc) && ...
          all(dpv(~isnan(dpv)) >= -1e-12) && ...
          sameAggregator(r2.stats, r2b.stats) && ...
          sameAggregator(r2.stats, r2c.stats);
    results = check(results, ok7, ...
        'T7: counts == numMc, percentiles monotone, seed-reproducible, chunked == unchunked');

    % ---- T8: EPRE notes ------------------------------------------------------
    o8 = o2; o8.epre = struct();
    r8 = runR23AasEirpCdfGrid(o8);
    o8b = baseOpts; o8b.epre = struct();
    r8b = runR23AasEirpCdfGrid(o8b);
    ok8 = contains(r8.epre.notes, '85 dBm') && ~contains(r8.epre.notes, '78.3') && ...
          contains(r8b.epre.notes, 'may exceed the 78.3 dBm band-integrated sector peak by design.');
    results = check(results, ok8, 'T8: EPRE notes quote 85 dBm at 2.7 GHz and keep 78.3 dBm text when off');

    % ---- T9: unknown band ----------------------------------------------------
    o9 = baseOpts; o9.band = '3.5ghz';
    ok9 = throwsId(@() runR23AasEirpCdfGrid(o9), 'imtBandName:unknownBand');
    results = check(results, ok9, 'T9: unknown band raises imtBandName:unknownBand');

    fprintf('\n--- test_runR23AasEirpCdfGrid_band2p7 summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function tf = sameAggregator(a, b)
%SAMEAGGREGATOR Exact (NaN-aware) equality of the streaming aggregator.
    flds = {'azGrid', 'elGrid', 'binEdges', 'counts', 'sum_lin_mW', ...
            'min_dBm', 'max_dBm', 'numMc', 'mean_lin_mW', 'mean_dBm'};
    tf = true;
    for k = 1:numel(flds)
        tf = tf && isfield(a, flds{k}) && isfield(b, flds{k}) && ...
             isequaln(a.(flds{k}), b.(flds{k}));
    end
end

function r = check(r, cond, msg)
    if cond
        r.summary{end+1} = ['PASS  ' msg];
    else
        r.summary{end+1} = ['FAIL  ' msg];
        r.passed = false;
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
