function cdf = compute_cdf_per_grid_point(eirpGrid, percentiles)
%COMPUTE_CDF_PER_GRID_POINT Empirical CDF of EIRP across snapshots, per cell.
%
%   CDF = compute_cdf_per_grid_point(EIRPGRID)
%   CDF = compute_cdf_per_grid_point(EIRPGRID, PERCENTILES)
%
%   Given a Naz x Nel x numSnapshots EIRP cube (e.g. from
%   run_monte_carlo_snapshots), computes a per-cell empirical CDF of
%   EIRP across the Monte Carlo dimension.
%
%   PERCENTILES is a sorted vector in [0, 100]. Default
%       [1 5 10 25 50 75 90 95 99].
%
%   Output struct fields:
%       sortedEirpDbm    Naz x Nel x numSnapshots, sorted along dim 3
%                        (ascending). The empirical CDF level for index k
%                        (1..numSnapshots) is k / numSnapshots.
%       cdfLevels        1 x numSnapshots, [1, 2, ..., numSnapshots]
%                        / numSnapshots
%       percentiles      passthrough vector, ascending
%       percentileEirpDbm Naz x Nel x numel(percentiles) [dBm / 100 MHz]
%       meanEirpDbm      Naz x Nel, 10*log10(mean(10.^(eirp/10)))
%                        (linear-mW mean, then back to dBm)
%       minEirpDbm       Naz x Nel, min over snapshots
%       maxEirpDbm       Naz x Nel, max over snapshots
%       numSnapshots     scalar
%
%   Per-cell monotonicity: by construction, percentileEirpDbm is non-
%   decreasing along the third dimension. test_single_sector_eirp_mvp
%   asserts this.

    if nargin < 1 || isempty(eirpGrid)
        error('compute_cdf_per_grid_point:missingEirpGrid', ...
            'eirpGrid (Naz x Nel x numSnapshots) is required.');
    end
    if ndims(eirpGrid) > 3 %#ok<ISMAT>
        error('compute_cdf_per_grid_point:badShape', ...
            'eirpGrid must be at most 3-D.');
    end
    if nargin < 2 || isempty(percentiles)
        percentiles = [1 5 10 25 50 75 90 95 99];
    end

    if ~(isnumeric(percentiles) && isvector(percentiles) && ...
            all(isfinite(percentiles)) && all(percentiles >= 0) && ...
            all(percentiles <= 100))
        error('compute_cdf_per_grid_point:badPercentiles', ...
            'percentiles must be a finite vector in [0, 100].');
    end
    percentiles = sort(double(percentiles(:).'));

    sz = size(eirpGrid);
    if numel(sz) == 2
        Naz = sz(1); Nel = 1; numSnap = sz(2);
        eirpGrid = reshape(eirpGrid, Naz, Nel, numSnap);
    else
        Naz = sz(1); Nel = sz(2); numSnap = sz(3);
    end

    sortedEirpDbm = sort(eirpGrid, 3, 'ascend');
    cdfLevels = (1:numSnap) ./ numSnap;

    % Linear interpolation on empirical CDF for each grid cell. Use a
    % vectorized formulation.
    P = numel(percentiles);
    pLevels = percentiles ./ 100;
    pLevels = max(pLevels, 1 / numSnap); % avoid -inf from clipping
    targetPos = pLevels .* numSnap;       % position along sorted axis
    targetPos = min(max(targetPos, 1), numSnap);

    lowIdx  = floor(targetPos);
    highIdx = ceil(targetPos);
    frac    = targetPos - lowIdx;

    percentileEirpDbm = zeros(Naz, Nel, P);
    for j = 1:P
        loSlice = sortedEirpDbm(:, :, lowIdx(j));
        hiSlice = sortedEirpDbm(:, :, highIdx(j));
        percentileEirpDbm(:, :, j) = loSlice + frac(j) .* (hiSlice - loSlice);
    end

    meanEirpDbm = 10 .* log10(mean(10 .^ (eirpGrid / 10), 3));
    minEirpDbm  = min(eirpGrid, [], 3);
    maxEirpDbm  = max(eirpGrid, [], 3);

    cdf = struct();
    cdf.sortedEirpDbm     = sortedEirpDbm;
    cdf.cdfLevels         = cdfLevels;
    cdf.percentiles       = percentiles;
    cdf.percentileEirpDbm = percentileEirpDbm;
    cdf.meanEirpDbm       = meanEirpDbm;
    cdf.minEirpDbm        = minEirpDbm;
    cdf.maxEirpDbm        = maxEirpDbm;
    cdf.numSnapshots      = numSnap;
end
