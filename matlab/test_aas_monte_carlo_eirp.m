function results = test_aas_monte_carlo_eirp()
%TEST_AAS_MONTE_CARLO_EIRP Unit tests for the MATLAB AAS / EIRP suite.
%
%   RESULTS = test_aas_monte_carlo_eirp()
%
%   Two groups of MATLAB-only checks are run:
%
%   Antenna sanity:
%       A1. single-element boresight equals G_Emax
%       A2. single-element off-axis gain is lower than boresight
%       A3. composite pattern returns finite values over an az/el grid
%       A4. composite gain changes when beam pointing changes
%       A5. rho = 0 collapses A_A toward the single-element pattern
%       A6. rho = 1 gives the full coherent composite result
%           (boresight = G_Emax + 10*log10(N_H * N_V))
%       A7. composite is azimuth-symmetric around boresight (rho = 1)
%
%   Monte Carlo statistics:
%       M1. fixed-beam mode is repeatable across two runs (same seed)
%       M2. histogram counts sum to numMc at every (az,el) cell
%       M3. CDF is monotonic non-decreasing at every (az,el) cell with
%           samples
%       M4. final CDF value equals 1 wherever samples exist
%       M5. mean EIRP is computed by averaging linear mW (not dBm)
%       M6. percentile maps are monotonic non-decreasing in p
%       M7. exceedance probability is non-increasing in threshold
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

    % ====================================================================
    % Antenna sanity
    % ====================================================================

    % --- A1. single-element boresight = G_Emax --------------------------
    se_boresight = imt2020_single_element_pattern(0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, cfg.k);
    results = check(results, ...
        abs(se_boresight - cfg.G_Emax) < 1e-12, ...
        sprintf('single-element boresight: got %.6f dBi, expected G_Emax = %.6f dBi', ...
            se_boresight, cfg.G_Emax));

    % --- A2. single-element off-axis gain is lower than boresight --------
    azOff = [-90, -45, -15, 15, 45, 90];
    elOff = [-30, -10,  10, 30,  0,  0];
    se_off = imt2020_single_element_pattern(azOff, elOff, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, cfg.k);
    results = check(results, all(se_off < se_boresight - 1e-9), ...
        sprintf(['single-element off-axis gain < boresight at all sample ' ...
                 'directions (max off-axis = %.3f dBi, boresight = %.3f dBi)'], ...
            max(se_off), se_boresight));

    % --- A3. composite returns finite values across an az/el grid --------
    % Use a near-boresight grid (az=-20..20, el=-10..10) for finite A3/A4
    % checks. Wider grids legitimately contain AF nulls (10*log10(0) =
    % -Inf), which a separate weaker mask-based check exercises below.
    azGridSafe = -20:1:20;
    elGridSafe = -10:1:10;
    [AZs, ELs] = ndgrid(azGridSafe, elGridSafe);
    Ad = imt2020_composite_pattern(AZs, ELs, 0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, cfg.k);
    results = check(results, all(isfinite(Ad(:))), ...
        sprintf(['composite pattern is finite over %dx%d near-boresight ' ...
                 'grid (any non-finite=%d)'], ...
            size(AZs,1), size(AZs,2), sum(~isfinite(Ad(:)))));

    % --- A4. composite gain changes when beam pointing changes ----------
    % Use the same near-boresight grid and two beam pointings well within
    % the main-lobe region to keep both surfaces finite.
    Ab1 = imt2020_composite_pattern(AZs, ELs,   0,  0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, cfg.k);
    Ab2 = imt2020_composite_pattern(AZs, ELs,  10, -3, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, cfg.k);
    diffBeams = Ab1 - Ab2;
    bothFinite = isfinite(Ab1) & isfinite(Ab2);
    if any(bothFinite(:))
        maxDelta = max(abs(diffBeams(bothFinite)));
    else
        maxDelta = 0;
    end
    results = check(results, all(bothFinite(:)) && maxDelta > 1.0, ...
        sprintf(['composite gain changes with beam pointing ' ...
                 '(max |A(0,0) - A(10,-3)| = %.3f dB > 1.0 dB, both finite=%d)'], ...
            maxDelta, all(bothFinite(:))));

    % --- A5. rho = 0 collapses to the single-element pattern ------------
    % Use a wider grid here: A_E has no array factor, A_A with rho=0 also
    % drops the array factor (10*log10(1+0) = 0), so finiteness on the
    % wider grid is fine.
    azGridDense = -85:5:85;
    elGridDense = -85:5:85;
    [AZd, ELd] = ndgrid(azGridDense, elGridDense);
    A_E_wide = imt2020_single_element_pattern(AZd, ELd, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, cfg.k);
    A_rho0 = imt2020_composite_pattern(AZd, ELd, 30, -5, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 0, cfg.k);
    rho0Err = max(abs(A_rho0(:) - A_E_wide(:)));
    results = check(results, rho0Err < 1e-12, ...
        sprintf('rho = 0: |A_A - A_E| max = %.3e dB (expected ~0)', rho0Err));

    % --- A6. rho = 1 boresight equals G_Emax + 10*log10(N_H*N_V) --------
    boresight = imt2020_composite_pattern(0, 0, 0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, cfg.k);
    expected = cfg.G_Emax + 10*log10(cfg.N_H * cfg.N_V);
    results = check(results, ...
        abs(boresight - expected) < 1e-9, ...
        sprintf(['rho = 1 boresight: got %.6f dBi, expected %.6f dBi ' ...
                 '(G_Emax + 10*log10(N_H*N_V))'], ...
            boresight, expected));

    % --- A7. azimuth symmetry around boresight (rho = 1) ----------------
    % Stay off ±90 deg to avoid the array-factor null where |G| -> -Inf.
    azGrid = -85:1:85;
    Glr = imt2020_composite_pattern(azGrid, zeros(size(azGrid)), 0, 0, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, 1, cfg.k);
    finiteMask = isfinite(Glr) & isfinite(fliplr(Glr));
    diffSym = abs(Glr - fliplr(Glr));
    sym = max(diffSym(finiteMask));
    results = check(results, sym < 1e-9, ...
        sprintf('azimuth symmetry: max |G(az) - G(-az)| = %.3e', sym));

    % ====================================================================
    % Monte Carlo statistics
    % ====================================================================

    % --- M1. fixed-beam repeatability ------------------------------------
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

    % --- M2. histogram counts sum to numMc at every cell -----------------
    rowSum = sum(double(s1.counts), 3);
    results = check(results, all(rowSum(:) == s1.numMc), ...
        sprintf('histogram counts sum to numMc=%d at every cell', s1.numMc));

    % Build a richer stats sample for M3..M7 with several distinct beam
    % directions so most cells receive samples.
    mcOpts = baseMcOpts();
    mcOpts.numMc = 200;
    mcOpts.seed  = 7;
    mcOpts.beamSampler = struct('mode','uniform', ...
        'azim_range', [-30 30], 'elev_range', [-10 0], 'numBeams', 1);
    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    % --- M3. CDF monotonic non-decreasing at every populated cell --------
    [Naz, Nel, Nbin] = size(stats.counts);
    flat   = double(reshape(stats.counts, Naz * Nel, Nbin));
    rowSum = sum(flat, 2);
    cdf    = cumsum(flat, 2) ./ max(rowSum, 1);
    populated = rowSum > 0;
    cdfPop = cdf(populated, :);
    cdfDiffs = diff(cdfPop, 1, 2);
    results = check(results, ...
        ~isempty(cdfPop) && all(cdfDiffs(:) >= -1e-12), ...
        sprintf(['CDF monotonic non-decreasing at every populated cell ' ...
                 '(populated cells = %d)'], sum(populated)));

    % --- M4. final CDF = 1 wherever samples exist ------------------------
    finalCdf = cdf(populated, end);
    results = check(results, ...
        ~isempty(finalCdf) && max(abs(finalCdf - 1)) < 1e-12, ...
        sprintf('final CDF value = 1 at every populated cell (max |cdf_end - 1| = %.3e)', ...
            max(abs(finalCdf - 1))));

    % --- M5. mean EIRP averages linear mW, not dBm -----------------------
    % Drive an MC run with a deterministic cyclic list of beam pointings,
    % then independently recompute the EIRP cube from imt_aas_bs_eirp and
    % verify stats.mean_lin_mW equals the *linear-mW* average across draws
    % (not the dBm average). For per-cell variation big enough to make the
    % distinction visible we also require the linear-mW dBm-equivalent to
    % differ from the naive dBm average by >0.01 dB at >=1 cell.
    listOpts = baseMcOpts();
    listOpts.numMc       = 6;
    listOpts.seed        = 99;
    % Use a near-boresight grid + small beam offsets so the composite
    % pattern stays well clear of array-factor nulls; this keeps the
    % independent reference cube finite cell-for-cell, which the per-cell
    % comparison below requires.
    listOpts.azGrid      = -20:2:20;
    listOpts.elGrid      = -10:2:10;
    listOpts.beamSampler = struct('mode', 'fixed', ...
        'azim_i', 0, 'elev_i', 0, 'numBeams', 1);
    azBeams = [-10, -5, 0, 5, 10,  3];
    elBeams = [ -4, -2, 0, -1, -3, -2];

    % Recreate the streaming aggregator manually to mirror what the MC
    % engine does, but with a deterministic beam list (sample_aas_beam
    % does not support a sequential list; this gives us full control).
    azG = listOpts.azGrid; elG = listOpts.elGrid;
    [AZm, ELm] = ndgrid(azG, elG);
    eirpStack = zeros([size(AZm), numel(azBeams)]);
    for b = 1:numel(azBeams)
        eirpStack(:,:,b) = imt_aas_bs_eirp(AZm, ELm, azBeams(b), elBeams(b), cfg);
    end
    refMean_mW_indep  = mean(10.^(eirpStack ./ 10), 3);
    naiveMean_dBm     = mean(eirpStack, 3);
    refMean_dBm_indep = 10 .* log10(refMean_mW_indep);

    % Drive the MC engine over the same beam list using a fixed sampler
    % swapped each iteration. We use the public driver for one draw at a
    % time so we exactly mirror the streaming code path.
    streamingStats = [];
    for b = 1:numel(azBeams)
        oneOpts = listOpts;
        oneOpts.numMc       = 1;
        oneOpts.beamSampler = struct('mode', 'fixed', ...
            'azim_i', azBeams(b), 'elev_i', elBeams(b), 'numBeams', 1);
        sB = run_imt_aas_eirp_monte_carlo(cfg, oneOpts);
        if isempty(streamingStats)
            streamingStats = sB;
        else
            streamingStats.counts     = streamingStats.counts     + sB.counts;
            streamingStats.sum_lin_mW = streamingStats.sum_lin_mW + sB.sum_lin_mW;
            streamingStats.min_dBm    = min(streamingStats.min_dBm, sB.min_dBm);
            streamingStats.max_dBm    = max(streamingStats.max_dBm, sB.max_dBm);
            streamingStats.numMc      = streamingStats.numMc      + sB.numMc;
        end
    end
    streamingMean_mW  = streamingStats.sum_lin_mW ./ streamingStats.numMc;
    streamingMean_dBm = 10 .* log10(streamingMean_mW);

    errLin = max(abs(streamingMean_mW(:)  - refMean_mW_indep(:)));
    errLog = max(abs(streamingMean_dBm(:) - refMean_dBm_indep(:)));
    gap    = max(abs(refMean_dBm_indep(:) - naiveMean_dBm(:)));

    okLinearAvg   = errLin < 1e-9 && errLog < 1e-9;
    okDistinctEst = gap > 1e-2;     % linear-mW vs naive dBm averaging
                                    % disagree somewhere in the grid
    results = check(results, okLinearAvg && okDistinctEst, ...
        sprintf(['mean EIRP averaged in linear mW: max |stream - ref| ' ...
                 'lin=%.2e mW, log=%.2e dB; max |linear-mW dB - dBm ' ...
                 'mean| = %.3f dB (>1e-2 confirms distinction)'], ...
            errLin, errLog, gap));

    % --- M6. percentile maps monotonic in p ------------------------------
    p = [1 5 10 50 90 95 99];
    pmaps = eirp_percentile_maps(stats, p);
    diffs = diff(pmaps.values, 1, 3);
    valid = all(~isnan(pmaps.values), 3);
    monotonic = all(diffs(repmat(valid,[1 1 numel(p)-1])) >= -1e-9);
    results = check(results, monotonic, ...
        'percentile maps are monotonically non-decreasing in p');

    % --- M7. exceedance probability decreases in threshold ---------------
    thr = -20:5:60;
    emaps = eirp_exceedance_maps(stats, thr);
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
