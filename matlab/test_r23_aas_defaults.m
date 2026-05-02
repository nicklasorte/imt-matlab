function results = test_r23_aas_defaults()
%TEST_R23_AAS_DEFAULTS Self tests for imt_r23_aas_defaults.
%
%   Verifies the R23 7.125-8.4 GHz IMT macro-AAS defaults match the
%   reference values:
%       N_H = 16, N_V = 8 (R23 row x column = 8 x 16)
%       G_Emax = 6.4, phi_3db = 90, theta_3db = 65
%       d_H = 0.5, d_V = 2.1
%       subarray.numVerticalElements = 3
%       subarray.d_V                  = 0.7
%       subarray.downtiltDeg          = 3
%       mechanicalDowntiltDeg = 6
%       txPower_dBm = 46.1
%       peakGain_dBi = 32.2
%       sectorEirp_dBm_per100MHz = 78.3
%
%   Also checks deployment-specific BS heights (macroUrban = 18 m,
%   macroSuburban = 20 m) and that an unknown deployment raises a clear
%   error.

    results.summary = {};
    results.passed  = true;

    % --- macroUrban defaults (also default deployment) ----------------
    cfg = imt_r23_aas_defaults('macroUrban');

    results = check(results, cfg.N_H == 16, ...
        sprintf('N_H = %g, expected 16', cfg.N_H));
    results = check(results, cfg.N_V == 8, ...
        sprintf('N_V = %g, expected 8', cfg.N_V));
    results = check(results, cfg.G_Emax == 6.4, ...
        sprintf('G_Emax = %g, expected 6.4', cfg.G_Emax));
    results = check(results, cfg.phi_3db == 90, ...
        sprintf('phi_3db = %g, expected 90', cfg.phi_3db));
    results = check(results, cfg.theta_3db == 65, ...
        sprintf('theta_3db = %g, expected 65', cfg.theta_3db));
    results = check(results, cfg.d_H == 0.5, ...
        sprintf('d_H = %g, expected 0.5', cfg.d_H));
    results = check(results, cfg.d_V == 2.1, ...
        sprintf('d_V = %g, expected 2.1', cfg.d_V));

    results = check(results, isfield(cfg, 'subarray') && isstruct(cfg.subarray), ...
        'cfg.subarray is a struct');
    results = check(results, cfg.subarray.numVerticalElements == 3, ...
        sprintf('subarray.numVerticalElements = %g, expected 3', ...
            cfg.subarray.numVerticalElements));
    results = check(results, cfg.subarray.d_V == 0.7, ...
        sprintf('subarray.d_V = %g, expected 0.7', cfg.subarray.d_V));
    results = check(results, cfg.subarray.downtiltDeg == 3, ...
        sprintf('subarray.downtiltDeg = %g, expected 3', ...
            cfg.subarray.downtiltDeg));

    results = check(results, cfg.mechanicalDowntiltDeg == 6, ...
        sprintf('mechanicalDowntiltDeg = %g, expected 6', ...
            cfg.mechanicalDowntiltDeg));

    results = check(results, abs(cfg.txPower_dBm - 46.1) < 1e-12, ...
        sprintf('txPower_dBm = %g, expected 46.1', cfg.txPower_dBm));
    results = check(results, abs(cfg.peakGain_dBi - 32.2) < 1e-12, ...
        sprintf('peakGain_dBi = %g, expected 32.2', cfg.peakGain_dBi));
    results = check(results, abs(cfg.sectorEirp_dBm_per100MHz - 78.3) < 1e-12, ...
        sprintf('sectorEirp_dBm_per100MHz = %g, expected 78.3', ...
            cfg.sectorEirp_dBm_per100MHz));

    results = check(results, ...
        strcmp(cfg.patternModel, 'r23_extended_aas'), ...
        sprintf('patternModel = "%s", expected "r23_extended_aas"', ...
            cfg.patternModel));
    results = check(results, cfg.frequencyMHz == 8000, ...
        sprintf('frequencyMHz = %g, expected 8000', cfg.frequencyMHz));
    results = check(results, cfg.bandwidthMHz == 100, ...
        sprintf('bandwidthMHz = %g, expected 100', cfg.bandwidthMHz));
    results = check(results, logical(cfg.normalizeToPeakGain), ...
        'normalizeToPeakGain is true');

    results = check(results, strcmp(cfg.deployment, 'macroUrban'), ...
        sprintf('deployment = "%s", expected "macroUrban"', cfg.deployment));
    results = check(results, cfg.bsHeight_m == 18, ...
        sprintf('macroUrban bsHeight_m = %g, expected 18', cfg.bsHeight_m));

    % --- default deployment (no argument) is macroUrban ---------------
    cfgDefault = imt_r23_aas_defaults();
    results = check(results, ...
        strcmp(cfgDefault.deployment, 'macroUrban') && cfgDefault.bsHeight_m == 18, ...
        'no-argument call defaults to macroUrban with 18 m BS height');

    % --- macroSuburban ------------------------------------------------
    cfgSub = imt_r23_aas_defaults('macroSuburban');
    results = check(results, strcmp(cfgSub.deployment, 'macroSuburban'), ...
        sprintf('deployment = "%s", expected "macroSuburban"', cfgSub.deployment));
    results = check(results, cfgSub.bsHeight_m == 20, ...
        sprintf('macroSuburban bsHeight_m = %g, expected 20', cfgSub.bsHeight_m));

    % macroSuburban shares antenna parameters with macroUrban
    results = check(results, ...
        cfgSub.N_H == 16 && cfgSub.N_V == 8 && cfgSub.peakGain_dBi == 32.2, ...
        'macroSuburban shares the same antenna table as macroUrban');

    % --- unknown deployment throws a useful error ---------------------
    threw = false;
    msg = '';
    try
        imt_r23_aas_defaults('mysteryDeployment');
    catch err
        threw = true;
        msg = err.message;
    end
    results = check(results, threw, ...
        'unknown deployment raises an error');
    results = check(results, threw && ~isempty(strfind(msg, 'mysteryDeployment')), ...
        sprintf('error message names the unknown deployment (got: "%s")', msg));

    fprintf('\n--- test_r23_aas_defaults summary ---\n');
    for i = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{i});
    end
    if results.passed
        fprintf('  ALL TESTS PASSED\n');
    else
        fprintf('  TESTS FAILED\n');
    end
end

function results = check(results, condition, msg)
    if condition
        tag = 'PASS';
    else
        tag = 'FAIL';
        results.passed = false;
    end
    line = sprintf('[%s] %s', tag, msg);
    fprintf('  %s\n', line);
    results.summary{end + 1} = line; %#ok<*AGROW>
end
