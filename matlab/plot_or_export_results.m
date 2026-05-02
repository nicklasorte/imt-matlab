function out = plot_or_export_results(mcOut, cdfOut, opts)
%PLOT_OR_EXPORT_RESULTS Render / export single-sector EIRP CDF results.
%
%   OUT = plot_or_export_results(MCOUT, CDFOUT)
%   OUT = plot_or_export_results(MCOUT, CDFOUT, OPTS)
%
%   Renders simple PNG plots of the per-cell P50 / P95 EIRP maps and / or
%   exports the percentile maps to CSV. Returns the resolved opts so the
%   caller can see what was written.
%
%   Inputs:
%       MCOUT   struct from run_monte_carlo_snapshots.
%       CDFOUT  struct from compute_cdf_per_grid_point.
%       OPTS    optional struct:
%                 .savePlot        default false
%                 .plotPath        default './single_sector_eirp_p95.png'
%                 .saveCsv         default false
%                 .csvPath         default './single_sector_eirp_pcts.csv'
%                 .show            default true
%                 .plotPercentile  default 95 (must be in CDFOUT.percentiles)
%
%   The plot uses base MATLAB / imagesc and labels axes in degrees. The
%   CSV has columns:
%       az_deg, el_deg, mean_dBm, min_dBm, max_dBm,
%       p<P1>_dBm, p<P2>_dBm, ...
%
%   Plotting and CSV writing are both optional and silently skipped when
%   their respective save flags are false.

    if nargin < 1 || isempty(mcOut)
        error('plot_or_export_results:missingMc', ...
            'mcOut struct (run_monte_carlo_snapshots) is required.');
    end
    if nargin < 2 || isempty(cdfOut)
        error('plot_or_export_results:missingCdf', ...
            'cdfOut struct (compute_cdf_per_grid_point) is required.');
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    opts.savePlot       = getOpt(opts, 'savePlot',       false);
    opts.plotPath       = getOpt(opts, 'plotPath',       fullfile(pwd, ...
                                'single_sector_eirp_p95.png'));
    opts.saveCsv        = getOpt(opts, 'saveCsv',        false);
    opts.csvPath        = getOpt(opts, 'csvPath',        fullfile(pwd, ...
                                'single_sector_eirp_pcts.csv'));
    opts.show           = getOpt(opts, 'show',           true);
    opts.plotPercentile = getOpt(opts, 'plotPercentile', 95);

    pIdx = find(abs(cdfOut.percentiles - opts.plotPercentile) < 1e-9, 1);
    if isempty(pIdx)
        error('plot_or_export_results:plotPercentileMissing', ...
            ['plotPercentile = %g is not in cdfOut.percentiles. ' ...
             'Recompute compute_cdf_per_grid_point with that level.'], ...
            opts.plotPercentile);
    end

    if opts.savePlot
        ensureDir(opts.plotPath);
        fig = figure('Visible', booleanToOnOff(opts.show));
        cleanupFig = onCleanup(@() closeIfNotShown(fig, opts.show));

        slice = cdfOut.percentileEirpDbm(:, :, pIdx).';
        imagesc(mcOut.azGridDeg, mcOut.elGridDeg, slice);
        set(gca, 'YDir', 'normal');
        xlabel('azimuth [deg, sector frame]');
        ylabel('elevation [deg]');
        title(sprintf('R23 single-sector aggregate EIRP P%g (numSnapshots=%d)', ...
            opts.plotPercentile, mcOut.numSnapshots));
        cb = colorbar();
        ylabel(cb, 'EIRP [dBm / 100 MHz]');
        try
            saveas(fig, opts.plotPath);
        catch err
            warning('plot_or_export_results:saveFailed', ...
                'Could not save plot to %s (%s).', opts.plotPath, err.message);
        end
    end

    if opts.saveCsv
        ensureDir(opts.csvPath);
        write_csv(opts.csvPath, mcOut, cdfOut);
    end

    out = opts;
end

% =====================================================================

function v = getOpt(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end

function ensureDir(p)
    [d, ~, ~] = fileparts(p);
    if ~isempty(d) && exist(d, 'dir') ~= 7
        mkdir(d);
    end
end

function s = booleanToOnOff(tf)
    if logical(tf), s = 'on'; else, s = 'off'; end
end

function closeIfNotShown(fig, show)
    if ~logical(show) && ishandle(fig)
        close(fig);
    end
end

function write_csv(csvPath, mcOut, cdfOut)
    fid = fopen(csvPath, 'w');
    if fid < 0
        warning('plot_or_export_results:csvOpenFailed', ...
            'Could not open %s for writing.', csvPath);
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    pcts = cdfOut.percentiles;
    headerCells = {'az_deg', 'el_deg', 'mean_dBm', 'min_dBm', 'max_dBm'};
    for j = 1:numel(pcts)
        headerCells{end+1} = sprintf('p%g_dBm', pcts(j));     %#ok<AGROW>
    end
    fprintf(fid, '%s\n', strjoin(headerCells, ','));

    az = mcOut.azGridDeg;
    el = mcOut.elGridDeg;
    Naz = numel(az);
    Nel = numel(el);
    for ia = 1:Naz
        for ie = 1:Nel
            row = [az(ia), el(ie), ...
                   cdfOut.meanEirpDbm(ia, ie), ...
                   cdfOut.minEirpDbm(ia, ie), ...
                   cdfOut.maxEirpDbm(ia, ie)];
            for j = 1:numel(pcts)
                row(end+1) = cdfOut.percentileEirpDbm(ia, ie, j); %#ok<AGROW>
            end
            fprintf(fid, '%s\n', strjoin(arrayfun( ...
                @(v) sprintf('%.6g', v), row, ...
                'UniformOutput', false), ','));
        end
    end
end
