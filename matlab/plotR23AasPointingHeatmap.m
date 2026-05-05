function fig = plotR23AasPointingHeatmap(out, which)
%PLOTR23AASPOINTINGHEATMAP Heatmap of antenna pointing angle per (az, el) cell.
%
%   FIG = plotR23AasPointingHeatmap(OUT)
%   FIG = plotR23AasPointingHeatmap(OUT, WHICH)
%
%   OUT is the struct returned by runR23AasEirpCdfGrid (with
%   computePointingHeatmap = true). WHICH is one of:
%       'azimuth'    (default) plots OUT.pointing.azimuthDegGrid
%       'elevation'            plots OUT.pointing.elevationDegGrid
%       'both'                 returns a struct of two figures
%
%   Each cell shows the average steering angle of the BS beam that
%   delivered the maximum gain toward that observation direction
%   across the Monte Carlo ensemble. Azimuth uses a circular mean
%   (atan2d(sumSin, sumCos)) and is therefore wrap-safe.
%
%   This is antenna pointing (degrees) only - it is NOT EIRP.
%
%   See also: runR23AasEirpCdfGrid, plotR23AasEirpCdfGrid.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotR23AasPointingHeatmap:invalidOut', ...
            'OUT must be the struct returned by runR23AasEirpCdfGrid.');
    end
    if ~isfield(out, 'pointing') || ~isstruct(out.pointing) || ...
            isempty(out.pointing.azimuthDegGrid)
        error('plotR23AasPointingHeatmap:noPointing', ...
            ['OUT.pointing is missing or empty. Re-run with ' ...
             'computePointingHeatmap = true.']);
    end
    if nargin < 2 || isempty(which)
        which = 'azimuth';
    end
    if isstring(which) && isscalar(which)
        which = char(which);
    end
    if ~ischar(which)
        error('plotR23AasPointingHeatmap:badWhich', ...
            'WHICH must be ''azimuth'', ''elevation'', or ''both''.');
    end

    az = double(out.pointing.azGrid(:).');
    el = double(out.pointing.elGrid(:).');

    statSummary = '';
    if isfield(out.pointing, 'summaryStatistic') && ...
            ~isempty(out.pointing.summaryStatistic)
        statSummary = char(out.pointing.summaryStatistic);
    end

    numMc = 0;
    if isfield(out, 'stats') && isfield(out.stats, 'numMc')
        numMc = double(out.stats.numMc);
    end
    numBeams = 0;
    if isfield(out, 'stats') && isfield(out.stats, 'numBeams')
        numBeams = double(out.stats.numBeams);
    end
    sectorEirp = NaN;
    if isfield(out, 'stats') && isfield(out.stats, 'sectorEirpDbm')
        sectorEirp = double(out.stats.sectorEirpDbm);
    end
    envTag = '';
    if isfield(out, 'metadata') && isfield(out.metadata, 'environment')
        envTag = char(out.metadata.environment);
    end

    switch lower(which)
        case 'azimuth'
            fig = renderHeatmap(az, el, ...
                out.pointing.azimuthDegGrid, ...
                titleFor('azimuth', envTag, statSummary, ...
                         numMc, numBeams, sectorEirp), ...
                'Pointing azimuth [deg]   (relative to sector boresight)');
        case 'elevation'
            fig = renderHeatmap(az, el, ...
                out.pointing.elevationDegGrid, ...
                titleFor('elevation', envTag, statSummary, ...
                         numMc, numBeams, sectorEirp), ...
                'Pointing elevation [deg]   (0 = horizon)');
        case 'both'
            f1 = renderHeatmap(az, el, ...
                out.pointing.azimuthDegGrid, ...
                titleFor('azimuth', envTag, statSummary, ...
                         numMc, numBeams, sectorEirp), ...
                'Pointing azimuth [deg]   (relative to sector boresight)');
            f2 = renderHeatmap(az, el, ...
                out.pointing.elevationDegGrid, ...
                titleFor('elevation', envTag, statSummary, ...
                         numMc, numBeams, sectorEirp), ...
                'Pointing elevation [deg]   (0 = horizon)');
            fig = struct('azimuth', f1, 'elevation', f2);
        otherwise
            error('plotR23AasPointingHeatmap:badWhich', ...
                'WHICH must be ''azimuth'', ''elevation'', or ''both''.');
    end
end

% =====================================================================

function txt = titleFor(kind, envTag, stat, numMc, numBeams, sectorEirp)
    head = ['R23 Extended AAS antenna-face pointing - no path loss'];
    body = sprintf( ...
        ['mean %s pointing per direction (env=%s, numMc=%d, ' ...
         'numUesPerSector=%d, sectorEirp=%.2f dBm/100MHz, stat=%s)'], ...
        kind, envTag, numMc, numBeams, sectorEirp, stat);
    txt = sprintf('%s\n%s', head, body);
end

function fig = renderHeatmap(az, el, gridVals, titleText, cbLabel)
    fig = figure('Name', 'R23 AAS Pointing Heatmap', 'Color', 'w');
    imagesc(el, az, gridVals);
    set(gca, 'YDir', 'normal');
    xlabel('Elevation [deg]   (0 = horizon)');
    ylabel('Azimuth [deg]    (0 = sector boresight)');
    title(titleText);
    cb = colorbar;
    ylabel(cb, cbLabel);
    axis tight;
end
