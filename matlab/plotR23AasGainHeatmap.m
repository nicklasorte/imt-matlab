function figs = plotR23AasGainHeatmap(out, percentileList, varargin)
%PLOTR23AASGAINHEATMAP Heatmaps for the R23 Extended AAS realized GAIN grid.
%
%   FIGS = plotR23AasGainHeatmap(OUT)
%   FIGS = plotR23AasGainHeatmap(OUT, PERCENTILELIST)
%   FIGS = plotR23AasGainHeatmap(OUT, PERCENTILELIST, 'Name', Value, ...)
%
%   OUT is the struct returned by runR23AasEirpCdfGrid run with
%   opts.outputDomain = 'gain' (or 'both'), so OUT.gainPercentileMaps.values
%   is populated. The function mirrors plotR23AasEirpCdfGrid's layout (same
%   az/el axes and percentile-keyed figures) but renders the antenna GAIN in
%   dBi instead of EIRP in dBm:
%
%       FIGS.percentiles   struct keyed p050, p095, ... -> figure handle,
%                          one heatmap per requested percentile from
%                          PERCENTILELIST. Default PERCENTILELIST is [50 95].
%                          Percentiles must already be present in
%                          OUT.gainPercentileMaps.percentiles.
%
%   The gain shown is the REALIZED served-beam composite gain (the MAX over
%   simultaneous beams envelope, NOT a power sum), exactly as accumulated by
%   runR23AasEirpCdfGrid. The colorbar is labelled 'Gain [dBi]'.
%
%   Optional Name-Value style arguments (shared with plotR23AasEirpCdfGrid and
%   plotImtAasSectorEirpGrid through imtAasHeatmapStyle):
%
%       'Colormap'  colormap name or N-by-3 RGB matrix. Default is the
%                   standard IMT-AAS colormap ('turbo').
%       'CLim'      1-by-2 [lo hi] color-axis limits applied to every heatmap
%                   axis so figures (e.g. urban vs suburban) are directly
%                   comparable. Default [] leaves the color-axis on auto.
%
%   If OUT.gainPercentileMaps.values is missing/empty the function errors and
%   tells the caller to re-run with opts.outputDomain = 'gain'.
%
%   See also: runR23AasEirpCdfGrid, plotR23AasEirpCdfGrid, imtAasHeatmapStyle.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotR23AasGainHeatmap:invalidOut', ...
            'OUT must be the struct returned by runR23AasEirpCdfGrid.');
    end
    if ~isfield(out, 'gainPercentileMaps') || ~isstruct(out.gainPercentileMaps) ...
            || ~isfield(out.gainPercentileMaps, 'values') ...
            || isempty(out.gainPercentileMaps.values)
        error('plotR23AasGainHeatmap:noGainMap', ...
            ['OUT.gainPercentileMaps.values is empty: the gain heatmap was ', ...
             'not computed. Re-run runR23AasEirpCdfGrid with ', ...
             'opts.outputDomain = ''gain'' (or ''both'').']);
    end
    if nargin < 2 || isempty(percentileList)
        percentileList = [50 95];
    end
    percentileList = double(percentileList(:).');

    [cmap, clim] = parseHeatmapStyleArgs(varargin);

    gmaps = out.gainPercentileMaps;
    az = double(gmaps.azGrid(:).');
    el = double(gmaps.elGrid(:).');

    % Context for the title (best-effort; degrade gracefully).
    numMc      = fieldOr(out, {'stats', 'numMc'},    NaN);
    numBeams   = fieldOr(out, {'stats', 'numBeams'}, NaN);
    peakGainDbi = fieldOr(out, {'metadata', 'peakGainDbi'}, NaN);

    figs = struct();
    figs.percentiles = struct();

    available = double(gmaps.percentiles(:).');
    for j = 1:numel(percentileList)
        p = percentileList(j);
        idx = find(abs(available - p) < 1e-9, 1, 'first');
        if isempty(idx)
            warning('plotR23AasGainHeatmap:missingPercentile', ...
                ['Requested percentile %.3g not present in ', ...
                 'out.gainPercentileMaps.percentiles; skipping.'], p);
            continue;
        end
        slice = gmaps.values(:, :, idx);
        titleP = sprintf( ...
            ['R23 Extended AAS realized served-beam gain (max over beams)\n', ...
             'P%g gain per direction (numMc=%d, numBeams=%d, ', ...
             'peakGain=%.2f dBi)'], ...
            p, numMc, numBeams, peakGainDbi);
        fig = renderHeatmap(az, el, slice, titleP, cmap, clim);
        figs.percentiles.(sprintf('p%03d', round(p))) = fig;
    end
end

% =====================================================================

function fig = renderHeatmap(az, el, gridVals, titleText, cmap, clim)
    fig = figure('Name', 'R23 AAS gain heatmap', 'Color', 'w');
    imagesc(el, az, gridVals);
    ax = gca;
    set(ax, 'YDir', 'normal');
    xlabel('Elevation [deg]   (0 = horizon)');
    ylabel('Azimuth [deg]    (0 = sector boresight)');
    title(titleText);
    cb = colorbar;
    ylabel(cb, 'Gain [dBi]');
    axis tight;
    imtAasHeatmapStyle(ax, cmap, clim);
end

% =====================================================================

function v = fieldOr(s, path, default)
%FIELDOR Nested struct read with default for missing / empty fields.
    v = default;
    cur = s;
    for k = 1:numel(path)
        if isstruct(cur) && isfield(cur, path{k}) && ~isempty(cur.(path{k}))
            cur = cur.(path{k});
        else
            return;
        end
    end
    v = cur;
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
        error('plotR23AasGainHeatmap:badStyleArgs', ...
            'Style options must be supplied as Name, Value pairs.');
    end
    for k = 1:2:numel(args)
        name = args{k};
        if isstring(name) && isscalar(name)
            name = char(name);
        end
        if ~ischar(name)
            error('plotR23AasGainHeatmap:badStyleName', ...
                'Style option names must be char/string scalars.');
        end
        switch lower(name)
            case 'colormap'
                cmap = args{k+1};
            case 'clim'
                clim = args{k+1};
            otherwise
                error('plotR23AasGainHeatmap:unknownStyleOption', ...
                    ['Unknown style option "%s". Supported: ', ...
                     '''Colormap'', ''CLim''.'], name);
        end
    end
end
