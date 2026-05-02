function out = imtAasExportEirpGridCsv(azGridDeg, elGridDeg, eirpGridDbm, ...
        outputPath, metadata)
%IMTAASEXPORTEIRPGRIDCSV Long-form CSV export for an AAS EIRP grid.
%
%   OUT = imtAasExportEirpGridCsv(AZGRIDDEG, ELGRIDDEG, EIRPGRIDDBM, ...
%                                 OUTPUTPATH, METADATA)
%
%   Writes an AAS EIRP grid to a long-form CSV with three columns:
%
%       az_deg, el_deg, eirp_dbm_per_100mhz
%
%   plus a sidecar metadata file next to the CSV. The CSV has one header
%   row and Naz * Nel data rows (one per (az, el) cell). Azimuth varies
%   slowest, elevation fastest, matching the [Naz x Nel] ndgrid layout
%   used by imtAasEirpGrid.
%
%   Inputs:
%       azGridDeg     vector, azimuth grid [deg].
%       elGridDeg     vector, elevation grid [deg].
%       eirpGridDbm   [Naz x Nel] matrix from imtAasEirpGrid.
%       outputPath    string / char with a .csv path. The directory is
%                     created if it does not already exist.
%       metadata      optional struct of additional metadata fields. The
%                     exporter merges these on top of the defaults below
%                     before writing the sidecar.
%
%   Default metadata (over-writable via the METADATA struct):
%       created_by                  'imtAasExportEirpGridCsv'
%       function                    'imtAasExportEirpGridCsv'
%       sector_eirp_dbm_per_100mhz  max(eirpGridDbm(:))
%       bandwidth_mhz               []
%       frequency_mhz               []
%       steer_az_deg                []
%       steer_el_deg                []
%       mechanical_downtilt_deg     []
%       subarray_downtilt_deg       []
%       num_rows                    []
%       num_columns                 []
%       notes                       'Antenna-face EIRP only; deterministic R23 macro AAS MVP.'
%
%   Sidecar metadata path: <outputPath without .csv>_metadata.json. JSON
%   is preferred (jsonencode); when jsonencode is unavailable, a plain
%   key=value text fallback is written to the same path and the result
%   struct reports out.metadataFormat = 'text'.
%
%   Output struct:
%       out.csvPath          absolute path to the written CSV
%       out.metadataPath     absolute path to the sidecar metadata file
%       out.metadataFormat   'json' or 'text'
%       out.numRowsWritten   number of data rows in the CSV (= Naz*Nel)
%       out.peakEirpDbm      max(eirpGridDbm(:))
%
%   Notes:
%   * Base MATLAB only - no toolboxes required.
%   * The CSV is written with %.6f for angles and %.6f for EIRP to keep
%     bit-for-bit reproducibility while avoiding gigantic files.
%   * The exporter does NOT compute path loss / receiver power. The
%     payload is antenna-face EIRP only.
%
%   See also imtAasEirpGrid, imtAasPatternCuts, plotImtAasPatternCuts.

    if nargin < 4
        error('imtAasExportEirpGridCsv:notEnoughInputs', ...
            ['imtAasExportEirpGridCsv requires at least 4 inputs: ', ...
             'azGridDeg, elGridDeg, eirpGridDbm, outputPath.']);
    end
    if nargin < 5 || isempty(metadata)
        metadata = struct();
    end
    if ~isstruct(metadata)
        error('imtAasExportEirpGridCsv:invalidMetadata', ...
            'metadata must be a struct (or [] for none).');
    end

    % ---- validate grid vectors / EIRP grid shape ----------------------
    if ~isnumeric(azGridDeg) || ~isreal(azGridDeg) || ~isvector(azGridDeg) ...
            || isempty(azGridDeg)
        error('imtAasExportEirpGridCsv:invalidGrid', ...
            'azGridDeg must be a non-empty real numeric vector.');
    end
    if ~isnumeric(elGridDeg) || ~isreal(elGridDeg) || ~isvector(elGridDeg) ...
            || isempty(elGridDeg)
        error('imtAasExportEirpGridCsv:invalidGrid', ...
            'elGridDeg must be a non-empty real numeric vector.');
    end
    if any(~isfinite(azGridDeg(:))) || any(~isfinite(elGridDeg(:)))
        error('imtAasExportEirpGridCsv:invalidGrid', ...
            'azGridDeg / elGridDeg contain NaN or Inf.');
    end

    azVec = double(azGridDeg(:).');
    elVec = double(elGridDeg(:).');
    Naz   = numel(azVec);
    Nel   = numel(elVec);

    if ~isnumeric(eirpGridDbm) || ~isreal(eirpGridDbm)
        error('imtAasExportEirpGridCsv:invalidEirpGrid', ...
            'eirpGridDbm must be a real numeric matrix.');
    end
    if ndims(eirpGridDbm) > 2 %#ok<ISMAT>
        error('imtAasExportEirpGridCsv:invalidEirpGrid', ...
            'eirpGridDbm must be a 2-D matrix.');
    end
    if ~isequal(size(eirpGridDbm), [Naz, Nel])
        error('imtAasExportEirpGridCsv:gridSizeMismatch', ...
            ['eirpGridDbm size %s does not match ', ...
             '[numel(azGridDeg), numel(elGridDeg)] = [%d %d].'], ...
            mat2str(size(eirpGridDbm)), Naz, Nel);
    end
    %   -Inf is legitimate (array-factor nulls in dB); only NaN is a defect.
    if any(isnan(eirpGridDbm(:)))
        error('imtAasExportEirpGridCsv:invalidEirpGrid', ...
            'eirpGridDbm contains NaN values.');
    end

    % ---- validate output path -----------------------------------------
    if ~(ischar(outputPath) || (isstring(outputPath) && isscalar(outputPath)))
        error('imtAasExportEirpGridCsv:invalidPath', ...
            'outputPath must be a char vector or scalar string.');
    end
    csvPath = char(outputPath);
    if isempty(csvPath)
        error('imtAasExportEirpGridCsv:invalidPath', ...
            'outputPath must be non-empty.');
    end

    [outDir, baseName, ext] = fileparts(csvPath);
    if isempty(ext)
        ext = '.csv';
        csvPath = fullfile(outDir, [baseName ext]);
    end

    if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
        [okMk, msgMk] = mkdir(outDir);
        if ~okMk
            error('imtAasExportEirpGridCsv:mkdirFailed', ...
                'Could not create output directory %s (%s).', outDir, msgMk);
        end
    end

    metadataPath = fullfile(outDir, [baseName '_metadata.json']);

    % ---- build long-form table (az slowest, el fastest) ---------------
    %   numRows = Naz * Nel
    [AZ, EL] = ndgrid(azVec, elVec);     % both Naz x Nel
    azCol    = AZ(:);
    elCol    = EL(:);
    eirpCol  = eirpGridDbm(:);
    numRows  = numel(eirpCol);

    % ---- write CSV ----------------------------------------------------
    fid = fopen(csvPath, 'w');
    if fid < 0
        error('imtAasExportEirpGridCsv:cannotOpen', ...
            'Could not open %s for writing.', csvPath);
    end
    cleanupCsv = onCleanup(@() fcloseSafe(fid));
    fprintf(fid, 'az_deg,el_deg,eirp_dbm_per_100mhz\n');
    %   Pre-pack rows as a 3 x numRows matrix and stream with one fprintf
    %   call - this is dramatically faster than a row-by-row loop on
    %   large grids while staying base MATLAB.
    rowMat = [azCol(:).'; elCol(:).'; eirpCol(:).'];
    fprintf(fid, '%.6f,%.6f,%.6f\n', rowMat);
    clear cleanupCsv;   %#ok<CLMVR>  forces fclose

    peakEirpDbm = max(eirpGridDbm(:));

    % ---- assemble metadata --------------------------------------------
    defaults = struct( ...
        'created_by',                  'imtAasExportEirpGridCsv', ...
        'function',                    'imtAasExportEirpGridCsv', ...
        'sector_eirp_dbm_per_100mhz',  peakEirpDbm, ...
        'bandwidth_mhz',               [], ...
        'frequency_mhz',               [], ...
        'steer_az_deg',                [], ...
        'steer_el_deg',                [], ...
        'mechanical_downtilt_deg',     [], ...
        'subarray_downtilt_deg',       [], ...
        'num_rows',                    [], ...
        'num_columns',                 [], ...
        'notes',                       'Antenna-face EIRP only; deterministic R23 macro AAS MVP.');

    meta = mergeMetadata(defaults, metadata);
    meta.num_az_grid_points = Naz;
    meta.num_el_grid_points = Nel;
    meta.num_rows_written   = numRows;
    meta.csv_path           = csvPath;

    % ---- write metadata sidecar (JSON preferred, text fallback) -------
    metadataFormat = 'json';
    wroteMeta = false;
    if exist('jsonencode', 'builtin') == 5 || exist('jsonencode', 'file') == 2
        try
            jsonText = jsonencode(meta);
            fidM = fopen(metadataPath, 'w');
            if fidM < 0
                error('imtAasExportEirpGridCsv:cannotOpen', ...
                    'Could not open %s for writing.', metadataPath);
            end
            cleanupMeta = onCleanup(@() fcloseSafe(fidM));
            fprintf(fidM, '%s\n', jsonText);
            clear cleanupMeta;   %#ok<CLMVR>
            wroteMeta = true;
        catch err
            warning('imtAasExportEirpGridCsv:jsonFallback', ...
                ['jsonencode failed (%s); writing plain key=value ', ...
                 'metadata fallback to %s.'], err.message, metadataPath);
        end
    end
    if ~wroteMeta
        metadataFormat = 'text';
        writeTextMetadata(metadataPath, meta);
    end

    % ---- result -------------------------------------------------------
    out = struct();
    out.csvPath        = csvPath;
    out.metadataPath   = metadataPath;
    out.metadataFormat = metadataFormat;
    out.numRowsWritten = numRows;
    out.peakEirpDbm    = peakEirpDbm;
end

% =====================================================================

function fcloseSafe(fid)
    if ~isempty(fid) && fid >= 0
        try
            fclose(fid);
        catch
            % ignore - the FD is already closed or invalid
        end
    end
end

function merged = mergeMetadata(defaults, overrides)
%MERGEMETADATA Field-by-field overlay; user fields take precedence.
    merged = defaults;
    if isempty(overrides)
        return;
    end
    f = fieldnames(overrides);
    for i = 1:numel(f)
        merged.(f{i}) = overrides.(f{i});
    end
end

function writeTextMetadata(metadataPath, meta)
    fid = fopen(metadataPath, 'w');
    if fid < 0
        error('imtAasExportEirpGridCsv:cannotOpen', ...
            'Could not open %s for writing.', metadataPath);
    end
    cleanupObj = onCleanup(@() fcloseSafeLocal(fid));
    fprintf(fid, '# imtAasExportEirpGridCsv metadata (text fallback)\n');
    f = fieldnames(meta);
    for i = 1:numel(f)
        fprintf(fid, '%s=%s\n', f{i}, valueToString(meta.(f{i})));
    end
    clear cleanupObj;   %#ok<CLMVR>
end

function fcloseSafeLocal(fid)
    if ~isempty(fid) && fid >= 0
        try
            fclose(fid);
        catch
        end
    end
end

function s = valueToString(v)
    if isempty(v)
        s = '';
    elseif ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    elseif islogical(v) && isscalar(v)
        if v, s = 'true'; else, s = 'false'; end
    elseif isnumeric(v) && isscalar(v)
        s = sprintf('%.10g', double(v));
    elseif isnumeric(v)
        s = mat2str(v);
    else
        s = '<unprintable>';
    end
end
