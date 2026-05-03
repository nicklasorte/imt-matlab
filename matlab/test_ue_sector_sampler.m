function results = test_ue_sector_sampler()
%TEST_UE_SECTOR_SAMPLER Unit tests for the ue_sector beam sampler.
%
%   RESULTS = test_ue_sector_sampler()
%
%   Covers:
%       U1. ue_sector returns azimuths inside [sector_az - W/2, sector_az + W/2]
%       U2. ue_sector returns elevations consistent with
%           atan2d(ue_height_m - bs_height_m, range_m)
%       U3. uniform_area produces a larger average range than uniform_radius
%           for the same min/max range
%       U4. fixed seed produces repeatable UE-driven beam samples
%       U5. existing sampler modes (uniform/sector/fixed/list) still pass
%       U6. run_imt_aas_eirp_monte_carlo accepts mode='ue_sector' without
%           changing downstream histogram/CDF/exporter behavior
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    % --- U1. azimuths within sector bounds -------------------------------
    sectorAz = 30;
    sectorW  = 90;
    sampler = struct('mode','ue_sector', ...
        'sector_az_deg',    sectorAz, ...
        'sector_width_deg', sectorW, ...
        'r_min_m', 10, 'r_max_m', 500, ...
        'bs_height_m', 25, 'ue_height_m', 1.5, ...
        'numBeams', 1);
    rng(123);
    nDraws = 5000;
    azs = zeros(nDraws,1);
    els = zeros(nDraws,1);
    rs  = zeros(nDraws,1);
    for i = 1:nDraws
        [a, e, dbg] = sample_aas_beam_direction(sampler);
        azs(i) = a;
        els(i) = e;
        rs(i)  = dbg.ueRange_m;
    end
    azLo = sectorAz - sectorW/2;
    azHi = sectorAz + sectorW/2;
    inBounds = all(azs >= azLo - 1e-9 & azs <= azHi + 1e-9);
    results = check(results, inBounds, ...
        sprintf(['U1: ue_sector azimuths within [%g, %g] (n=%d, ' ...
                 'observed [%g, %g])'], ...
            azLo, azHi, nDraws, min(azs), max(azs)));

    % --- U2. elevations consistent with atan2d(dh, r) --------------------
    expectedEl = atan2d(1.5 - 25, rs);
    elErr = max(abs(els - expectedEl));
    results = check(results, elErr < 1e-12, ...
        sprintf(['U2: elevations match atan2d(ue_height - bs_height, r) ' ...
                 '(max abs err = %.3e deg)'], elErr));

    % Also verify ue_sector returns negative elevations when UE is lower
    % than the BS (geometric sanity).
    results = check(results, all(els < 0), ...
        'U2b: UE below BS yields strictly negative beam elevations');

    % --- U3. uniform_area mean range > uniform_radius mean range ---------
    nMean = 20000;
    samplerArea = struct('mode','ue_sector', ...
        'sector_az_deg', 0, 'sector_width_deg', 120, ...
        'r_min_m', 10, 'r_max_m', 500, ...
        'bs_height_m', 25, 'ue_height_m', 1.5, ...
        'radial_distribution', 'uniform_area', 'numBeams', 1);
    samplerRad = samplerArea;
    samplerRad.radial_distribution = 'uniform_radius';

    rng(7);
    rArea = zeros(nMean,1);
    for i = 1:nMean
        [~,~,dbg] = sample_aas_beam_direction(samplerArea);
        rArea(i) = dbg.ueRange_m;
    end
    rng(7);
    rRad = zeros(nMean,1);
    for i = 1:nMean
        [~,~,dbg] = sample_aas_beam_direction(samplerRad);
        rRad(i) = dbg.ueRange_m;
    end
    mArea = mean(rArea);
    mRad  = mean(rRad);
    % Theoretical expectations for [10, 500]:
    %   uniform_radius mean -> (10+500)/2 = 255
    %   uniform_area   mean -> (2/3)*(R^3-r^3)/(R^2-r^2) ~ 333.4
    results = check(results, mArea > mRad + 50, ...
        sprintf(['U3: uniform_area mean range (%.1f m) > uniform_radius ' ...
                 'mean range (%.1f m) by > 50 m'], mArea, mRad));

    % --- U4. seed -> repeatable ------------------------------------------
    samplerRep = struct('mode','ue_sector', ...
        'sector_az_deg', 15, 'sector_width_deg', 90, ...
        'r_min_m', 10, 'r_max_m', 500, ...
        'bs_height_m', 25, 'ue_height_m', 1.5, ...
        'numBeams', 1);
    [a1,e1,d1] = sample_aas_beam_direction(samplerRep, 2024);
    [a2,e2,d2] = sample_aas_beam_direction(samplerRep, 2024);
    okRep = isequaln(a1,a2) && isequaln(e1,e2) && ...
            isequaln(d1.ueRange_m, d2.ueRange_m) && ...
            isequaln(d1.ueX_m,     d2.ueX_m) && ...
            isequaln(d1.ueY_m,     d2.ueY_m);
    results = check(results, okRep, ...
        'U4: ue_sector samples are reproducible with the same RNG seed');

    % --- U5. existing modes still pass -----------------------------------
    % uniform
    [a,e] = sample_aas_beam_direction(struct('mode','uniform', ...
        'azim_range',[-30 30],'elev_range',[-5 5],'numBeams', 4), 1);
    okU = isequal(size(a),[4 1]) && isequal(size(e),[4 1]) && ...
          all(a >= -30-1e-12 & a <= 30+1e-12) && ...
          all(e >= -5-1e-12  & e <= 5+1e-12);
    results = check(results, okU, 'U5a: uniform mode still works');

    % sector
    [a,e] = sample_aas_beam_direction(struct('mode','sector', ...
        'sector_az',0,'sector_az_width',120, ...
        'elev_range',[-10 0],'numBeams', 8), 1);
    okS = all(a >= -60-1e-12 & a <= 60+1e-12) && ...
          all(e >= -10-1e-12 & e <= 0+1e-12);
    results = check(results, okS, 'U5b: sector mode still works');

    % fixed
    [a,e] = sample_aas_beam_direction(struct('mode','fixed', ...
        'azim_i',12,'elev_i',-3,'numBeams',3));
    okF = isequal(a,[12;12;12]) && isequal(e,[-3;-3;-3]);
    results = check(results, okF, 'U5c: fixed mode still works');

    % list
    [a,e] = sample_aas_beam_direction(struct('mode','list', ...
        'azim_list',[-10 0 10],'elev_list',[-3 0 -2],'numBeams', 50), 1);
    okL = all(ismember(a,[-10 0 10])) && all(ismember(e,[-3 0 -2]));
    results = check(results, okL, 'U5d: list mode still works');

    % --- U6. MC engine accepts ue_sector ---------------------------------
    cfg = baseCfg();
    mcOpts = struct();
    mcOpts.numMc    = 40;
    mcOpts.azGrid   = -60:5:60;
    mcOpts.elGrid   = -30:5:30;
    mcOpts.binEdges = -50:1:120;
    mcOpts.seed     = 11;
    mcOpts.beamSampler = struct('mode','ue_sector', ...
        'sector_az_deg', 0, 'sector_width_deg', 120, ...
        'r_min_m', 10, 'r_max_m', 500, ...
        'bs_height_m', 25, 'ue_height_m', 1.5, ...
        'radial_distribution', 'uniform_area', 'numBeams', 1);

    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    % shape and bookkeeping invariants downstream of the sampler
    Naz = numel(mcOpts.azGrid);
    Nel = numel(mcOpts.elGrid);
    Nbin = numel(mcOpts.binEdges) - 1;
    okShape = isequal(size(stats.counts), [Naz Nel Nbin]) && ...
              stats.numMc == mcOpts.numMc;
    rowSum = sum(double(stats.counts), 3);
    okCounts = all(rowSum(:) == stats.numMc);
    results = check(results, okShape && okCounts, ...
        sprintf(['U6a: MC engine accepts ue_sector and produces a ' ...
                 'fully-populated histogram (numMc=%d)'], stats.numMc));

    % CDF monotonic non-decreasing on populated cells
    flat    = double(reshape(stats.counts, Naz*Nel, Nbin));
    rsum    = sum(flat, 2);
    cdf     = cumsum(flat, 2) ./ max(rsum, 1);
    pop     = rsum > 0;
    cdfPop  = cdf(pop, :);
    cdfDiff = diff(cdfPop, 1, 2);
    okCdf   = ~isempty(cdfPop) && all(cdfDiff(:) >= -1e-12);
    results = check(results, okCdf, ...
        'U6b: CDF monotonic non-decreasing under ue_sector sampling');

    % percentile maps + exceedance maps still work end-to-end
    pmaps = eirp_percentile_maps(stats, [5 50 95]);
    emaps = eirp_exceedance_maps(stats, [40 50 60]);
    okMaps = isequal(size(pmaps.values), [Naz Nel 3]) && ...
             isequal(size(emaps.prob),   [Naz Nel 3]);
    results = check(results, okMaps, ...
        'U6c: percentile / exceedance maps build cleanly under ue_sector');

    % exporter still produces the standard one-row-per-(az,el) shape
    T = export_eirp_percentile_table(stats);
    okExp = istable(T) && height(T) == Naz*Nel && width(T) == 2 + 101;
    results = check(results, okExp, ...
        sprintf(['U6d: export_eirp_percentile_table returns the standard ' ...
                 '%dx%d table under ue_sector'], Naz*Nel, 2 + 101));

    fprintf('\n--- test_ue_sector_sampler summary ---\n');
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

function cfg = baseCfg()
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
end
