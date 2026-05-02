function stats = update_eirp_histograms(stats, eirp_dBm)
%UPDATE_EIRP_HISTOGRAMS Streaming per-cell statistics for the EIRP cube.
%
%   STATS = update_eirp_histograms(STATS, EIRP_DBM)
%
%   STATS.binEdges    1 x (Nbin+1) histogram bin edges in dBm (created in
%                     run_imt_aas_eirp_monte_carlo).
%   STATS.counts      [Naz x Nel x Nbin] running histogram bin counts.
%   STATS.sum_lin_mW  [Naz x Nel] running sum of linear EIRP in mW.
%   STATS.min_dBm     [Naz x Nel] running per-cell minimum EIRP.
%   STATS.max_dBm     [Naz x Nel] running per-cell maximum EIRP.
%   STATS.numMc       running count of Monte Carlo draws aggregated.
%
%   EIRP_DBM is the new EIRP slice [Naz x Nel] from the current draw.
%
%   Implementation note: each draw increments exactly one bin per (az,el)
%   cell, so the linear indices into the [Naz x Nel x Nbin] count cube are
%   guaranteed unique. We exploit that with a single direct indexed
%   increment instead of building an accumarray scatter list (which
%   internally sorts/groups its index argument).

    edges = stats.binEdges;
    Nbin  = numel(edges) - 1;

    % --- linear (mW) sum for arithmetic mean of linear power ---------------
    stats.sum_lin_mW = stats.sum_lin_mW + 10.^(eirp_dBm ./ 10);

    % --- min / max ---------------------------------------------------------
    stats.min_dBm = min(stats.min_dBm, eirp_dBm);
    stats.max_dBm = max(stats.max_dBm, eirp_dBm);

    % --- histogram (vectorised across all (az,el) cells) -------------------
    % Bin index per cell: 1..Nbin, clipped so out-of-range goes into the
    % first/last bin (matches typical CDF clipping). NaN is funneled to the
    % last bin to mirror the previous behavior.
    binIdx = discretize(eirp_dBm, edges);
    binIdx(eirp_dBm < edges(1))     = 1;
    binIdx(eirp_dBm >= edges(end))  = Nbin;
    binIdx(isnan(binIdx))           = Nbin;

    [Naz, Nel] = size(eirp_dBm);
    NazNel     = Naz * Nel;
    binFlat    = binIdx(:);

    % Linear indices into the flat (NazNel x Nbin) reshape of stats.counts.
    % Each (cell -> bin) pair appears at most once across the slice, so a
    % direct subscripted-add updates each location exactly once.
    linIdx     = (1:NazNel).' + NazNel .* (binFlat - 1);

    countsFlat         = reshape(stats.counts, NazNel, Nbin);
    countsFlat(linIdx) = countsFlat(linIdx) + 1;
    stats.counts       = reshape(countsFlat, [Naz, Nel, Nbin]);

    stats.numMc = stats.numMc + 1;
end
