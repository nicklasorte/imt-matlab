function figs = plotR23AasPointingHistogram(out, mode)
%PLOTR23AASPOINTINGHISTOGRAM Plot the joint (az, el) pointing-angle histogram.
%
%   FIGS = plotR23AasPointingHistogram(OUT)
%   FIGS = plotR23AasPointingHistogram(OUT, MODE)
%
%   OUT is the struct returned by runR23AasEirpCdfGrid with
%   opts.computePointingHistogram = true, so OUT.pointingHistogram.counts
%   is populated. MODE selects what the 2-D map shows:
%       'pmf'   (default) probability mass per (az, el) bin
%       'count'           raw sample counts per (az, el) bin
%
%   Renders three figures, returned in a struct:
%       FIGS.joint       2-D heatmap of the pointing PMF (or counts) over
%                        (steering az, steering el), with az on the y axis
%                        and el on the x axis -- the same orientation as
%                        the EIRP / gain / pointing heatmaps.
%       FIGS.azMarginal  1-D bar plot of the azimuth marginal counts.
%       FIGS.elMarginal  1-D bar plot of the elevation marginal counts.
%
%   This is the distribution of UE-driven beam pointing directions across
%   the Monte Carlo ensemble. It is NOT time-weighted (see the pointing
%   caveat in OUT.metadata.notes) and it is NOT EIRP.
%
%   See also: runR23AasEirpCdfGrid, imtAasPointingHistogram,
%             plotR23AasPointingHeatmap.

    if nargin < 1 || isempty(out) || ~isstruct(out)
        error('plotR23AasPointingHistogram:invalidOut', ...
            'OUT must be the struct returned by runR23AasEirpCdfGrid.');
    end
    if ~isfield(out, 'pointingHistogram') || ...
            ~isstruct(out.pointingHistogram) || ...
            isempty(out.pointingHistogram.counts)
        error('plotR23AasPointingHistogram:noHistogram', ...
            ['OUT.pointingHistogram is missing or empty. Re-run with ' ...
             'opts.computePointingHistogram = true.']);
    end
    if nargin < 2 || isempty(mode)
        mode = 'pmf';
    end
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('plotR23AasPointingHistogram:badMode', ...
            'MODE must be ''pmf'' or ''count''.');
    end
    mode = lower(mode);

    ph        = out.pointingHistogram;
    azCenters = double(ph.azCenters(:).');
    elCenters = double(ph.elCenters(:).');

    switch mode
        case 'pmf'
            M       = ph.pmf;
            cbLabel = 'Probability';
        case 'count'
            M       = double(ph.counts);
            cbLabel = 'Count';
        otherwise
            error('plotR23AasPointingHistogram:badMode', ...
                'MODE must be ''pmf'' or ''count'' (got ''%s'').', mode);
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

    xlabAz = 'Pointing azimuth [deg]   (relative to sector boresight)';
    xlabEl = 'Pointing elevation [deg]   (0 = horizon)';

    % ---- joint 2-D heatmap (az on y, el on x) -----------------------
    figJoint = figure('Name', 'R23 AAS Pointing Histogram', 'Color', 'w');
    imagesc(elCenters, azCenters, M);
    set(gca, 'YDir', 'normal');
    xlabel(xlabEl);
    ylabel(xlabAz);
    title(sprintf( ...
        ['R23 Extended AAS pointing-angle distribution (not time-weighted)' ...
         '\ndistribution of UE-driven beam pointing dirs ' ...
         '(env=%s, numMc=%d, numUesPerSector=%d)'], ...
        envTag, numMc, numBeams));
    cb = colorbar;
    ylabel(cb, cbLabel);
    % Use the shared heatmap colormap when the project provides one.
    if exist('imtAasHeatmapStyle', 'file') == 2
        try
            imtAasHeatmapStyle(gca);
        catch
            % Style helper is best-effort; fall back to the default map.
        end
    end
    axis tight;

    % ---- azimuth marginal -------------------------------------------
    figAz = figure('Name', 'R23 AAS Pointing Histogram - Azimuth marginal', ...
        'Color', 'w');
    bar(azCenters, double(ph.azMarginalCounts(:)));
    xlabel(xlabAz);
    ylabel('Count');
    title('Pointing azimuth marginal distribution');
    axis tight;

    % ---- elevation marginal -----------------------------------------
    figEl = figure('Name', 'R23 AAS Pointing Histogram - Elevation marginal', ...
        'Color', 'w');
    bar(elCenters, double(ph.elMarginalCounts(:)));
    xlabel(xlabEl);
    ylabel('Count');
    title('Pointing elevation marginal distribution');
    axis tight;

    figs = struct('joint', figJoint, 'azMarginal', figAz, 'elMarginal', figEl);
end
