function result = verifyR23GoldenReference(name, varargin)
%VERIFYR23GOLDENREFERENCE Compare a current run against a frozen golden.
%
%   RESULT = verifyR23GoldenReference(NAME)
%   RESULT = verifyR23GoldenReference(NAME, 'GoldenDir', PATH)
%
%   Re-runs the named golden scenario via r23GoldenReferenceScenario +
%   runR23AasEirpCdfGrid, exports a temporary validation snapshot, and
%   compares the current outputs against the tracked golden artifact.
%
%   The verifier compares:
%
%     - self-check status                     (exact)
%     - observedMaxGridEirp_dBm               (abs tol = 1e-6 dB)
%     - percentile_summary.csv values         (abs tol = 0.51 dB,
%                                              accommodates 1 dB bin
%                                              half-widths)
%     - scenarioPreset                        (exact)
%     - randomSeed / numSnapshots             (exact)
%     - azGrid_deg / elGrid_deg / percentiles (exact)
%
%   RESULT struct fields:
%     .name           name of the golden scenario verified
%     .goldenDir      directory of the tracked golden artifact
%     .passed         logical
%     .summary        cell array of human-readable PASS/FAIL lines
%     .differences    struct array {field, expected, observed, tolerance,
%                                   passed, note}
%
%   This is a regression anchor only. It does not introduce new RF /
%   system modeling capability. Plotting is not used.
%
%   See also: r23GoldenReferenceScenario, runR23AasEirpCdfGrid,
%             exportR23ValidationSnapshot.

    if nargin < 1 || isempty(name)
        error('verifyR23GoldenReference:badArgs', ...
            'Usage: verifyR23GoldenReference("<golden-name>", ...).');
    end
    if isstring(name) && isscalar(name)
        name = char(name);
    end

    opts = parseOpts(varargin);

    if isempty(opts.goldenDir)
        opts.goldenDir = defaultGoldenDir(name);
    end

    result = struct();
    result.name        = name;
    result.goldenDir   = opts.goldenDir;
    result.passed      = true;
    result.summary     = {};
    result.differences = repmat(emptyDiff(), 0, 1);

    % ---- check golden artifact exists -------------------------------
    if exist(opts.goldenDir, 'dir') ~= 7
        result.passed = false;
        result.summary{end+1} = sprintf( ...
            'FAIL  golden directory missing: %s', opts.goldenDir);
        result.differences(end+1) = makeDiff('goldenDir', ...
            opts.goldenDir, '<missing>', 0, false, ...
            'tracked golden artifact directory not found');
        return;
    end

    manifestPath = fullfile(opts.goldenDir, 'golden_manifest.json');
    if exist(manifestPath, 'file') ~= 2
        result.passed = false;
        result.summary{end+1} = sprintf( ...
            'FAIL  golden_manifest.json missing in %s', opts.goldenDir);
        result.differences(end+1) = makeDiff('goldenManifest', ...
            manifestPath, '<missing>', 0, false, ...
            'tracked golden manifest not found');
        return;
    end

    expected = readJsonFile(manifestPath);
    if isempty(expected)
        result.passed = false;
        result.summary{end+1} = sprintf( ...
            'FAIL  could not parse manifest at %s', manifestPath);
        return;
    end

    % ---- rebuild and run the golden scenario ------------------------
    params = r23GoldenReferenceScenario(name);

    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    out = runR23AasEirpCdfGrid(params);

    % Build a fresh snapshot in a temp dir; we read the same files the
    % tracked artifact would have, which keeps the comparison honest.
    tmpDir = fullfile(tempdir, sprintf('r23_golden_verify_%s_%s', ...
        sanitize(name), randTag()));
    cleanupTmp = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>
    snap = exportR23ValidationSnapshot(out, tmpDir);

    % ---- compare scalars and arrays ---------------------------------
    [result] = checkScalar(result, 'scenarioPreset', ...
        getOrDefault(expected, 'scenarioPreset', ''), ...
        getOrDefault(out.metadata, 'scenarioPreset', ''));

    [result] = checkScalar(result, 'randomSeed', ...
        toScalarNum(getOrDefault(expected, 'randomSeed', NaN)), ...
        toScalarNum(getOrDefault(out.metadata, 'randomSeed', NaN)));

    [result] = checkScalar(result, 'numSnapshots', ...
        toScalarNum(getOrDefault(expected, 'numSnapshots', NaN)), ...
        toScalarNum(getOrDefault(out.metadata, 'numMc', NaN)));

    [result] = checkVector(result, 'azGrid_deg', ...
        toVec(getOrDefault(expected, 'azGrid_deg', [])), ...
        toVec(out.opts.azGridDeg));

    [result] = checkVector(result, 'elGrid_deg', ...
        toVec(getOrDefault(expected, 'elGrid_deg', [])), ...
        toVec(out.opts.elGridDeg));

    [result] = checkVector(result, 'percentiles', ...
        toVec(getOrDefault(expected, 'percentiles', [])), ...
        toVec(out.percentileMaps.percentiles));

    [result] = checkScalar(result, 'expectedSelfCheckStatus', ...
        getOrDefault(expected, 'expectedSelfCheckStatus', ''), ...
        getOrDefault(out.selfCheck.powerSemantics, 'status', ''));

    tolDet = 1e-6;
    if isfield(expected, 'tolerances') && ...
            isfield(expected.tolerances, 'absToleranceDeterministicEirp_dB')
        tolDet = double(expected.tolerances.absToleranceDeterministicEirp_dB);
    end
    [result] = checkNumeric(result, 'observedMaxGridEirp_dBm', ...
        toScalarNum(getOrDefault(expected, ...
            'expectedObservedMaxGridEirp_dBm', NaN)), ...
        toScalarNum(getOrDefault(out.selfCheck.powerSemantics, ...
            'observedMaxGridEirp_dBm', NaN)), ...
        tolDet);

    % ---- compare percentile_summary.csv -----------------------------
    tolBin = 0.51;
    if isfield(expected, 'tolerances') && ...
            isfield(expected.tolerances, 'absTolerancePercentileBinned_dB')
        tolBin = double(expected.tolerances.absTolerancePercentileBinned_dB);
    end
    expCsv = fullfile(opts.goldenDir, 'percentile_summary.csv');
    obsCsv = snap.files.percentileSummary;
    [result] = checkPercentileCsv(result, expCsv, obsCsv, tolBin);

    % ---- max-percentile-across-grid sanity --------------------------
    obsMaxP = obsMaxPercentile(out);
    [result] = checkNumeric(result, 'maxPercentileAcrossGrid_dBm', ...
        toScalarNum(getOrDefault(expected, ...
            'expectedMaxPercentileAcrossGrid_dBm', NaN)), ...
        obsMaxP, tolBin);

    if result.passed
        result.summary{end+1} = 'PASS  golden reference matches tracked artifact';
    else
        result.summary{end+1} = 'FAIL  one or more golden checks did not match';
    end
