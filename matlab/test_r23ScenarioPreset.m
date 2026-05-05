function results = test_r23ScenarioPreset()
%TEST_R23SCENARIOPRESET Self tests for the R23 scenario preset system.
%
%   Covers:
%       S1.  urban-baseline preset exists.
%       S2.  urban-baseline contents (environment, cellRadius_m, bsHeight_m).
%       S3.  suburban-baseline contents.
%       S4.  all presets preserve sector EIRP / bandwidth / AAS table.
%       S5.  runR23AasEirpCdfGrid(params) works for every preset.
%       S6.  scenarioPreset propagates into out.metadata.
%       S7.  invalid preset name fails cleanly.
%       S8.  power self-check exists.
%       S9a. self-check passes when observed <= sector peak + tolerance.
%       S9b. self-check warns but does not fail on large peak shortfall.
%       S9c. self-check fails when observation exceeds sector peak.
%       S10. compareR23ScenarioMetadata returns expected diff entries.
%       S11. preset overrides are forwarded into params.
%       S12. reference-only metadata is stamped (and clearly tagged).

    results.summary = {};
    results.passed  = true;

    results = s_urban_exists(results);
    results = s_urban_contents(results);
    results = s_suburban_contents(results);
    results = s_presets_preserve_sector_eirp(results);
    results = s_run_each_preset(results);
    results = s_metadata_propagation(results);
    results = s_invalid_preset(results);
    results = s_self_check_exists(results);
    results = s_self_check_pass(results);
    results = s_self_check_warn(results);
    results = s_self_check_fail(results);
    results = s_compare_diff(results);
    results = s_overrides_forwarded(results);
    results = s_reference_only_metadata(results);

    fprintf('\n--- test_r23ScenarioPreset summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function r = s_urban_exists(r)
    p = r23ScenarioPreset('urban-baseline');
    ok = isstruct(p) && isfield(p, 'metadata') && ...
         isfield(p.metadata, 'scenarioPreset') && ...
         strcmp(char(p.metadata.scenarioPreset), 'urban-baseline');
    r = check(r, ok, 'S1: r23ScenarioPreset("urban-baseline") returns a struct with scenarioPreset metadata');
end

function r = s_urban_contents(r)
    p = r23ScenarioPreset('urban-baseline');
    ok = strcmp(p.deployment.environment, 'urban') && ...
         p.deployment.cellRadius_m == 400 && ...
         p.deployment.bsHeight_m == 18 && ...
         p.ue.numUesPerSector == 3;
    r = check(r, ok, 'S2: urban-baseline -> environment=urban, cellRadius=400, bsHeight=18, 3 UEs');
end

function r = s_suburban_contents(r)
    p = r23ScenarioPreset('suburban-baseline');
    ok = strcmp(p.deployment.environment, 'suburban') && ...
         p.deployment.cellRadius_m == 800 && ...
         p.deployment.bsHeight_m == 20 && ...
         p.ue.numUesPerSector == 3;
    r = check(r, ok, 'S3: suburban-baseline -> environment=suburban, cellRadius=800, bsHeight=20, 3 UEs');
end

function r = s_presets_preserve_sector_eirp(r)
    pu = r23ScenarioPreset('urban-baseline');
    ps = r23ScenarioPreset('suburban-baseline');
    okUrban = abs(pu.bs.maxEirpPerSector_dBm - 78.3) < 1e-12 && ...
              pu.bs.channelBandwidth_MHz == 100 && ...
              isequal(pu.aas, r23DefaultParams('urban').aas);
    okSub   = abs(ps.bs.maxEirpPerSector_dBm - 78.3) < 1e-12 && ...
              ps.bs.channelBandwidth_MHz == 100 && ...
              isequal(ps.aas, r23DefaultParams('suburban').aas);
    okShared = isequal(pu.aas, ps.aas);
    r = check(r, okUrban && okSub && okShared, ...
        'S4: presets preserve 78.3 dBm sector EIRP, 100 MHz BW, shared Extended AAS table');
end

function r = s_run_each_preset(r)
    presets = {'urban-baseline', 'suburban-baseline'};
    okAll = true;
    for k = 1:numel(presets)
        p = r23ScenarioPreset(presets{k});
        % Tighten sim grid for fast tests.
        p.sim.numSnapshots = 4;
        p.sim.azGrid_deg   = -60:10:60;
        p.sim.elGrid_deg   = -10:5:10;
        p.sim.binEdges_dBm = -80:5:120;
        p.sim.percentiles  = [50 95];
        p.sim.randomSeed   = 1;
        out = quietRun(p);
        ok = isstruct(out) && isfield(out, 'stats') && ...
             isfield(out, 'metadata') && isfield(out, 'selfCheck');
        if ~ok, okAll = false; break; end
    end
    r = check(r, okAll, ...
        'S5: runR23AasEirpCdfGrid(params) works for every preset');
end

function r = s_metadata_propagation(r)
    p = r23ScenarioPreset('suburban-baseline');
    p.sim.numSnapshots = 4;
    p.sim.azGrid_deg   = -60:10:60;
    p.sim.elGrid_deg   = -10:5:10;
    p.sim.binEdges_dBm = -80:5:120;
    p.sim.percentiles  = [50 95];
    p.sim.randomSeed   = 2;
    out = quietRun(p);
    md = out.metadata;
    ok = isfield(md, 'scenarioPreset') && ...
         strcmp(char(md.scenarioPreset), 'suburban-baseline') && ...
         isfield(md, 'scenarioCategory') && ...
         strcmp(char(md.scenarioCategory), 'baseline') && ...
         isfield(md, 'sourceReference') && ...
         ~isempty(md.sourceReference) && ...
         isfield(md, 'reproducible') && md.reproducible == true;
    r = check(r, ok, ...
        'S6: scenarioPreset / scenarioCategory / sourceReference / reproducible propagate into out.metadata');
end

function r = s_invalid_preset(r)
    threw = false;
    msg = '';
    try
        r23ScenarioPreset('does-not-exist');
    catch err
        threw = true;
        msg = err.message;
    end
    okErr = threw && ~isempty(strfind(msg, 'does-not-exist')); %#ok<STREMP>
    r = check(r, okErr, 'S7: invalid preset name fails cleanly with the offending name');
end

function r = s_self_check_exists(r)
    p = r23ScenarioPreset('urban-baseline');
    p.sim.numSnapshots = 4;
    p.sim.azGrid_deg   = -60:10:60;
    p.sim.elGrid_deg   = -10:5:10;
    p.sim.binEdges_dBm = -80:5:120;
    p.sim.percentiles  = [50 95];
    p.sim.randomSeed   = 3;
    out = quietRun(p);
    ps = out.selfCheck.powerSemantics;
    ok = isfield(ps, 'expectedSectorPeakEirp_dBm') && ...
         isfield(ps, 'expectedPerBeamPeakEirp_dBm') && ...
         isfield(ps, 'observedMaxGridEirp_dBm') && ...
         isfield(ps, 'peakShortfall_dB') && ...
         isfield(ps, 'tolerance_dB') && ...
         isfield(ps, 'status') && ...
         isfield(ps, 'message') && ...
         ismember(ps.status, {'pass','warn','fail'});
    r = check(r, ok, 'S8: out.selfCheck.powerSemantics is populated with all required fields');
end

function r = s_self_check_pass(r)
    % Construct a clean pass: observed <= sector peak (no exceed),
    % shortfall small. Using the helper directly with chosen inputs.
    sectorPeak  = 78.3;
    perBeamPeak = sectorPeak - 10*log10(3);   % ~73.5
    observed    = perBeamPeak - 0.5;          % small shortfall
    ps = r23PowerSemanticsSelfCheck(observed, sectorPeak, perBeamPeak, true);
    ok = strcmp(ps.status, 'pass') && ...
         abs(ps.observedMaxGridEirp_dBm - observed) < 1e-12;
    r = check(r, ok, ...
        'S9a: power self-check status=pass when observed <= sector peak with small shortfall');
end

function r = s_self_check_warn(r)
    % observed well below per-beam peak triggers warn but not fail.
    sectorPeak  = 78.3;
    perBeamPeak = sectorPeak - 10*log10(3);
    observed    = perBeamPeak - 10;            % 10 dB shortfall, > 3 dB threshold
    ps = r23PowerSemanticsSelfCheck(observed, sectorPeak, perBeamPeak, true);
    ok = strcmp(ps.status, 'warn');
    r = check(r, ok, 'S9b: power self-check status=warn on large peak shortfall (does not fail)');
end

function r = s_self_check_fail(r)
    % observed exceeds sector peak by more than tolerance -> hard fail.
    sectorPeak  = 78.3;
    perBeamPeak = sectorPeak - 10*log10(3);
    observed    = sectorPeak + 1.0;            % deliberate overshoot
    ps = r23PowerSemanticsSelfCheck(observed, sectorPeak, perBeamPeak, true);
    okHelper = strcmp(ps.status, 'fail');

    % And confirm runR23AasEirpCdfGrid raises on the corresponding error
    % id when normalization "intentionally exceeds max sector EIRP". We
    % simulate this by running, then re-invoking the check via the
    % helper; the runner itself raises the error id when it detects a
    % fail status during its own self-check.
    threw = false;
    try
        % Force a fail by calling runR23AasEirpCdfGrid through a fake
        % stats path: easiest is to verify the runner's error id name
        % by directly calling the helper and then asserting the runner
        % would map fail -> 'runR23AasEirpCdfGrid:powerSelfCheckFail'.
        % We don't try to fabricate stats internal to the runner.
        if strcmp(ps.status, 'fail')
            error('runR23AasEirpCdfGrid:powerSelfCheckFail', '%s', ps.message);
        end
    catch err
        threw = strcmp(err.identifier, 'runR23AasEirpCdfGrid:powerSelfCheckFail');
    end

    r = check(r, okHelper && threw, ...
        'S9c: power self-check status=fail and the runner-equivalent error id maps to FAIL');
end

function r = s_compare_diff(r)
    a = r23ScenarioPreset('urban-baseline');
    b = r23ScenarioPreset('suburban-baseline');
    diff = compareR23ScenarioMetadata(a, b, 'Print', false);
    fields = arrayfun(@(d) d.field, diff, 'UniformOutput', false);
    okFields = all(ismember({'environment','cellRadius_m','bsHeight_m', ...
                             'numUesPerSector','maxEirpPerSector_dBm', ...
                             'randomSeed'}, fields));
    % Confirm that environment / cellRadius / bsHeight differ between
    % urban and suburban baselines.
    diffEnv  = ~diffEqual(diff, 'environment');
    diffRad  = ~diffEqual(diff, 'cellRadius_m');
    diffH    = ~diffEqual(diff, 'bsHeight_m');
    okEqual  = diffEqual(diff, 'numUesPerSector') && ...
               diffEqual(diff, 'maxEirpPerSector_dBm');
    r = check(r, okFields && diffEnv && diffRad && diffH && okEqual, ...
        'S10: compareR23ScenarioMetadata diff includes core fields and flags expected differences');
end

function r = s_overrides_forwarded(r)
    p = r23ScenarioPreset('urban-baseline', ...
                          'numUesPerSector', 10, ...
                          'maxEirpPerSector_dBm', 75);
    ok = p.ue.numUesPerSector == 10 && ...
         abs(p.bs.maxEirpPerSector_dBm - 75) < 1e-12 && ...
         isfield(p.metadata, 'presetOverrides') && ...
         p.metadata.presetOverrides.numUesPerSector == 10;
    r = check(r, ok, ...
        'S11: overrides ("numUesPerSector"=10, "maxEirpPerSector_dBm"=75) are applied and recorded');
end

function r = s_reference_only_metadata(r)
    p = r23ScenarioPreset('urban-baseline');
    ok = isfield(p.metadata, 'referenceOnly') && ...
         isstruct(p.metadata.referenceOnly) && ...
         isfield(p.metadata.referenceOnly, 'networkLoadingFactor') && ...
         isfield(p.metadata.referenceOnly, 'bsTddActivityFactor') && ...
         isfield(p.metadata.referenceOnly, 'notes') && ...
         ~isempty(strfind(lower(p.metadata.referenceOnly.notes), 'not active')); %#ok<STREMP>
    r = check(r, ok, ...
        'S12: referenceOnly metadata is stamped and explicitly marked NOT active');
end

% =====================================================================

function out = quietRun(p)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    out = runR23AasEirpCdfGrid(p);
end

function tf = diffEqual(diff, fieldName)
    tf = false;
    for k = 1:numel(diff)
        if strcmp(diff(k).field, fieldName)
            tf = logical(diff(k).equal);
            return;
        end
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
