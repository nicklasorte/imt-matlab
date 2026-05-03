function figs = plotR23AasEirpCdfGrid(out, percentileList)
%PLOTR23AASEIRPCDFGRID Heatmaps for the R23 Extended AAS EIRP CDF-grid.
%
%   FIGS = plotR23AasEirpCdfGrid(OUT)
%   FIGS = plotR23AasEirpCdfGrid(OUT, PERCENTILELIST)
%
%   OUT is the struct returned by runR23AasEirpCdfGrid. The function plots:
%
%       FIGS.mean              heatmap of OUT.stats.mean_dBm.
%       FIGS.percentiles       containers.Map (or struct fallback) keyed
%                              by percentile (numeric) -> figure handle,
%                              one heatmap per requested percentile from
%                              PERCENTILELIST. Default PERCENTILELIST is
%                              [50 95]. Percentiles must already be
%                              present in OUT.percentileMaps.percentiles.
%
%   Every title carries the explicit reminder:
%
%       "R23 Extended AAS antenna-face EIRP only - no path loss"
%
%   so figures are not mistaken for received power.
%
%   See also: runR23AasEirpCdfGrid, plotImtAasSectorEirpGrid,
%             eirp_percentile_maps.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotR23AasEirpCdfGrid:invalidOut', ...
            'OUT must be the struct returned by runR23AasEirpCdfGrid.');
    end
    requiredFields = {'stats', 'percentileMaps'};
    for i = 1:numel(requiredFields)
        if ~isfield(out, requiredFields{i})
            error('plotR23AasEirpCdfGrid:missingField', ...
                'OUT is missing field "%s".', requiredFields{i});
        end
    end
    if nargin < 2 || isempty(percentileList)
        percentileList = [50 95];
    end
    percentileList = double(percentileList(:).');

    stats  = out.stats;
    pmaps  = out.percentileMaps;

    az = double(stats.azGrid(:).');
    el = double(stats.elGrid(:).');

    figs = struct();
    figs.percentiles = struct();   % field names like p050, p095

    % ---- mean map ----------------------------------------------------
    titleMean = sprintf( ...
        ['R23 Extended AAS antenna-face EIRP only - no path loss\n', ...
         'mean EIRP (linear-mW averaged, numMc=%d, numBeams=%d, ', ...
         'sectorEirp=%.2f dBm/100MHz)'], ...
        stats.numMc, stats.numBeams, stats.sectorEirpDbm);
    figs.mean = renderHeatmap(az, el, stats.mean_dBm, titleMean);

    % ---- percentile maps --------------------------------------------
    available = double(pmaps.percentiles(:).');
    for j = 1:numel(percentileList)
        p = percentileList(j);
        idx = find(abs(available - p) < 1e-9, 1, 'first');
        if isempty(idx)
            warning('plotR23AasEirpCdfGrid:missingPercentile', ...
                ['Requested percentile %.3g not present in ', ...
                 'out.percentileMaps.percentiles; skipping.'], p);
            continue;
        end
        slice = pmaps.values(:, :, idx);
        titleP = sprintf( ...
            ['R23 Extended AAS antenna-face EIRP only - no path loss\n', ...
             'P%g EIRP per direction (numMc=%d, numBeams=%d, ', ...
             'sectorEirp=%.2f dBm/100MHz)'], ...
            p, stats.numMc, stats.numBeams, stats.sectorEirpDbm);
        fig = renderHeatmap(az, el, slice, titleP);
        figs.percentiles.(sprintf('p%03d', round(p))) = fig;
    end
end

% =====================================================================

function fig = renderHeatmap(az, el, gridVals, titleText)
    fig = figure('Name', 'R23 AAS EIRP CDF grid', 'Color', 'w');
    imagesc(el, az, gridVals);
    set(gca, 'YDir', 'normal');
    xlabel('Elevation [deg]   (0 = horizon)');
    ylabel('Azimuth [deg]    (0 = sector boresight)');
    title(titleText);
    cb = colorbar;
    ylabel(cb, 'EIRP [dBm / 100 MHz]');
    axis tight;
end
