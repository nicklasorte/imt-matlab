function out = runR23AasEirpCdfGrid(varargin)
%RUNR23AASEIRPCDFGRID R23 7/8 GHz Extended AAS EIRP CDF-grid generator.
%
%   OUT = runR23AasEirpCdfGrid()
%   OUT = runR23AasEirpCdfGrid(OPTS)
%   OUT = runR23AasEirpCdfGrid(PARAMS)
%   OUT = runR23AasEirpCdfGrid('Name', Value, ...)
%   OUT = runR23AasEirpCdfGrid(PARAMS, 'Name', Value, ...)
%
%   Source-aligned MVP entry point for the R23 7.125-8.4 GHz Extended AAS
%   per-(azimuth, elevation) EIRP CDF-grid generator. For each Monte
%   Carlo draw the runner samples NUMUESPERSECTOR UE-driven beam
%   steering angles, builds the aggregate antenna-face sector EIRP grid
%   via imtAasSectorEirpGridFromBeams (linear-mW summed over the
%   simultaneous beams), and updates a streaming per-cell histogram and
%   pointing-angle aggregator. The full per-draw EIRP cube is NEVER
%   materialised.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N, NO FS / FSS receiver logic, NO
%   coordination distance, and NO multi-site aggregation in this slice.
%
%   Three input styles are supported:
%
%   1) Flat OPTS struct (legacy):
%        opts.numMc, opts.azGridDeg, opts.elGridDeg, opts.binEdgesDbm,
%        opts.percentiles, opts.seed, opts.deployment, opts.numBeams,
%        opts.splitSectorPower, opts.progressEvery, opts.mcChunkSize,
%        opts.outputCsvPath, opts.outputMetadataPath,
%        opts.numUesPerSector, opts.maxEirpPerSector_dBm,
%        opts.environment, opts.computePointingHeatmap.
%
%   2) Nested PARAMS struct as built by r23DefaultParams. The runner
%      auto-detects fields .deployment / .ue / .bs / .aas / .sim and
%      flattens to internal opts. Per-call overrides may then be passed
%      as additional name-value pairs.
%
%   3) Name-value pairs e.g.
%        runR23AasEirpCdfGrid('numUesPerSector', 10, ...
%                             'maxEirpPerSector_dBm', 75, ...
%                             'environment', 'suburban')
%
%   Power semantics (R23 macro 7.125-8.4 GHz):
%       maxEirpPerSector_dBm = 78.3   sector peak EIRP [dBm / 100 MHz]
%       conductedPower_dBm   = 46.1   conducted BS power [dBm / 100 MHz]
%       peakGain_dBi         = 32.2   peak composite gain [dBi]
%       46.1 + 32.2 = 78.3
%
%   maxEirpPerSector_dBm is the SECTOR peak EIRP and is split across
%   simultaneous beams via perBeamPeakEirpDbm = sectorEirp - 10*log10(N)
%   when splitSectorPower = true (default). Conducted power and gain are
%   never both added on top of an already-stated sector EIRP.
%
%   Output (OUT struct):
%       .params             imtAasDefaultParams-shaped struct used.
%       .nestedParams       full nested r23DefaultParams struct used (for
%                           reproduction / metadata).
%       .sector             imtAasSingleSectorParams(deployment, params).
%       .opts               resolved flat opts struct (with defaults).
%       .stats              streaming aggregator (counts, sum_lin_mW,
%                           min_dBm, max_dBm, mean_dBm, ...).
%       .percentileMaps     struct from eirp_percentile_maps.
%       .pointing           pointing-angle aggregator (when computed):
%                             .azimuthDegGrid       Naz x Nel [deg]
%                             .elevationDegGrid     Naz x Nel [deg]
%                             .summaryStatistic     'meanAcrossSnapshots'
%                             .azWrappedConvention  'circular mean atan2d'
%                             .numSamples           Naz x Nel uint32
%       .percentileTable    optional table from
%                           export_eirp_percentile_table when
%                           opts.outputCsvPath is provided.
%       .metadata           struct describing the run (generator, model,
%                           scope, no-path-loss/no-receiver caveats,
%                           environment, numUesPerSector,
%                           maxEirpPerSector_dBm, sourceDefault, ...).
%
%   See also: r23DefaultParams, imtAasDefaultParams,
%             imtAasSingleSectorParams, imtAasGenerateBeamSet,
%             imtAasSectorEirpGridFromBeams, update_eirp_histograms,
%             eirp_percentile_maps, plotR23AasEirpCdfGrid,
%             plotR23AasPointingHeatmap.

    % ---- argument resolution ----------------------------------------
    [opts, nestedParams] = resolveInputs(varargin);

    params = r23ToImtAasParams(nestedParams);

    % ---- resolve opts with defaults ----------------------------------
    if ~isfield(opts, 'maxEirpPerSector_dBm') || isempty(opts.maxEirpPerSector_dBm)
        opts.maxEirpPerSector_dBm = nestedParams.bs.maxEirpPerSector_dBm;
    end

    % numBeams is the legacy alias for numUesPerSector. Resolution rules:
    %   * both present and equal              -> use it (no-op).
    %   * both present and disagree           -> numUesPerSector wins (warn).
    %   * only numUesPerSector present        -> set numBeams to match.
    %   * only numBeams present               -> set numUesPerSector to match.
    %   * neither present                     -> default from nested params.
    hasNumUes   = isfield(opts, 'numUesPerSector') && ~isempty(opts.numUesPerSector);
    hasNumBeams = isfield(opts, 'numBeams')        && ~isempty(opts.numBeams);
    if hasNumUes && hasNumBeams
        if ~isequal(double(opts.numBeams), double(opts.numUesPerSector))
            warning('runR23AasEirpCdfGrid:numBeamsConflict', ...
                ['opts.numBeams=%g conflicts with opts.numUesPerSector=%g; ' ...
                 'numUesPerSector wins.'], ...
                double(opts.numBeams), double(opts.numUesPerSector));
        end
        opts.numBeams = opts.numUesPerSector;
    elseif hasNumUes
        opts.numBeams = opts.numUesPerSector;
    elseif hasNumBeams
        opts.numUesPerSector = opts.numBeams;
    else
        opts.numUesPerSector = nestedParams.ue.numUesPerSector;
        opts.numBeams        = opts.numUesPerSector;
    end

    opts.numMc       = getOpt(opts, 'numMc',       nestedParams.sim.numSnapshots);
    opts.azGridDeg   = getOpt(opts, 'azGridDeg',   nestedParams.sim.azGrid_deg);
    opts.elGridDeg   = getOpt(opts, 'elGridDeg',   nestedParams.sim.elGrid_deg);
    opts.binEdgesDbm = getOpt(opts, 'binEdgesDbm', nestedParams.sim.binEdges_dBm);
    opts.percentiles = getOpt(opts, 'percentiles', nestedParams.sim.percentiles);
    opts.seed        = getOpt(opts, 'seed',        nestedParams.sim.randomSeed);
    opts.deployment  = getOpt(opts, 'deployment',  ...
                            environmentToDeployment(nestedParams.deployment.environment));
    opts.splitSectorPower    = getOpt(opts, 'splitSectorPower',    ...
                                        nestedParams.sim.splitSectorPower);
    opts.computePointingHeatmap = getOpt(opts, 'computePointingHeatmap', ...
                                        nestedParams.sim.computePointingHeatmap);
    opts.progressEvery       = getOpt(opts, 'progressEvery',       0);
    opts.mcChunkSize         = getOpt(opts, 'mcChunkSize',         ...
                                        min(double(opts.numMc), 500));
    opts.outputCsvPath       = getOpt(opts, 'outputCsvPath',       '');
    opts.outputMetadataPath  = getOpt(opts, 'outputMetadataPath',  '');
    opts.environment         = getOpt(opts, 'environment',         ...
                                        nestedParams.deployment.environment);

    % ---- propagate maxEirpPerSector override into params ------------
    if isnumeric(opts.maxEirpPerSector_dBm) && isscalar(opts.maxEirpPerSector_dBm) ...
            && isfinite(opts.maxEirpPerSector_dBm)
        params.sectorEirpDbm = double(opts.maxEirpPerSector_dBm);
        nestedParams.bs.maxEirpPerSector_dBm = double(opts.maxEirpPerSector_dBm);
    else
        error('runR23AasEirpCdfGrid:badMaxEirp', ...
            'opts.maxEirpPerSector_dBm must be a finite scalar [dBm].');
    end

    % ---- validation -------------------------------------------------
    validateNumUes(opts.numUesPerSector);
    validateNumMc(opts.numMc);

    azGrid = double(opts.azGridDeg(:).');
    elGrid = double(opts.elGridDeg(:).');
    edges  = double(opts.binEdgesDbm(:).');
    Naz    = numel(azGrid);
    Nel    = numel(elGrid);
    Nbin   = numel(edges) - 1;

    % ---- sector geometry --------------------------------------------
    sector = imtAasSingleSectorParams(opts.deployment, params);
    % Override sector geometry from nested params (cellRadius, bsHeight,
    % minUeDistance) so user-provided overrides are respected.
    sector.bsHeight_m       = nestedParams.deployment.bsHeight_m;
    sector.cellRadius_m     = nestedParams.deployment.cellRadius_m;
    sector.minUeDistance_m  = nestedParams.deployment.minUeDistance_m;
    sector.ueHeight_m       = nestedParams.ue.height_m;
    if isfield(nestedParams.deployment, 'sectorHalfWidthDeg') && ...
            ~isempty(nestedParams.deployment.sectorHalfWidthDeg)
        hw = double(nestedParams.deployment.sectorHalfWidthDeg);
        sector.azLimitsDeg  = [-hw, hw];
        sector.sectorWidthDeg = 2 * hw;
    end

    % ---- per-beam peak EIRP for metadata ----------------------------
    numBeams = double(opts.numUesPerSector);
    if opts.splitSectorPower
        perBeamPeakEirpDbm = params.sectorEirpDbm - 10 * log10(numBeams);
    else
        perBeamPeakEirpDbm = params.sectorEirpDbm;
    end

    % ---- init streaming stats ---------------------------------------
    stats = struct();
    stats.azGrid             = azGrid;
    stats.elGrid             = elGrid;
    stats.binEdges           = edges;
    stats.counts             = zeros(Naz, Nel, Nbin, 'uint32');
    stats.sum_lin_mW         = zeros(Naz, Nel);
    stats.min_dBm            =  inf(Naz, Nel);
    stats.max_dBm            = -inf(Naz, Nel);
    stats.numMc              = 0;
    stats.deployment         = sector.deployment;
    stats.environment        = nestedParams.deployment.environment;
    stats.numBeams           = numBeams;
    stats.numUesPerSector    = numBeams;
    stats.sectorEirpDbm      = params.sectorEirpDbm;
    stats.perBeamPeakEirpDbm = perBeamPeakEirpDbm;
    stats.params             = params;
    stats.opts               = opts;

    % ---- init pointing aggregator -----------------------------------
    computePointing = logical(opts.computePointingHeatmap);
    if computePointing
        pointAgg = struct();
        pointAgg.sumCosAz   = zeros(Naz, Nel);
        pointAgg.sumSinAz   = zeros(Naz, Nel);
        pointAgg.sumEl      = zeros(Naz, Nel);
        pointAgg.numSamples = zeros(Naz, Nel, 'uint32');
    end

    % ---- seed once and advance the global stream from there --------
    if ~isempty(opts.seed)
        rng(opts.seed);
    end

    sectorOpts = struct( ...
        'splitSectorPower', logical(opts.splitSectorPower), ...
        'returnPerBeam',    computePointing, ...
        'sectorEirpDbm',    params.sectorEirpDbm);

    progressEvery = double(opts.progressEvery);
    numMc         = double(opts.numMc);

    tStart = tic;
    for it = 1:numMc
        beams = imtAasGenerateBeamSet(numBeams, sector);

        sectorOut = imtAasSectorEirpGridFromBeams( ...
            azGrid, elGrid, beams, params, sectorOpts);

        stats = update_eirp_histograms(stats, sectorOut.aggregateEirpDbm);

        if computePointing
            steerAz = double(beams.steerAzDeg(:));
            steerEl = double(beams.steerElDeg(:));
            % Selected beam at each grid cell = argmax along beam axis.
            [~, idx] = max(sectorOut.perBeamEirpDbm, [], 3);
            selAz = steerAz(idx);   % Naz x Nel
            selEl = steerEl(idx);
            pointAgg.sumCosAz   = pointAgg.sumCosAz   + cosd(selAz);
            pointAgg.sumSinAz   = pointAgg.sumSinAz   + sind(selAz);
            pointAgg.sumEl      = pointAgg.sumEl      + selEl;
            pointAgg.numSamples = pointAgg.numSamples + uint32(1);
        end

        if progressEvery > 0 && mod(it, progressEvery) == 0
            tElapsed   = toc(tStart);
            tPerDraw   = tElapsed / it;
            tRemaining = tPerDraw * (numMc - it);
            fprintf(['[R23-MC] %d / %d (%.1f%%) ' ...
                     'elapsed=%.2fs ETA=%.2fs\n'], ...
                it, numMc, 100 * it / numMc, tElapsed, tRemaining);
        end
    end
    stats.elapsedSeconds = toc(tStart);

    stats.mean_lin_mW = stats.sum_lin_mW ./ max(stats.numMc, 1);
    stats.mean_dBm    = 10 .* log10(stats.mean_lin_mW);

    % ---- pointing summary ------------------------------------------
    if computePointing
        ns = double(pointAgg.numSamples);
        nsSafe = max(ns, 1);
        meanCos = pointAgg.sumCosAz ./ nsSafe;
        meanSin = pointAgg.sumSinAz ./ nsSafe;
        meanAz  = atan2d(meanSin, meanCos);
        meanEl  = pointAgg.sumEl ./ nsSafe;
        % Cells with no samples (should be none in this MVP) get NaN.
        noData = (ns == 0);
        meanAz(noData) = NaN;
        meanEl(noData) = NaN;

        pointing = struct();
        pointing.azimuthDegGrid     = meanAz;
        pointing.elevationDegGrid   = meanEl;
        pointing.numSamples         = pointAgg.numSamples;
        pointing.summaryStatistic   = nestedParams.sim.pointingSummaryStatistic;
        pointing.azWrappedConvention = 'circular mean via atan2d(sumSin, sumCos)';
        pointing.azGrid             = azGrid;
        pointing.elGrid             = elGrid;
        pointing.units              = 'degrees';
    else
        pointing = struct( ...
            'azimuthDegGrid',   [], ...
            'elevationDegGrid', [], ...
            'numSamples',       [], ...
            'summaryStatistic', 'disabled', ...
            'azGrid',           azGrid, ...
            'elGrid',           elGrid, ...
            'units',            'degrees');
    end

    % ---- percentile maps --------------------------------------------
    pmaps = eirp_percentile_maps(stats, opts.percentiles);

    % ---- metadata ---------------------------------------------------
    metadata = struct();
    metadata.generator             = 'runR23AasEirpCdfGrid';
    metadata.model                 = 'R23 7/8 GHz Extended AAS';
    metadata.scope                 = 'antenna-face EIRP CDF-grid only';
    metadata.aasModel              = nestedParams.metadata.aasModel;
    metadata.environment           = nestedParams.deployment.environment;
    metadata.deployment            = sector.deployment;
    metadata.cellRadius_m          = nestedParams.deployment.cellRadius_m;
    metadata.bsHeight_m            = nestedParams.deployment.bsHeight_m;
    metadata.bandwidthMHz          = params.bandwidthMHz;
    metadata.frequencyMHz          = params.frequencyMHz;
    metadata.numMc                 = double(opts.numMc);
    metadata.numSnapshots          = double(opts.numMc);
    metadata.numBeams              = numBeams;
    metadata.numUesPerSector       = numBeams;
    metadata.maxEirpPerSector_dBm  = params.sectorEirpDbm;
    metadata.sectorEirpDbm         = params.sectorEirpDbm;
    metadata.perBeamPeakEirpDbm    = perBeamPeakEirpDbm;
    metadata.splitSectorPower      = logical(opts.splitSectorPower);
    metadata.txPowerDbmPer100MHz   = params.txPowerDbmPer100MHz;
    metadata.peakGainDbi           = params.peakGainDbi;
    metadata.numRows               = params.numRows;
    metadata.numColumns            = params.numColumns;
    metadata.mechanicalDowntiltDeg = params.mechanicalDowntiltDeg;
    metadata.subarrayDowntiltDeg   = params.subarrayDowntiltDeg;
    metadata.seed                  = opts.seed;
    metadata.randomSeed            = opts.seed;
    metadata.computePointingHeatmap = computePointing;
    metadata.pointingSummaryStatistic = nestedParams.sim.pointingSummaryStatistic;
    metadata.sourceDefault         = nestedParams.metadata.sourceDefault;
    metadata.includesPathLoss              = false;
    metadata.includesReceiverAntenna       = false;
    metadata.includesReceiverGain          = false;
    metadata.includesINMetric              = false;
    metadata.includesPropagation           = false;
    metadata.includesCoordinationDistance  = false;
    metadata.includesMultiSiteAggregation  = false;
    metadata.notes = ['R23 Extended AAS antenna-face EIRP CDF-grid only. ', ...
        'No path loss, no receiver antenna gain, no I / N, ', ...
        'no propagation, no coordination distance, no 19-site laydown. ', ...
        'CDF/percentiles describe Monte Carlo source-side snapshots over ', ...
        'UE-driven beam pointings; they are NOT a time-probability ', ...
        'distribution beyond the Monte Carlo ensemble.'];
    metadata.createdAtIso          = iso8601Now();

    % ---- assemble output --------------------------------------------
    out = struct();
    out.params         = params;
    out.nestedParams   = nestedParams;
    out.sector         = sector;
    out.opts           = opts;
    out.stats          = stats;
    out.percentileMaps = pmaps;
    out.pointing       = pointing;
    out.metadata       = metadata;

    % ---- optional CSV export ----------------------------------------
    if ~isempty(opts.outputCsvPath)
        out.percentileTable = export_eirp_percentile_table( ...
            stats, opts.outputCsvPath);
    end

    % ---- optional metadata sidecar ----------------------------------
    if ~isempty(opts.outputMetadataPath)
        writeMetadataSidecar(metadata, opts.outputMetadataPath);
    end
end

% =====================================================================

function [opts, nestedParams] = resolveInputs(args)
%RESOLVEINPUTS Normalize varargin to (flat opts, nested params).

    nestedParams = [];
    opts = struct();

    if isempty(args)
        nestedParams = r23DefaultParams();
        return;
    end

    first = args{1};
    rest  = args(2:end);

    if isstruct(first)
        if looksLikeNestedParams(first)
            nestedParams = first;
        else
            opts = first;
        end
    elseif (ischar(first) || (isstring(first) && isscalar(first))) && ...
            mod(numel(args), 2) == 0
        % Pure name-value pair invocation.
        rest = args;
    else
        error('runR23AasEirpCdfGrid:badArgs', ...
            ['First argument must be a struct (flat opts or nested ' ...
             'params from r23DefaultParams) or a name/value string.']);
    end

    % If no nested params yet and an "environment" hint may be in the
    % name-value pairs, peek ahead so we can use the right preset.
    if isempty(nestedParams)
        env = peekNameValue(rest, 'environment');
        if isempty(env)
            envFromOpts = '';
            if isstruct(opts) && isfield(opts, 'environment') && ~isempty(opts.environment)
                envFromOpts = opts.environment;
            elseif isstruct(opts) && isfield(opts, 'deployment') && ~isempty(opts.deployment)
                envFromOpts = opts.deployment;
            end
            if ~isempty(envFromOpts)
                nestedParams = r23DefaultParams(envFromOpts);
            else
                nestedParams = r23DefaultParams();
            end
        else
            nestedParams = r23DefaultParams(env);
        end
    end

    % Apply name-value overrides over the (possibly nested) opts.
    if ~isempty(rest)
        for k = 1:2:numel(rest)
            nm = rest{k};
            if isstring(nm) && isscalar(nm)
                nm = char(nm);
            end
            if ~ischar(nm)
                error('runR23AasEirpCdfGrid:badNV', ...
                    'Name-value names must be char/string scalars.');
            end
            opts.(nm) = rest{k+1};
        end
    end

    % If a nested params field was passed inside flat opts, prefer it.
    if isstruct(opts) && isfield(opts, 'params') && isstruct(opts.params) && ...
            looksLikeNestedParams(opts.params)
        nestedParams = opts.params;
        opts = rmfield(opts, 'params');
    end
end

function tf = looksLikeNestedParams(s)
    tf = isstruct(s) && ...
         (isfield(s, 'aas') && isstruct(s.aas)) && ...
         (isfield(s, 'bs')  && isstruct(s.bs))  && ...
         (isfield(s, 'ue')  && isstruct(s.ue));
end

function v = peekNameValue(rest, name)
    v = '';
    for k = 1:2:numel(rest)-1
        nm = rest{k};
        if isstring(nm) && isscalar(nm)
            nm = char(nm);
        end
        if ischar(nm) && strcmpi(nm, name)
            v = rest{k+1};
            return;
        end
    end
end

function dep = environmentToDeployment(env)
    if isstring(env) && isscalar(env)
        env = char(env);
    end
    switch lower(env)
        case {'urban', 'macrourban'}
            dep = 'macroUrban';
        case {'suburban', 'macrosuburban'}
            dep = 'macroSuburban';
        otherwise
            dep = char(env);
    end
end

function validateNumUes(N)
    if ~(isnumeric(N) && isscalar(N) && isfinite(N) && N >= 1 && ...
            N == floor(N))
        error('runR23AasEirpCdfGrid:badNumUesPerSector', ...
            'numUesPerSector must be a positive integer.');
    end
end

function validateNumMc(N)
    if ~(isnumeric(N) && isscalar(N) && isfinite(N) && N >= 1 && ...
            N == floor(N))
        error('runR23AasEirpCdfGrid:badNumMc', ...
            'numMc / numSnapshots must be a positive integer.');
    end
end

function v = getOpt(opts, name, defaultVal)
    if isfield(opts, name) && ~isempty(opts.(name))
        v = opts.(name);
    else
        v = defaultVal;
    end
end

function s = iso8601Now()
    try
        s = char(datetime('now', 'TimeZone', 'UTC', ...
            'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    catch
        s = datestr(now, 'yyyy-mm-ddTHH:MM:SS'); %#ok<DATST,TNOW1>
    end
end

function writeMetadataSidecar(metadata, sidecarPath)
    [outDir, ~, ~] = fileparts(sidecarPath);
    if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end
    fid = fopen(sidecarPath, 'w');
    if fid < 0
        warning('runR23AasEirpCdfGrid:cannotOpenSidecar', ...
            'Could not open %s for writing.', sidecarPath);
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    try
        fprintf(fid, '%s', jsonencode(metadata));
    catch
        flds = fieldnames(metadata);
        for k = 1:numel(flds)
            v = metadata.(flds{k});
            if ischar(v) || isstring(v)
                fprintf(fid, '%s = %s\n', flds{k}, char(v));
            elseif islogical(v)
                fprintf(fid, '%s = %d\n', flds{k}, double(v));
            elseif isnumeric(v) && isscalar(v)
                fprintf(fid, '%s = %.10g\n', flds{k}, double(v));
            else
                fprintf(fid, '%s = <unprintable>\n', flds{k});
            end
        end
    end
end
