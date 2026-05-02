function results = test_against_pycraf()
%TEST_AGAINST_PYCRAF Compare MATLAB AAS pattern to pycraf reference.
%
%   RESULTS = test_against_pycraf()
%
%   When MATLAB's pyenv() reports a working interpreter that has both
%   numpy and pycraf importable, this function:
%       1. Builds a small az/el grid.
%       2. Computes the IMT-2020 composite pattern in MATLAB and in pycraf
%          for an identical configuration.
%       3. Reports max abs error, mean abs error, pass/fail at 1e-6 dB.
%
%   When pycraf is unavailable, the test is skipped cleanly and returns
%   results.skipped = true.

    results = struct('skipped', false, 'passed', false, ...
        'maxAbsErr_dB', NaN, 'meanAbsErr_dB', NaN, 'reason', '');

    if exist('pyenv', 'builtin') ~= 5 && exist('pyenv', 'file') ~= 2
        results.skipped = true;
        results.reason  = 'pyenv not available in this MATLAB version';
        fprintf('[test_against_pycraf] SKIP: %s\n', results.reason);
        return
    end

    try
        pe = pyenv;
    catch err
        results.skipped = true;
        results.reason  = sprintf('pyenv() failed: %s', err.message);
        fprintf('[test_against_pycraf] SKIP: %s\n', results.reason);
        return
    end

    % nudge Python startup if needed
    if isprop(pe, 'Status') && pe.Status == "NotLoaded"
        try
            py.list();
        catch err
            results.skipped = true;
            results.reason  = sprintf('Python failed to start: %s', err.message);
            fprintf('[test_against_pycraf] SKIP: %s\n', results.reason);
            return
        end
    end

    try
        np      = py.importlib.import_module('numpy');
        antenna = py.importlib.import_module('pycraf.antenna');
        cnv     = py.importlib.import_module('pycraf.conversions');
        u       = py.importlib.import_module('astropy.units');
    catch err
        results.skipped = true;
        results.reason  = sprintf('pycraf/astropy not available: %s', err.message);
        fprintf('[test_against_pycraf] SKIP: %s\n', results.reason);
        return
    end

    % --- shared configuration (M.2101 Annex 1 example values) -------------
    cfg = defaultCfg();

    azGrid = -90:5:90;
    elGrid = -45:5:45;
    [AZ, EL] = ndgrid(azGrid, elGrid);

    azim_i = 30;
    elev_i = -5;

    % --- MATLAB result ----------------------------------------------------
    A_M = imt2020_composite_pattern(AZ, EL, azim_i, elev_i, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, cfg.rho, cfg.k);

    % --- pycraf result via direct calls (no py.eval) ----------------------
    try
        AZ_np = np.asarray(AZ);
        EL_np = np.asarray(EL);

        A_P_q = antenna.imt2020_composite_pattern( ...
            AZ_np * u.deg, EL_np * u.deg, ...
            azim_i * u.deg, elev_i * u.deg, ...
            cfg.G_Emax * cnv.dB, cfg.A_m * cnv.dB, cfg.SLA_nu * cnv.dB, ...
            cfg.phi_3db * u.deg, cfg.theta_3db * u.deg, ...
            cfg.d_H * cnv.dimless, cfg.d_V * cnv.dimless, ...
            int32(cfg.N_H), int32(cfg.N_V), ...
            cfg.rho * cnv.dimless, pyargs('k', cfg.k) );

        A_P = double(A_P_q.value);
    catch err
        results.skipped = true;
        results.reason = sprintf('pycraf call failed: %s', err.message);
        fprintf('[test_against_pycraf] SKIP: %s\n', results.reason);
        return
    end

    diff = A_M - A_P;
    results.maxAbsErr_dB  = max(abs(diff(:)));
    results.meanAbsErr_dB = mean(abs(diff(:)));

    tol = 1e-6;
    results.passed = results.maxAbsErr_dB < tol;

    fprintf('[test_against_pycraf] grid: %dx%d, beam (az,el)=(%g,%g)\n', ...
        size(AZ,1), size(AZ,2), azim_i, elev_i);
    fprintf('   maxAbsErr  = %.3e dB\n', results.maxAbsErr_dB);
    fprintf('   meanAbsErr = %.3e dB\n', results.meanAbsErr_dB);
    fprintf('   tolerance  = %.0e dB -> %s\n', tol, ...
        ternary(results.passed, 'PASS', 'FAIL'));
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function cfg = defaultCfg()
    cfg.G_Emax    = 5;
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
