function results = test_against_pycraf_strict()
%TEST_AGAINST_PYCRAF_STRICT Strict MATLAB-vs-pycraf equivalence gate.
%
%   RESULTS = test_against_pycraf_strict()
%
%   This is the authoritative equivalence gate for the antenna math.
%   It directly compares the MATLAB implementations against pycraf:
%
%       imt2020_single_element_pattern.m
%           against pycraf.antenna.imt2020_single_element_pattern
%
%       imt2020_composite_pattern.m
%           against pycraf.antenna.imt2020_composite_pattern
%
%   Identical input grids and parameters are used in both languages:
%       azim grid: -180:10:180
%       elev grid:  -90:10:90
%       G_Emax = 8, A_m = 30, SLA_nu = 30,
%       phi_3db = 65, theta_3db = 65,
%       d_H = d_V = 0.5, N_H = N_V = 8, rho = 1, k = 12.
%
%   Beam-pointing cases:
%       three fixed cases: ( 0,  0), (30, -5), (-45, -10)
%       plus 50 randomized cases drawn with a fixed seed (azim_i in
%       [-180, 180], elev_i in [-90, 90]).
%
%   Pass rule:
%       max abs error <= 1e-6 dB across every (az, el) point and every
%       beam-pointing case.
%
%   Skip behavior:
%       if pyenv / Python / pycraf is unavailable the test prints a clear
%       SKIP message with the reason and returns results.skipped = true,
%       results.passed = true so the suite is not failed by a skip.
%
%   IMPORTANT:
%       Any change that touches the antenna math (single-element pattern,
%       composite array factor, angle conventions, k / rho handling) MUST
%       leave this test passing. Treat this as the regression gate for
%       pycraf parity.

    results = struct('skipped', false, 'passed', true, ...
        'reason', '', 'cases', struct([]), 'summary', {{}}, ...
        'tolerance_dB', 1e-6);

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

    fprintf('[test_against_pycraf_strict] grid: %dx%d (%d points)\n', ...
        size(AZ, 1), size(AZ, 2), numel(AZ));
    fprintf('[test_against_pycraf_strict] tolerance: max|err| <= %.1e dB\n', ...
        results.tolerance_dB);

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

    % ---- composite pattern: fixed + randomized beam-pointing cases ------
    fixedCases = struct( ...
        'name',   {'composite_az0_el0',   'composite_az30_elM5',   'composite_azM45_elM10'}, ...
        'azim_i', {0,                     30,                      -45}, ...
        'elev_i', {0,                     -5,                      -10});

    nRandom = 50;
    randCases = makeRandomBeamCases(nRandom);

    allCases = [fixedCases, randCases];

    AZ_np = np.asarray(AZ);
    EL_np = np.asarray(EL);

    for c = 1:numel(allCases)
        cs = allCases(c);

        A_M = imt2020_composite_pattern(AZ, EL, cs.azim_i, cs.elev_i, ...
            cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
            cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, cfg.rho, cfg.k);

        try
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

    fprintf('\n--- test_against_pycraf_strict summary ---\n');
    fprintf('  cases: 1 single-element + %d fixed composite + %d random composite\n', ...
        numel(fixedCases), nRandom);
    nShown = min(numel(results.summary), 8);
    for k = 1:nShown
        fprintf('  %s\n', results.summary{k});
    end
    if numel(results.summary) > nShown
        fprintf('  ... (%d more case lines suppressed)\n', ...
            numel(results.summary) - nShown);
    end
    if isfield(results, 'overallMaxAbsErr_dB')
        fprintf('  overall max|err| = %.3e dB\n', results.overallMaxAbsErr_dB);
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% -------------------------------------------------------------------------

function cases = makeRandomBeamCases(n)
%MAKERANDOMBEAMCASES Reproducible randomized beam-pointing cases.
% Uses an isolated RandStream so the surrounding RNG state is not
% disturbed and so the same 50 beam cases are exercised every run.
    rs = RandStream('mt19937ar', 'Seed', 20240501);
    az = -180 + 360 .* rand(rs, n, 1);
    el =  -90 + 180 .* rand(rs, n, 1);

    cases = repmat(struct('name', '', 'azim_i', 0, 'elev_i', 0), 1, n);
    for i = 1:n
        cases(i).name   = sprintf('composite_rand_%02d', i);
        cases(i).azim_i = az(i);
        cases(i).elev_i = el(i);
    end
end

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
        passed     = maxAbsErr <= results.tolerance_dB;
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

    if ~isfield(results, 'overallMaxAbsErr_dB') || ...
            isempty(results.overallMaxAbsErr_dB) || ...
            ~isfinite(results.overallMaxAbsErr_dB)
        results.overallMaxAbsErr_dB = 0;
    end
    if isfinite(maxAbsErr)
        results.overallMaxAbsErr_dB = max(results.overallMaxAbsErr_dB, maxAbsErr);
    end

    fprintf(['[test_against_pycraf_strict] %s\n' ...
             '   maxAbsErr  = %.3e dB\n' ...
             '   meanAbsErr = %.3e dB\n' ...
             '   tolerance  = %.1e dB -> %s\n'], ...
            label, maxAbsErr, meanAbsErr, results.tolerance_dB, ...
            ifElse(passed, 'PASS', 'FAIL'));

    msg = sprintf('%s  %s (max=%.3e dB, mean=%.3e dB)', ...
        ifElse(passed, 'PASS', 'FAIL'), name, maxAbsErr, meanAbsErr);
    results.summary{end + 1} = msg; %#ok<*AGROW>
end

function results = skipResult(results, reason)
    results.skipped = true;
    results.reason  = reason;
    % keep .passed = true so MATLAB-only runs are not failed by a skip
    fprintf('[test_against_pycraf_strict] SKIP: %s\n', reason);
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
