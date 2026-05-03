function [cdf, edges] = eirp_cdf_at_angle(stats, az_deg, el_deg)
%EIRP_CDF_AT_ANGLE Empirical CDF of EIRP at one (az, el) cell.
%
%   [CDF, EDGES] = eirp_cdf_at_angle(STATS, AZ_DEG, EL_DEG)
%
%   STATS is the streaming-stats struct produced by
%   run_imt_aas_eirp_monte_carlo. The CDF is built from STATS.counts at the
%   grid cell nearest to (az_deg, el_deg).
%
%   CDF(k) = P( EIRP <= EDGES(k+1) ).
%   The last value is guaranteed to be 1 (numerical floor 1.0).

    [iAz, iEl] = locateCell(stats, az_deg, el_deg);

    h     = squeeze(stats.counts(iAz, iEl, :));
    total = sum(h);
    if total <= 0
        edges = stats.binEdges;
        cdf   = zeros(size(h));
        return
    end

    cdf   = cumsum(h) ./ total;
    cdf(end) = 1;          % enforce by-construction CDF endpoint
    edges = stats.binEdges;
end

function [iAz, iEl] = locateCell(stats, az_deg, el_deg)
    [~, iAz] = min(abs(stats.azGrid - az_deg));
    [~, iEl] = min(abs(stats.elGrid - el_deg));
end
