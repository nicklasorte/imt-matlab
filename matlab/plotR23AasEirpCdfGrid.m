function figs = plotR23AasEirpCdfGrid(out, percentileList, varargin)
%PLOTR23AASEIRPCDFGRID Heatmaps for the R23 Extended AAS EIRP CDF-grid.
%
%   FIGS = plotR23AasEirpCdfGrid(OUT)
%   FIGS = plotR23AasEirpCdfGrid(OUT, PERCENTILELIST)
%   FIGS = plotR23AasEirpCdfGrid(OUT, PERCENTILELIST, 'Name', Value, ...)
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
%   Optional Name-Value style arguments (shared with plotImtAasSectorEirpGrid
%   and plotR23AasGainHeatmap through imtAasHeatmapStyle):
%
%       'Colormap'  colormap name or N-by-3 RGB matrix. Default is the
%                   standard IMT-AAS colormap ('turbo'); switching to that
%                   standard colormap is the ONLY visual change versus the
%                   historical single-argument call.
%       'CLim'      1-by-2 [lo hi] color-axis limits applied to every heatmap
%                   axis so figures (e.g. urban vs suburban) are directly
%                   comparable. Default [] leaves the color-axis on auto
%                   (the historical autoscaled behavior).
%
%   Every title carries the explicit reminder:
%
%       "R23 Extended AAS antenna-face EIRP only - no path loss"
%
%   so figures are not mistaken for received power.
%
%   See also: runR23AasEirpCdfGrid, plotImtAasSectorEirpGrid,
%             plotR23AasGainHeatmap, imtAasHeatmapStyle,
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

    [cmap, clim] = parseHeatmapStyleArgs(varargin);

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
    figs.mean = renderHeatmap(az, el, stats.mean_dBm, titleMean, cmap, clim);

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
        fig = renderHeatmap(az, el, slice, titleP, cmap, clim);
        figs.percentiles.(sprintf('p%03d', round(p))) = fig;
    end
end

% =====================================================================

function fig = renderHeatmap(az, el, gridVals, titleText, cmap, clim)
    fig = figure('Name', 'R23 AAS EIRP CDF grid', 'Color', 'w');
    imagesc(el, az, gridVals);
    ax = gca;
    set(ax, 'YDir', 'normal');
    xlabel('Elevation [deg]   (0 = horizon)');
    ylabel('Azimuth [deg]    (0 = sector boresight)');
    title(titleText);
    cb = colorbar;
    ylabel(cb, 'EIRP [dBm / 100 MHz]');
    axis tight;
    imtAasHeatmapStyle(ax, cmap, clim);
end

% =====================================================================

function [cmap, clim] = parseHeatmapStyleArgs(args)
%PARSEHEATMAPSTYLEARGS Read optional 'Colormap'/'CLim' name-value pairs.
%   Defaults: Colormap -> [] (resolved to the standard default inside
%   imtAasHeatmapStyle); CLim -> [] (auto color-axis, historical behavior).
    cmap = [];
    clim = [];
    if isempty(args)
        return;
    end
    if mod(numel(args), 2) ~= 0
        error('plotR23AasEirpCdfGrid:badStyleArgs', ...
            'Style options must be supplied as Name, Value pairs.');
    end
    for k = 1:2:numel(args)
        name = args{k};
        if isstring(name) && isscalar(name)
            name = char(name);
        end
        if ~ischar(name)
            error('plotR23AasEirpCdfGrid:badStyleName', ...
                'Style option names must be char/string scalars.');
        end
        switch lower(name)
            case 'colormap'
                cmap = args{k+1};
            case 'clim'
                clim = args{k+1};
            otherwise
                error('plotR23AasEirpCdfGrid:unknownStyleOption', ...
                    ['Unknown style option "%s". Supported: ', ...
                     '''Colormap'', ''CLim''.'], name);
        end
    end
end
