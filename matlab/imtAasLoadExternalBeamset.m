function beamset = imtAasLoadExternalBeamset(filePath, opts)
%IMTAASLOADEXTERNALBEAMSET Load + validate an external PMI/codebook beam set.
%
%   BEAMSET = imtAasLoadExternalBeamset(FILEPATH)
%   BEAMSET = imtAasLoadExternalBeamset(FILEPATH, OPTS)
%
%   Loads a vendor / measured beam-set MAT file and returns a canonical
%   struct for the 'external' branch of opts.beamSelection in
%   runR23AasEirpCdfGrid. Base MATLAB only.
%
%   Canonical output BEAMSET:
%       .type       'patterns' | 'weights' | 'directions'
%       .numBeams   scalar
%       .gainDbi    [nAz x nEl x numBeams] double  (type='patterns')
%       .azDeg      [nAz x 1] pattern azimuth axis (type='patterns')
%                   OR [numBeams x 1] steering az (type='directions')
%       .elDeg      [nEl x 1] pattern elevation axis (type='patterns')
%                   OR [numBeams x 1] steering el (type='directions')
%       .weights    [nElem x numBeams] complex     (type='weights')
%       .gainFloorDbi  scalar; the delivered floor/null sentinel, and the
%                   value returned for out-of-domain directions
%       .peakGainDbi, .peakAzDeg, .peakElDeg  [numBeams x 1] per-beam peak
%       .meta       provenance: sourceFile, bytes, checksum (MD5),
%                   frequencyHz, frequencyLabel, metadataRaw,
%                   metadataStruct, loadSeconds, notes
%
%   SUPPORTED LAYOUT (as delivered; determined by inspection of
%   7p4_N1-8_N2-8_N-16_M-8_SA3x1_O2x2_T0.mat and siblings):
%       beams     [numBeams x numEl x numAz] double, ABSOLUTE composite
%                 gain in dBi. Beam i is squeeze(beams(i,:,:)).
%       az        [1 x numAz] deg, strictly increasing
%       el        [1 x numEl] deg, strictly increasing
%       metadata  JSON CHAR string (NOT a struct)
%       pmi_env   [numEl x numAz] envelope = squeeze(max(beams,[],1))
%   This is type='patterns'. Note the delivered beam dimension is FIRST;
%   it is permuted here to the canonical [nAz x nEl x numBeams] order.
%
%   FRAME CONVENTION (important):
%   The delivered az/el are PANEL-FRAME, PRE-MECHANICAL-TILT directions --
%   the same convention imt_aas_codebook_select uses. The delivered
%   metadata carries array_electrical_tilt_deg = mechanical_downtilt_deg =
%   subarray_downtilt_deg = 0.0, i.e. no tilt of any kind is baked into
%   the patterns. Downstream, imtAasCompositeGain rotates the STEERING
%   direction from the sector frame into the panel frame and evaluates
%   these patterns there; the pattern itself is never rotated a second
%   time. Treating these patterns as sector-frame would apply the
%   mechanical downtilt twice.
%
%   AS-DELIVERED TILT CAVEAT:
%   metadata reports subarray_downtilt_deg = 0, whereas
%   aasGeometryPreset('r23_1x3_default') defaults to subarrayDowntiltDeg =
%   3. The patterns are used AS DELIVERED: no elevation offset is
%   synthesized to compensate, because that would inject an invented
%   modeling assumption into vendor data. For an apples-to-apples
%   external-vs-ideal comparison, run the ideal/codebook baseline with the
%   subarrayDowntiltDeg = 0 override. See BEAMSET.meta.notes.
%
%   PERFORMANCE:
%   The delivered files are MAT v7 (NOT v7.3), so matfile() partial
%   loading re-inflates the ENTIRE beams array on every access. This
%   loader therefore issues exactly ONE plain load() and derives every
%   per-beam quantity in that same pass (~33 s / ~1.33 GB resident for the
%   8x8 file). Callers must load once and reuse: runR23AasEirpCdfGrid
%   loads before the Monte Carlo loop, never per draw.
%
%   OPTS (optional struct, all fields optional):
%       geometry        aasGeometryPreset()-shaped struct. When supplied
%                       and the file carries physical-grid metadata, the
%                       geometry is cross-checked and a disagreement
%                       raises :geometryMismatch.
%       requireGeometryMatch  logical, default true when geometry given.
%       validateEnvelope logical, default true (check pmi_env vs beams).
%       computeChecksum logical, default true (streaming MD5 of the file).
%       useCache        logical, default true. Cache the per-beam peak
%                       table to <file>.peakcache.mat so repeat dev-loop
%                       loads skip the recompute. Invalidated on source
%                       size / mtime change. Never caches the tensor.
%       cachePath       char, explicit sidecar path.
%       verbose         logical, default false.
%
%   ERROR IDENTIFIERS:
%       imtAasLoadExternalBeamset:notEnoughInputs
%       imtAasLoadExternalBeamset:invalidPath
%       imtAasLoadExternalBeamset:fileNotFound
%       imtAasLoadExternalBeamset:invalidOpts
%       imtAasLoadExternalBeamset:loadFailed
%       imtAasLoadExternalBeamset:unknownLayout
%       imtAasLoadExternalBeamset:invalidDimensions
%       imtAasLoadExternalBeamset:invalidAxis
%       imtAasLoadExternalBeamset:nonFiniteData
%       imtAasLoadExternalBeamset:invalidMetadata
%       imtAasLoadExternalBeamset:envelopeMismatch
%       imtAasLoadExternalBeamset:elementCountMismatch
%       imtAasLoadExternalBeamset:geometryMismatch
%
%   See also imtAasExternalBeamGain, imtAasCompositeGain,
%   runR23AasEirpCdfGrid, aasGeometryPreset.

    if nargin < 1
        error('imtAasLoadExternalBeamset:notEnoughInputs', ...
            'imtAasLoadExternalBeamset requires a filePath input.');
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts) || ~isscalar(opts)
        error('imtAasLoadExternalBeamset:invalidOpts', ...
            'opts must be a scalar struct (or [] / omitted).');
    end

    validateEnv  = getLogicalOpt(opts, 'validateEnvelope', true);
    doChecksum   = getLogicalOpt(opts, 'computeChecksum',  true);
    useCache     = getLogicalOpt(opts, 'useCache',         true);
    verbose      = getLogicalOpt(opts, 'verbose',          false);

    filePath  = validatePath(filePath);
    cachePath = resolveCachePath(opts, filePath);
    srcInfo   = dir(filePath);

    t0 = tic;
    try
        S = load(filePath, '-mat');
    catch loadErr
        error('imtAasLoadExternalBeamset:loadFailed', ...
            'Could not load "%s" as a MAT file: %s', filePath, loadErr.message);
    end
    loadSecs = toc(t0);
    if verbose
        fprintf('imtAasLoadExternalBeamset: load %.1f s (%s)\n', ...
            loadSecs, filePath);
    end

    layout = detectLayout(S, filePath);

    switch layout
        case 'patterns'
            beamset = buildPatterns(S, filePath, validateEnv, useCache, ...
                cachePath, srcInfo, verbose);
        case 'weights'
            beamset = buildWeights(S, filePath);
        case 'directions'
            beamset = buildDirections(S, filePath);
    end

    % ---- provenance ---------------------------------------------------
    [metaStruct, metaRaw] = decodeMetadata(S, filePath);
    meta = struct();
    meta.sourceFile     = filePath;
    meta.bytes          = srcInfo(1).bytes;
    meta.sourceDatenum  = srcInfo(1).datenum;
    meta.loadSeconds    = loadSecs;
    meta.metadataRaw    = metaRaw;
    meta.metadataStruct = metaStruct;
    [meta.frequencyHz, meta.frequencyLabel, meta.frequencyNote] = ...
        resolveFrequency(metaStruct, filePath);
    meta.checksum = '';
    if doChecksum
        meta.checksum = fileChecksumMd5(filePath);
    end
    meta.notes = [ ...
        'External beam set used AS DELIVERED. az/el are PANEL-FRAME, ', ...
        'pre-mechanical-tilt (metadata tilt fields are 0). No subarray ', ...
        'downtilt offset is synthesized: metadata subarray_downtilt_deg ', ...
        '= 0 vs aasGeometryPreset(''r23_1x3_default'') default of 3 deg. ', ...
        'For an apples-to-apples external-vs-ideal comparison, run the ', ...
        'ideal/codebook baseline with subarrayDowntiltDeg = 0.'];
    beamset.meta = meta;

    % ---- optional geometry cross-check --------------------------------
    if isfield(opts, 'geometry') && ~isempty(opts.geometry)
        requireMatch = getLogicalOpt(opts, 'requireGeometryMatch', true);
        checkGeometry(beamset, opts.geometry, requireMatch, filePath);
    end
