function results = test_r23DefaultParams()
%TEST_R23DEFAULTPARAMS Self tests for the centralized r23DefaultParams builder.
%
%   Covers urban / suburban presets, AAS antenna table sharing, BS power
%   defaults, sim defaults, and error handling.

    results.summary = {};
    results.passed  = true;

    results = t_default_is_urban(results);
    results = t_urban_preset(results);
    results = t_suburban_preset(results);
    results = t_same_aas_table(results);
    results = t_bs_power_defaults(results);
    results = t_ue_defaults(results);
    results = t_sim_defaults(results);
    results = t_unknown_environment_errors(results);

    fprintf('\n--- test_r23DefaultParams summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function r = t_default_is_urban(r)
    p = r23DefaultParams();
    ok = strcmp(p.deployment.environment, 'urban') && ...
         p.deployment.cellRadius_m == 400 && ...
         p.deployment.bsHeight_m == 18;
    r = check(r, ok, 'T1: r23DefaultParams() defaults to urban (400 m / 18 m BS)');
end

function r = t_urban_preset(r)
    p = r23DefaultParams('urban');
    okEnv  = strcmp(p.deployment.environment, 'urban');
    okGeom = p.deployment.cellRadius_m == 400 && p.deployment.bsHeight_m == 18;
    okDens = abs(p.deployment.bsDensityPerKm2 - 10) < 1e-9;

    % Alias 'macroUrban' should produce the same urban preset.
    p2 = r23DefaultParams('macroUrban');
    okAlias = isequal(p.deployment, p2.deployment);
    r = check(r, okEnv && okGeom && okDens && okAlias, ...
        'T2: urban preset (400 m, 18 m, 10 BSs/km^2; macroUrban alias works)');
end

function r = t_suburban_preset(r)
    p = r23DefaultParams('suburban');
    okEnv  = strcmp(p.deployment.environment, 'suburban');
    okGeom = p.deployment.cellRadius_m == 800 && p.deployment.bsHeight_m == 20;
    okDens = abs(p.deployment.bsDensityPerKm2 - 2.4) < 1e-9;

    % Alias 'macroSuburban' should produce the same suburban preset.
    p2 = r23DefaultParams('macroSuburban');
    okAlias = isequal(p.deployment, p2.deployment);
    r = check(r, okEnv && okGeom && okDens && okAlias, ...
        'T3: suburban preset (800 m, 20 m, 2.4 BSs/km^2; macroSuburban alias works)');
end

function r = t_same_aas_table(r)
    pu = r23DefaultParams('urban');
    ps = r23DefaultParams('suburban');
    ok = isequal(pu.aas, ps.aas);
    r = check(r, ok, 'T4: urban and suburban share the same Extended AAS antenna table');

    % And it matches the source table values.
    okVals = pu.aas.numRows == 8 && pu.aas.numColumns == 16 && ...
             pu.aas.elementGain_dBi == 6.4 && ...
             pu.aas.elementHorizontal3dBBeamwidth_deg == 90 && ...
             pu.aas.elementVertical3dBBeamwidth_deg == 65 && ...
             pu.aas.frontToBackRatio_dB == 30 && ...
             pu.aas.horizontalSpacing_lambda == 0.5 && ...
             pu.aas.verticalSubarraySpacing_lambda == 2.1 && ...
             pu.aas.numElementRowsInSubarray == 3 && ...
             pu.aas.verticalElementSeparationInSubarray_lambda == 0.7 && ...
             pu.aas.subarrayDowntilt_deg == 3 && ...
             pu.aas.mechanicalDowntilt_deg == 6 && ...
             isequal(pu.aas.horizontalCoverage_deg, [-60 60]) && ...
             isequal(pu.aas.verticalCoverageGlobal_deg, [90 100]) && ...
             strcmp(char(pu.aas.model), 'extended');
    r = check(r, okVals, 'T5: AAS antenna table values match the source (8x16, 6.4 dBi, 90/65 deg, ...)');
end

function r = t_bs_power_defaults(r)
    p = r23DefaultParams();
    ok = abs(p.bs.maxEirpPerSector_dBm - 78.3) < 1e-12 && ...
         abs(p.bs.conductedPower_dBm - 46.1)   < 1e-12 && ...
         abs(p.bs.peakGain_dBi - 32.2)         < 1e-12 && ...
         p.bs.channelBandwidth_MHz == 100 && ...
         abs(p.bs.tddActivityFactor - 0.75) < 1e-12 && ...
         abs(p.bs.networkLoadingFactor - 0.20) < 1e-12;
    r = check(r, ok, 'T6: BS power defaults (78.3 / 46.1 / 32.2 dBm, 100 MHz, 75%, 20%)');
end

function r = t_ue_defaults(r)
    p = r23DefaultParams();
    ok = p.ue.numUesPerSector == 3 && ...
         p.ue.height_m == 1.5 && ...
         p.ue.maxOutputPower_dBm == 23 && ...
         p.ue.antennaGain_dBi == -4 && ...
         p.ue.bodyLoss_dB == 4 && ...
         abs(p.ue.indoorFraction - 0.70) < 1e-12 && ...
         abs(p.ue.p0Pusch_dBmPerRb - (-92.2)) < 1e-12 && ...
         abs(p.ue.alpha - 0.8) < 1e-12;
    r = check(r, ok, 'T7: UE defaults (3 UEs / sector, 1.5 m, 23 dBm, -4 dBi, 4 dB body)');
end

function r = t_sim_defaults(r)
    p = r23DefaultParams();
    ok = isnumeric(p.sim.numSnapshots) && p.sim.numSnapshots >= 1 && ...
         isnumeric(p.sim.randomSeed) && ...
         logical(p.sim.computePointingHeatmap) && ...
         logical(p.sim.splitSectorPower) && ...
         strcmp(char(p.sim.pointingSummaryStatistic), 'meanAcrossSnapshots');
    r = check(r, ok, 'T8: sim defaults (numSnapshots set, computePointingHeatmap on, splitSectorPower on)');
end

function r = t_unknown_environment_errors(r)
    threw = false;
    msg = '';
    try
        r23DefaultParams('mysteryEnvironment');
    catch err
        threw = true;
        msg = err.message;
    end
    okErr = threw && ~isempty(strfind(msg, 'mysteryEnvironment')); %#ok<STREMP>
    r = check(r, okErr, 'T9: unknown environment raises a clear error naming the input');
end

% =====================================================================

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
