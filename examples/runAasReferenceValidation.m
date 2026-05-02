function summary = runAasReferenceValidation()
%RUNAASREFERENCEVALIDATION Validate AAS EIRP cuts against reference CSVs.
%
%   SUMMARY = runAasReferenceValidation()
%
%   AAS-03 reference-validation harness. Generates the nominal R23 macro
%   AAS EIRP grid, extracts horizontal / vertical pattern cuts, and -
%   when reference CSVs are present under references/aas/ - compares
%   them against the references with bounded dB error metrics, plots
%   the comparisons, and writes a summary CSV to examples/output/.
%
%   Reference CSVs (optional):
%       references/aas/r23_macro_horizontal_cut.csv
%       references/aas/r23_macro_vertical_cut.csv
%
%   When the CSVs are missing, this driver prints a clear "skipped"
%   message and returns without failure. When they are present, it
%   produces:
%       examples/output/aas_reference_validation_summary.csv
%       examples/output/aas_reference_horizontal_comparison.png
%       examples/output/aas_reference_vertical_comparison.png
%
%   Output struct (always returned):
%       summary.skipped               logical
%       summary.reason                char (only when skipped)
%       summary.azGridDeg             grid used
%       summary.elGridDeg             grid used
%       summary.steerAzDeg
%       summary.steerElDeg
%       summary.cuts                  imtAasPatternCuts output
%       summary.references            struct with .horizontalPath /
%                                       .verticalPath / .horizontalExists /
%                                       .verticalExists
%       summary.horizontal            imtAasComparePatternCut output (if
%                                       reference present)
%       summary.vertical              imtAasComparePatternCut output (if
%                                       reference present)
%       summary.summaryCsvPath        path to validation summary CSV (if
%                                       written)
%       summary.allPassed             logical (true iff all present
%                                       comparisons passed)
%
%   Scope: antenna-face EIRP only. No path loss, no receiver, no
%   coordination distance.
%
%   See also imtAasLoadReferenceCutCsv, imtAasComparePatternCut,
%   plotImtAasReferenceComparison, imtAasPatternCuts, imtAasEirpGrid.

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    summary = struct();
    summary.skipped = false;
    summary.reason  = '';

    params = imtAasDefaultParams();

    azGridDeg  = -180:1:180;
    elGridDeg  =  -90:1:90;
    steerAzDeg = 0;
    steerElDeg = -9;

    eirpGridDbm = imtAasEirpGrid(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, params.sectorEirpDbm, params);
    cuts = imtAasPatternCuts(azGridDeg, elGridDeg, eirpGridDbm, ...
        steerAzDeg, steerElDeg);

    summary.azGridDeg  = azGridDeg;
    summary.elGridDeg  = elGridDeg;
    summary.steerAzDeg = steerAzDeg;
    summary.steerElDeg = steerElDeg;
    summary.cuts       = cuts;

    refDir   = fullfile(repoRoot, 'references', 'aas');
    horizRef = fullfile(refDir, 'r23_macro_horizontal_cut.csv');
    vertRef  = fullfile(refDir, 'r23_macro_vertical_cut.csv');

    horizExists = exist(horizRef, 'file') == 2;
    vertExists  = exist(vertRef,  'file') == 2;

    summary.references = struct( ...
        'horizontalPath',   horizRef, ...
        'verticalPath',     vertRef, ...
        'horizontalExists', horizExists, ...
        'verticalExists',   vertExists);

    if ~horizExists && ~vertExists
        summary.skipped = true;
        summary.reason  = sprintf( ...
            ['No reference CSVs found under %s. ', ...
             'Reference validation skipped (this is not a failure). ', ...
             'See references/aas/README.md for the expected format.'], ...
            refDir);
        fprintf('\n--- runAasReferenceValidation ---\n');
        fprintf('  [SKIP] %s\n', summary.reason);
        fprintf('---------------------------------\n');
        summary.allPassed = true;
        return;
    end

    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    summaryRows = {};

    fprintf('\n--- runAasReferenceValidation ---\n');
    fprintf('  reference dir: %s\n', refDir);

    summary.allPassed = true;

    % ---- horizontal cut ----------------------------------------------
    if horizExists
        ref = imtAasLoadReferenceCutCsv(horizRef);
        cmpH = imtAasComparePatternCut(cuts.azGridDeg, ...
            cuts.horizontalCutAtSteerElDbm, ...
            ref.angleDeg, ref.eirpDbmPer100MHz);
        summary.horizontal = cmpH;

        figH = plotImtAasReferenceComparison(cmpH, ...
            sprintf('Horizontal cut (el = %.2f deg)', ...
                cuts.horizontalCutElevationDeg));
        pngH = fullfile(outDir, 'aas_reference_horizontal_comparison.png');
        saveFigure(figH, pngH);

        printCmpResult('horizontal', cmpH);
        summary.allPassed = summary.allPassed && cmpH.pass;

        summaryRows(end + 1, :) = {'horizontal', horizRef, cmpH}; %#ok<AGROW>
    else
        fprintf('  [SKIP] horizontal: no reference at %s\n', horizRef);
    end

    % ---- vertical cut -------------------------------------------------
    if vertExists
        ref = imtAasLoadReferenceCutCsv(vertRef);
        cmpV = imtAasComparePatternCut(cuts.elGridDeg, ...
            cuts.verticalCutAtSteerAzDbm, ...
            ref.angleDeg, ref.eirpDbmPer100MHz);
        summary.vertical = cmpV;

        figV = plotImtAasReferenceComparison(cmpV, ...
            sprintf('Vertical cut (az = %.2f deg)', ...
                cuts.verticalCutAzimuthDeg));
        pngV = fullfile(outDir, 'aas_reference_vertical_comparison.png');
        saveFigure(figV, pngV);

        printCmpResult('vertical', cmpV);
        summary.allPassed = summary.allPassed && cmpV.pass;

        summaryRows(end + 1, :) = {'vertical', vertRef, cmpV}; %#ok<AGROW>
    else
        fprintf('  [SKIP] vertical: no reference at %s\n', vertRef);
    end

    % ---- summary CSV --------------------------------------------------
    if ~isempty(summaryRows)
        summaryCsvPath = fullfile(outDir, ...
            'aas_reference_validation_summary.csv');
        writeSummaryCsv(summaryCsvPath, summaryRows);
        summary.summaryCsvPath = summaryCsvPath;
        fprintf('  summary CSV   : %s\n', summaryCsvPath);
    end

    if summary.allPassed
        fprintf('  RESULT: PASSED\n');
    else
        fprintf('  RESULT: FAILED\n');
    end
    fprintf('---------------------------------\n');
