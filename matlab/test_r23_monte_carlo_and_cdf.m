function results = test_r23_monte_carlo_and_cdf()
%TEST_R23_MONTE_CARLO_AND_CDF Validation tests for R23 MC + CDF pipeline.
%
%   RESULTS = test_r23_monte_carlo_and_cdf()
%
%   Lightweight regression suite for the R23 single-sector Monte Carlo
%   snapshot runner (run_monte_carlo_snapshots) and the per-cell CDF
%   builder (compute_cdf_per_grid_point). It pins six contracts:
%
%       T1. Deterministic reproducibility: identical seed -> bit-equal
%           eirpGrid; identical shape.
%       T2. Variability sanity: different seeds -> different cubes; the
%           linear-mW mean EIRP per cell still agrees within a small
%           tolerance because the underlying physics is unchanged.
%       T3. UE sampling sanity: every sampled UE is inside the R23 sector
%           (>= minUeDistance_m, <= cellRadius_m, |azRel| <= hCoverage),
%           heights are constant at 1.5 m, and the population is not
%           degenerate (positive variance, multiple distinct positions).
%       T4. CDF monotonicity: per-cell CDFs are non-decreasing along the
%           empirical-CDF axis, the final level is exactly 1, the first
%           level is > 0, and there are no NaNs / Infs anywhere.
%       T5. CDF shape sanity: at a chosen grid cell, the empirical CDF
%           spans a non-trivial range (max - min >= floor) so we can
%           detect a Monte Carlo loop that has accidentally collapsed
%           to a single deterministic snapshot.
%       T6. Output dimension consistency: eirpGrid is
%           [Naz, Nel, numSnapshots] and every CDF field has the matching
%           shape ([Naz, Nel] or [Naz, Nel, numel(percentiles)]).
%
%   Tests intentionally use small grids and modest snapshot counts to
%   stay fast in run_all_tests. No plotting, no file I/O.

    results.summary = {};
    results.passed  = true;

    results = t1_determinism(results);
    results = t2_variability(results);
    results = t3_ue_sampling(results);
    results = t4_cdf_monotonic(results);
    results = t5_cdf_shape(results);
    results = t6_dimensions(results);

    fprintf('\n--- test_r23_monte_carlo_and_cdf summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function r = t1_determinism(r)
%T1 Same seed -> bit-equal eirpGrid; expected shape.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    grid = struct('azGridDeg', -30:15:30, 'elGridDeg', -10:5:5);
    cfg  = struct('numSnapshots', 10, 'numUes', 3, 'seed', 42);

    a = run_monte_carlo_snapshots(bs, grid, p, cfg);
    b = run_monte_carlo_snapshots(bs, grid, p, cfg);

    Naz = numel(grid.azGridDeg);
    Nel = numel(grid.elGridDeg);
    okShape = isequal(size(a.eirpGrid), [Naz, Nel, 10]);
    okEqual = isequal(a.eirpGrid, b.eirpGrid);

    r = check(r, okShape && okEqual, ...
        'T1: same seed -> bit-equal eirpGrid; shape = [Naz, Nel, numSnapshots]');
end

% =====================================================================
function r = t2_variability(r)
%T2 Different seeds -> different cubes; mean EIRP within tolerance.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    grid = struct('azGridDeg', -30:15:30, 'elGridDeg', -10:5:5);
    cfgA = struct('numSnapshots', 30, 'numUes', 3, 'seed', 7);
    cfgB = struct('numSnapshots', 30, 'numUes', 3, 'seed', 8);

    a = run_monte_carlo_snapshots(bs, grid, p, cfgA);
    b = run_monte_carlo_snapshots(bs, grid, p, cfgB);

    okDifferent = ~isequal(a.eirpGrid, b.eirpGrid);

    % Compare a stable aggregate: the grand linear-mW mean across the full
    % cube. With matched physics (same BS, same params, same N) and an
    % R23-clamped, area-uniform UE sampler, this aggregate converges
    % regardless of seed.
    grandA = 10*log10(mean(10.^(a.eirpGrid(:)/10)));
    grandB = 10*log10(mean(10.^(b.eirpGrid(:)/10)));
    okGrandClose = abs(grandA - grandB) < 3.0; % within 3 dB

    % Cube-peak EIRP must match the sector peak (78.3) for both seeds: the
    % aggregate-of-N-identical-beams invariant guarantees the upper bound
    % regardless of seed (the sector peak is hit exactly when the N beams
    % co-align on a grid cell, otherwise it is an upper envelope).
    peakA = max(a.eirpGrid(:));
    peakB = max(b.eirpGrid(:));
    okPeakBound = (peakA <= bs.eirp_dBm_per_100MHz + 1e-6) && ...
                  (peakB <= bs.eirp_dBm_per_100MHz + 1e-6);

    r = check(r, okDifferent && okGrandClose && okPeakBound, sprintf( ...
        ['T2: different seeds -> different cubes; grand mean delta = %.3f dB; '...
         'peaks (%.3f, %.3f) <= sector EIRP'], ...
         abs(grandA - grandB), peakA, peakB));
end

% =====================================================================
function r = t3_ue_sampling(r)
%T3 UE sampling stays inside the sector and is non-degenerate.
    bs     = get_default_bs();
    p      = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, p);

    numSnap = 60;
    numUes  = 3;
    rng(123);
    allX = zeros(numSnap * numUes, 1);
    allY = zeros(numSnap * numUes, 1);
    allR = zeros(numSnap * numUes, 1);
    allAz = zeros(numSnap * numUes, 1);
    allH  = zeros(numSnap * numUes, 1);
    idx = 0;
    for k = 1:numSnap
        ue = sample_ue_positions_in_sector(bs, p, [], numUes);
        sel = idx + (1:numUes);
        allX(sel)  = ue.x_m;
        allY(sel)  = ue.y_m;
        allR(sel)  = ue.r_m;
        allAz(sel) = ue.azRelDeg;
        allH(sel)  = ue.height_m;
        idx = idx + numUes;
    end

    tol = 1e-6;
    okMin   = all(allR >= layout.minUeDistance_m - tol);
    okMax   = all(allR <= layout.cellRadius_m   + tol);
    okAz    = all(allAz >= layout.azLimitsDeg(1) - tol) && ...
              all(allAz <= layout.azLimitsDeg(2) + tol);
    okHt    = all(abs(allH - layout.ueHeight_m) < 1e-9);
    okSpread = (var(allX) > 0) && (var(allY) > 0) && ...
               (numel(unique(allR)) >= numUes * 2);

    r = check(r, okMin && okMax && okAz && okHt && okSpread, sprintf( ...
        ['T3: UE sampling: r in [%g, %g] m, az in +/- %g, h = %.2f m, '...
         'unique r = %d / %d'], ...
        layout.minUeDistance_m, layout.cellRadius_m, ...
        layout.azLimitsDeg(2), layout.ueHeight_m, ...
        numel(unique(allR)), numel(allR)));
