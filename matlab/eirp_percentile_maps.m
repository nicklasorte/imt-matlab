function pmaps = eirp_percentile_maps(stats, percentiles)
%EIRP_PERCENTILE_MAPS Per-angle EIRP percentile maps from streaming stats.
%
%   PMAPS = eirp_percentile_maps(STATS, PERCENTILES)
%
%   STATS       struct produced by run_imt_aas_eirp_monte_carlo.
%   PERCENTILES vector of percentiles in [0,100] (default
%               [1 5 10 50 90 95 99]).
%
%   PMAPS is a struct:
%       .percentiles    1 x P                    (input mirrored)
%       .azGrid         1 x Naz                  (deg)
%       .elGrid         1 x Nel                  (deg)
%       .values         Naz x Nel x P            (dBm)
%       .binEdges       1 x (Nbin+1)             (dBm, source bin edges)
%
%   Bin midpoints are used as the EIRP value for each percentile via the
%   smallest bin whose cumulative probability >= p/100.

    if nargin < 2 || isempty(percentiles)
        percentiles = [1 5 10 50 90 95 99];
    end
    percentiles = percentiles(:).';

    edges = stats.binEdges;
    mids  = 0.5 .* (edges(1:end-1) + edges(2:end));   % bin midpoints

    [Naz, Nel, Nbin] = size(stats.counts);
    P = numel(percentiles);

    % Convert uint32 counts to double for cumsum/division arithmetic.
    flat = double(reshape(stats.counts, Naz*Nel, Nbin));
    rowSum = sum(flat, 2);
    cdf  = cumsum(flat, 2) ./ max(rowSum, 1);

    values = NaN(Naz*Nel, P);
    for j = 1:P
        target = percentiles(j) ./ 100;
        % first bin with cdf >= target
        ge = cdf >= target;
        % handle empty cells (no draws)
        anyGE = any(ge, 2);
        idx = ones(Naz*Nel, 1);
        [~, firstIdx] = max(ge, [], 2);
        idx(anyGE) = firstIdx(anyGE);
        values(:, j) = mids(idx);
        % cells with no data return NaN
        values(rowSum == 0, j) = NaN;
    end

    pmaps.percentiles = percentiles;
    pmaps.azGrid      = stats.azGrid;
    pmaps.elGrid      = stats.elGrid;
    pmaps.values      = reshape(values, Naz, Nel, P);
    pmaps.binEdges    = edges;
end
