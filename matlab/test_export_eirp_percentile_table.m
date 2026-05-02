function results = test_export_eirp_percentile_table()
%TEST_EXPORT_EIRP_PERCENTILE_TABLE Unit tests for export_eirp_percentile_table.
%
%   RESULTS = test_export_eirp_percentile_table()
%
%   Verifies:
%       1. Default-grid output has 65,341 rows and 103 columns.
%       2. Column names are azimuth_deg, elevation_deg, p000..p100.
%       3. Percentile values for a known histogram match by construction.
%       4. Each row's percentile columns are monotonic non-decreasing.
%       5. p000 / p100 equal the first / last nonzero occupied bin centers.
%       6. Cells with zero samples produce NaN across p000:p100.
%       7. The function works without a raw EIRP sample cube.
%       8. Calling without outputCsvPath (or empty) returns the table only.
%       9. CSV is written when outputCsvPath is provided.
%      10. Spec field names (azGrid_deg, elGrid_deg, eirpBinEdges_dBm,
%          histCounts) are accepted and produce the same table.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = test_default_grid_shape(results);
    results = test_column_names(results);
    results = test_percentile_values_known_histogram(results);
    results = test_monotonic_per_row(results);
    results = test_p000_p100_endpoints(results);
    results = test_zero_sample_cell_returns_nan(results);
    results = test_no_raw_cube_required(results);
    results = test_no_path_returns_table(results);
    results = test_csv_write(results);
    results = test_spec_field_names(results);

    fprintf('\n--- test_export_eirp_percentile_table summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% -------------------------------------------------------------------------

function r = test_default_grid_shape(r)
    az = -180:1:180;
    el =  -90:1:90;
    edges = -10:5:90;       % small Nbin to keep memory modest
    stats = makeEmptyStats(az, el, edges);
    % seed one count so percentile rows aren't all NaN
    stats.counts(1, 1, 5) = 1;
    T = export_eirp_percentile_table(stats);

    r = check(r, height(T) == 65341, ...
        sprintf('default grid row count = %d (expected 65341)', height(T)));
    r = check(r, width(T) == 103, ...
        sprintf('default grid column count = %d (expected 103)', width(T)));
    names = T.Properties.VariableNames;
    r = check(r, strcmp(names{1}, 'azimuth_deg'), ...
        ['first column is "azimuth_deg" (got "' names{1} '")']);
    r = check(r, strcmp(names{2}, 'elevation_deg'), ...
        ['second column is "elevation_deg" (got "' names{2} '")']);
end

function r = test_column_names(r)
    stats = makeSimpleStats();
    T = export_eirp_percentile_table(stats);
    names = T.Properties.VariableNames;
    ok = numel(names) == 103;
    for q = 0:100
        ok = ok && strcmp(names{q + 3}, sprintf('p%03d', q));
    end
    r = check(r, ok, 'percentile columns named p000 .. p100 in order');
end

function r = test_percentile_values_known_histogram(r)
    edges = 0:1:10;                       % 10 bins, centers 0.5..9.5
    counts = zeros(1, 1, 10);
    counts(1, 1, 1)  = 1;                 % bin center 0.5
    counts(1, 1, 5)  = 8;                 % bin center 4.5
    counts(1, 1, 10) = 1;                 % bin center 9.5
    stats = struct('azGrid', 0, 'elGrid', 0, ...
                   'binEdges', edges, 'counts', counts);

    T = export_eirp_percentile_table(stats);

    cdf_at_bin5 = (1 + 8) / 10;           % 0.9
    ok = abs(T.p000(1) - 0.5) < 1e-12 ...
       && abs(T.p100(1) - 9.5) < 1e-12 ...
       && abs(T.p010(1) - 0.5) < 1e-12 ...        % cdf(1) = 0.1
       && abs(T.p050(1) - 4.5) < 1e-12 ...        % cdf jumps to 0.9 at bin 5
       && abs(T.p090(1) - 4.5) < 1e-12 ...        % 0.9 reached at bin 5
       && abs(T.p095(1) - 9.5) < 1e-12;           % 0.95 only at bin 10
    r = check(r, ok, ...
        sprintf(['known histogram percentiles: p000=%.2f p010=%.2f ' ...
                 'p050=%.2f p090=%.2f p095=%.2f p100=%.2f ' ...
                 '(cdf@bin5=%.2f)'], ...
                 T.p000(1), T.p010(1), T.p050(1), T.p090(1), ...
                 T.p095(1), T.p100(1), cdf_at_bin5));
end

function r = test_monotonic_per_row(r)
    stats = makeSimpleStats();
    T = export_eirp_percentile_table(stats);
    P = T{:, 3:end};
    rowsValid = ~all(isnan(P), 2);
    Pvalid = P(rowsValid, :);
    diffs = diff(Pvalid, 1, 2);
    ok = ~any(isnan(Pvalid(:))) && all(diffs(:) >= -1e-9);
    r = check(r, ok, ...
        'percentile columns are monotonic non-decreasing across each row');
end

function r = test_p000_p100_endpoints(r)
    stats = makeSimpleStats();
    edges = stats.binEdges;
    centers = 0.5 .* (edges(1:end-1) + edges(2:end));
    T = export_eirp_percentile_table(stats);
    [Naz, Nel, Nbin] = size(stats.counts); %#ok<ASGLU>

    flat = double(reshape(stats.counts, Naz * Nel, Nbin));
    rowSum = sum(flat, 2);
    nonzero = flat > 0;

    [~, firstIdx] = max(nonzero, [], 2);
    [~, flipIdx]  = max(fliplr(nonzero), [], 2);
    lastIdx = Nbin - flipIdx + 1;

    expectedP000 = centers(firstIdx);
    expectedP100 = centers(lastIdx);
    expectedP000(rowSum == 0) = NaN;
    expectedP100(rowSum == 0) = NaN;

    ok = isequaln(T.p000, expectedP000(:)) ...
       && isequaln(T.p100, expectedP100(:));
    r = check(r, ok, 'p000 = first nonzero bin center, p100 = last nonzero bin center');
end

function r = test_zero_sample_cell_returns_nan(r)
    edges = -10:1:10;
    Naz = 3; Nel = 3; Nbin = numel(edges) - 1;
    counts = zeros(Naz, Nel, Nbin);
    counts(1, 1, 5) = 1;          % only the (-1, -1) cell has a sample
    stats = struct('azGrid', [-1 0 1], 'elGrid', [-1 0 1], ...
                   'binEdges', edges, 'counts', counts);
    T = export_eirp_percentile_table(stats);

    rowOk    = T.azimuth_deg == -1 & T.elevation_deg == -1;
    okRowVals = ~any(isnan(T{rowOk, 3:end}));
    P_other  = T{~rowOk, 3:end};
    okOtherNaN = all(isnan(P_other(:)));
    r = check(r, okRowVals && okOtherNaN, ...
        'cells with zero samples produce NaN across p000:p100');
end

function r = test_no_raw_cube_required(r)
    % stats has no raw EIRP sample cube field; the function must still work.
    stats = makeSimpleStats();
    flds = fieldnames(stats);
    hasCube = any(strcmpi(flds, 'eirpCube') | strcmpi(flds, 'samples') | ...
                  strcmpi(flds, 'rawCube'));
    T = export_eirp_percentile_table(stats);
    okShape = height(T) == numel(stats.azGrid) * numel(stats.elGrid) ...
              && width(T) == 103;
    r = check(r, ~hasCube && okShape, ...
        'function operates on histograms only (no raw sample cube needed)');
end

function r = test_no_path_returns_table(r)
    stats = makeSimpleStats();
    T1 = export_eirp_percentile_table(stats);
    T2 = export_eirp_percentile_table(stats, '');
    r = check(r, isequaln(T1, T2), ...
        'omitted vs empty outputCsvPath both return the table only');
end

function r = test_csv_write(r)
    stats = makeSimpleStats();
    tmp = [tempname, '.csv'];
    cleaner = onCleanup(@() removeIfExists(tmp)); %#ok<NASGU>
    T = export_eirp_percentile_table(stats, tmp);

    written = exist(tmp, 'file') == 2;
    if written
        Tread = readtable(tmp);
        sameShape = height(Tread) == height(T) && width(Tread) == width(T);
        sameNames = isequal(Tread.Properties.VariableNames, ...
                            T.Properties.VariableNames);
        ok = sameShape && sameNames;
    else
        ok = false;
    end
    r = check(r, ok, 'CSV written and round-tripped via readtable');
end

function r = test_spec_field_names(r)
    s1 = makeSimpleStats();

    s2 = struct();
    s2.azGrid_deg       = s1.azGrid;
    s2.elGrid_deg       = s1.elGrid;
    s2.eirpBinEdges_dBm = s1.binEdges;
    % spec layout: [Nel x Naz x Nbin]
    s2.histCounts       = permute(s1.counts, [2 1 3]);

    T1 = export_eirp_percentile_table(s1);
    T2 = export_eirp_percentile_table(s2);
    r = check(r, isequaln(T1, T2), ...
        'spec field names (azGrid_deg/elGrid_deg/eirpBinEdges_dBm/histCounts) match repo names');
end

% -------------------------------------------------------------------------

function r = check(r, cond, msg)
    if cond
        r.summary{end + 1} = ['PASS  ' msg];
    else
        r.summary{end + 1} = ['FAIL  ' msg];
        r.passed = false;
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end

function stats = makeEmptyStats(az, el, edges)
    Naz = numel(az); Nel = numel(el); Nbin = numel(edges) - 1;
    stats = struct();
    stats.azGrid   = az;
    stats.elGrid   = el;
    stats.binEdges = edges;
    stats.counts   = zeros(Naz, Nel, Nbin, 'uint32');
end

function stats = makeSimpleStats()
    az = -10:5:10;       % Naz = 5
    el = -5:5:5;         % Nel = 3
    edges = 0:1:50;      % 50 bins
    Naz = numel(az); Nel = numel(el);
    stats = struct();
    stats.azGrid   = az;
    stats.elGrid   = el;
    stats.binEdges = edges;
    counts = zeros(Naz, Nel, numel(edges) - 1);
    rng(1234);
    for iA = 1:Naz
        for iE = 1:Nel
            mu = 25 + 0.5 * iA - 0.3 * iE;
            sigma = 4;
            samples = mu + sigma * randn(400, 1);
            samples = min(max(samples, edges(1) + 0.01), edges(end) - 0.01);
            h = histcounts(samples, edges);
            counts(iA, iE, :) = h;
        end
    end
    stats.counts = counts;
end

function removeIfExists(p)
    if exist(p, 'file') == 2
        delete(p);
    end
end
