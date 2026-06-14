function figs = plotR23AasPointingWeightedMap(out, quantity)
%PLOTR23AASPOINTINGWEIGHTEDMAP Probability-weighted max-EIRP main-beam map.
%
%   FIGS = plotR23AasPointingWeightedMap(OUT)
%   FIGS = plotR23AasPointingWeightedMap(OUT, QUANTITY)
%
%   OUT is the struct returned by runR23AasEirpCdfGrid with
%   opts.pointingWeightedMap = true. QUANTITY is one of:
%       'eirp'   (default) plots OUT.pointingWeightedMap.eirpWeightedDbm
%       'gain'             plots OUT.pointingWeightedMap.gainWeightedDbi
%
%   Each cell shows the max-EIRP main beam (the PEAK sector EIRP / peak
%   antenna gain, which is essentially constant) scaled by the probability
%   the array actually steers there: the "worst-case-but-likely" main-beam
%   map for the FSS-zone (0,0) analysis. Cells the beam never points to are
%   -Inf. This is antenna-face EIRP / gain only - it is NOT path loss.
%
%   See also: runR23AasEirpCdfGrid, plotR23AasPointingHeatmap,
%             plotR23AasPointingHistogram, imtAasHeatmapStyle.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotR23AasPointingWeightedMap:invalidOut', ...
            'OUT must be the struct returned by runR23AasEirpCdfGrid.');
    end
    if ~isfield(out, 'pointingWeightedMap') || ...
            ~isstruct(out.pointingWeightedMap) || ...
            isempty(out.pointingWeightedMap.eirpWeightedDbm)
        error('plotR23AasPointingWeightedMap:noWeightedMap', ...
            ['OUT.pointingWeightedMap is missing or empty. Re-run with ' ...
             'opts.pointingWeightedMap = true.']);
    end
    if nargin < 2 || isempty(quantity)
        quantity = 'eirp';
    end
    if isstring(quantity) && isscalar(quantity)
        quantity = char(quantity);
    end
    if ~ischar(quantity)
        error('plotR23AasPointingWeightedMap:badQuantity', ...
            'QUANTITY must be ''eirp'' or ''gain''.');
    end

    pw = out.pointingWeightedMap;
    az = double(pw.azGrid(:).');
    el = double(pw.elGrid(:).');

    switch lower(quantity)
        case 'eirp'
            M       = pw.eirpWeightedDbm;
            cbLabel = 'Weighted EIRP [dBm/100MHz]';
        case 'gain'
            M       = pw.gainWeightedDbi;
            cbLabel = 'Weighted gain [dBi]';
        otherwise
            error('plotR23AasPointingWeightedMap:badQuantity', ...
                'QUANTITY must be ''eirp'' or ''gain''.');
    end

    envTag = '';
    if isfield(out, 'metadata') && isfield(out.metadata, 'environment')
        envTag = char(out.metadata.environment);
    end
    numMc = 0;
    if isfield(out, 'stats') && isfield(out.stats, 'numMc')
        numMc = double(out.stats.numMc);
    end
    numBeams = 0;
    if isfield(out, 'stats') && isfield(out.stats, 'numBeams')
        numBeams = double(out.stats.numBeams);
    end

    figs = renderWeightedMap(az, el, M, ...
        titleFor(lower(quantity), envTag, numMc, numBeams), cbLabel);
end

% =====================================================================

function txt = titleFor(quantity, envTag, numMc, numBeams)
    head = 'R23 Extended AAS max-EIRP main beam weighted by pointing probability';
    body = sprintf( ...
        ['%s, worst-case-but-likely (env=%s, numMc=%d, ' ...
         'numUesPerSector=%d)'], quantity, envTag, numMc, numBeams);
    txt = sprintf('%s\n%s', head, body);
end

function fig = renderWeightedMap(az, el, gridVals, titleText, cbLabel)
    fig = figure('Name', 'R23 AAS Pointing-Weighted Map', 'Color', 'w');
    ax  = axes(fig);
    imagesc(ax, el, az, gridVals);
    set(ax, 'YDir', 'normal');
    xlabel(ax, 'Pointing elevation [deg]   (0 = horizon)');
    ylabel(ax, 'Pointing azimuth [deg]    (relative to sector boresight)');
    title(ax, titleText);
    cb = colorbar(ax);
    ylabel(cb, cbLabel);
    axis(ax, 'tight');
    if exist('imtAasHeatmapStyle', 'file') == 2
        imtAasHeatmapStyle(ax);
    end
end
