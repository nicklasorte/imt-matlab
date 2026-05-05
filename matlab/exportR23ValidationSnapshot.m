function snapshot = exportR23ValidationSnapshot(out, outputDir)
%EXPORTR23VALIDATIONSNAPSHOT Lightweight reproducibility artifact for
%   a validated R23 AAS EIRP run.
%
%   SNAPSHOT = exportR23ValidationSnapshot(OUT, OUTPUTDIR)
%
%   OUT       Output struct from runR23AasEirpCdfGrid.
%   OUTPUTDIR Target directory. Created if it does not exist.
%
%   Writes the following files into OUTPUTDIR:
%
%     metadata.json          - run metadata (provenance + scenario)
%     selfcheck.json         - power-semantics self-check result
%     scenario_diff.json     - empty when no preset / overrides; otherwise
%                              records scenarioPreset, presetOverrides,
%                              referenceOnly metadata and core scenario
%                              fields for reproducibility.
%     percentile_summary.csv - small percentiles x stats summary
%                              (NOT the full per-(az,el) percentile table)
%     validation_summary.txt - human-readable provenance + status sheet
%
%   The full per-draw EIRP cube is NEVER written. The streaming
%   histogram is intentionally not exported. This is a lightweight
%   reproducibility metadata sidecar, not a raw Monte Carlo store.
%
%   SNAPSHOT is a struct of paths and a fileSizes summary.
%
%   Example:
%       params = r23ScenarioPreset("urban-baseline");
%       out    = runR23AasEirpCdfGrid(params);
%       snap   = exportR23ValidationSnapshot(out, "artifacts/run001");
%
%   Scope: this helper does NOT add modeling capability. It does not
%   emit path loss, clutter, rooftop, receiver, I/N, propagation,
%   coordination distance, multi-site aggregation, or any cube data.

    if nargin < 2 || isempty(outputDir)
        error('exportR23ValidationSnapshot:badArgs', ...
            'Usage: exportR23ValidationSnapshot(out, outputDir).');
    end
    if ~isstruct(out) || ~isfield(out, 'metadata')
        error('exportR23ValidationSnapshot:badOut', ...
            'OUT must be the struct returned by runR23AasEirpCdfGrid.');
    end

    if isstring(outputDir) && isscalar(outputDir)
        outputDir = char(outputDir);
    end
    if ~ischar(outputDir)
        error('exportR23ValidationSnapshot:badDir', ...
            'outputDir must be a char or string scalar.');
    end

    if exist(outputDir, 'dir') ~= 7
        [ok, msg] = mkdir(outputDir);
        if ~ok
            error('exportR23ValidationSnapshot:mkdirFailed', ...
                'Could not create %s: %s', outputDir, msg);
        end
    end

    paths = struct();
    paths.metadata           = fullfile(outputDir, 'metadata.json');
    paths.selfCheck          = fullfile(outputDir, 'selfcheck.json');
    paths.scenarioDiff       = fullfile(outputDir, 'scenario_diff.json');
    paths.percentileSummary  = fullfile(outputDir, 'percentile_summary.csv');
    paths.validationSummary  = fullfile(outputDir, 'validation_summary.txt');

    writeJsonFile(paths.metadata,    out.metadata);

    if isfield(out, 'selfCheck') && isstruct(out.selfCheck)
        writeJsonFile(paths.selfCheck, out.selfCheck);
    else
        writeJsonFile(paths.selfCheck, struct('status', 'unknown'));
    end

    writeJsonFile(paths.scenarioDiff, buildScenarioDiff(out.metadata));

    writePercentileSummary(paths.percentileSummary, out);

    writeValidationSummary(paths.validationSummary, out);

    snapshot = struct();
    snapshot.outputDir = outputDir;
    snapshot.files     = paths;
    snapshot.fileSizes = collectFileSizes(paths);
end

% =====================================================================