end

% =====================================================================

function printCmpResult(label, cmp)
    if cmp.pass
        tag = 'PASS';
    else
        tag = 'FAIL';
    end
    fprintf(['  [%s] %s : maxAbs=%.4f dB, RMS=%.4f dB, ', ...
             'maxAbsMain=%.4f dB, n=%d (ignored=%d)\n'], ...
        tag, label, cmp.maxAbsErrorDb, cmp.rmsErrorDb, ...
        cmp.maxAbsErrorMainLobeDb, cmp.numCompared, cmp.numIgnored);
    if ~isempty(cmp.failReasons)
        for i = 1:numel(cmp.failReasons)
            fprintf('         reason: %s\n', cmp.failReasons{i});
        end
    end
end

function writeSummaryCsv(csvPath, rows)
    fid = fopen(csvPath, 'w');
    if fid < 0
        error('runAasReferenceValidation:cannotOpen', ...
            'Could not open %s for writing.', csvPath);
    end
    cleanupObj = onCleanup(@() fcloseSafe(fid));
    fprintf(fid, ['cut,reference_path,num_compared,num_ignored,', ...
                  'num_main_lobe,peak_angle_deg,peak_actual_dbm,', ...
                  'max_abs_error_db,rms_error_db,mean_error_db,', ...
                  'max_abs_error_main_lobe_db,rms_error_main_lobe_db,', ...
                  'max_abs_error_db_threshold,rms_error_db_threshold,', ...
                  'main_lobe_max_abs_error_db_threshold,', ...
                  'main_lobe_window_deg,pass\n']);
    for i = 1:size(rows, 1)
        label = rows{i, 1};
        path  = rows{i, 2};
        cmp   = rows{i, 3};
        fprintf(fid, ['%s,%s,%d,%d,%d,%.6f,%.6f,', ...
                      '%.6f,%.6f,%.6f,%.6f,%.6f,', ...
                      '%.6f,%.6f,%.6f,%.6f,%d\n'], ...
            label, path, cmp.numCompared, cmp.numIgnored, ...
            cmp.numMainLobe, cmp.peakAngleDeg, cmp.peakActualDbm, ...
            cmp.maxAbsErrorDb, cmp.rmsErrorDb, cmp.meanErrorDb, ...
            cmp.maxAbsErrorMainLobeDb, cmp.rmsErrorMainLobeDb, ...
            cmp.opts.maxAbsErrorDb, cmp.opts.rmsErrorDb, ...
            cmp.opts.mainLobeMaxAbsErrorDb, cmp.mainLobeWindowDeg, ...
            double(cmp.pass));
    end
    clear cleanupObj;   %#ok<CLMVR>  forces fclose
end

function fcloseSafe(fid)
    if ~isempty(fid) && fid >= 0
        try
            fclose(fid);
        catch
        end
    end
end

function saveFigure(figHandle, pngPath)
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
