function results = test_aas_monte_carlo_eirp()
%TEST_AAS_MONTE_CARLO_EIRP Unit tests for the MATLAB AAS / EIRP suite.
%
%   RESULTS = test_aas_monte_carlo_eirp()
%
%   Runs a battery of MATLAB-only checks:
%       1. Boresight gain ~ 10*log10(N_H*N_V) + G_Emax
%       2. Off-axis attenuation (gain < boresight)
%       3. Azimuth symmetry around boresight (rho = 1)
%       4. Fixed-beam repeatability (deterministic seed)
%       5. Histogram counts sum to numMc per cell
%       6. Percentile values are monotonic
%       7. CDF reaches 1 at last bin
%       8. Exceedance probability is non-increasing in threshold
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    cfg = struct();
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
    cfg.txPower_dBm   = 40;
    cfg.feederLoss_dB = 3;

    % --- 1. Boresight gain ----------------------------------------------
    boresight = imt2020_composite_pattern(0, 0, 0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, 12);
    expected = cfg.G_Emax + 10*log10(cfg.N_H * cfg.N_V);
    results = check(results, ...
        abs(boresight - expected) < 1e-9, ...
        sprintf('boresight gain: got %.6f dBi, expected %.6f dBi', ...
            boresight, expected));

    % --- 2. Off-axis attenuation ----------------------------------------
    offAxis = imt2020_composite_pattern(45, 0, 0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, 12);
    results = check(results, offAxis < boresight - 5, ...
        sprintf('off-axis @ az=45: %.2f dBi < boresight - 5 = %.2f', ...
            offAxis, boresight - 5));

    % --- 3. Azimuth symmetry (boresight aim, rho=1) ---------------------
    % Stay off ±90 deg to avoid the array-factor null where |G| -> -Inf
    % (mathematically correct but produces Inf-Inf=NaN under subtraction).
    azGrid = -85:1:85;
    Glr = imt2020_composite_pattern(azGrid, zeros(size(azGrid)), 0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, 12);
    finiteMask = isfinite(Glr) & isfinite(fliplr(Glr));
    diffSym = abs(Glr - fliplr(Glr));
    sym = max(diffSym(finiteMask));
    results = check(results, sym < 1e-9, ...
        sprintf('azimuth symmetry: max |G(az) - G(-az)| = %.3e', sym));

    % --- 4. Fixed-beam repeatability ------------------------------------
    mcOpts = baseMcOpts();
    mcOpts.numMc = 30;
    mcOpts.seed  = 42;
    mcOpts.beamSampler = struct('mode','fixed','azim_i',10,'elev_i',-3, ...
                                'numBeams', 1);
    s1 = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
    s2 = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
    eqMin = isequaln(s1.min_dBm, s2.min_dBm);
    eqMax = isequaln(s1.max_dBm, s2.max_dBm);
    eqHis = isequal(s1.counts, s2.counts);
    results = check(results, eqMin && eqMax && eqHis, ...
        'fixed-beam: two runs with identical seed produce identical stats');

    % --- 5. Histogram counts sum to numMc -------------------------------
    rowSum = sum(double(s1.counts), 3);
    results = check(results, all(rowSum(:) == s1.numMc), ...
        sprintf('histogram counts sum to numMc=%d at every cell', s1.numMc));

    % --- 6. Percentile values are monotonic -----------------------------
    mcOpts = baseMcOpts();
    mcOpts.numMc = 200;
    mcOpts.seed  = 7;
    mcOpts.beamSampler = struct('mode','uniform', ...
        'azim_range', [-30 30], 'elev_range', [-10 0], 'numBeams', 1);
    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
    p = [1 5 10 50 90 95 99];
    pmaps = eirp_percentile_maps(stats, p);
    % monotonicity along the percentile axis at every cell with data
    diffs = diff(pmaps.values, 1, 3);
    valid = all(~isnan(pmaps.values), 3);
    monotonic = all(diffs(repmat(valid,[1 1 numel(p)-1])) >= -1e-9);
    results = check(results, monotonic, ...
        'percentile maps are monotonically non-decreasing in p');

    % --- 7. CDF reaches 1 at last bin -----------------------------------
    [cdf, ~] = eirp_cdf_at_angle(stats, 0, 0);
    results = check(results, abs(cdf(end) - 1) < 1e-12, ...
        sprintf('CDF endpoint at (0,0) = %.6f', cdf(end)));

    % --- 8. Exceedance probability decreases ----------------------------
    thr = -20:5:60;
    emaps = eirp_exceedance_maps(stats, thr);
    % at the boresight cell (0,0)
    [~, iAz] = min(abs(stats.azGrid -  0));
    [~, iEl] = min(abs(stats.elGrid -  0));
    pBoresight = squeeze(emaps.prob(iAz, iEl, :));
    nonIncreasing = all(diff(pBoresight) <= 1e-12);
    results = check(results, nonIncreasing, ...
        'exceedance probability is non-increasing in threshold @ (0,0)');

    fprintf('\n--- test_aas_monte_carlo_eirp summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
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

function mc = baseMcOpts()
    mc = struct();
    mc.numMc    = 50;
    mc.azGrid   = -60:5:60;
    mc.elGrid   = -30:5:30;
    mc.binEdges = -50:1:120;
    mc.beamSampler = struct('mode','uniform', ...
        'azim_range', [-30 30], 'elev_range', [-10 0], 'numBeams', 1);
end
