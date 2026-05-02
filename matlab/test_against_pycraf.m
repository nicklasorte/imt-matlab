function results = test_against_pycraf()
%TEST_AGAINST_PYCRAF Compare MATLAB AAS pattern to pycraf reference.
%
%   RESULTS = test_against_pycraf()
%
%   When MATLAB's pyenv() reports a working interpreter that has both
%   numpy and pycraf importable, this function compares:
%
%       imt2020_single_element_pattern.m
%           against pycraf.antenna.imt2020_single_element_pattern
%
%       imt2020_composite_pattern.m
%           against pycraf.antenna.imt2020_composite_pattern, evaluated at
%           three beam-pointing cases:
%               (azim_i, elev_i) = ( 0,   0)
%                                  (30,  -5)
%                                  (-45,-10)
%
%   Identical input grids and parameters are used in both languages:
%       azim grid: -180:10:180
%       elev grid:  -90:10:90
%       G_Emax = 8, A_m = 30, SLA_nu = 30,
%       phi_3db = 65, theta_3db = 65,
%       d_H = d_V = 0.5, N_H = N_V = 8, rho = 1, k = 12.
%
%   For each comparison the function prints max abs error and mean abs
%   error (in dB). A check passes when max abs error <= 1e-6 dB.
%
%   When pycraf or Python is unavailable the test is skipped cleanly and
%   returns results.skipped = true; in that case results.passed is left at
%   true so it does not fail MATLAB-only test runs.

    results = struct('skipped', false, 'passed', true, ...
        'reason', '', 'cases', struct([]), 'summary', {{}});

    if exist('pyenv', 'builtin') ~= 5 && exist('pyenv', 'file') ~= 2
        results = skipResult(results, ...
            'pyenv not available in this MATLAB version');
        return
    end

    try
        pe = pyenv;
    catch err
        results = skipResult(results, ...
            sprintf('pyenv() failed: %s', err.message));
        return
    end

    if isprop(pe, 'Status') && pe.Status == "NotLoaded"
        try
            py.list();
        catch err
            results = skipResult(results, ...
                sprintf('Python failed to start: %s', err.message));
            return
        end
    end

    try
        np      = py.importlib.import_module('numpy');
        antenna = py.importlib.import_module('pycraf.antenna');
        cnv     = py.importlib.import_module('pycraf.conversions');
        u       = py.importlib.import_module('astropy.units');
    catch err
        results = skipResult(results, ...
            sprintf('pycraf/astropy not available: %s', err.message));
        return
    end

    cfg = defaultCfg();

    azGrid = -180:10:180;
    elGrid =  -90:10:90;
    [AZ, EL] = ndgrid(azGrid, elGrid);

    fprintf('[test_against_pycraf] grid: %dx%d (%d points)\n', ...
        size(AZ, 1), size(AZ, 2), numel(AZ));

    % ---- single-element pattern -----------------------------------------
    A_M_se = imt2020_single_element_pattern(AZ, EL, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, cfg.k);

    try
        AZ_np = np.asarray(AZ);
        EL_np = np.asarray(EL);
        A_P_se_q = callPycrafSingleElement(antenna, cnv, u, ...
            AZ_np, EL_np, cfg);
        A_P_se = double(A_P_se_q.value);
    catch err
        results = skipResult(results, sprintf( ...
            'pycraf single-element call failed: %s', err.message));
        return
    end

    results = recordCase(results, 'single_element', ...
        'imt2020_single_element_pattern', NaN, NaN, A_M_se, A_P_se);

    % ---- composite pattern: three beam-pointing cases -------------------
    cases = struct( ...
        'name',   {'composite_az0_el0',   'composite_az30_elM5',   'composite_azM45_elM10'}, ...
        'azim_i', {0,                     30,                      -45}, ...
        'elev_i', {0,                     -5,                      -10});

    for c = 1:numel(cases)
        cs = cases(c);

        A_M = imt2020_composite_pattern(AZ, EL, cs.azim_i, cs.elev_i, ...
            cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
            cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, cfg.rho, cfg.k);

        try
            AZ_np = np.asarray(AZ);
            EL_np = np.asarray(EL);
            A_P_q = antenna.imt2020_composite_pattern( ...
                AZ_np * u.deg, EL_np * u.deg, ...
                cs.azim_i * u.deg, cs.elev_i * u.deg, ...
                cfg.G_Emax * cnv.dB, cfg.A_m * cnv.dB, cfg.SLA_nu * cnv.dB, ...
                cfg.phi_3db * u.deg, cfg.theta_3db * u.deg, ...
                cfg.d_H * cnv.dimless, cfg.d_V * cnv.dimless, ...
                int32(cfg.N_H), int32(cfg.N_V), ...
                cfg.rho * cnv.dimless, pyargs('k', cfg.k));
            A_P = double(A_P_q.value);
        catch err
            results = skipResult(results, sprintf( ...
                'pycraf composite call failed (%s): %s', cs.name, err.message));
            return
        end

        label = sprintf('imt2020_composite_pattern @ azim_i=%g, elev_i=%g', ...
            cs.azim_i, cs.elev_i);
        results = recordCase(results, cs.name, label, ...
            cs.azim_i, cs.elev_i, A_M, A_P);
    end

    fprintf('\n--- test_against_pycraf summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% -------------------------------------------------------------------------

function results = recordCase(results, name, label, azim_i, elev_i, A_M, A_P)
    diff = A_M - A_P;
    finiteMask = isfinite(diff);
    if ~any(finiteMask(:))
        maxAbsErr  = NaN;
        meanAbsErr = NaN;
        passed     = false;
    else
        maxAbsErr  = max(abs(diff(finiteMask)));
        meanAbsErr = mean(abs(diff(finiteMask)));
        passed     = maxAbsErr <= 1e-6;
    end

    cs = struct('name', name, 'label', label, ...
        'azim_i', azim_i, 'elev_i', elev_i, ...
        'maxAbsErr_dB', maxAbsErr, 'meanAbsErr_dB', meanAbsErr, ...
        'passed', passed);

    if isempty(results.cases)
        results.cases = cs;
    else
        results.cases(end + 1) = cs;
    end

    results.passed = results.passed && passed;

    fprintf(['[test_against_pycraf] %s\n' ...
             '   maxAbsErr  = %.3e dB\n' ...
             '   meanAbsErr = %.3e dB\n' ...
             '   tolerance  = 1e-06 dB -> %s\n'], ...
            label, maxAbsErr, meanAbsErr, ifElse(passed, 'PASS', 'FAIL'));

    msg = sprintf('%s  %s (max=%.3e dB, mean=%.3e dB)', ...
        ifElse(passed, 'PASS', 'FAIL'), name, maxAbsErr, meanAbsErr);
    results.summary{end + 1} = msg; %#ok<*AGROW>
end

function results = skipResult(results, reason)
    results.skipped = true;
    results.reason  = reason;
    % keep .passed = true so MATLAB-only runs are not failed by a skip
    fprintf('[test_against_pycraf] SKIP: %s\n', reason);
end

function A_P_se_q = callPycrafSingleElement(antenna, cnv, u, AZ_np, EL_np, cfg)
%CALLPYCRAFSINGLEELEMENT Invoke pycraf single-element pattern, tolerating
% small signature differences (some pycraf versions accept k via kwarg,
% others expose it positionally / not at all). We try the kwarg form first
% and fall back to the no-kwarg form.

    try
        A_P_se_q = antenna.imt2020_single_element_pattern( ...
            AZ_np * u.deg, EL_np * u.deg, ...
            cfg.G_Emax * cnv.dB, cfg.A_m * cnv.dB, cfg.SLA_nu * cnv.dB, ...
            cfg.phi_3db * u.deg, cfg.theta_3db * u.deg, ...
            pyargs('k', cfg.k));
    catch
        A_P_se_q = antenna.imt2020_single_element_pattern( ...
            AZ_np * u.deg, EL_np * u.deg, ...
            cfg.G_Emax * cnv.dB, cfg.A_m * cnv.dB, cfg.SLA_nu * cnv.dB, ...
            cfg.phi_3db * u.deg, cfg.theta_3db * u.deg);
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end

function cfg = defaultCfg()
    cfg.G_Emax    = 8;
    cfg.A_m       = 30;
    cfg.SLA_nu    = 30;
    cfg.phi_3db   = 65;
    cfg.theta_3db = 65;
    cfg.d_H       = 0.5;
    cfg.d_V       = 0.5;
    cfg.N_H       = 8;
    cfg.N_V       = 8;
    cfg.rho       = 1;
    cfg.k         = 12;
end
