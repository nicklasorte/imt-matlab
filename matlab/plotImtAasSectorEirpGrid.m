function figs = plotImtAasSectorEirpGrid(out, varargin)
%PLOTIMTAASSECTOREIRPGRID Heatmaps for a UE-driven sector EIRP grid.
%
%   FIGS = plotImtAasSectorEirpGrid(OUT)
%   FIGS = plotImtAasSectorEirpGrid(OUT, 'Name', Value, ...)
%
%   OUT is the struct returned by imtAasSectorEirpGridFromBeams (or by
%   imtAasCreateDefaultSectorEirpGrid). The function produces:
%
%       figs.aggregate     heatmap of out.aggregateEirpDbm
%       figs.envelope      heatmap of out.maxEnvelopeEirpDbm
%       figs.perBeam       1xK array of figure handles for the first K
%                          per-beam heatmaps (K = min(3, out.numBeams));
%                          empty when out.perBeamEirpDbm is missing.
%
%   Optional Name-Value style arguments (shared with plotR23AasEirpCdfGrid
%   and plotR23AasGainHeatmap through imtAasHeatmapStyle):
%       'Colormap'  colormap name or N-by-3 RGB matrix. Default is the
%                   standard IMT-AAS colormap ('turbo').
%       'CLim'      1-by-2 [lo hi] color-axis limits applied to every heatmap
%                   axis for direct comparability. Default [] = auto.
%
%   Every title carries the explicit reminder
%       "Antenna-face EIRP only - no path loss"
%   so figures are not mistaken for received power.
%
%   See also imtAasSectorEirpGridFromBeams, plotImtAasEirpGrid,
%            imtAasHeatmapStyle.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotImtAasSectorEirpGrid:invalidOut', ...
            'OUT must be the struct returned by imtAasSectorEirpGridFromBeams.');
    end
    requiredFields = {'azGridDeg', 'elGridDeg', ...
        'aggregateEirpDbm', 'maxEnvelopeEirpDbm', 'numBeams'};
    for i = 1:numel(requiredFields)
        if ~isfield(out, requiredFields{i})
            error('plotImtAasSectorEirpGrid:missingField', ...
                'OUT is missing field "%s".', requiredFields{i});
        end
    end

    [cmap, clim] = parseHeatmapStyleArgs(varargin);

    az = double(out.azGridDeg(:).');
    el = double(out.elGridDeg(:).');

    figs = struct();

    figs.aggregate = renderHeatmap(az, el, out.aggregateEirpDbm, ...
        sprintf(['Sector aggregate EIRP (numBeams = %d, peak %.2f ' ...
                 'dBm/100MHz)\nAntenna-face EIRP only - no path loss'], ...
                out.numBeams, max(out.aggregateEirpDbm(:))), cmap, clim);

    figs.envelope = renderHeatmap(az, el, out.maxEnvelopeEirpDbm, ...
        sprintf(['Sector envelope EIRP (max over beams, peak %.2f ' ...
                 'dBm/100MHz)\nAntenna-face EIRP only - no path loss'], ...
                max(out.maxEnvelopeEirpDbm(:))), cmap, clim);

    figs.perBeam = [];
    if isfield(out, 'perBeamEirpDbm') && ~isempty(out.perBeamEirpDbm)
        K = min(3, out.numBeams);
        beamFigs = cell(1, K);
        for k = 1:K
            steerAz = NaN; steerEl = NaN;
            if isfield(out, 'beams')
                if isfield(out.beams, 'steerAzDeg')
                    steerAz = out.beams.steerAzDeg(k);
                end
                if isfield(out.beams, 'steerElDeg')
                    steerEl = out.beams.steerElDeg(k);
                end
            end
            beamFigs{k} = renderHeatmap(az, el, ...
                out.perBeamEirpDbm(:, :, k), ...
                sprintf(['Per-beam EIRP %d / %d  (steer az=%.2f, ' ...
                         'el=%.2f deg, peak %.2f dBm/100MHz)\n' ...
                         'Antenna-face EIRP only - no path loss'], ...
                        k, out.numBeams, steerAz, steerEl, ...
                        max(reshape(out.perBeamEirpDbm(:, :, k), [], 1))), ...
                cmap, clim);
        end
        figs.perBeam = beamFigs;
    end
end

% =====================================================================

function fig = renderHeatmap(az, el, grid, titleText, cmap, clim)
    fig = figure('Name', 'IMT AAS sector EIRP grid', 'Color', 'w');
    imagesc(el, az, grid);
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
        error('plotImtAasSectorEirpGrid:badStyleArgs', ...
            'Style options must be supplied as Name, Value pairs.');
    end
    for k = 1:2:numel(args)
        name = args{k};
        if isstring(name) && isscalar(name)
            name = char(name);
        end
        if ~ischar(name)
            error('plotImtAasSectorEirpGrid:badStyleName', ...
                'Style option names must be char/string scalars.');
        end
        switch lower(name)
            case 'colormap'
                cmap = args{k+1};
            case 'clim'
                clim = args{k+1};
            otherwise
                error('plotImtAasSectorEirpGrid:unknownStyleOption', ...
                    ['Unknown style option "%s". Supported: ', ...
                     '''Colormap'', ''CLim''.'], name);
        end
    end
end
