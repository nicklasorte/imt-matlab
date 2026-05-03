function T = export_eirp_percentile_table(stats, outputCsvPath)
%EXPORT_EIRP_PERCENTILE_TABLE One row per az/el cell, with p000:p100 EIRP [dBm].
%
%   T = export_eirp_percentile_table(STATS)
%   T = export_eirp_percentile_table(STATS, OUTPUTCSVPATH)
%
%   Builds a MATLAB table whose rows are the (azimuth, elevation) observation
%   bins on the Monte-Carlo grid and whose columns are the EIRP value [dBm]
%   at integer CDF percentiles 0..100, named p000, p001, ..., p100.
%
%   Inputs
%   ------
%   STATS   struct holding the streaming Monte-Carlo histogram. Both the
%           "spec" field names and the existing repo field names are
%           accepted:
%               .azGrid_deg    or .azGrid       1xNaz [deg]
%               .elGrid_deg    or .elGrid       1xNel [deg]
%               .eirpBinEdges_dBm or .binEdges  1x(Nbin+1) [dBm]
%               .histCounts    or .counts       histogram bin counts
%
%           If .histCounts is provided it is treated as [Nel x Naz x Nbin]
%           (the spec layout). If .counts is provided it is treated as
%           [Naz x Nel x Nbin] (the repo layout).
%
%   OUTPUTCSVPATH (optional) char/string. When non-empty the table is
%           written via writetable.
%
%   Output
%   ------
%   T       MATLAB table with height Naz*Nel and width 103. Columns:
%               azimuth_deg, elevation_deg, p000, p001, ..., p100
%
%   Percentile rule
%   ---------------
%   Bin centers:  c(k) = 0.5 * (edges(k) + edges(k+1))
%   For each cell with at least one sample:
%       cdf(k) = cumsum(counts) / sum(counts)
%       For 0 < q < 100:  p_q = c(k*) where k* is the smallest k with
%                                cdf(k) >= q/100.
%       p000 = bin center of the first nonzero occupied bin.
%       p100 = bin center of the last  nonzero occupied bin.
%   Cells with zero samples receive NaN across p000:p100.
%
%   Notes
%   -----
%   - This function never reconstructs or stores the raw EIRP sample cube.
%   - Row order is azimuth-fastest (i.e. for each elevation, all azimuths
%     are emitted in order before advancing to the next elevation), matching
%     a column-major flatten of an [Naz x Nel] grid.

    if nargin < 2
        outputCsvPath = '';
    end

    [azGrid, elGrid, edges, counts] = unpackStats(stats);

    Naz  = numel(azGrid);
    Nel  = numel(elGrid);
    Nbin = numel(edges) - 1;
    if size(counts, 1) ~= Naz || size(counts, 2) ~= Nel || size(counts, 3) ~= Nbin
        error('export_eirp_percentile_table:badShape', ...
            ['histogram counts have shape [%d %d %d] which does not match ' ...
             '[Naz Nel Nbin]=[%d %d %d].'], ...
            size(counts, 1), size(counts, 2), size(counts, 3), Naz, Nel, Nbin);
    end

    binCenters_dBm = 0.5 .* (edges(1:end-1) + edges(2:end));   % 1 x Nbin

    flat   = double(reshape(counts, Naz * Nel, Nbin));
    rowSum = sum(flat, 2);
    cdf    = cumsum(flat, 2) ./ max(rowSum, 1);

    nonzeroMask = flat > 0;
    anyNonzero  = any(nonzeroMask, 2);

    [~, firstNonzero] = max(nonzeroMask, [], 2);
    [~, flipFirst]    = max(fliplr(nonzeroMask), [], 2);
    lastNonzero       = Nbin - flipFirst + 1;

    Q       = 0:100;
    nQ      = numel(Q);
    nRows   = Naz * Nel;
    pVals   = NaN(nRows, nQ);

    for iq = 1:nQ
        q = Q(iq);
        if q == 0
            idx = firstNonzero;
        elseif q == 100
            idx = lastNonzero;
        else
            ge = cdf >= (q / 100);
            [~, idx] = max(ge, [], 2);
        end
        v = binCenters_dBm(idx);
        pVals(:, iq) = v(:);
    end
    pVals(~anyNonzero, :) = NaN;

    [AZ, EL] = ndgrid(azGrid, elGrid);
    azCol = AZ(:);
    elCol = EL(:);

    pNames    = arrayfun(@(q) sprintf('p%03d', q), Q, 'UniformOutput', false);
    varNames  = [{'azimuth_deg', 'elevation_deg'}, pNames];

    T = array2table([azCol, elCol, pVals], 'VariableNames', varNames);

    if ~isempty(outputCsvPath)
        writetable(T, char(outputCsvPath));
    end
end

function [azGrid, elGrid, edges, counts] = unpackStats(stats)
    if isfield(stats, 'azGrid_deg') && ~isempty(stats.azGrid_deg)
        azGrid = stats.azGrid_deg(:).';
    elseif isfield(stats, 'azGrid')
        azGrid = stats.azGrid(:).';
    else
        error('export_eirp_percentile_table:noAz', ...
            'stats must provide azGrid_deg or azGrid.');
    end

    if isfield(stats, 'elGrid_deg') && ~isempty(stats.elGrid_deg)
        elGrid = stats.elGrid_deg(:).';
    elseif isfield(stats, 'elGrid')
        elGrid = stats.elGrid(:).';
    else
        error('export_eirp_percentile_table:noEl', ...
            'stats must provide elGrid_deg or elGrid.');
    end

    if isfield(stats, 'eirpBinEdges_dBm') && ~isempty(stats.eirpBinEdges_dBm)
        edges = stats.eirpBinEdges_dBm(:).';
    elseif isfield(stats, 'binEdges')
        edges = stats.binEdges(:).';
    else
        error('export_eirp_percentile_table:noEdges', ...
            'stats must provide eirpBinEdges_dBm or binEdges.');
    end

    if isfield(stats, 'histCounts') && ~isempty(stats.histCounts)
        counts = permute(stats.histCounts, [2 1 3]);   % [Nel Naz Nbin] -> [Naz Nel Nbin]
    elseif isfield(stats, 'counts')
        counts = stats.counts;
    else
        error('export_eirp_percentile_table:noCounts', ...
            'stats must provide histCounts or counts.');
    end
end
