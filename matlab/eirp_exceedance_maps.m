function emaps = eirp_exceedance_maps(stats, thresholds_dBm)
%EIRP_EXCEEDANCE_MAPS Per-angle P(EIRP > threshold) maps.
%
%   EMAPS = eirp_exceedance_maps(STATS, THRESHOLDS_DBM)
%
%   STATS         struct from run_imt_aas_eirp_monte_carlo
%   THRESHOLDS_DBM vector of EIRP thresholds [dBm]
%
%   EMAPS struct:
%       .thresholds_dBm   1 x T
%       .azGrid           1 x Naz
%       .elGrid           1 x Nel
%       .prob             Naz x Nel x T   (probability of exceedance)
%       .numMc            scalar (Monte Carlo runs)
%
%   Probability is computed as 1 - CDF evaluated at the bin edge nearest
%   each threshold. Thresholds outside the histogram support saturate to
%   0 or 1 with a warning.

    edges = stats.binEdges;
    [Naz, Nel, Nbin] = size(stats.counts);
    thresholds_dBm = thresholds_dBm(:).';
    T = numel(thresholds_dBm);

    % Convert uint32 counts to double for cumsum/division arithmetic.
    flat = double(reshape(stats.counts, Naz*Nel, Nbin));
    total = sum(flat, 2);
    cdf  = cumsum(flat, 2) ./ max(total, 1);

    prob = NaN(Naz*Nel, T);
    saturatedHi = thresholds_dBm >= edges(end);
    saturatedLo = thresholds_dBm <  edges(1);

    if any(saturatedHi)
        warning('eirp_exceedance_maps:thresholdHigh', ...
            'Some thresholds exceed histogram support; clipping to 0.');
    end
    if any(saturatedLo)
        warning('eirp_exceedance_maps:thresholdLow', ...
            'Some thresholds below histogram support; clipping to 1.');
    end

    for j = 1:T
        thr = thresholds_dBm(j);
        if saturatedHi(j)
            prob(:, j) = 0;
        elseif saturatedLo(j)
            prob(:, j) = 1;
        else
            % find the largest bin upper edge that is <= thr
            % so cdf at that bin = P(EIRP <= upper_edge) ~ P(EIRP <= thr)
            upper = edges(2:end);
            mask  = upper <= thr;
            if ~any(mask)
                prob(:, j) = 1;
                continue
            end
            kIdx = find(mask, 1, 'last');
            prob(:, j) = 1 - cdf(:, kIdx);
        end
    end

    prob(total == 0, :) = NaN;

    emaps.thresholds_dBm = thresholds_dBm;
    emaps.azGrid         = stats.azGrid;
    emaps.elGrid         = stats.elGrid;
    emaps.prob           = reshape(prob, Naz, Nel, T);
    emaps.numMc          = stats.numMc;
end
