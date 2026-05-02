function ref = imtAasLoadReferenceCutCsv(csvPath)
%IMTAASLOADREFERENCECUTCSV Load a reference EIRP pattern-cut CSV.
%
%   REF = imtAasLoadReferenceCutCsv(CSVPATH)
%
%   Reads a reference 1-D pattern-cut CSV produced by an external
%   reference generator (pycraf, ITU validation material, frozen
%   MATLAB-reviewed output, etc.) for the AAS-03 reference-validation
%   harness.
%
%   Required columns (case-insensitive header match):
%       angle_deg
%       eirp_dbm_per_100mhz
%
%   Optional columns:
%       gain_dbi
%       notes        (free-form text; preserved as a string column)
%
%   Output struct:
%       ref.csvPath              absolute path of the loaded CSV
%       ref.angleDeg             1xN row vector of angle samples [deg]
%       ref.eirpDbmPer100MHz     1xN row vector of EIRP samples
%       ref.gainDbi              1xN row vector of element/composite
%                                gain samples (only if column present)
%       ref.notes                1xN cell array of strings (only if
%                                column present)
%       ref.numPoints            scalar, equal to numel(ref.angleDeg)
%       ref.headerColumns        1xK cell array of header column names
%
%   Behavior:
%   * Missing file, malformed CSV, missing required columns, mismatched
%     row lengths, and non-finite required values are all hard errors.
%   * Comment lines starting with '#' or '%' and blank lines are skipped.
%   * Base MATLAB only - no toolbox-specific readers (readtable etc.).
%
%   See also imtAasComparePatternCut, plotImtAasReferenceComparison,
%   runAasReferenceValidation.

    if nargin < 1
        error('imtAasLoadReferenceCutCsv:notEnoughInputs', ...
            'imtAasLoadReferenceCutCsv requires a csvPath input.');
    end
    if ~(ischar(csvPath) || (isstring(csvPath) && isscalar(csvPath)))
        error('imtAasLoadReferenceCutCsv:invalidPath', ...
            'csvPath must be a char vector or scalar string.');
    end
    csvPath = char(csvPath);
    if isempty(csvPath)
        error('imtAasLoadReferenceCutCsv:invalidPath', ...
            'csvPath must be non-empty.');
    end
    if exist(csvPath, 'file') ~= 2
        error('imtAasLoadReferenceCutCsv:fileNotFound', ...
            'Reference CSV not found: %s', csvPath);
    end

    fid = fopen(csvPath, 'r');
    if fid < 0
        error('imtAasLoadReferenceCutCsv:cannotOpen', ...
            'Could not open %s for reading.', csvPath);
    end
    cleanupFid = onCleanup(@() fcloseSafe(fid));

    headerCols = {};
    dataCells  = {};

    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        trimmed = strtrim(line);
        if isempty(trimmed)
            continue;
        end
        if trimmed(1) == '#' || trimmed(1) == '%'
            continue;
        end
        if isempty(headerCols)
            headerCols = parseCsvLine(trimmed);
            headerCols = cellfun(@(s) lower(strtrim(s)), headerCols, ...
                'UniformOutput', false);
        else
            row = parseCsvLine(trimmed);
            if numel(row) ~= numel(headerCols)
                error('imtAasLoadReferenceCutCsv:rowLengthMismatch', ...
                    ['Row has %d fields but header has %d columns ', ...
                     'in %s. Row: "%s"'], numel(row), numel(headerCols), ...
                    csvPath, trimmed);
            end
            dataCells(end + 1, :) = row; %#ok<AGROW>
        end
    end
    clear cleanupFid;   %#ok<CLMVR>  forces fclose

    if isempty(headerCols)
        error('imtAasLoadReferenceCutCsv:emptyFile', ...
            'Reference CSV %s has no header line.', csvPath);
    end
    if isempty(dataCells)
        error('imtAasLoadReferenceCutCsv:noData', ...
            'Reference CSV %s has a header but no data rows.', csvPath);
    end

    requiredCols = {'angle_deg', 'eirp_dbm_per_100mhz'};
    for i = 1:numel(requiredCols)
        if ~any(strcmp(headerCols, requiredCols{i}))
            error('imtAasLoadReferenceCutCsv:missingColumn', ...
                ['Reference CSV %s is missing required column "%s". ', ...
                 'Columns found: %s'], csvPath, requiredCols{i}, ...
                strjoin(headerCols, ', '));
        end
    end

    angleIdx = find(strcmp(headerCols, 'angle_deg'), 1, 'first');
    eirpIdx  = find(strcmp(headerCols, 'eirp_dbm_per_100mhz'), 1, 'first');
    gainIdx  = find(strcmp(headerCols, 'gain_dbi'), 1, 'first');
    notesIdx = find(strcmp(headerCols, 'notes'), 1, 'first');

    nRows    = size(dataCells, 1);
    angleDeg = parseNumericColumn(dataCells(:, angleIdx), ...
        'angle_deg', csvPath);
    eirpDbm  = parseNumericColumn(dataCells(:, eirpIdx), ...
        'eirp_dbm_per_100mhz', csvPath);

    if ~all(isfinite(angleDeg))
        error('imtAasLoadReferenceCutCsv:nonFiniteAngle', ...
            'Reference CSV %s contains non-finite angle_deg values.', ...
            csvPath);
    end
    if ~all(isfinite(eirpDbm))
        error('imtAasLoadReferenceCutCsv:nonFiniteEirp', ...
            ['Reference CSV %s contains non-finite ', ...
             'eirp_dbm_per_100mhz values.'], csvPath);
    end

    ref = struct();
    ref.csvPath          = csvPath;
    ref.angleDeg         = angleDeg(:).';
    ref.eirpDbmPer100MHz = eirpDbm(:).';
    ref.numPoints        = nRows;
    ref.headerColumns    = headerCols;

    if ~isempty(gainIdx)
        gainDbi = parseNumericColumn(dataCells(:, gainIdx), ...
            'gain_dbi', csvPath);
        ref.gainDbi = gainDbi(:).';
    end
    if ~isempty(notesIdx)
        ref.notes = dataCells(:, notesIdx).';
    end
end

% =====================================================================

function fcloseSafe(fid)
    if ~isempty(fid) && fid >= 0
        try
            fclose(fid);
        catch
            % ignore - fd already closed or invalid
        end
    end
end

function fields = parseCsvLine(line)
%PARSECSVLINE Split a CSV line on commas, trimming whitespace per field.
%   Minimal splitter: this loader does not support quoted fields with
%   embedded commas. Reference CSVs are expected to use simple numeric
%   columns plus a short notes column without commas.
    parts = strsplit(line, ',');
    fields = cell(1, numel(parts));
    for i = 1:numel(parts)
        fields{i} = strtrim(parts{i});
    end
end

function vec = parseNumericColumn(strCells, colName, csvPath)
    n   = numel(strCells);
    vec = zeros(n, 1);
    for i = 1:n
        s = strCells{i};
        if isempty(s)
            error('imtAasLoadReferenceCutCsv:emptyValue', ...
                ['Reference CSV %s row %d column "%s" is empty.'], ...
                csvPath, i, colName);
        end
        v = sscanf(s, '%f', 1);
        if isempty(v)
            error('imtAasLoadReferenceCutCsv:parseFailed', ...
                ['Could not parse "%s" as numeric for column "%s" ', ...
                 'in %s row %d.'], s, colName, csvPath, i);
        end
        vec(i) = v;
    end
end
