function out = runR23AasMorphologyHeatmaps(eirpPercentile)
%RUNR23AASMORPHOLOGYHEATMAPS Standardized urban vs suburban AAS heatmaps.
%
%   OUT = runR23AasMorphologyHeatmaps()
%   OUT = runR23AasMorphologyHeatmaps(EIRPPERCENTILE)
%
%   Produces two standardized heatmaps per morphology (urban and suburban)
%   for the R23 7/8 GHz Extended AAS, so the DoW review can compare the two
%   deployments side by side:
%
%       (1) EIRP at a chosen percentile [dBm / 100 MHz]
%       (2) realized served-beam gain  [dBi]
%
%   Both morphologies use the SAME geometry preset, seed, grids and
%   opts.outputDomain = 'both', so the only difference is the deployment
%   environment. Comparability rule: EIRP and gain are different quantities,
%   so TWO shared color-axes are used -- one common CLim across {urban,
%   suburban} for the EIRP pair, and a separate common CLim across {urban,
%   suburban} for the gain pair. All four figures use the standard IMT-AAS
%   colormap (via imtAasHeatmapStyle) so the two EIRP maps are directly
%   comparable and the two gain maps are directly comparable.
%
%   EIRPPERCENTILE (default 95) selects the EIRP and gain percentile slice;
%   change it at the call site or via the constant at the top of the body.
%
%   Saves four PNGs to examples/output/ and prints the assumptions table
%   (imtAasAssumptionsTable) for each morphology:
%       eirp_urban_p<P>.png      eirp_suburban_p<P>.png
%       gain_urban.png           gain_suburban.png
%
%   This is antenna-face EIRP / gain only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N, NO propagation, NO coordination
%   distance, and NO 19-site laydown.
%
%   Run from the repo root:
%       runR23AasMorphologyHeatmaps
%   Or:
%       cd examples
%       runR23AasMorphologyHeatmaps
%
%   See also: runR23AasEirpCdfGrid, plotR23AasEirpCdfGrid,
%             plotR23AasGainHeatmap, imtAasHeatmapStyle,
%             imtAasAssumptionsTable.

    % ---- parameters (easy to change) --------------------------------
    if nargin < 1 || isempty(eirpPercentile)
        eirpPercentile = 95;     % EIRP + gain percentile slice to render
    end
    pct = double(eirpPercentile);

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

    % ---- shared run configuration (only environment differs) --------
    common = struct();
    common.aasGeometryPreset = 'r23_1x3_default';
    common.numMc             = 200;
    common.seed              = 7;
    common.azGridDeg         = -90:2:90;
    common.elGridDeg         = -20:1:6;
    common.percentiles       = unique([50 95 pct]);
    common.outputDomain      = 'both';

    urban    = runMorphology(common, 'urban');
    suburban = runMorphology(common, 'suburban');

    % ---- shared color-axes (EIRP pair vs gain pair) -----------------
    eirpU = pctSlice(urban.percentileMaps,        pct);
    eirpS = pctSlice(suburban.percentileMaps,     pct);
    gainU = pctSlice(urban.gainPercentileMaps,    pct);
    gainS = pctSlice(suburban.gainPercentileMaps, pct);

    eirpClim = sharedClim([eirpU(:); eirpS(:)]);
    gainClim = sharedClim([gainU(:); gainS(:)]);

    cmap = imtAasHeatmapStyle();   % the standard IMT-AAS colormap name

    % ---- render the four comparable heatmaps ------------------------
    pKey = sprintf('p%03d', round(pct));

    feU = plotR23AasEirpCdfGrid(urban,    pct, 'Colormap', cmap, 'CLim', eirpClim);
    feS = plotR23AasEirpCdfGrid(suburban, pct, 'Colormap', cmap, 'CLim', eirpClim);
    fgU = plotR23AasGainHeatmap(urban,    pct, 'Colormap', cmap, 'CLim', gainClim);
    fgS = plotR23AasGainHeatmap(suburban, pct, 'Colormap', cmap, 'CLim', gainClim);

    saveFigure(feU.percentiles.(pKey), ...
        fullfile(outDir, sprintf('eirp_urban_p%g.png', pct)));
    saveFigure(feS.percentiles.(pKey), ...
        fullfile(outDir, sprintf('eirp_suburban_p%g.png', pct)));
    saveFigure(fgU.percentiles.(pKey), fullfile(outDir, 'gain_urban.png'));
    saveFigure(fgS.percentiles.(pKey), fullfile(outDir, 'gain_suburban.png'));

    % ---- assumptions tables (printed to console) --------------------
    fprintf('\n##### URBAN morphology assumptions #####\n');
    Tu = imtAasAssumptionsTable(urban);
    fprintf('\n##### SUBURBAN morphology assumptions #####\n');
    Ts = imtAasAssumptionsTable(suburban);

    % ---- summary ----------------------------------------------------
    fprintf('\n=========================================================\n');
    fprintf('  runR23AasMorphologyHeatmaps (R23 7/8 GHz Extended AAS)\n');
    fprintf('=========================================================\n');
    fprintf('  percentile rendered  : P%g\n', pct);
    fprintf('  shared EIRP CLim     : [%.1f %.1f] dBm/100MHz\n', ...
        eirpClim(1), eirpClim(2));
    fprintf('  shared gain CLim     : [%.1f %.1f] dBi\n', ...
        gainClim(1), gainClim(2));
    fprintf('  output folder        : %s\n', outDir);
    fprintf('---------------------------------------------------------\n');
    fprintf('  REMINDER: antenna-face EIRP / gain only.\n');
    fprintf('    no path loss, no receiver antenna, no I / N,\n');
    fprintf('    no propagation, no coordination distance,\n');
    fprintf('    no 19-site laydown.\n');
    fprintf('=========================================================\n');

    out = struct();
    out.eirpPercentile     = pct;
    out.urban              = urban;
    out.suburban           = suburban;
    out.eirpClim           = eirpClim;
    out.gainClim           = gainClim;
    out.colormap           = cmap;
    out.assumptionsUrban   = Tu;
    out.assumptionsSuburban = Ts;
    out.figures = struct( ...
        'eirpUrban',    feU.percentiles.(pKey), ...
        'eirpSuburban', feS.percentiles.(pKey), ...
        'gainUrban',    fgU.percentiles.(pKey), ...
        'gainSuburban', fgS.percentiles.(pKey));
end

% =====================================================================

function out = runMorphology(common, environment)
    opts = common;
    opts.environment = environment;
    out = runR23AasEirpCdfGrid(opts);
end

function s = pctSlice(maps, p)
%PCTSLICE Naz x Nel slice of a percentile map at percentile P.
    avail = double(maps.percentiles(:).');
    idx = find(abs(avail - p) < 1e-9, 1, 'first');
    if isempty(idx)
        error('runR23AasMorphologyHeatmaps:missingPercentile', ...
            'Percentile %.3g is not present in the result maps.', p);
    end
    s = maps.values(:, :, idx);
end

function c = sharedClim(vals)
%SHAREDCLIM Outward-rounded [lo hi] over finite values for a shared color-axis.
    v = double(vals(:));
    v = v(isfinite(v));
    if isempty(v)
        c = [0 1];
        return;
    end
    lo = floor(min(v));
    hi = ceil(max(v));
    if hi <= lo
        hi = lo + 1;
    end
    c = [lo hi];
end

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
