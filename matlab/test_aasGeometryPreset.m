function results = test_aasGeometryPreset()
%TEST_AASGEOMETRYPRESET Self tests for the AAS geometry preset layer.
%
%   RESULTS = test_aasGeometryPreset()
%
%   Covers:
%       T1.  aasGeometryPreset('r23_1x3_default') returns expected geometry.
%       T2.  aasGeometryPreset('ctia_7ghz_1x6')   returns expected geometry.
%       T3.  CTIA total physical elements across polarizations = 768.
%       T4.  CTIA subarray gain ~= 7.78 dB.
%       T5.  CTIA array gain    ~= 18.06 dB.
%       T6.  CTIA antenna gain  ~= 32.24 dBi (~= 32.2).
%       T7.  R23 default antenna gain ~= 32.24 dBi (~= 32.2).
%       T8.  runR23AasEirpCdfGrid() default matches explicit r23_1x3_default
%            for a deterministic small run.
%       T9.  runR23AasEirpCdfGrid('aasGeometryPreset','ctia_7ghz_1x6')
%            runs cleanly and reports the CTIA preset / geometry in metadata.
%       T10. CTIA preset elevation pattern differs from R23 default for the
%            same steering direction (different vertical aperture).
%       T11. Invalid preset name raises an error.
%       T12. Negative subarrayElementRows raises an error.
%       T13. Non-integer subarrayElementRows raises an error.
%       T14. Zero arrayRows raises an error.
%       T15. Unknown geometry override raises an error.
%       T16. custom preset without required fields raises an error.
%       T17. Custom override via runR23AasEirpCdfGrid works end-to-end.
%       T18. CTIA preset propagates 90.8 dBm sector EIRP into params/stats.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = t_r23_default_fields(results);
    results = t_ctia_fields(results);
    results = t_ctia_element_count(results);
    results = t_ctia_subarray_gain(results);
    results = t_ctia_array_gain(results);
    results = t_ctia_antenna_gain(results);
    results = t_r23_antenna_gain(results);
    results = t_runner_default_matches_explicit(results);
    results = t_runner_ctia_runs(results);
    results = t_pattern_differs(results);
    results = t_invalid_preset(results);
    results = t_negative_subarray_rows(results);
    results = t_noninteger_subarray_rows(results);
    results = t_zero_array_rows(results);
    results = t_unknown_override(results);
    results = t_custom_missing_field(results);
    results = t_runner_custom_override(results);
    results = t_ctia_sector_eirp(results);

    fprintf('\n--- test_aasGeometryPreset summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% T1
% =====================================================================
function r = t_r23_default_fields(r)
    g = aasGeometryPreset('r23_1x3_default');
    ok = strcmp(g.presetName, 'r23_1x3_default') && ...
         g.arrayRows == 8 && ...
         g.arrayCols == 16 && ...
         g.subarrayElementRows == 3 && ...
         g.subarrayElementCols == 1 && ...
         abs(g.subarrayElementVerticalSpacingLambda - 0.7) < 1e-12 && ...
         abs(g.radiatingSubarrayHorizontalSpacingLambda - 0.5) < 1e-12 && ...
         abs(g.radiatingSubarrayVerticalSpacingLambda - 2.1) < 1e-12 && ...
         abs(g.subarrayDowntiltDeg - 3) < 1e-12 && ...
         abs(g.mechanicalDowntiltDeg - 6) < 1e-12 && ...
         abs(g.elementGainDbi - 6.4) < 1e-12 && ...
         abs(g.sectorEirpDbm - 78.3) < 1e-12;
    r = check(r, ok, 'T1: r23_1x3_default preset fields match spec');
end

% =====================================================================
% T2
% =====================================================================
function r = t_ctia_fields(r)
    g = aasGeometryPreset('ctia_7ghz_1x6');
    ok = strcmp(g.presetName, 'ctia_7ghz_1x6') && ...
         g.arrayRows == 4 && ...
         g.arrayCols == 16 && ...
         g.subarrayElementRows == 6 && ...
         g.subarrayElementCols == 1 && ...
         abs(g.subarrayElementVerticalSpacingLambda - 0.7) < 1e-12 && ...
         abs(g.radiatingSubarrayHorizontalSpacingLambda - 0.5) < 1e-12 && ...
         abs(g.radiatingSubarrayVerticalSpacingLambda - 4.2) < 1e-12 && ...
         abs(g.elementGainDbi - 6.4) < 1e-12 && ...
         abs(g.sectorEirpDbm - 90.8) < 1e-12 && ...
         abs(g.conductedPowerDbm - 58.6) < 1e-12;
    r = check(r, ok, 'T2: ctia_7ghz_1x6 preset fields match spec');
end

% =====================================================================
% T3
% =====================================================================
function r = t_ctia_element_count(r)
    g = aasGeometryPreset('ctia_7ghz_1x6');
    ok = g.totalPhysicalElementsAcrossPolarizations == 768;
    r = check(r, ok, sprintf( ...
        'T3: CTIA total physical elements across polarizations = 768 (got %d)', ...
        g.totalPhysicalElementsAcrossPolarizations));
end

% =====================================================================
% T4
% =====================================================================
function r = t_ctia_subarray_gain(r)
    g = aasGeometryPreset('ctia_7ghz_1x6');
    expected = 10 * log10(6);
    ok = abs(g.calculatedSubarrayGainDb - expected) < 1e-9 && ...
         abs(g.calculatedSubarrayGainDb - 7.78) < 0.02;
    r = check(r, ok, sprintf( ...
        'T4: CTIA subarray gain ~ %.4f dB (got %.4f)', expected, ...
        g.calculatedSubarrayGainDb));
end

% =====================================================================
% T5
% =====================================================================
function r = t_ctia_array_gain(r)
    g = aasGeometryPreset('ctia_7ghz_1x6');
    expected = 10 * log10(64);
    ok = abs(g.calculatedArrayGainDb - expected) < 1e-9 && ...
         abs(g.calculatedArrayGainDb - 18.06) < 0.02;
    r = check(r, ok, sprintf( ...
        'T5: CTIA array gain ~ %.4f dB (got %.4f)', expected, ...
        g.calculatedArrayGainDb));
end

% =====================================================================
% T6
% =====================================================================
function r = t_ctia_antenna_gain(r)
    g = aasGeometryPreset('ctia_7ghz_1x6');
    expected = 6.4 + 10 * log10(6) + 10 * log10(64);
    ok = abs(g.calculatedAntennaGainDbi - expected) < 1e-9 && ...
         abs(g.calculatedAntennaGainDbi - 32.2) < 0.1;
    r = check(r, ok, sprintf( ...
        'T6: CTIA antenna gain ~ %.4f dBi (got %.4f)', expected, ...
        g.calculatedAntennaGainDbi));
end

% =====================================================================
% T7
% =====================================================================
function r = t_r23_antenna_gain(r)
    g = aasGeometryPreset('r23_1x3_default');
    expected = 6.4 + 10 * log10(3) + 10 * log10(8 * 16);
    ok = abs(g.calculatedAntennaGainDbi - expected) < 1e-9 && ...
         abs(g.calculatedAntennaGainDbi - 32.2) < 0.1;
    r = check(r, ok, sprintf( ...
        'T7: R23 default antenna gain ~ %.4f dBi (got %.4f)', expected, ...
        g.calculatedAntennaGainDbi));
end

% =====================================================================
% T8
% =====================================================================
function r = t_runner_default_matches_explicit(r)
    opts = smallOpts();
    opts.seed = 17;
    outDefault  = runR23AasEirpCdfGrid(opts);
    outExplicit = runR23AasEirpCdfGrid(opts, ...
        'aasGeometryPreset', 'r23_1x3_default');

    okCounts = isequal(outDefault.stats.counts, outExplicit.stats.counts);
    okSum    = isequaln(outDefault.stats.sum_lin_mW, ...
                        outExplicit.stats.sum_lin_mW);
    okMeta   = strcmp(outDefault.metadata.aasGeometry.aasGeometryPreset, ...
                      'r23_1x3_default') && ...
               strcmp(outExplicit.metadata.aasGeometry.aasGeometryPreset, ...
                      'r23_1x3_default');
    r = check(r, okCounts && okSum && okMeta, ...
        'T8: default == explicit r23_1x3_default (counts, sum, metadata)');
end

% =====================================================================
% T9
% =====================================================================
function r = t_runner_ctia_runs(r)
    opts = smallOpts();
    opts.seed = 17;
    out = runR23AasEirpCdfGrid(opts, ...
        'aasGeometryPreset', 'ctia_7ghz_1x6');

    md = out.metadata;
    okPreset = strcmp(md.aasGeometryPreset, 'ctia_7ghz_1x6');
    g = md.aasGeometry;
    okGeom = g.arrayRows == 4 && g.arrayCols == 16 && ...
             g.subarrayElementRows == 6 && g.subarrayElementCols == 1 && ...
             g.totalPhysicalElementsAcrossPolarizations == 768;
    okGain = abs(g.calculatedAntennaGainDbi - 32.2) < 0.1;
    okFinite = all(isfinite(out.stats.mean_dBm(:)));
    r = check(r, okPreset && okGeom && okGain && okFinite, ...
        'T9: CTIA preset runs cleanly and reports CTIA geometry in metadata');
end

% =====================================================================
% T10
% =====================================================================
function r = t_pattern_differs(r)
    p23  = applyGeometry(imtAasDefaultParams(), 'r23_1x3_default');
    pCtia = applyGeometry(imtAasDefaultParams(), 'ctia_7ghz_1x6');
    az = 0;
    el = -90:1:30;
    g23  = imtAasCompositeGain(az, el, 0, -9, p23);
    gCti = imtAasCompositeGain(az, el, 0, -9, pCtia);

    % The two presets share the same 32.2 dBi peak but have different
    % vertical apertures, so the elevation pattern shape MUST differ.
    sameShape = all(abs(g23(:) - gCti(:)) < 1e-6);
    finite = all(isfinite(g23(:))) && all(isfinite(gCti(:)));
    r = check(r, ~sameShape && finite, ...
        'T10: CTIA elevation pattern differs from R23 default at steerEl=-9');
end

% =====================================================================
% T11
% =====================================================================
function r = t_invalid_preset(r)
    threw = false;
    try
        aasGeometryPreset('not_a_real_preset');
    catch err
        threw = strcmp(err.identifier, 'aasGeometryPreset:unknownPreset');
    end
    r = check(r, threw, 'T11: unknown preset raises aasGeometryPreset:unknownPreset');
end

% =====================================================================
% T12
% =====================================================================
function r = t_negative_subarray_rows(r)
    threw = false;
    try
        aasGeometryPreset('r23_1x3_default', 'subarrayElementRows', -1);
    catch err
        threw = strcmp(err.identifier, 'aasGeometryPreset:badGeometryValue');
    end
    r = check(r, threw, 'T12: negative subarrayElementRows raises badGeometryValue');
end

% =====================================================================
% T13
% =====================================================================
function r = t_noninteger_subarray_rows(r)
    threw = false;
    try
        aasGeometryPreset('r23_1x3_default', 'subarrayElementRows', 2.5);
    catch err
        threw = strcmp(err.identifier, 'aasGeometryPreset:badGeometryValue');
    end
    r = check(r, threw, 'T13: non-integer subarrayElementRows raises badGeometryValue');
end

% =====================================================================
% T14
% =====================================================================
function r = t_zero_array_rows(r)
    threw = false;
    try
        aasGeometryPreset('r23_1x3_default', 'arrayRows', 0);
    catch err
        threw = strcmp(err.identifier, 'aasGeometryPreset:badGeometryValue');
    end
    r = check(r, threw, 'T14: zero arrayRows raises badGeometryValue');
end

% =====================================================================
% T15
% =====================================================================
function r = t_unknown_override(r)
    threw = false;
    try
        aasGeometryPreset('r23_1x3_default', 'thisFieldDoesNotExist', 1);
    catch err
        threw = strcmp(err.identifier, 'aasGeometryPreset:unknownOverride');
    end
    r = check(r, threw, 'T15: unknown geometry override raises unknownOverride');
end

% =====================================================================
% T16
% =====================================================================
function r = t_custom_missing_field(r)
    threw = false;
    try
        % Only one geometry field provided -- the rest are missing.
        aasGeometryPreset('custom', 'arrayRows', 4);
    catch err
        threw = strcmp(err.identifier, 'aasGeometryPreset:missingCustomField');
    end
    r = check(r, threw, ...
        'T16: custom preset without required fields raises missingCustomField');
end

% =====================================================================
% T17
% =====================================================================
function r = t_runner_custom_override(r)
    opts = smallOpts();
    opts.seed = 23;
    out = runR23AasEirpCdfGrid(opts, ...
        'aasGeometryPreset', 'r23_1x3_default', ...
        'subarrayElementRows', 2);
    g = out.metadata.aasGeometry;
    okOverride = g.subarrayElementRows == 2 && ...
                 g.arrayRows == 8 && g.arrayCols == 16;
    okFinite = all(isfinite(out.stats.mean_dBm(:)));
    r = check(r, okOverride && okFinite, ...
        'T17: per-call subarrayElementRows override propagates into metadata');
end

% =====================================================================
% T18
% =====================================================================
function r = t_ctia_sector_eirp(r)
    opts = smallOpts();
    opts.seed = 31;
    out = runR23AasEirpCdfGrid(opts, ...
        'aasGeometryPreset', 'ctia_7ghz_1x6');
    okEirp = abs(out.stats.sectorEirpDbm - 90.8) < 1e-9 && ...
             abs(out.metadata.maxEirpPerSector_dBm - 90.8) < 1e-9;
    r = check(r, okEirp, ...
        'T18: CTIA preset propagates 90.8 dBm sectorEirpDbm into stats / metadata');
end

% =====================================================================
% Helpers
% =====================================================================
function opts = smallOpts()
    opts = struct();
    opts.numMc       = 4;
    opts.azGridDeg   = -30:10:30;     % 7
    opts.elGridDeg   = -10:5:10;      % 5
    opts.binEdgesDbm = -80:5:130;
    opts.percentiles = [5 50 95];
    opts.seed        = 1;
    opts.numBeams    = 3;
    opts.deployment  = 'macroUrban';
    opts.computePointingHeatmap = false;
end

function params = applyGeometry(params, presetName)
    g = aasGeometryPreset(presetName);
    params.numRows                   = g.arrayRows;
    params.numColumns                = g.arrayCols;
    params.numElementsPerSubarray    = g.subarrayElementRows;
    params.elementSpacingWavelengths = g.subarrayElementVerticalSpacingLambda;
    params.hSpacingWavelengths       = g.radiatingSubarrayHorizontalSpacingLambda;
    params.vSubarraySpacingWavelengths = g.radiatingSubarrayVerticalSpacingLambda;
    params.subarrayDowntiltDeg       = g.subarrayDowntiltDeg;
    params.mechanicalDowntiltDeg     = g.mechanicalDowntiltDeg;
    params.elementGainDbi            = g.elementGainDbi;
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