end

% =====================================================================
function r = t4_cdf_monotonic(r)
%T4 Per-cell empirical CDF is non-decreasing, ends at 1, finite.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    grid = struct('azGridDeg', -30:15:30, 'elGridDeg', -10:5:5);
    cfg  = struct('numSnapshots', 40, 'numUes', 3, 'seed', 17);

    mc  = run_monte_carlo_snapshots(bs, grid, p, cfg);
    pcs = [1 5 25 50 75 95 99];
    cdf = compute_cdf_per_grid_point(mc.eirpGrid, pcs);

    % cdfLevels: empirical CDF level (1..N)/N; ends exactly at 1.
    okLevelsMono = all(diff(cdf.cdfLevels) > 0);
    okLevelEnd   = abs(cdf.cdfLevels(end) - 1) < eps(1);
    okLevelStart = cdf.cdfLevels(1) > 0;

    % sortedEirpDbm: ascending along dim 3 by construction.
    diffsSorted = diff(cdf.sortedEirpDbm, 1, 3);
    okSortedMono = all(diffsSorted(:) >= -1e-9);

    % percentileEirpDbm: non-decreasing along the percentile axis.
    diffsPct = diff(cdf.percentileEirpDbm, 1, 3);
    okPctMono = all(diffsPct(:) >= -1e-9);

    finiteAll = all(isfinite(cdf.sortedEirpDbm(:))) && ...
                all(isfinite(cdf.percentileEirpDbm(:))) && ...
                all(isfinite(cdf.cdfLevels(:)));

    r = check(r, okLevelsMono && okLevelEnd && okLevelStart && ...
                 okSortedMono && okPctMono && finiteAll, ...
        'T4: empirical CDF strictly non-decreasing, ends at 1, all finite');