function writeJsonFile(path, payload)
%WRITEJSONFILE Write a struct as pretty-ish JSON. Falls back to a
%   line-oriented dump when jsonencode is unavailable / fails.
    [outDir, ~, ~] = fileparts(path);
    if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end
    fid = fopen(path, 'w');
    if fid < 0
        error('exportR23ValidationSnapshot:cannotWrite', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    try
        try
            txt = jsonencode(payload, 'PrettyPrint', true);
        catch
            txt = jsonencode(payload);
        end
        fwrite(fid, txt, 'char');
    catch
        flds = fieldnames(payload);
        for k = 1:numel(flds)
            v = payload.(flds{k});
            fprintf(fid, '%s = %s\n', flds{k}, scalarRepr(v));
        end
    end
end

function diff = buildScenarioDiff(metadata)
%BUILDSCENARIODIFF Compact reproducibility diff describing the scenario.
    diff = struct();
    diff.hasScenarioPreset = isfield(metadata, 'scenarioPreset') && ...
        ~isempty(metadata.scenarioPreset);
    if diff.hasScenarioPreset
        diff.scenarioPreset = metadata.scenarioPreset;
    else
        diff.scenarioPreset = '';
    end
    if isfield(metadata, 'scenarioCategory')
        diff.scenarioCategory = metadata.scenarioCategory;
    end
    if isfield(metadata, 'sourceReference')
        diff.sourceReference = metadata.sourceReference;
    end
    if isfield(metadata, 'reproducible')
        diff.reproducible = logical(metadata.reproducible);
    end
    if isfield(metadata, 'presetOverrides')
        diff.presetOverrides = metadata.presetOverrides;
    end
    if isfield(metadata, 'referenceOnly')
        diff.referenceOnly = metadata.referenceOnly;
    end
    diff.coreScenarioFields = struct( ...
        'environment',            getOrDefault(metadata, 'environment', ''), ...
        'cellRadius_m',           getOrDefault(metadata, 'cellRadius_m', NaN), ...
        'bsHeight_m',             getOrDefault(metadata, 'bsHeight_m', NaN), ...
        'numUesPerSector',        getOrDefault(metadata, 'numUesPerSector', NaN), ...
        'maxEirpPerSector_dBm',   getOrDefault(metadata, 'maxEirpPerSector_dBm', NaN), ...
        'splitSectorPower',       getOrDefault(metadata, 'splitSectorPower', NaN), ...
        'frequencyMHz',           getOrDefault(metadata, 'frequencyMHz', NaN), ...
        'bandwidthMHz',           getOrDefault(metadata, 'bandwidthMHz', NaN));
end

function writePercentileSummary(path, out)
%WRITEPERCENTILESUMMARY Compact CSV with the per-percentile EIRP min/
%   median/max across the (az, el) grid -- a small reproducibility
%   fingerprint, NOT the full percentile cube.
    fid = fopen(path, 'w');
    if fid < 0
        error('exportR23ValidationSnapshot:cannotWrite', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, ['percentile,minAcrossGrid_dBm,medianAcrossGrid_dBm,' ...
                  'maxAcrossGrid_dBm,numFiniteCells\n']);

    if ~isfield(out, 'percentileMaps') || ~isstruct(out.percentileMaps)
        return;
    end
    pmaps = out.percentileMaps;
    if ~isfield(pmaps, 'percentiles') || ~isfield(pmaps, 'values')
        return;
    end
    pcts = double(pmaps.percentiles(:).');
    vals = pmaps.values;
    if numel(pcts) == 0 || isempty(vals)
        return;
    end
    Np = numel(pcts);
    for k = 1:Np
        slice = vals(:, :, k);
        finiteSlice = slice(isfinite(slice));
        if isempty(finiteSlice)
            fprintf(fid, '%.6g,NaN,NaN,NaN,0\n', pcts(k));
        else
            fprintf(fid, '%.6g,%.6f,%.6f,%.6f,%d\n', ...
                pcts(k), min(finiteSlice), median(finiteSlice), ...
                max(finiteSlice), numel(finiteSlice));
        end
    end
end

function writeValidationSummary(path, out)
%WRITEVALIDATIONSUMMARY Human-readable provenance + status sheet.
    md = out.metadata;
    sc = struct();
    if isfield(out, 'selfCheck') && isfield(out.selfCheck, 'powerSemantics')
        sc = out.selfCheck.powerSemantics;
    end

    fid = fopen(path, 'w');
    if fid < 0
        error('exportR23ValidationSnapshot:cannotWrite', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'R23 AAS EIRP Validation Snapshot\n');
    fprintf(fid, '================================\n\n');

    fprintf(fid, 'Provenance\n');
    fprintf(fid, '  matlabVersion          : %s\n', strRepr(getOrDefault(md, 'matlabVersion', 'unknown')));
    fprintf(fid, '  repoCommitSha          : %s\n', strRepr(getOrDefault(md, 'repoCommitSha', 'unknown')));
    fprintf(fid, '  platform               : %s\n', strRepr(getOrDefault(md, 'platform', 'unknown')));
    fprintf(fid, '  validationTimestampUtc : %s\n', strRepr(getOrDefault(md, 'validationTimestampUtc', 'unknown')));
    fprintf(fid, '\n');

    fprintf(fid, 'Scenario\n');
    fprintf(fid, '  scenarioPreset         : %s\n', strRepr(getOrDefault(md, 'scenarioPreset', '(none)')));
    fprintf(fid, '  environment            : %s\n', strRepr(getOrDefault(md, 'environment', 'unknown')));
    fprintf(fid, '  numUesPerSector        : %s\n', scalarRepr(getOrDefault(md, 'numUesPerSector', NaN)));
    fprintf(fid, '  maxEirpPerSector_dBm   : %s\n', scalarRepr(getOrDefault(md, 'maxEirpPerSector_dBm', NaN)));
    fprintf(fid, '  splitSectorPower       : %s\n', scalarRepr(getOrDefault(md, 'splitSectorPower', NaN)));
    fprintf(fid, '  cellRadius_m           : %s\n', scalarRepr(getOrDefault(md, 'cellRadius_m', NaN)));
    fprintf(fid, '  bsHeight_m             : %s\n', scalarRepr(getOrDefault(md, 'bsHeight_m', NaN)));
    fprintf(fid, '  numMc / numSnapshots   : %s\n', scalarRepr(getOrDefault(md, 'numMc', NaN)));
    fprintf(fid, '\n');

    fprintf(fid, 'Power-semantics self-check\n');
    fprintf(fid, '  status                 : %s\n', strRepr(getOrDefault(sc, 'status', 'unknown')));
    fprintf(fid, '  observedMaxGridEirp_dBm: %s\n', scalarRepr(getOrDefault(sc, 'observedMaxGridEirp_dBm', NaN)));
    fprintf(fid, '  expectedSectorPeak_dBm : %s\n', scalarRepr(getOrDefault(sc, 'expectedSectorPeakEirp_dBm', NaN)));
    fprintf(fid, '  expectedPerBeamPeak_dBm: %s\n', scalarRepr(getOrDefault(sc, 'expectedPerBeamPeakEirp_dBm', NaN)));
    fprintf(fid, '  peakShortfall_dB       : %s\n', scalarRepr(getOrDefault(sc, 'peakShortfall_dB', NaN)));
    fprintf(fid, '  tolerance_dB           : %s\n', scalarRepr(getOrDefault(sc, 'tolerance_dB', NaN)));
    fprintf(fid, '\n');

    fprintf(fid, 'Scope\n');
    fprintf(fid, '  Antenna-face EIRP only. No path loss, no clutter, no\n');
    fprintf(fid, '  receiver antenna, no I/N, no propagation, no coordination\n');
    fprintf(fid, '  distance, no multi-site aggregation. This snapshot is a\n');
    fprintf(fid, '  lightweight reproducibility metadata sidecar, NOT a raw\n');
    fprintf(fid, '  Monte Carlo store.\n');
end

function fs = collectFileSizes(paths)
    flds = fieldnames(paths);
    fs = struct();
    for k = 1:numel(flds)
        p = paths.(flds{k});
        d = dir(p);
        if isempty(d)
            fs.(flds{k}) = NaN;
        else
            fs.(flds{k}) = d(1).bytes;
        end
    end
end

function v = getOrDefault(s, name, dflt)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = dflt;
    end
end

function s = strRepr(v)
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    else
        s = scalarRepr(v);
    end
end

function s = scalarRepr(v)
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    elseif islogical(v) && isscalar(v)
        if v
            s = 'true';
        else
            s = 'false';
        end
    elseif isnumeric(v) && isscalar(v)
        if isnan(v)
            s = 'NaN';
        elseif isinf(v)
            if v > 0
                s = 'Inf';
            else
                s = '-Inf';
            end
        elseif v == floor(v) && abs(v) < 1e15
            s = sprintf('%d', int64(v));
        else
            s = sprintf('%.10g', v);
        end
    else
        s = '<non-scalar>';
    end
end
