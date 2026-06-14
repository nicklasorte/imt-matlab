function results = test_pointing_weighted_map()
%TEST_POINTING_WEIGHTED_MAP opts.pointingWeightedMap integration tests.
%
%   RESULTS = test_pointing_weighted_map()
%
%   Covers the opts.pointingWeightedMap layer on runR23AasEirpCdfGrid. This
%   is the max-EIRP main beam (peak sector EIRP / peak antenna gain) weighted
%   by the probability the array steers there: a SEPARATE, additive output
%   that never reshapes the band-integrated path.
%       T1.  Opt-in / back-compat: default (no pointingWeightedMap) ->
%            out.pointingWeightedMap empty + metadata.pointingWeightedMap
%            false; ON vs OFF at the same seed leaves raw percentileMaps /
%            stats byte-identical (read-only on stats).
%       T2.  Enabled, exact relationship: eirpWeightedDbm == peakEirpDbm +
%            10log10(pmf) and gainWeightedDbi == peakGainDbi + 10log10(pmf);
%            pmf sums to 1; unpointed cells -> -Inf; no silent drops.
%       T3.  Bounded by the peak (pmf <= 1); peakEirpDbm == sectorEirpDbm.
%       T4.  Physical sanity: default clampElevation -> no pointing mass at
%            elGrid > 0, so those cells are -Inf.
%       T5.  Geometry-agnostic: macro (78.3) vs micro (61.5) peak EIRP and the
%            exact relationship hold for each preset.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    % ---- small fast config ------------------------------------------
    baseOpts = struct();
    baseOpts.numMc       = 60;
    baseOpts.azGridDeg   = -60:5:60;        % 25
    baseOpts.elGridDeg   = -12:1:6;         % 19
    baseOpts.binEdgesDbm = -100:1:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 7;
    baseOpts.numBeams    = 3;
    baseOpts.deployment  = 'macroUrban';

    base = runR23AasEirpCdfGrid(baseOpts);

    % ---- T1: opt-in / back-compat -----------------------------------
    onOpts = baseOpts;
    onOpts.pointingWeightedMap = true;
    onRun = runR23AasEirpCdfGrid(onOpts);

    ok1 = isfield(base, 'pointingWeightedMap') && ...
          isstruct(base.pointingWeightedMap) && ...
          isempty(base.pointingWeightedMap.eirpWeightedDbm) && ...
          isempty(base.pointingWeightedMap.pmf) && ...
          base.metadata.pointingWeightedMap == false && ...
          onRun.metadata.pointingWeightedMap == true && ...
          ~isempty(onRun.pointingWeightedMap.eirpWeightedDbm) && ...
          isequaln(onRun.percentileMaps.values, base.percentileMaps.values) && ...
          isequal(onRun.stats.counts,           base.stats.counts) && ...
          isequaln(onRun.stats.sum_lin_mW,      base.stats.sum_lin_mW) && ...
          isequaln(onRun.stats.min_dBm,         base.stats.min_dBm) && ...
          isequaln(onRun.stats.max_dBm,         base.stats.max_dBm) && ...
          isequaln(onRun.gainPercentileMaps,    base.gainPercentileMaps) && ...
          isequaln(onRun.pointing,              base.pointing) && ...
          isequaln(onRun.pointingHistogram,     base.pointingHistogram);
    results = check(results, ok1, ...
        'T1: default-off empty; ON vs OFF leaves raw maps/stats byte-identical');

    % ---- T2: enabled, exact relationship ----------------------------
    PW  = onRun.pointingWeightedMap;
    m   = PW.pmf > 0;
    ok2 = isequal(size(PW.eirpWeightedDbm), [numel(PW.azGrid) numel(PW.elGrid)]) && ...
          (PW.numInRange + PW.numOutOfRange == onRun.metadata.numUesPerSector * 60) && ...
          abs(sum(PW.pmf(:)) - 1) < 1e-9 && ...
          max(abs(PW.eirpWeightedDbm(m) - (PW.peakEirpDbm + 10*log10(PW.pmf(m)))), [], 'all') < 1e-9 && ...
          max(abs(PW.gainWeightedDbi(m) - (PW.peakGainDbi + 10*log10(PW.pmf(m)))), [], 'all') < 1e-9 && ...
          all(isinf(PW.eirpWeightedDbm(~m))) && all(PW.eirpWeightedDbm(~m) < 0);
    results = check(results, ok2, ...
        'T2: eirp/gainWeighted == peak + 10log10(pmf); pmf sums to 1; unpointed -> -Inf');

    % ---- T3: bounded by the peak ------------------------------------
    ok3 = max(PW.eirpWeightedDbm(:)) <= PW.peakEirpDbm + 1e-9 && ...
          abs(PW.peakEirpDbm - onRun.metadata.sectorEirpDbm) < 1e-6;
    results = check(results, ok3, ...
        'T3: weighted EIRP bounded by peak; peakEirpDbm == sectorEirpDbm');

    % ---- T4: physical sanity (clampElevation default) ---------------
    posEl = PW.elGrid > 0;
    if any(posEl)
        ok4 = all(isinf(PW.eirpWeightedDbm(:, posEl)), 'all');
    else
        ok4 = true;   % grid has no cells above the horizon
    end
    results = check(results, ok4, ...
        'T4: no pointing mass at elGrid>0 -> those cells are -Inf');

    % ---- T5: geometry-agnostic (macro vs micro) ---------------------
    macroPW = PW;   % 'r23_1x3_default' macro from baseOpts
    okMacro = abs(macroPW.peakEirpDbm - 78.3) < 1e-6 && exactRel(macroPW);

    microOpts = struct();
    microOpts.aasGeometryPreset = 'r23_micro_8x8';
    microOpts.environment       = 'microUrban';
    microOpts.numMc       = 60;
    microOpts.azGridDeg   = -60:5:60;
    microOpts.elGridDeg   = -32:2:6;
    microOpts.binEdgesDbm = -100:1:120;
    microOpts.percentiles = [5 50 95];
    microOpts.seed        = 7;
    microOpts.numBeams    = 3;
    microOpts.pointingWeightedMap = true;
    microRun = runR23AasEirpCdfGrid(microOpts);
    microPW  = microRun.pointingWeightedMap;
    okMicro = abs(microPW.peakEirpDbm - 61.5) < 1e-6 && exactRel(microPW);

    ok5 = okMacro && okMicro;
    results = check(results, ok5, sprintf( ...
        'T5: geometry-correct peaks (macro %.1f / micro %.1f) + exact relationship', ...
        macroPW.peakEirpDbm, microPW.peakEirpDbm));

    fprintf('\n--- test_pointing_weighted_map summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function tf = exactRel(PW)
    m  = PW.pmf > 0;
    tf = abs(sum(PW.pmf(:)) - 1) < 1e-9 && ...
         max(abs(PW.eirpWeightedDbm(m) - (PW.peakEirpDbm + 10*log10(PW.pmf(m)))), [], 'all') < 1e-9 && ...
         max(abs(PW.gainWeightedDbi(m) - (PW.peakGainDbi + 10*log10(PW.pmf(m)))), [], 'all') < 1e-9 && ...
         all(isinf(PW.eirpWeightedDbm(~m)), 'all');
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
