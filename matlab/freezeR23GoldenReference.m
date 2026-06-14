function manifest = freezeR23GoldenReference(name, varargin)
%FREEZER23GOLDENREFERENCE Freeze the golden artifact for a named scenario.
%
%   MANIFEST = freezeR23GoldenReference(NAME)
%   MANIFEST = freezeR23GoldenReference(NAME, 'GoldenDir', PATH)
%
%   Runs the named golden scenario through the SAME pipeline the verifier
%   uses (r23GoldenReferenceScenario -> runR23AasEirpCdfGrid with the
%   scenario's metadata.goldenRunOptions applied -> exportR23ValidationSnapshot)
%   and writes the tracked artifact files into the golden directory:
%
%       metadata.json, selfcheck.json, scenario_diff.json,
%       percentile_summary.csv, validation_summary.txt   (snapshot), and
%       golden_manifest.json                              (regression anchor)
%
%   This is the ONE command used to (re)freeze a golden from a real run of
%   the current code. It must be run in MATLAB -- the frozen values are
%   the deterministic outputs the 1e-6 dB verifier gate compares against,
%   and Octave / other interpreters do NOT reproduce MATLAB's RNG stream
%   (the existing urban golden does not verify under Octave), so freezing
%   anywhere other than MATLAB would produce artifacts that fail the
%   MATLAB verifier. Do not hand-edit the numeric values.
%
%   The golden directory is resolved from NAME the same way the verifier
%   resolves it (hyphens -> underscores under artifacts/golden/), or it
%   can be overridden with the 'GoldenDir' option.
%
%   This helper introduces NO modeling capability. It is a freeze /
%   reproducibility utility only.
%
%   See also: r23GoldenReferenceScenario, verifyR23GoldenReference,
%             runR23AasEirpCdfGrid, exportR23ValidationSnapshot.

    if nargin < 1 || isempty(name)
        error('freezeR23GoldenReference:badArgs', ...
            'Usage: freezeR23GoldenReference("<golden-name>", ...).');
    end
    if isstring(name) && isscalar(name)
        name = char(name);
    end

    opts = struct('goldenDir', '');
    if mod(numel(varargin), 2) ~= 0
        error('freezeR23GoldenReference:badNV', ...
            'Optional args must be Name, Value pairs.');
    end
    for k = 1:2:numel(varargin)
        nm = varargin{k};
        if isstring(nm) && isscalar(nm), nm = char(nm); end
        switch lower(nm)
            case 'goldendir'
                v = varargin{k+1};
                if isstring(v) && isscalar(v), v = char(v); end
                opts.goldenDir = v;
            otherwise
                error('freezeR23GoldenReference:unknownOpt', ...
                    'Unknown option "%s".', nm);
        end
    end

    if isempty(opts.goldenDir)
        opts.goldenDir = defaultGoldenDir(name);
    end
    if exist(opts.goldenDir, 'dir') ~= 7
        [ok, msg] = mkdir(opts.goldenDir);
        if ~ok
            error('freezeR23GoldenReference:mkdirFailed', ...
                'Could not create %s: %s', opts.goldenDir, msg);
        end
    end

    % ---- build + run exactly as the verifier does -------------------
    params = r23GoldenReferenceScenario(name);
    runOpts = getGoldenRunOptions(params);
    nv = runOptionsCell(runOpts);

    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    if isempty(nv)
        out = runR23AasEirpCdfGrid(params);
    else
        out = runR23AasEirpCdfGrid(params, nv{:});
    end

    % ---- snapshot sidecar files -------------------------------------
    exportR23ValidationSnapshot(out, opts.goldenDir);

    % ---- golden manifest --------------------------------------------
    manifest = buildManifest(name, params, out, runOpts);
    writeManifest(fullfile(opts.goldenDir, 'golden_manifest.json'), manifest);

    fprintf('Froze golden "%s" -> %s\n', name, opts.goldenDir);
    fprintf('  expectedSelfCheckStatus          = %s\n', ...
        manifest.expectedSelfCheckStatus);
    fprintf('  expectedObservedMaxGridEirp_dBm  = %.15g\n', ...
        manifest.expectedObservedMaxGridEirp_dBm);
    fprintf('  expectedMaxPercentileAcrossGrid_dBm = %.15g\n', ...
        manifest.expectedMaxPercentileAcrossGrid_dBm);
end

% =====================================================================

function m = buildManifest(name, params, out, runOpts)
    m = struct();
    m.goldenReferenceName    = name;
    m.goldenReferenceVersion = double(getOrDefault(params.metadata, ...
        'goldenReferenceVersion', 1));
    m.goldenReferencePurpose = 'regression-anchor';
    m.scenarioPreset         = char(getOrDefault(out.metadata, ...
        'scenarioPreset', ''));
    m.randomSeed             = double(getOrDefault(out.metadata, ...
        'randomSeed', NaN));
    m.numSnapshots           = double(getOrDefault(out.metadata, ...
        'numMc', NaN));
    m.azGrid_deg             = double(out.opts.azGridDeg(:).');
    m.elGrid_deg             = double(out.opts.elGridDeg(:).');
    m.percentiles            = double(out.percentileMaps.percentiles(:).');
    m.expectedSelfCheckStatus = char(getOrDefault( ...
        out.selfCheck.powerSemantics, 'status', ''));
    m.expectedObservedMaxGridEirp_dBm = double(getOrDefault( ...
        out.selfCheck.powerSemantics, 'observedMaxGridEirp_dBm', NaN));
    m.expectedMaxPercentileAcrossGrid_dBm = maxFinitePercentile(out);
    m.goldenRunOptions       = runOpts;
    m.createdBy              = 'freezeR23GoldenReference';
    m.createdUtc             = utcNow();
    m.repoCommitSha          = repoCommitSha();
    m.tolerances = struct( ...
        'absToleranceDeterministicEirp_dB', 1e-6, ...
        'absTolerancePercentileBinned_dB', 0.51, ...
        'rationale', ['observedMaxGridEirp_dBm is deterministic from a ' ...
            'fixed seed; percentile_summary CSV values are emitted in ' ...
            '1 dB bin centers, so a 0.51 dB tolerance accommodates ' ...
            'half-bin behavior.']);
end

function v = maxFinitePercentile(out)
    v = NaN;
    if isfield(out, 'percentileMaps') && isstruct(out.percentileMaps) && ...
            isfield(out.percentileMaps, 'values')
        vals = out.percentileMaps.values;
        fv = vals(isfinite(vals));
        if ~isempty(fv)
            v = double(max(fv));
        end
    end
end

function runOpts = getGoldenRunOptions(params)
    runOpts = struct();
    if isfield(params, 'metadata') && isstruct(params.metadata) && ...
            isfield(params.metadata, 'goldenRunOptions') && ...
            isstruct(params.metadata.goldenRunOptions)
        runOpts = params.metadata.goldenRunOptions;
    end
end

function nv = runOptionsCell(runOpts)
    nv = {};
    if ~isstruct(runOpts) || isempty(fieldnames(runOpts))
        return;
    end
    fn = fieldnames(runOpts);
    nv = cell(1, 2 * numel(fn));
    for k = 1:numel(fn)
        nv{2*k-1} = fn{k};
        nv{2*k}   = runOpts.(fn{k});
    end
end

function writeManifest(path, manifest)
    fid = fopen(path, 'w');
    if fid < 0
        error('freezeR23GoldenReference:cannotWrite', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    try
        txt = jsonencode(manifest, 'PrettyPrint', true);
    catch
        txt = jsonencode(manifest);
    end
    fwrite(fid, txt, 'char');
end

function p = defaultGoldenDir(name)
    sub = lower(char(name));
    sub = strrep(sub, '-', '_');
    here = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    if isempty(repoRoot)
        repoRoot = pwd;
    end
    p = fullfile(repoRoot, 'artifacts', 'golden', sub);
end

function s = utcNow()
    try
        s = char(datetime('now', 'TimeZone', 'UTC', ...
            'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    catch
        s = datestr(now, 'yyyy-mm-ddTHH:MM:SSZ'); %#ok<DATST,TNOW>
    end
end

function sha = repoCommitSha()
    sha = '';
    try
        [st, out] = system('git rev-parse HEAD');
        if st == 0
            sha = strtrim(out);
        end
    catch
    end
end

function v = getOrDefault(s, name, dflt)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = dflt;
    end
end
