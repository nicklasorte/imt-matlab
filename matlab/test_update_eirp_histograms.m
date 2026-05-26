function results = test_update_eirp_histograms()
%TEST_UPDATE_EIRP_HISTOGRAMS Focused unit tests for update_eirp_histograms.
%
%   RESULTS = test_update_eirp_histograms()
%
%   Covers:
%       1. After one update with a constant EIRP grid, every (az,el) cell
%          has exactly one count in the matching bin and numMc == 1.
%       2. sum_lin_mW = 10^(eirp/10) elementwise after one update.
%       3. min_dBm / max_dBm track per-cell running extremes across
%          successive updates.
%       4. Counts are uint32 and grow by exactly one per cell per draw.
%       5. EIRP below the first edge bin-bins into bin 1 (clipping).
%       6. EIRP at or above the last edge bin-bins into bin Nbin.
%       7. Total count across all bins per cell equals numMc after K
%          updates (mass conservation).
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_update_eirp_histograms ---\n');

    Naz = 5; Nel = 3;
    edges = 0:5:100;           % 20 bins, midpoints 2.5, 7.5, ..., 97.5
    Nbin = numel(edges) - 1;
    tol = 1e-12;

    stats = initStats(Naz, Nel, Nbin, edges);

    % ===== 1. one update with constant grid =====
    eirp1 = 27 .* ones(Naz, Nel);   % bin 6 (edges 25..30, midpoint 27.5)
    stats = update_eirp_histograms(stats, eirp1);
    assert(stats.numMc == 1, 'numMc must advance to 1');
    assert(all(stats.counts(:, :, 6) == 1, 'all'), ...
        'bin 6 must receive 1 count per (az,el) cell');
    otherBins = stats.counts;
    otherBins(:, :, 6) = 0;
    assert(all(otherBins(:) == 0), 'no other bins should be populated');
    fprintf('  [OK] one update -> single count per cell in the right bin\n');

    % ===== 2. linear-mW running sum =====
    expectedLin = 10.^(eirp1 ./ 10);
    assert(all(abs(stats.sum_lin_mW(:) - expectedLin(:)) < tol), ...
        'sum_lin_mW must equal 10^(eirp/10) after one draw');
    fprintf('  [OK] sum_lin_mW = 10^(eirp/10) elementwise\n');

    % ===== 3. min / max tracking across draws =====
    eirp2 = 42 .* ones(Naz, Nel);
    stats = update_eirp_histograms(stats, eirp2);
    eirp3 = 19 .* ones(Naz, Nel);
    stats = update_eirp_histograms(stats, eirp3);
    assert(all(stats.min_dBm(:) == 19), 'min_dBm must equal 19 after 3 draws');
    assert(all(stats.max_dBm(:) == 42), 'max_dBm must equal 42 after 3 draws');
    fprintf('  [OK] min_dBm / max_dBm track per-cell extremes\n');

    % ===== 4. counts are uint32 =====
    assert(isa(stats.counts, 'uint32'), 'counts must remain uint32');
    fprintf('  [OK] counts class preserved (uint32)\n');

    % ===== 5. EIRP below first edge -> bin 1 =====
    statsLow = initStats(Naz, Nel, Nbin, edges);
    eirpLow = (edges(1) - 10) .* ones(Naz, Nel);
    statsLow = update_eirp_histograms(statsLow, eirpLow);
    assert(all(statsLow.counts(:, :, 1) == 1, 'all'), ...
        'below-first-edge EIRP must clip into bin 1');
    fprintf('  [OK] EIRP below first edge -> bin 1\n');

    % ===== 6. EIRP at/above last edge -> bin Nbin =====
    statsHi = initStats(Naz, Nel, Nbin, edges);
    eirpHi = (edges(end) + 10) .* ones(Naz, Nel);
    statsHi = update_eirp_histograms(statsHi, eirpHi);
    assert(all(statsHi.counts(:, :, Nbin) == 1, 'all'), ...
        'at/above-last-edge EIRP must clip into bin Nbin');
    fprintf('  [OK] EIRP >= last edge -> bin Nbin\n');

    % ===== 7. mass conservation across K updates =====
    K = 7;
    statsK = initStats(Naz, Nel, Nbin, edges);
    rng(11);
    for k = 1:K
        e = 5 + 80 .* rand(Naz, Nel);  % keep inside edges
        statsK = update_eirp_histograms(statsK, e);
    end
    perCellTotal = sum(statsK.counts, 3);
    assert(all(double(perCellTotal(:)) == K), ...
        'sum over bins per cell must equal numMc=%d, got %s', ...
        K, mat2str(unique(double(perCellTotal(:))).'));
    assert(statsK.numMc == K, 'numMc must equal K');
    fprintf('  [OK] sum(counts, 3) per cell == numMc after %d updates\n', K);

    results.passed = true;
    fprintf('--- test_update_eirp_histograms PASSED ---\n');
end

% =====================================================================

function s = initStats(Naz, Nel, Nbin, edges)
    s = struct();
    s.binEdges   = edges;
    s.counts     = zeros(Naz, Nel, Nbin, 'uint32');
    s.sum_lin_mW = zeros(Naz, Nel);
    s.min_dBm    =  inf(Naz, Nel);
    s.max_dBm    = -inf(Naz, Nel);
    s.numMc      = 0;
end
