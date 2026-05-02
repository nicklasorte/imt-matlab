function runAasEirpValidationExport()
%RUNAASEIRPVALIDATIONEXPORT Validate / export the R23 macro AAS EIRP grid.
%
%   runAasEirpValidationExport()
%
%   End-to-end MVP example for the AAS-02 validation / export layer:
%
%     1. Build the R23 default IMT AAS parameters.
%     2. Generate the per-direction antenna-face EIRP grid for the
%        nominal beam:
%             azGridDeg  = -180:1:180
%             elGridDeg  =  -90:1:90
%             steerAzDeg =  0
%             steerElDeg = -9       (sub-array 3 deg + mech 6 deg downtilt)
%     3. Extract horizontal / vertical 1-D cuts at the steering angle
%        (imtAasPatternCuts).
%     4. Plot the EIRP grid (plotImtAasEirpGrid) and the two cuts
%        (plotImtAasPatternCuts).
%     5. Export a long-form CSV + JSON metadata sidecar
%        (imtAasExportEirpGridCsv).
%     6. If exportgraphics / saveas is available, save PNGs of all three
%        figures.
%
%   Output artifacts (under examples/output/):
%       aas_eirp_grid_r23_macro.csv
%       aas_eirp_grid_r23_macro_metadata.json
%       aas_eirp_grid_r23_macro.png
%       aas_eirp_horizontal_cut_r23_macro.png
%       aas_eirp_vertical_cut_r23_macro.png
%
%   Scope: deterministic R23 macro AAS antenna-face EIRP only. This is
%   not a path-loss / receiver / coordination-distance / I-N pipeline.
%
%   Run from the repo root:
%       runAasEirpValidationExport
%
%   Or, with cd:
%       cd examples
%       runAasEirpValidationExport

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    params = imtAasDefaultParams();

    azGridDeg  = -180:1:180;
    elGridDeg  =  -90:1:90;
    steerAzDeg = 0;
    steerElDeg = -9;

    eirpGridDbm = imtAasEirpGrid(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, params.sectorEirpDbm, params);

    cuts = imtAasPatternCuts(azGridDeg, elGridDeg, eirpGridDbm, ...
        steerAzDeg, steerElDeg);

    % ---- plots --------------------------------------------------------
    figGrid    = plotImtAasEirpGrid(azGridDeg, elGridDeg, eirpGridDbm);
    figCuts    = plotImtAasPatternCuts(cuts);

    % ---- output paths -------------------------------------------------
    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end
    csvPath = fullfile(outDir, 'aas_eirp_grid_r23_macro.csv');

    % ---- metadata for the CSV sidecar --------------------------------
    metadata = struct( ...
        'created_by',                  'runAasEirpValidationExport', ...
        'function',                    'imtAasExportEirpGridCsv', ...
        'sector_eirp_dbm_per_100mhz',  params.sectorEirpDbm, ...
        'bandwidth_mhz',               params.bandwidthMHz, ...
        'frequency_mhz',               params.frequencyMHz, ...
        'steer_az_deg',                steerAzDeg, ...
        'steer_el_deg',                steerElDeg, ...
        'mechanical_downtilt_deg',     params.mechanicalDowntiltDeg, ...
        'subarray_downtilt_deg',       params.subarrayDowntiltDeg, ...
        'num_rows',                    params.numRows, ...
        'num_columns',                 params.numColumns, ...
        'notes',                       ['Deterministic R23 macro AAS MVP; ', ...
                                        'antenna-face EIRP only (no path loss).']);

    expOut = imtAasExportEirpGridCsv(azGridDeg, elGridDeg, eirpGridDbm, ...
        csvPath, metadata);

    % ---- PNGs (best effort) ------------------------------------------
    pngGridPath  = fullfile(outDir, 'aas_eirp_grid_r23_macro.png');
    pngHorizPath = fullfile(outDir, 'aas_eirp_horizontal_cut_r23_macro.png');
    pngVertPath  = fullfile(outDir, 'aas_eirp_vertical_cut_r23_macro.png');
    saveFigure(figGrid,         pngGridPath);
    saveFigure(figCuts.horizontal, pngHorizPath);
    saveFigure(figCuts.vertical,   pngVertPath);

    % ---- summary ------------------------------------------------------
    fprintf('\n--- runAasEirpValidationExport summary ---\n');
    fprintf('  peak EIRP                : %.3f dBm/100 MHz\n', cuts.peakEirpDbm);
    fprintf('  peak (az, el)            : (%.2f, %.2f) deg\n', ...
        cuts.peakAzDeg, cuts.peakElDeg);
    fprintf('  steering (az, el)        : (%.2f, %.2f) deg\n', ...
        steerAzDeg, steerElDeg);
    fprintf('  CSV path                 : %s\n', expOut.csvPath);
    fprintf('  metadata path            : %s   [%s]\n', ...
        expOut.metadataPath, expOut.metadataFormat);
    fprintf('  CSV rows written         : %d\n', expOut.numRowsWritten);
    fprintf('  grid PNG                 : %s\n', pngGridPath);
    fprintf('  horizontal-cut PNG       : %s\n', pngHorizPath);
    fprintf('  vertical-cut PNG         : %s\n', pngVertPath);
    fprintf('-----------------------------------------\n');
end

% =====================================================================

function saveFigure(figHandle, pngPath)
%SAVEFIGURE Best-effort PNG export, swallowing toolbox-availability errors.
    if isempty(figHandle) || ~isgraphics(figHandle)
        return;
    end
    if exist('exportgraphics', 'file') == 2 ...
            || exist('exportgraphics', 'builtin') == 5
        try
            exportgraphics(figHandle, pngPath, 'Resolution', 150);
            return;
        catch err
            fprintf('  [warn] exportgraphics failed for %s (%s); ', ...
                pngPath, err.message);
            fprintf('falling back to saveas.\n');
        end
    end
    try
        saveas(figHandle, pngPath);
    catch err
        fprintf('  [warn] could not save %s (%s).\n', pngPath, err.message);
    end
end
