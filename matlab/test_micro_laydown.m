function results = test_micro_laydown()
%TEST_MICRO_LAYDOWN Self tests for the ITU 7 GHz micro-urban (8x8) laydown.
%
%   RESULTS = test_micro_laydown()
%
%   Covers the additive ITU-R R23 7.125-8.4 GHz "Small cell outdoor /
%   Micro urban" scenario: the 'r23_micro_8x8' AAS geometry preset plus
%   the 'microUrban' / 'microSuburban' deployment environments.
%
%   Covers:
%       T1.  aasGeometryPreset('r23_micro_8x8') geometry / gain / count.
%       T2.  microUrban / microSuburban deployment geometry + elevation
%            limits via imtAasSingleSectorParams and r23DefaultParams.
%       T3.  Driver end-to-end with the micro preset + microUrban env.
%       T4.  Macro back-compat is untouched (78.3 dBm, 18 m, [-10 0]).
%       T5.  Micro peak realized gain is well below macro (physical sanity).
%       T6.  subarrayElementRows == 1 yields a finite unity-sub-array
%            composite pattern (no NaN/Inf where populated).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = t_geometry_preset(results);
    results = t_deployment(results);
    results = t_driver_end_to_end(results);
    results = t_macro_untouched(results);
    results = t_micro_gain_below_macro(results);
    results = t_unity_subarray_finite(results);

    fprintf('\n--- test_micro_laydown summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% T1 -- geometry preset
% =====================================================================
function r = t_geometry_preset(r)
    g = aasGeometryPreset('r23_micro_8x8');
    ok = strcmp(g.presetName, 'r23_micro_8x8') && ...
         g.arrayRows == 8 && g.arrayCols == 8 && ...
         g.subarrayElementRows == 1 && g.subarrayElementCols == 1 && ...
         abs(g.radiatingSubarrayVerticalSpacingLambda - 0.7) < 1e-12 && ...
         abs(g.mechanicalDowntiltDeg - 10) < 1e-12 && ...
         abs(g.sectorEirpDbm - 61.5) < 1e-12 && ...
         abs(g.calculatedAntennaGainDbi - (6.4 + 10*log10(64))) < 1e-9 && ...
         g.totalPhysicalElementsAcrossPolarizations == 128;
    r = check(r, ok, sprintf( ...
        ['T1: r23_micro_8x8 = 8x8 elements, no sub-array, 0.7 lambda V, ' ...
         '~%.2f dBi, 128 elements'], g.calculatedAntennaGainDbi));

    % Aliases resolve to the same canonical preset.
    okAlias = strcmp(aasGeometryPreset('micro').presetName, 'r23_micro_8x8') && ...
              strcmp(aasGeometryPreset('micro_8x8').presetName, 'r23_micro_8x8') && ...
              strcmp(aasGeometryPreset('r23-micro-8x8').presetName, 'r23_micro_8x8');
    r = check(r, okAlias, 'T1b: micro preset aliases resolve to r23_micro_8x8');
end

% =====================================================================
% T2 -- deployment geometry + elevation limits
% =====================================================================
function r = t_deployment(r)
    p = r23DefaultParams('microUrban'); %#ok<NASGU>
    pU = r23DefaultParams('microUrban');
    okParams = strcmp(pU.deployment.environment, 'microUrban') && ...
               pU.deployment.cellRadius_m == 180 && ...
               pU.deployment.bsHeight_m == 6;

    s = imtAasSingleSectorParams('microUrban', imtAasDefaultParams());
    okU = s.bsHeight_m == 6 && isequal(s.elLimitsDeg, [-30 0]) && ...
          isequal(s.azLimitsDeg, [-60 60]) && s.cellRadius_m == 180;

    sS = imtAasSingleSectorParams('microSuburban', imtAasDefaultParams());
    okS = sS.cellRadius_m == 300 && sS.bsHeight_m == 6 && ...
          isequal(sS.elLimitsDeg, [-30 0]);

    r = check(r, okParams && okU && okS, ...
        'T2: microUrban/microSuburban geometry + [-30 0] elevation limits');
end

% =====================================================================
% T3 -- driver end-to-end
% =====================================================================
function r = t_driver_end_to_end(r)
    opts = microOpts();
    rr = runR23AasEirpCdfGrid(opts);

    v = rr.percentileMaps.values;
    okShaped = all(isfinite(v(:)) | isnan(v(:)));
    okEirp   = abs(rr.metadata.sectorEirpDbm - 61.5) < 1e-6;
    okGeo    = rr.metadata.bsHeight_m == 6 && ...
               isequal(rr.metadata.elevationLimitsDeg, [-30 0]);
    okGain   = abs(rr.metadata.aasGeometry.calculatedAntennaGainDbi - ...
                   (6.4 + 10*log10(64))) < 1e-6;
    okTilt   = abs(rr.metadata.mechanicalDowntiltDeg - 10) < 1e-6;

    r = check(r, okShaped && okEirp && okGeo && okGain && okTilt, ...
        'T3: driver runs micro preset + microUrban end-to-end with micro metadata');
end

% =====================================================================
% T4 -- macro back-compat untouched
% =====================================================================
function r = t_macro_untouched(r)
    opts = microOpts();
    opts.aasGeometryPreset = 'r23_1x3_default';
    opts.environment       = 'urban';
    rM = runR23AasEirpCdfGrid(opts);

    ok = abs(rM.metadata.sectorEirpDbm - 78.3) < 1e-6 && ...
         rM.metadata.bsHeight_m == 18 && ...
         isequal(rM.metadata.elevationLimitsDeg, [-10 0]);
    r = check(r, ok, ...
        'T4: macro (r23_1x3_default/urban) still 78.3 dBm, 18 m, [-10 0]');
end

% =====================================================================
% T5 -- micro peak realized gain well below macro
% =====================================================================
function r = t_micro_gain_below_macro(r)
    optsMicro = microOpts();
    optsMicro.outputDomain = 'gain';
    rMicro = runR23AasEirpCdfGrid(optsMicro);

    optsMacro = microOpts();
    optsMacro.aasGeometryPreset = 'r23_1x3_default';
    optsMacro.environment       = 'urban';
    optsMacro.outputDomain      = 'gain';
    rMacro = runR23AasEirpCdfGrid(optsMacro);

    microPeak = max(rMicro.gainPercentileMaps.values(:,:,end), [], 'all');
    macroPeak = max(rMacro.gainPercentileMaps.values(:,:,end), [], 'all');
    ok = microPeak < macroPeak - 5;
    r = check(r, ok, sprintf( ...
        'T5: micro peak gain %.2f dBi is >5 dB below macro %.2f dBi', ...
        microPeak, macroPeak));
end

% =====================================================================
% T6 -- unity sub-array composite pattern is finite
% =====================================================================
function r = t_unity_subarray_finite(r)
    opts = microOpts();
    opts.outputDomain = 'gain';
    rr = runR23AasEirpCdfGrid(opts);
    v = rr.gainPercentileMaps.values;
    populated = ~isnan(v);
    ok = all(isfinite(v(populated)));
    r = check(r, ok, ...
        'T6: subarrayElementRows==1 gives a finite unity-sub-array pattern');
end

% =====================================================================
% Helpers
% =====================================================================
function opts = microOpts()
    opts = struct();
    opts.aasGeometryPreset = 'r23_micro_8x8';
    opts.environment       = 'microUrban';
    opts.numMc             = 40;
    opts.seed              = 7;
    opts.azGridDeg         = -30:10:30;   % 7
    opts.elGridDeg         = -30:10:0;    % 4
    opts.binEdgesDbm       = -80:5:130;
    opts.percentiles       = [5 50 95];
    opts.computePointingHeatmap = false;
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
