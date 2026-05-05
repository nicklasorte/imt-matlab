function out = runR23AasEirpCdfGridExample(varargin)
%RUNR23AASEIRPCDFGRIDEXAMPLE End-to-end R23 AAS EIRP CDF-grid example.
%
%   OUT = runR23AasEirpCdfGridExample()
%   OUT = runR23AasEirpCdfGridExample('Name', Value, ...)
%
%   Runs a small deterministic Monte Carlo example of the R23 7/8 GHz
%   Extended AAS EIRP CDF-grid generator with:
%
%       opts.numMc                = 100
%       opts.environment          = 'urban'
%       opts.numUesPerSector      = 3
%       opts.maxEirpPerSector_dBm = 78.3
%       opts.seed                 = 1
%       opts.azGridDeg            = -180:2:180
%       opts.elGridDeg            = -90:2:30
%       opts.percentiles          = [5 50 95]
%
%   Optional name-value overrides are passed straight through to
%   runR23AasEirpCdfGrid. Examples:
%
%       % suburban macro with 10 UEs / sector and 75 dBm sector EIRP
%       runR23AasEirpCdfGridExample( ...
%           'environment', 'suburban', ...
%           'numUesPerSector', 10, ...
%           'maxEirpPerSector_dBm', 75);
%
%   Plots the mean / P50 / P95 EIRP maps and the pointing
%   azimuth + elevation heatmaps, saves PNG / CSV / metadata under
%   examples/output/, and prints the antenna-face EIRP anchors.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N, NO propagation, NO coordination
%   distance, and NO 19-site laydown.
%
%   Run from the repo root:
%       runR23AasEirpCdfGridExample
%
%   Or, with cd:
%       cd examples
%       runR23AasEirpCdfGridExample

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    opts = struct();
    opts.numMc                = 100;
    opts.environment          = 'urban';
    opts.numUesPerSector      = 3;
    opts.maxEirpPerSector_dBm = 78.3;
    opts.seed                 = 1;
    opts.azGridDeg            = -180:2:180;
    opts.elGridDeg            = -90:2:30;
    opts.percentiles          = [5 50 95];
    opts.outputCsvPath = fullfile(outDir, ...
        'r23_aas_eirp_cdf_grid_percentiles.csv');
    opts.outputMetadataPath = fullfile(outDir, ...
        'r23_aas_eirp_cdf_grid_metadata.json');

    % Apply optional name-value overrides supplied by the caller.
    for k = 1:2:numel(varargin)
        opts.(varargin{k}) = varargin{k+1};
    end

    out = runR23AasEirpCdfGrid(opts);

    % ---- plot --------------------------------------------------------
    figs = plotR23AasEirpCdfGrid(out, [50 95]);

    saveFigure(figs.mean, fullfile(outDir, 'r23_aas_eirp_mean_grid.png'));
    if isfield(figs.percentiles, 'p050')
        saveFigure(figs.percentiles.p050, ...
            fullfile(outDir, 'r23_aas_eirp_p50_grid.png'));
    end
    if isfield(figs.percentiles, 'p095')
        saveFigure(figs.percentiles.p095, ...
            fullfile(outDir, 'r23_aas_eirp_p95_grid.png'));
    end

    % ---- pointing heatmaps ------------------------------------------
    if isfield(out, 'pointing') && isstruct(out.pointing) && ...
            ~isempty(out.pointing.azimuthDegGrid)
        try
            azFig = plotR23AasPointingHeatmap(out, 'azimuth');
            saveFigure(azFig, fullfile(outDir, ...
                'r23_aas_pointing_az_grid.png'));
            elFig = plotR23AasPointingHeatmap(out, 'elevation');
            saveFigure(elFig, fullfile(outDir, ...
                'r23_aas_pointing_el_grid.png'));
        catch err
            fprintf('  pointing heatmap render failed: %s\n', err.message);
        end
    end

    % ---- print summary ----------------------------------------------
    perBeamPeak = out.stats.perBeamPeakEirpDbm;
    meanGrid = out.stats.mean_dBm;
    finiteMean = meanGrid(isfinite(meanGrid));

    fprintf('=========================================================\n');
    fprintf('  runR23AasEirpCdfGridExample (R23 7/8 GHz Extended AAS)\n');
    fprintf('=========================================================\n');
    fprintf('  numMc                : %d\n', out.stats.numMc);
    fprintf('  environment          : %s\n', out.metadata.environment);
    fprintf('  deployment           : %s\n', out.sector.deployment);
    fprintf('  cellRadius_m         : %.0f m\n', out.metadata.cellRadius_m);
    fprintf('  bsHeight_m           : %.1f m\n', out.metadata.bsHeight_m);
    fprintf('  numUesPerSector      : %d\n', out.stats.numUesPerSector);
    fprintf('  maxEirpPerSector_dBm : %.2f dBm / 100 MHz\n', ...
        out.metadata.maxEirpPerSector_dBm);
    fprintf('  perBeamPeakEirpDbm   : %.2f dBm / 100 MHz (%d-beam split)\n', ...
        perBeamPeak, out.stats.numBeams);
    if isempty(finiteMean)
        fprintf('  mean_dBm grid        : (no finite cells)\n');
    else
        fprintf('  mean_dBm min / mean / max : %.2f / %.2f / %.2f dBm\n', ...
            min(finiteMean), mean(finiteMean), max(finiteMean));
    end
    fprintf('---------------------------------------------------------\n');
    fprintf('  REMINDER: antenna-face EIRP only.\n');
    fprintf('    no path loss, no receiver antenna, no I / N,\n');
    fprintf('    no propagation, no coordination distance,\n');
    fprintf('    no 19-site laydown.\n');
    fprintf('=========================================================\n');
end

% =====================================================================

function saveFigure(fig, pngPath)
    if isempty(fig) || ~isgraphics(fig)
        return;
    end
    if exist('exportgraphics', 'file') == 2
        try
            exportgraphics(fig, pngPath, 'Resolution', 150);
            fprintf('  saved %s\n', pngPath);
            return;
        catch err
            fprintf('  exportgraphics failed (%s); falling back to saveas\n', ...
                err.message);
        end
    end
    try
        saveas(fig, pngPath);
        fprintf('  saved %s\n', pngPath);
    catch err
        fprintf('  could not save %s (%s)\n', pngPath, err.message);
    end
end