end

% =====================================================================

function v = obsMaxPercentile(out)
    v = NaN;
    if isfield(out, 'percentileMaps') && isstruct(out.percentileMaps) && ...
            isfield(out.percentileMaps, 'values')
        vals = out.percentileMaps.values;
        fv = vals(isfinite(vals));
        if ~isempty(fv)
            v = max(fv);
        end
    end
end

function r = checkScalar(r, field, expected, observed)
    eq = isequal(expected, observed);
    if ~eq && (ischar(expected) || isstring(expected)) && ...
            (ischar(observed) || isstring(observed))
        eq = strcmp(char(expected), char(observed));
    end
    if ~eq && isnumeric(expected) && isnumeric(observed) && ...
            isscalar(expected) && isscalar(observed)
        eq = (expected == observed) || (isnan(expected) && isnan(observed));
    end
    note = '';
    diff = makeDiff(field, expected, observed, 0, eq, note);
    r.differences(end+1) = diff;
    r = appendSummary(r, eq, field, expected, observed, 0);
    if ~eq, r.passed = false; end
end

function r = checkVector(r, field, expected, observed)
    expected = double(expected(:).');
    observed = double(observed(:).');
    eq = isequal(size(expected), size(observed)) && ...
         all(expected == observed);
    diff = makeDiff(field, expected, observed, 0, eq, '');
    r.differences(end+1) = diff;
    r = appendSummary(r, eq, field, expected, observed, 0);
    if ~eq, r.passed = false; end
end

function r = checkNumeric(r, field, expected, observed, tol)
    expected = toScalarNum(expected);
    observed = toScalarNum(observed);
    if isnan(expected) || isnan(observed)
        eq = isnan(expected) && isnan(observed);
        delta = NaN;
    else
        delta = abs(expected - observed);
        eq = delta <= tol;
    end
    note = sprintf('|delta|=%.6g, tol=%.6g', delta, tol);
    diff = makeDiff(field, expected, observed, tol, eq, note);
    r.differences(end+1) = diff;
    r = appendSummary(r, eq, field, expected, observed, tol);
    if ~eq, r.passed = false; end
end

function r = checkPercentileCsv(r, expCsv, obsCsv, tol)
    if exist(expCsv, 'file') ~= 2
        r.passed = false;
        r.summary{end+1} = sprintf('FAIL  expected CSV missing: %s', expCsv);
        r.differences(end+1) = makeDiff('percentile_summary.csv', ...
            expCsv, '<missing>', tol, false, 'expected CSV missing');
        return;
    end
    if exist(obsCsv, 'file') ~= 2
        r.passed = false;
        r.summary{end+1} = sprintf('FAIL  observed CSV missing: %s', obsCsv);
        r.differences(end+1) = makeDiff('percentile_summary.csv', ...
            '<present>', '<missing>', tol, false, 'observed CSV missing');
        return;
    end
    expRows = readPercentileCsv(expCsv);
    obsRows = readPercentileCsv(obsCsv);
    if size(expRows, 1) ~= size(obsRows, 1) || size(expRows, 2) ~= size(obsRows, 2)
        r.passed = false;
        r.summary{end+1} = sprintf( ...
            'FAIL  percentile_summary.csv shape mismatch: exp %s vs obs %s', ...
            mat2str(size(expRows)), mat2str(size(obsRows)));
        r.differences(end+1) = makeDiff('percentile_summary.csv', ...
            size(expRows), size(obsRows), tol, false, 'shape mismatch');
        return;
    end
    delta = abs(expRows - obsRows);
    finiteMask = isfinite(expRows) & isfinite(obsRows);
    nanMatch = isnan(expRows) == isnan(obsRows);
    rowOk = (delta(finiteMask) <= tol);
    eq = all(rowOk(:)) && all(nanMatch(:));
    maxAbs = max([0; delta(finiteMask)]);
    note = sprintf('max |delta|=%.6g across %d rows, tol=%.6g', ...
        maxAbs, size(expRows, 1), tol);
    diff = makeDiff('percentile_summary.csv', ...
        sprintf('rows=%d', size(expRows, 1)), ...
        sprintf('rows=%d', size(obsRows, 1)), tol, eq, note);
    r.differences(end+1) = diff;
    if eq
        r.summary{end+1} = sprintf('PASS  percentile_summary.csv (%s)', note);
    else
        r.summary{end+1} = sprintf('FAIL  percentile_summary.csv (%s)', note);
        r.passed = false;
    end
end

function rows = readPercentileCsv(path)
%READPERCENTILECSV Read all numeric values from percentile_summary.csv.
    rows = [];
    fid = fopen(path, 'r');
    if fid < 0, return; end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    header = fgetl(fid); %#ok<NASGU>
    data = [];
    while ~feof(fid)
        ln = fgetl(fid);
        if ~ischar(ln) || isempty(strtrim(ln))
            continue;
        end
        parts = strsplit(ln, ',');
        if numel(parts) < 1, continue; end
        rowVals = nan(1, numel(parts));
        for k = 1:numel(parts)
            p = strtrim(parts{k});
            if strcmpi(p, 'NaN')
                rowVals(k) = NaN;
            else
                v = str2double(p);
                rowVals(k) = v;
            end
        end
        data(end+1, :) = rowVals; %#ok<AGROW>
    end
    rows = data;
end

% =====================================================================

function opts = parseOpts(args)
    opts.goldenDir = '';
    if isempty(args), return; end
    if mod(numel(args), 2) ~= 0
        error('verifyR23GoldenReference:badNV', ...
            'Optional args must be Name, Value pairs.');
    end
    for k = 1:2:numel(args)
        nm = args{k};
        if isstring(nm) && isscalar(nm), nm = char(nm); end
        switch lower(nm)
            case 'goldendir'
                v = args{k+1};
                if isstring(v) && isscalar(v), v = char(v); end
                opts.goldenDir = v;
            otherwise
                error('verifyR23GoldenReference:unknownOpt', ...
                    'Unknown option "%s".', nm);
        end
    end
end

function p = defaultGoldenDir(name)
    sub = sanitize(name);
    here = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    if isempty(repoRoot)
        repoRoot = pwd;
    end
    p = fullfile(repoRoot, 'artifacts', 'golden', sub);
end

function s = sanitize(name)
    s = lower(char(name));
    s = strrep(s, '-', '_');
end

function tag = randTag()
    tag = char('a' + floor(26 * rand(1, 8)));
end

function safeRmdir(d)
    try
        if exist(d, 'dir') == 7
            rmdir(d, 's');
        end
    catch
    end
end

function v = toScalarNum(x)
    if islogical(x), x = double(x); end
    if isnumeric(x) && isscalar(x)
        v = double(x);
    elseif isnumeric(x) && ~isempty(x)
        v = double(x(1));
    else
        v = NaN;
    end
end

function v = toVec(x)
    if isempty(x)
        v = [];
    elseif isnumeric(x) || islogical(x)
        v = double(x(:).');
    else
        v = [];
    end
end

function v = getOrDefault(s, name, dflt)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = dflt;
    end
end

function payload = readJsonFile(path)
    payload = struct();
    fid = fopen(path, 'r');
    if fid < 0, return; end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    raw = fread(fid, Inf, 'uint8=>char').';
    try
        payload = jsondecode(raw);
    catch
        payload = struct();
    end
end

function d = emptyDiff()
    d = struct('field', '', 'expected', [], 'observed', [], ...
               'tolerance', 0, 'passed', true, 'note', '');
end

function d = makeDiff(field, expected, observed, tolerance, passed, note)
    d = struct('field', field, 'expected', expected, ...
               'observed', observed, 'tolerance', tolerance, ...
               'passed', logical(passed), 'note', note);
end

function r = appendSummary(r, eq, field, expected, observed, tol)
    if eq
        tag = 'PASS';
    else
        tag = 'FAIL';
    end
    expRepr = scalarRepr(expected);
    obsRepr = scalarRepr(observed);
    if tol > 0
        r.summary{end+1} = sprintf('%s  %s exp=%s obs=%s tol=%.6g', ...
            tag, field, expRepr, obsRepr, tol);
    else
        r.summary{end+1} = sprintf('%s  %s exp=%s obs=%s', ...
            tag, field, expRepr, obsRepr);
    end
end

function s = scalarRepr(v)
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    elseif islogical(v) && isscalar(v)
        if v, s = 'true'; else, s = 'false'; end
    elseif isnumeric(v) && isscalar(v)
        if isnan(v)
            s = 'NaN';
        else
            s = sprintf('%.10g', v);
        end
    elseif isnumeric(v) && ~isempty(v)
        s = mat2str(v(:).');
    else
        s = '<non-scalar>';
    end
end