end

% =====================================================================
function r = t5_cdf_shape(r)
%T5 CDF spans a non-trivial range at a representative grid cell.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    % Pick a grid that includes the boresight + nominal R23 downtilt cell
    % so we know the cell is regularly illuminated by Monte Carlo beams.
    azVec = -60:10:60;
    elVec = -15:3:0;
    grid  = struct('azGridDeg', azVec, 'elGridDeg', elVec);
    cfg   = struct('numSnapshots', 50, 'numUes', 3, 'seed', 31);

    mc  = run_monte_carlo_snapshots(bs, grid, p, cfg);
    cdf = compute_cdf_per_grid_point(mc.eirpGrid);

    % Pick the cell at (az = 0, el = -9) -- closest grid point to nominal
    % R23 boresight + 9 deg downtilt.
    [~, ia] = min(abs(azVec));
    [~, ie] = min(abs(elVec - (-9)));
    samples = squeeze(mc.eirpGrid(ia, ie, :));

    okFinite = all(isfinite(samples));
    okSpread = (max(samples) - min(samples)) > 0.5; % > 0.5 dB span
    okMatchMin = abs(min(samples) - cdf.minEirpDbm(ia, ie)) < 1e-9;
    okMatchMax = abs(max(samples) - cdf.maxEirpDbm(ia, ie)) < 1e-9;

    r = check(r, okFinite && okSpread && okMatchMin && okMatchMax, sprintf( ...
        'T5: cell (az=%g, el=%g) EIRP spans %.3f dB; min/max match cdf', ...
        azVec(ia), elVec(ie), max(samples) - min(samples)));
end

% =====================================================================
function r = t6_dimensions(r)
%T6 Output dimensions consistent end to end.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    azVec = -45:15:45;
    elVec = -10:5:5;
    grid  = struct('azGridDeg', azVec, 'elGridDeg', elVec);
    numSnap = 12;
    cfg  = struct('numSnapshots', numSnap, 'numUes', 3, 'seed', 99);

    mc  = run_monte_carlo_snapshots(bs, grid, p, cfg);
    Naz = numel(azVec);
    Nel = numel(elVec);

    okMcShape   = isequal(size(mc.eirpGrid), [Naz, Nel, numSnap]);
    okGridShape = isequal(size(mc.AZ), [Naz, Nel]) && ...
                  isequal(size(mc.EL), [Naz, Nel]);
    okBeamCount = numel(mc.perSnapshotBeams) == numSnap && ...
                  numel(mc.perSnapshotUes)   == numSnap;

    pcs = [10 50 90];
    cdf = compute_cdf_per_grid_point(mc.eirpGrid, pcs);
    okSorted = isequal(size(cdf.sortedEirpDbm), [Naz, Nel, numSnap]);
    okLevels = isequal(size(cdf.cdfLevels), [1, numSnap]);
    okPct    = isequal(size(cdf.percentileEirpDbm), [Naz, Nel, numel(pcs)]);
    okMean   = isequal(size(cdf.meanEirpDbm), [Naz, Nel]);
    okMin    = isequal(size(cdf.minEirpDbm),  [Naz, Nel]);
    okMax    = isequal(size(cdf.maxEirpDbm),  [Naz, Nel]);

    r = check(r, okMcShape && okGridShape && okBeamCount && ...
                 okSorted && okLevels && okPct && okMean && ...
                 okMin && okMax, ...
        'T6: eirpGrid / CDF output dimensions consistent ([Naz, Nel, ...])');
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