end

% =====================================================================

function layout = detectLayout(S, filePath)
%DETECTLAYOUT Classify the MAT contents into a canonical beam-set type.
    hasBeams = isfield(S, 'beams') && isnumeric(S.beams) && ndims(S.beams) == 3;
    hasAxes  = isfield(S, 'az') && isfield(S, 'el');
    if hasBeams && hasAxes
        layout = 'patterns';
        return;
    end
    if isfield(S, 'gainDbi') && isnumeric(S.gainDbi) && ndims(S.gainDbi) == 3 && hasAxes
        layout = 'patterns';
        return;
    end
    if isfield(S, 'weights') && ~isreal(S.weights) && ismatrix(S.weights)
        layout = 'weights';
        return;
    end
    if isfield(S, 'weights') && isnumeric(S.weights) && ismatrix(S.weights)
        layout = 'weights';
        return;
    end
    if (isfield(S, 'azDeg') && isfield(S, 'elDeg')) || ...
            (isfield(S, 'steerAzDeg') && isfield(S, 'steerElDeg'))
        layout = 'directions';
        return;
    end
    error('imtAasLoadExternalBeamset:unknownLayout', ...
        ['Could not classify "%s" as an external beam set. Expected one ', ...
         'of: (patterns) 3-D "beams"/"gainDbi" plus "az"/"el"; ', ...
         '(weights) 2-D "weights" [nElem x numBeams]; (directions) ', ...
         '"azDeg"/"elDeg". Variables found: %s'], ...
        filePath, strjoin(fieldnames(S)', ', '));
end

% ---------------------------------------------------------------------

function beamset = buildPatterns(S, filePath, validateEnv, useCache, ...
        cachePath, srcInfo, verbose)
%BUILDPATTERNS Canonicalize the delivered [numBeams x nEl x nAz] layout.
    if isfield(S, 'beams')
        raw = S.beams;
        rawName = 'beams';
    else
        raw = S.gainDbi;
        rawName = 'gainDbi';
    end
    if ~(isnumeric(raw) && isreal(raw))
        error('imtAasLoadExternalBeamset:invalidDimensions', ...
            '%s: "%s" must be a real numeric array (got %s).', ...
            filePath, rawName, class(raw));
    end
    raw = double(raw);
    if ~all(isfinite(raw(:)))
        error('imtAasLoadExternalBeamset:nonFiniteData', ...
            ['%s: "%s" contains %d non-finite value(s). Delivered beam ', ...
             'sets use a finite floor sentinel (e.g. -300 dBi), not ', ...
             'NaN/Inf.'], filePath, rawName, sum(~isfinite(raw(:))));
    end

    [numBeams, numEl, numAz] = size(raw);
    az = validateAxis(S.az, 'az', numAz, filePath);
    el = validateAxis(S.el, 'el', numEl, filePath);

    % Optional envelope cross-check BEFORE the permute (cheaper here).
    if validateEnv && isfield(S, 'pmi_env') && ~isempty(S.pmi_env)
        env = double(S.pmi_env);
        if ~isequal(size(env), [numEl, numAz])
            error('imtAasLoadExternalBeamset:invalidDimensions', ...
                ['%s: "pmi_env" is [%s] but must be [numEl x numAz] = ', ...
                 '[%d %d].'], filePath, strtrim(sprintf('%d ', size(env))), ...
                numEl, numAz);
        end
        envChk = reshape(max(raw, [], 1), [numEl, numAz]);
        maxDev = max(abs(envChk(:) - env(:)));
        if maxDev > 1e-6
            error('imtAasLoadExternalBeamset:envelopeMismatch', ...
                ['%s: "pmi_env" disagrees with max(beams,[],1) by up to ', ...
                 '%.3g dB (tolerance 1e-6 dB).'], filePath, maxDev);
        end
    end

    % Per-beam peaks in this same pass (single vectorized max over angle).
    peaks = [];
    if useCache
        peaks = tryReadPeakCache(cachePath, srcInfo, numBeams);
    end
    if isempty(peaks)
        flat = reshape(raw, numBeams, numEl * numAz);
        [peakGain, linIdx] = max(flat, [], 2);
        elIdx = mod(linIdx - 1, numEl) + 1;   % el varies fastest per page
        azIdx = floor((linIdx - 1) / numEl) + 1;
        peaks = struct('peakGainDbi', peakGain(:), ...
                       'peakElDeg',   el(elIdx).', ...
                       'peakAzDeg',   az(azIdx).');
        clear flat;
        if useCache
            tryWritePeakCache(cachePath, srcInfo, peaks, verbose);
        end
    elseif verbose
        fprintf('imtAasLoadExternalBeamset: peak cache hit (%s)\n', cachePath);
    end

    beamset = struct();
    beamset.type         = 'patterns';
    beamset.numBeams     = numBeams;
    % Canonical order [nAz x nEl x numBeams]: each beam page is then
    % contiguous, which is the layout imtAasExternalBeamGain wants.
    beamset.gainDbi      = permute(raw, [3 2 1]);
    beamset.azDeg        = az(:);
    beamset.elDeg        = el(:);
    beamset.gainFloorDbi = min(raw(:));
    beamset.peakGainDbi  = peaks.peakGainDbi;
    beamset.peakAzDeg    = peaks.peakAzDeg;
    beamset.peakElDeg    = peaks.peakElDeg;
end

% ---------------------------------------------------------------------

function beamset = buildWeights(S, filePath)
%BUILDWEIGHTS Canonicalize a per-element excitation-weight beam set.
    w = S.weights;
    if ~(isnumeric(w) && ismatrix(w) && ~isempty(w))
        error('imtAasLoadExternalBeamset:invalidDimensions', ...
            '%s: "weights" must be a non-empty 2-D numeric matrix.', filePath);
    end
    if ~all(isfinite(w(:)))
        error('imtAasLoadExternalBeamset:nonFiniteData', ...
            '%s: "weights" contains %d non-finite value(s).', ...
            filePath, sum(~isfinite(w(:))));
    end
    beamset = struct();
    beamset.type         = 'weights';
    beamset.numBeams     = size(w, 2);
    beamset.numElements  = size(w, 1);
    beamset.weights      = w;
    beamset.gainFloorDbi = -300;
    beamset.peakGainDbi  = nan(size(w, 2), 1);
    beamset.peakAzDeg    = nan(size(w, 2), 1);
    beamset.peakElDeg    = nan(size(w, 2), 1);
end

% ---------------------------------------------------------------------

function beamset = buildDirections(S, filePath)
%BUILDDIRECTIONS Canonicalize a steering-direction-only beam set.
    if isfield(S, 'azDeg')
        a = S.azDeg; e = S.elDeg;
    else
        a = S.steerAzDeg; e = S.steerElDeg;
    end
    if ~(isnumeric(a) && isnumeric(e) && isvector(a) && isvector(e))
        error('imtAasLoadExternalBeamset:invalidDimensions', ...
            '%s: steering azDeg/elDeg must be numeric vectors.', filePath);
    end
    if numel(a) ~= numel(e)
        error('imtAasLoadExternalBeamset:invalidDimensions', ...
            '%s: azDeg has %d entries but elDeg has %d.', ...
            filePath, numel(a), numel(e));
    end
    if ~all(isfinite(a(:))) || ~all(isfinite(e(:)))
        error('imtAasLoadExternalBeamset:nonFiniteData', ...
            '%s: steering azDeg/elDeg contain non-finite values.', filePath);
    end
    beamset = struct();
    beamset.type         = 'directions';
    beamset.numBeams     = numel(a);
    beamset.azDeg        = double(a(:));
    beamset.elDeg        = double(e(:));
    beamset.gainFloorDbi = -300;
    beamset.peakGainDbi  = nan(numel(a), 1);
    beamset.peakAzDeg    = double(a(:));
    beamset.peakElDeg    = double(e(:));
end

% =====================================================================

function checkGeometry(beamset, geom, requireMatch, filePath)
%CHECKGEOMETRY Cross-check the file against the active preset geometry.
%   For type='weights' this is a hard element-count test
%   (:elementCountMismatch). For type='patterns' there are no elements in
%   the file, so the equivalent test is on the physical-grid metadata
%   (:geometryMismatch).
    if ~isstruct(geom) || ~isscalar(geom)
        error('imtAasLoadExternalBeamset:invalidOpts', ...
            'opts.geometry must be a scalar struct from aasGeometryPreset.');
    end

    if strcmp(beamset.type, 'weights')
        if isfield(geom, 'totalPhysicalElementsAcrossPolarizations')
            expected = geom.totalPhysicalElementsAcrossPolarizations;
            if beamset.numElements ~= expected
                error('imtAasLoadExternalBeamset:elementCountMismatch', ...
                    ['%s: "weights" has %d elements but preset "%s" ', ...
                     'implies %d physical elements across polarizations.'], ...
                    filePath, beamset.numElements, ...
                    getPresetName(geom), expected);
            end
        end
        return;
    end

    md = beamset.meta.metadataStruct;
    if isempty(md) || ~isstruct(md) || ~requireMatch
        return;
    end

    checks = { ...
        'physical_grid_horizontal_cols_per_pol', 'arrayCols'; ...
        'physical_grid_vertical_rows_per_pol',   'arrayRows'; ...
        'aas_subarray_rows',                     'subarrayElementRows'; ...
        'aas_subarray_cols',                     'subarrayElementCols'; ...
        'num_physical_elements', 'totalPhysicalElementsAcrossPolarizations'};

    for i = 1:size(checks, 1)
        mdField = checks{i, 1};
        gField  = checks{i, 2};
        if ~isfield(md, mdField) || ~isfield(geom, gField)
            continue;
        end
        got = double(md.(mdField));
        want = double(geom.(gField));
        if ~isequal(got, want)
            error('imtAasLoadExternalBeamset:geometryMismatch', ...
                ['%s: external beam-set metadata %s = %g disagrees with ', ...
                 'preset "%s" %s = %g. The beam set was synthesized for a ', ...
                 'different array; pick the matching aasGeometryPreset ', ...
                 'or the matching beam-set file.'], ...
                filePath, mdField, got, getPresetName(geom), gField, want);
        end
    end
end

function name = getPresetName(geom)
    if isfield(geom, 'presetName') && ~isempty(geom.presetName)
        name = char(string(geom.presetName));
    else
        name = '<unnamed>';
    end
end

% =====================================================================

function [freqHz, label, note] = resolveFrequency(md, filePath)
%RESOLVEFREQUENCY Report the metadata frequency and any filename conflict.
%   The delivered 7p4_* files carry carrier_frequency_hz = 3.7e9, which
%   disagrees with the "7p4" (7.4 GHz) filename prefix. This is recorded
%   verbatim as a passthrough discrepancy, never silently reconciled.
    freqHz = [];
    note   = '';
    if isstruct(md) && isfield(md, 'carrier_frequency_hz')
        freqHz = double(md.carrier_frequency_hz);
    end
    [~, base] = fileparts(filePath);
    label = '';
    tok = regexp(base, '^(\d+)p(\d+)_', 'tokens', 'once');
    if ~isempty(tok)
        label = sprintf('%s.%s GHz (from filename)', tok{1}, tok{2});
        fileGhz = str2double([tok{1} '.' tok{2}]);
        if ~isempty(freqHz) && abs(freqHz / 1e9 - fileGhz) > 1e-6
            note = sprintf(['DISCREPANCY (passthrough, not reconciled): ', ...
                'metadata carrier_frequency_hz = %.6g Hz (%.3f GHz) but ', ...
                'the filename prefix indicates %.3f GHz.'], ...
                freqHz, freqHz / 1e9, fileGhz);
        end
    end
end

function digest = fileChecksumMd5(filePath)
%FILECHECKSUMMD5 Streaming MD5 over the file. Base MATLAB (JVM) only.
%   Streamed in chunks so a 689 MB source is not re-read into memory.
    digest = '';
    fid = fopen(filePath, 'r');
    if fid < 0
        return;
    end
    closer = onCleanup(@() fclose(fid));
    try
        mdObj = java.security.MessageDigest.getInstance('MD5');
        chunkBytes = 8 * 1024 * 1024;
        while true
            data = fread(fid, chunkBytes, '*uint8');
            if isempty(data)
                break;
            end
            mdObj.update(typecast(data, 'int8'));
        end
        raw = typecast(mdObj.digest(), 'uint8');
        digest = lower(reshape(dec2hex(raw, 2).', 1, []));
    catch
        digest = '';   % JVM unavailable: provenance degrades, load does not fail
    end
end

% =====================================================================

function p = validatePath(filePath)
    if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
        error('imtAasLoadExternalBeamset:invalidPath', ...
            'filePath must be a char vector or scalar string.');
    end
    p = char(filePath);
    if isempty(strtrim(p))
        error('imtAasLoadExternalBeamset:invalidPath', ...
            'filePath must be non-empty.');
    end
    if exist(p, 'file') ~= 2
        error('imtAasLoadExternalBeamset:fileNotFound', ...
            'External beam-set file not found: %s', p);
    end
    info = dir(p);
    if isempty(info) || info(1).isdir
        error('imtAasLoadExternalBeamset:fileNotFound', ...
            'External beam-set path is not a file: %s', p);
    end
end

function tf = getLogicalOpt(opts, name, defaultValue)
    tf = defaultValue;
    if isfield(opts, name) && ~isempty(opts.(name))
        v = opts.(name);
        if ~((islogical(v) || isnumeric(v)) && isscalar(v))
            error('imtAasLoadExternalBeamset:invalidOpts', ...
                'opts.%s must be a logical scalar.', name);
        end
        tf = logical(v);
    end
end

function cachePath = resolveCachePath(opts, filePath)
    if isfield(opts, 'cachePath') && ~isempty(opts.cachePath)
        v = opts.cachePath;
        if ~(ischar(v) || (isstring(v) && isscalar(v)))
            error('imtAasLoadExternalBeamset:invalidOpts', ...
                'opts.cachePath must be a char vector or scalar string.');
        end
        cachePath = char(v);
    else
        cachePath = [filePath, '.peakcache.mat'];
    end
end

function ax = validateAxis(ax, name, expectedN, filePath)
%VALIDATEAXIS Real, finite, strictly increasing, correct length.
    if ~(isnumeric(ax) && isreal(ax) && isvector(ax) && ~isempty(ax))
        error('imtAasLoadExternalBeamset:invalidAxis', ...
            '%s: "%s" must be a non-empty real numeric vector.', filePath, name);
    end
    ax = double(ax(:).');
    if ~all(isfinite(ax))
        error('imtAasLoadExternalBeamset:invalidAxis', ...
            '%s: "%s" contains non-finite values.', filePath, name);
    end
    if numel(ax) ~= expectedN
        error('imtAasLoadExternalBeamset:invalidDimensions', ...
            '%s: "%s" has %d samples but the beam tensor implies %d.', ...
            filePath, name, numel(ax), expectedN);
    end
    if numel(ax) > 1 && ~all(diff(ax) > 0)
        error('imtAasLoadExternalBeamset:invalidAxis', ...
            ['%s: "%s" must be strictly increasing (found %d ', ...
             'non-increasing step(s)).'], filePath, name, sum(diff(ax) <= 0));
    end
end

function [metaStruct, metaRaw] = decodeMetadata(S, filePath)
%DECODEMETADATA Accept a JSON char descriptor (as delivered) or a struct.
    metaStruct = struct();
    metaRaw    = [];
    if ~isfield(S, 'metadata')
        return;
    end
    metaRaw = S.metadata;
    if isstruct(metaRaw) && isscalar(metaRaw)
        metaStruct = metaRaw;
        return;
    end
    if ischar(metaRaw) || (isstring(metaRaw) && isscalar(metaRaw))
        try
            decoded = jsondecode(char(metaRaw));
        catch decodeErr
            error('imtAasLoadExternalBeamset:invalidMetadata', ...
                ['%s: "metadata" is a char descriptor but is not valid ', ...
                 'JSON: %s'], filePath, decodeErr.message);
        end
        if ~isstruct(decoded) || ~isscalar(decoded)
            error('imtAasLoadExternalBeamset:invalidMetadata', ...
                '%s: "metadata" JSON must decode to a scalar object (got %s).', ...
                filePath, class(decoded));
        end
        metaStruct = decoded;
        return;
    end
    error('imtAasLoadExternalBeamset:invalidMetadata', ...
        ['%s: "metadata" must be a JSON char/string descriptor or a ', ...
         'scalar struct (got %s).'], filePath, class(metaRaw));
end

function peaks = tryReadPeakCache(cachePath, srcInfo, numBeams)
%TRYREADPEAKCACHE Return [] on any miss; a stale cache is never fatal.
    peaks = [];
    if exist(cachePath, 'file') ~= 2
        return;
    end
    try
        C = load(cachePath);
    catch
        return;
    end
    needed = {'sourceBytes', 'sourceDatenum', 'peakGainDbi', 'peakAzDeg', 'peakElDeg'};
    for i = 1:numel(needed)
        if ~isfield(C, needed{i})
            return;
        end
    end
    if ~isequal(C.sourceBytes, srcInfo(1).bytes) || ...
            abs(C.sourceDatenum - srcInfo(1).datenum) > 1e-9 || ...
            numel(C.peakGainDbi) ~= numBeams
        return;
    end
    peaks = struct('peakGainDbi', C.peakGainDbi(:), ...
                   'peakAzDeg',   C.peakAzDeg(:), ...
                   'peakElDeg',   C.peakElDeg(:));
end

function tryWritePeakCache(cachePath, srcInfo, peaks, verbose)
%TRYWRITEPEAKCACHE Best-effort; a read-only directory must not break loading.
    C = struct('sourceBytes',   srcInfo(1).bytes, ...
               'sourceDatenum', srcInfo(1).datenum, ...
               'peakGainDbi',   peaks.peakGainDbi, ...
               'peakAzDeg',     peaks.peakAzDeg, ...
               'peakElDeg',     peaks.peakElDeg);
    try
        save(cachePath, '-struct', 'C');
        if verbose
            fprintf('imtAasLoadExternalBeamset: wrote peak cache %s\n', cachePath);
        end
    catch cacheErr
        warning('imtAasLoadExternalBeamset:peakCacheWriteFailed', ...
            'Could not write peak cache %s (%s); continuing without it.', ...
            cachePath, cacheErr.message);
    end
end
