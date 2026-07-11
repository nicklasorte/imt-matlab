function results = test_eirp_percentile_maps()
%TEST_EIRP_PERCENTILE_MAPS Focused unit tests for eirp_percentile_maps.
%
%   RESULTS = test_eirp_percentile_maps()
%
%   Covers:
%       1. Default percentile vector [1 5 10 50 90 95 99] is used when
%          PERCENTILES is omitted.
%       2. pmaps.values has shape [Naz, Nel, P].
%       3. azGrid, elGrid, binEdges, percentiles are echoed.
%       4. For a 1-cell stats with all weight in a single bin, every
%          percentile in (0, 100] equals that bin's midpoint.
%       5. Percentiles are monotonic non-decreasing across the P axis.
%       6. Cells with zero counts produce NaN at every percentile.
%       7. Bit-identical output across consecutive calls (determinism).
%       8. The 0th percentile returns the lowest occupied bin.
%       9. Invalid percentile values are rejected with a specific error.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_eirp_percentile_maps ---\n');

    % ===== build a small deterministic stats struct =====
    rng(2024);
    az = -10:5:10;   % Naz = 5
    el = -5:5:5;     % Nel = 3
    edges = 0:1:50;  % 50 bins
    Naz = numel(az); Nel = numel(el); Nbin = numel(edges) - 1;
    counts = zeros(Naz, Nel, Nbin, 'uint32');
    for iA = 1:Naz
        for iE = 1:Nel
            mu    = 25 + 0.5*iA - 0.3*iE;
            sigma = 4;
            samples = mu + sigma * randn(400, 1);
            samples = min(max(samples, edges(1) + 0.01), edges(end) - 0.01);
            h = histcounts(samples, edges);
            counts(iA, iE, :) = uint32(h);
        end
    end
    stats = struct('azGrid', az, 'elGrid', el, ...
                   'binEdges', edges, 'counts', counts);

    % ===== 1. default percentiles =====
    pm = eirp_percentile_maps(stats);
    assert(isequal(pm.percentiles, [1 5 10 50 90 95 99]), ...
        'default percentile vector mismatch');
    fprintf('  [OK] default percentiles [1 5 10 50 90 95 99]\n');

    % ===== 2. shape =====
    assert(isequal(size(pm.values), [Naz, Nel, numel(pm.percentiles)]), ...
        'pmaps.values shape mismatch');
    fprintf('  [OK] values shape = [Naz, Nel, P] = [%d %d %d]\n', ...
        Naz, Nel, numel(pm.percentiles));

    % ===== 3. echoed fields =====
    assert(isequal(pm.azGrid, az), 'azGrid echoed');
    assert(isequal(pm.elGrid, el), 'elGrid echoed');
    assert(isequal(pm.binEdges, edges), 'binEdges echoed');
    fprintf('  [OK] azGrid / elGrid / binEdges / percentiles echoed\n');

    % ===== 4. degenerate 1-cell: all weight in bin 5 -> midpoint =====
    stats1 = struct( ...
        'azGrid', 0, 'elGrid', 0, 'binEdges', edges, ...
        'counts', zeros(1, 1, Nbin, 'uint32'));
    stats1.counts(1, 1, 5) = uint32(100);
    pm1 = eirp_percentile_maps(stats1, [1 50 99]);
    mid5 = 0.5 * (edges(5) + edges(6));
    assert(all(abs(pm1.values(:) - mid5) < 1e-12), ...
        'single-bin percentile must equal that bin midpoint');
    fprintf('  [OK] single-bin -> midpoint at every percentile\n');

    % ===== 5. monotonic non-decreasing across P =====
    P = pm.values;
    diffP = diff(P, 1, 3);
    assert(all(diffP(:) >= -1e-9), ...
        'percentile axis must be monotonic non-decreasing');
    fprintf('  [OK] percentile axis monotonic non-decreasing\n');

    % ===== 6. zero-count cell -> NaN =====
    statsZero = stats;
    statsZero.counts(1, 1, :) = uint32(0);    % zero out the (1,1) cell
    pmZ = eirp_percentile_maps(statsZero, [50]); %#ok<NBRAK2>
    assert(isnan(pmZ.values(1, 1, 1)), ...
        'zero-count cell must yield NaN');
    fprintf('  [OK] zero-count cell -> NaN\n');

    % ===== 7. determinism =====
    pmA = eirp_percentile_maps(stats);
    pmB = eirp_percentile_maps(stats);
    assert(isequaln(pmA, pmB), 'percentile maps must be deterministic');
    fprintf('  [OK] deterministic across consecutive calls\n');

    % ===== 8. p0 selects the lowest occupied bin =====
    pm0 = eirp_percentile_maps(stats1, [0 100]);
    assert(all(abs(pm0.values(:) - mid5) < 1e-12), ...
        'p0 and p100 must both select the sole occupied bin');
    fprintf('  [OK] p0 selects the lowest occupied bin\n');

    % ===== 9. invalid percentile validation =====
    badId = 'eirp_percentile_maps:badPercentiles';
    assert(throwsId(@() eirp_percentile_maps(stats, -1), badId), ...
        'negative percentile must throw %s', badId);
    assert(throwsId(@() eirp_percentile_maps(stats, 101), badId), ...
        'percentile above 100 must throw %s', badId);
    assert(throwsId(@() eirp_percentile_maps(stats, NaN), badId), ...
        'NaN percentile must throw %s', badId);
    fprintf('  [OK] invalid percentiles rejected with %s\n', badId);

    results.passed = true;
    fprintf('--- test_eirp_percentile_maps PASSED ---\n');
end

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
