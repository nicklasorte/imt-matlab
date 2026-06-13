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
%        opts.environment, opts.computePointingHeatmap,
%        opts.clampElevation, opts.beamSelection, opts.codebookOversample.
%      The flat OPTS struct also accepts the same AAS geometry fields as
%      the name-value form:
%        opts.aasGeometryPreset,
%        opts.arrayRows, opts.arrayCols,
%        opts.subarrayElementRows, opts.subarrayElementCols,
%        opts.subarrayElementVerticalSpacingLambda,
%        opts.radiatingSubarrayHorizontalSpacingLambda,
%        opts.radiatingSubarrayVerticalSpacingLambda,
%        opts.subarrayDowntiltDeg, opts.mechanicalDowntiltDeg,
%        opts.elementGainDbi,
%        opts.sectorEirpDbm, opts.conductedPowerDbm.
%      When both the flat-opts and name-value forms supply the same
%      geometry field in one call, the name-value form wins (matches the
%      override-merge semantics used for the non-geometry fields).
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
%   AAS geometry preset (transmit-side antenna only):
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'r23_1x3_default')
%           -> source-aligned R23/ITU Extended AAS baseline (default).
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'ctia_7ghz_1x6')
%           -> CTIA 7 GHz 1x6 AAS sensitivity case (4x16 sub-array,
%              6 elements per sub-array, 768 total elements across two
%              polarizations, ~32.2 dBi antenna gain, ~90.8 dBm sector
%              EIRP at 58.6 dBm conducted power).
%       runR23AasEirpCdfGrid('aasGeometryPreset', 'custom', ...
%                            'arrayRows', 4, 'arrayCols', 16, ...
%                            'subarrayElementRows', 6, ...)
%           -> explicit geometry sensitivity. All required geometry
%              fields must be supplied. See aasGeometryPreset for the
%              full list of override names.
%
%   Beam selection (non-breaking; default 'ideal'):
%       runR23AasEirpCdfGrid('beamSelection', 'codebook', ...
%                            'codebookOversample', [4 4])
%       opts.beamSelection ('ideal' | 'codebook', default 'ideal'):
%           'ideal'    -> each beam points exactly at its served UE
%                         (continuous steering; historical behavior,
%                          byte-identical default).
%           'codebook' -> each beam is snapped to the nearest 3GPP
%                         TS 38.214 v19.2.0 Sec. 5.2.2.2.1 Type I
%                         single-panel oversampled-DFT (PMI) codebook
%                         beam, i.e. the quantized beam a real gNB would
%                         form from a reported PMI. Applied in the PANEL
%                         frame after the mechanical-tilt transform
%                         inside imtAasArrayFactor.
%       opts.codebookOversample: positive integer scalar or [O_H O_V]
%           pair, default [4 4] (TS 38.214 Table 5.2.2.2.1-2 default).
%       Surfaced in out.metadata.beamSelection / out.metadata.beamCodebook.
%       See imt_aas_dft_codebook / imt_aas_codebook_select for the
%       construction, the max-gain == nearest-bin property, and the
%       aliasing (grating lobe) caveat for the d_V = 2.1 lambda stack.
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
%       .selfCheck          power-semantics self-check struct:
%                             .powerSemantics       expected vs observed
%                                                   sector / per-beam peak
%                                                   EIRP, status field is
%                                                   'pass' / 'warn' / 'fail'
%                                                   (HARD FAIL on EIRP
%                                                    exceeding sector peak,
%                                                    SOFT WARN on coarse-
%                                                    grid undershoot).
%       .percentileTable    optional table from
%                           export_eirp_percentile_table when
%                           opts.outputCsvPath is provided.
%       .metadata           struct describing the run (generator, model,
%                           scope, no-path-loss/no-receiver caveats,
%                           environment, numUesPerSector,
%                           maxEirpPerSector_dBm, sourceDefault, ...).
%                           Provenance fields (best-effort, never fatal):
%                             .repoCommitSha          git HEAD or 'unknown'
%                             .matlabVersion          version + release tag
%                             .platform               os-arch identifier
%                             .validationTimestampUtc ISO 8601 UTC string
%
%   See also: r23DefaultParams, imtAasDefaultParams,
%             imtAasSingleSectorParams, imtAasGenerateBeamSet,
%             imtAasSectorEirpGridFromBeams, update_eirp_histograms,
%             eirp_percentile_maps, plotR23AasEirpCdfGrid,
%             plotR23AasPointingHeatmap.

    % ---- argument resolution ----------------------------------------
    [opts, nestedParams, geom] = resolveInputs(varargin);

    % ---- apply AAS geometry preset to nested params -----------------
    % The preset selects the radiating-subarray geometry (R23 1x3 default
    % or CTIA 7 GHz 1x6) and the corresponding sector EIRP / conducted
    % power. It is purely a transmit-side antenna change: no propagation,
    % no clutter, no receiver, no laydown is touched.
    nestedParams = applyGeometryPresetToNested(nestedParams, geom);

    params = r23ToImtAasParams(nestedParams);

    % ---- output frame (non-breaking; default 'global') --------------
    % Resolve + validate opts.outputFrame and propagate it as
    % params.observationFrame so it rides the params struct down through
    % imtAasSectorEirpGridFromBeams -> imtAasEirpGrid -> imtAasCompositeGain.
    %   'global' (default) / 'sector' (alias) -> curved sector-frame maps
    %   'panel'                               -> flat panel-frame maps
    opts.outputFrame = resolveOutputFrame(opts);
    params.observationFrame = opts.outputFrame;

    % ---- beam selection (non-breaking; default 'ideal') --------------
    % Resolve + validate opts.beamSelection / opts.codebookOversample and
    % propagate the result as params.beamCodebook so it rides the params
    % struct down through imtAasSectorEirpGridFromBeams -> imtAasEirpGrid
    % -> imtAasCompositeGain -> imtAasArrayFactor, where the PANEL-FRAME
    % steering spatial frequencies are snapped to the Type I DFT grid
    % (after the mechanical-tilt transform, so the codebook is fixed to
    % the array as on real hardware).
    %   'ideal'    (default) -> continuous steering (historical, no-op)
    %   'codebook'           -> 3GPP TS 38.214 Sec. 5.2.2.2.1 Type I
    %                           single-panel oversampled-DFT (PMI) beams
    [opts.beamSelection, params.beamCodebook] = resolveBeamCodebook(opts);

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
    opts.clampElevation      = getOpt(opts, 'clampElevation',      true);
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
    [hWaitbar_ml_mc_chunks,hWaitbarMsgQueue_ml_mc_chunks]= ParForWaitbarCreateMH_time('Number of MC: ',numMc);    %%%%%%% Create ParFor Waitbar, this one covers points and chunks
    for it = 1:numMc
        it
        beamGenOpts = struct('clampElevation', logical(opts.clampElevation));
        beams = imtAasGenerateBeamSet(numBeams, sector, beamGenOpts);

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
        hWaitbarMsgQueue_ml_mc_chunks.send(0);
    end
    delete(hWaitbarMsgQueue_ml_mc_chunks);
    close(hWaitbar_ml_mc_chunks);
    stats.elapsedSeconds = toc(tStart);

    stats.mean_lin_mW = stats.sum_lin_mW ./ max(stats.numMc, 1);
    stats.mean_dBm    = 10 .* log10(stats.mean_lin_mW);

    % ---- pointing summary ------------------------------------------
    tic;
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
    tic;

    % ---- percentile maps --------------------------------------------
    'Percentile Maps'
    tic;
    pmaps = eirp_percentile_maps(stats, opts.percentiles);
    toc;

    % ---- power-semantics self-check ---------------------------------
    % Continuously validate EIRP normalization to guard against future
    % power double-counting / aggregation / normalization regressions.
    %
    %   - HARD FAIL if the observed grid maximum exceeds the sector
    %     peak EIRP by more than a small numerical tolerance: that
    %     means power is being double-counted somewhere.
    %   - SOFT WARN if the observed peak is well below the expected
    %     per-beam peak: coarse grids / random steering may not land
    %     exactly on the beam peak, so this is informational only.
    %   - PASS otherwise.
    finiteMaxStats = stats.max_dBm(isfinite(stats.max_dBm));
    if isempty(finiteMaxStats)
        observedMax_dBm = -Inf;
    else
        observedMax_dBm = max(finiteMaxStats(:));
    end
    selfCheck = struct();
    selfCheck.powerSemantics = r23PowerSemanticsSelfCheck( ...
        observedMax_dBm, params.sectorEirpDbm, perBeamPeakEirpDbm, ...
        logical(opts.splitSectorPower));
    if strcmp(selfCheck.powerSemantics.status, 'fail')
        error('runR23AasEirpCdfGrid:powerSelfCheckFail', ...
            '%s', selfCheck.powerSemantics.message);
    elseif strcmp(selfCheck.powerSemantics.status, 'warn')
        warning('runR23AasEirpCdfGrid:powerSelfCheckWarn', ...
            '%s', selfCheck.powerSemantics.message);
    end

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
    metadata.outputFrame           = opts.outputFrame;
    metadata.beamSelection         = opts.beamSelection;
    metadata.beamCodebook          = params.beamCodebook;
    metadata.computePointingHeatmap = computePointing;
    metadata.clampElevation        = logical(opts.clampElevation);
    metadata.elevationLimitsDeg    = sector.elLimitsDeg;   % effective nominal gate [-10 0]
    metadata.pointingSummaryStatistic = nestedParams.sim.pointingSummaryStatistic;
    metadata.sourceDefault         = nestedParams.metadata.sourceDefault;
    % Propagate scenario preset metadata when present (set by
    % r23ScenarioPreset). Stays empty/absent for ad-hoc runs.
    if isfield(nestedParams, 'metadata') && isstruct(nestedParams.metadata)
        nm = nestedParams.metadata;
        if isfield(nm, 'scenarioPreset')
            metadata.scenarioPreset = nm.scenarioPreset;
        end
        if isfield(nm, 'scenarioCategory')
            metadata.scenarioCategory = nm.scenarioCategory;
        end
        if isfield(nm, 'sourceReference')
            metadata.sourceReference = nm.sourceReference;
        end
        if isfield(nm, 'reproducible')
            metadata.reproducible = logical(nm.reproducible);
        end
        if isfield(nm, 'presetOverrides')
            metadata.presetOverrides = nm.presetOverrides;
        end
        if isfield(nm, 'referenceOnly')
            metadata.referenceOnly = nm.referenceOnly;
        end
    end
    % ---- resolved AAS geometry preset (auditable) -------------------
    geomMeta = struct();
    geomMeta.aasGeometryPreset                          = geom.presetName;
    geomMeta.arrayRows                                  = double(geom.arrayRows);
    geomMeta.arrayCols                                  = double(geom.arrayCols);
    geomMeta.subarrayElementRows                        = double(geom.subarrayElementRows);
    geomMeta.subarrayElementCols                        = double(geom.subarrayElementCols);
    geomMeta.subarrayElementVerticalSpacingLambda       = double(geom.subarrayElementVerticalSpacingLambda);
    geomMeta.radiatingSubarrayHorizontalSpacingLambda   = double(geom.radiatingSubarrayHorizontalSpacingLambda);
    geomMeta.radiatingSubarrayVerticalSpacingLambda     = double(geom.radiatingSubarrayVerticalSpacingLambda);
    geomMeta.subarrayDowntiltDeg                        = double(geom.subarrayDowntiltDeg);
    geomMeta.mechanicalDowntiltDeg                      = double(geom.mechanicalDowntiltDeg);
    geomMeta.elementGainDbi                             = double(geom.elementGainDbi);
    geomMeta.calculatedSubarrayGainDb                   = double(geom.calculatedSubarrayGainDb);
    geomMeta.calculatedArrayGainDb                      = double(geom.calculatedArrayGainDb);
    geomMeta.calculatedAntennaGainDbi                   = double(geom.calculatedAntennaGainDbi);
    geomMeta.totalPhysicalElementsAcrossPolarizations   = double(geom.totalPhysicalElementsAcrossPolarizations);
    if isfield(geom, 'sectorEirpDbm') && ~isempty(geom.sectorEirpDbm)
        geomMeta.sectorEirpDbm = double(geom.sectorEirpDbm);
    end
    if isfield(geom, 'conductedPowerDbm') && ~isempty(geom.conductedPowerDbm)
        geomMeta.totalConductedPowerDbm = double(geom.conductedPowerDbm);
    end
    metadata.aasGeometry                   = geomMeta;
    metadata.aasGeometryPreset             = geom.presetName;

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
    metadata.validationTimestampUtc = metadata.createdAtIso;
    metadata.repoCommitSha         = getRepoCommitSha();
    metadata.matlabVersion         = getMatlabVersion();
    metadata.platform              = getPlatformDescription();

    % ---- assemble output --------------------------------------------
    out = struct();
    out.params         = params;
    out.nestedParams   = nestedParams;
    out.sector         = sector;
    out.opts           = opts;
    out.stats          = stats;
    out.percentileMaps = pmaps;
    out.pointing       = pointing;
    out.selfCheck      = selfCheck;
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

function [opts, nestedParams, geom] = resolveInputs(args)
%RESOLVEINPUTS Normalize varargin to (flat opts, nested params, geometry).

    nestedParams = [];
    opts = struct();

    if isempty(args)
        nestedParams = r23DefaultParams();
        geom = aasGeometryPreset('r23_1x3_default');
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

    % Strip geometry-related fields out of the flat OPTS struct and
    % convert them to the name-value form the existing geometry path
    % already consumes. They are prepended to `rest` so that any explicit
    % name-value override later in the same call wins (later wins inside
    % extractGeometryNameValues). This keeps the flat-opts and name-value
    % invocation styles bit-equivalent for identical inputs.
    [optsGeomNv, opts] = extractGeometryNvFromOpts(opts);
    rest = [optsGeomNv, rest];

    % Strip geometry-related name-value pairs before storing in opts.
    [geomPresetName, geomOverrides, rest] = extractGeometryNameValues(rest);

    % Apply remaining name-value overrides over the (possibly nested) opts.
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

    if isempty(geomPresetName)
        geomPresetName = 'r23_1x3_default';
    end
    geomOverrideArgs = structToNameValueCell(geomOverrides);
    geom = aasGeometryPreset(geomPresetName, geomOverrideArgs{:});
end

function [geomNv, opts] = extractGeometryNvFromOpts(opts)
%EXTRACTGEOMETRYNVFROMOPTS Strip geometry-related fields out of flat opts.
%
%   [GEOMNV, OPTS] = extractGeometryNvFromOpts(OPTS)
%
%   Pulls the AAS geometry preset name and per-field geometry overrides
%   out of the flat OPTS struct, returns them as a {name, value, ...}
%   cell array in canonical order (aasGeometryPreset first), and removes
%   them from OPTS. The cell array is fed into the same
%   extractGeometryNameValues path used for the name-value invocation,
%   so both invocation styles reach identical internal geometry state.
    geomNv = {};
    if ~isstruct(opts)
        return;
    end

    geomFieldNames = { ...
        'aasGeometryPreset', ...
        'arrayRows', 'arrayCols', ...
        'subarrayElementRows', 'subarrayElementCols', ...
        'subarrayElementVerticalSpacingLambda', ...
        'radiatingSubarrayHorizontalSpacingLambda', ...
        'radiatingSubarrayVerticalSpacingLambda', ...
        'subarrayDowntiltDeg', 'mechanicalDowntiltDeg', ...
        'elementGainDbi', ...
        'sectorEirpDbm', 'conductedPowerDbm'};

    for k = 1:numel(geomFieldNames)
        fld = geomFieldNames{k};
        if isfield(opts, fld)
            geomNv{end+1} = fld;          %#ok<AGROW>
            geomNv{end+1} = opts.(fld);   %#ok<AGROW>
            opts = rmfield(opts, fld);
        end
    end
end

function [presetName, overrides, restOut] = extractGeometryNameValues(rest)
%EXTRACTGEOMETRYNAMEVALUES Strip geometry NV pairs out of generic rest.
    presetName = '';
    overrides  = struct();
    keep       = true(1, numel(rest));

    geomFieldNames = { ...
        'arrayRows', 'arrayCols', ...
        'subarrayElementRows', 'subarrayElementCols', ...
        'subarrayElementVerticalSpacingLambda', ...
        'radiatingSubarrayHorizontalSpacingLambda', ...
        'radiatingSubarrayVerticalSpacingLambda', ...
        'subarrayDowntiltDeg', 'mechanicalDowntiltDeg', ...
        'elementGainDbi', ...
        'sectorEirpDbm', 'conductedPowerDbm'};

    for k = 1:2:numel(rest)-1
        nm = rest{k};
        if isstring(nm) && isscalar(nm)
            nm = char(nm);
        end
        if ~ischar(nm)
            continue;
        end
        if strcmpi(nm, 'aasGeometryPreset')
            v = rest{k+1};
            if isstring(v) && isscalar(v)
                v = char(v);
            end
            if ~ischar(v)
                error('runR23AasEirpCdfGrid:badGeometryPreset', ...
                    'aasGeometryPreset must be a char/string scalar.');
            end
            presetName = v;
            keep(k)   = false;
            keep(k+1) = false;
        else
            for f = 1:numel(geomFieldNames)
                if strcmp(nm, geomFieldNames{f})
                    overrides.(geomFieldNames{f}) = rest{k+1};
                    keep(k)   = false;
                    keep(k+1) = false;
                    break;
                end
            end
        end
    end

    restOut = rest(keep);
end

function args = structToNameValueCell(s)
%STRUCTTONAMEVALUECELL Flatten a struct into a {name, value, ...} cell.
    if ~isstruct(s)
        args = {};
        return;
    end
    flds = fieldnames(s);
    args = cell(1, 2 * numel(flds));
    for k = 1:numel(flds)
        args{2*k-1} = flds{k};
        args{2*k}   = s.(flds{k});
    end
end

function nestedParams = applyGeometryPresetToNested(nestedParams, geom)
%APPLYGEOMETRYPRESETTONESTED Push resolved geometry into nestedParams.aas/bs.
%
%   Only writes fields that the geometry preset has resolved. The nested
%   params struct is the single source of truth; downstream conversion
%   (r23ToImtAasParams) reads it.

    if ~isstruct(nestedParams) || ~isfield(nestedParams, 'aas') || ...
            ~isstruct(nestedParams.aas)
        return;
    end

    a = nestedParams.aas;

    a.numRows                                    = double(geom.arrayRows);
    a.numColumns                                 = double(geom.arrayCols);
    a.numElementRowsInSubarray                   = double(geom.subarrayElementRows);
    a.verticalElementSeparationInSubarray_lambda = double(geom.subarrayElementVerticalSpacingLambda);
    a.horizontalSpacing_lambda                   = double(geom.radiatingSubarrayHorizontalSpacingLambda);
    a.verticalSubarraySpacing_lambda             = double(geom.radiatingSubarrayVerticalSpacingLambda);
    a.subarrayDowntilt_deg                       = double(geom.subarrayDowntiltDeg);
    a.mechanicalDowntilt_deg                     = double(geom.mechanicalDowntiltDeg);
    a.elementGain_dBi                            = double(geom.elementGainDbi);
    a.aasGeometryPreset                          = geom.presetName;

    nestedParams.aas = a;

    % peakGain_dBi is metadata only (EIRP grids are renormalized to the
    % actual composite-gain peak inside imtAasEirpGrid), so it is left
    % alone here. The calculated antenna gain is surfaced via
    % out.metadata.aasGeometry.calculatedAntennaGainDbi.
    if isfield(nestedParams, 'bs') && isstruct(nestedParams.bs)
        b = nestedParams.bs;
        if isfield(geom, 'sectorEirpDbm') && ~isempty(geom.sectorEirpDbm) && ...
                isfinite(geom.sectorEirpDbm)
            b.maxEirpPerSector_dBm = double(geom.sectorEirpDbm);
        end
        if isfield(geom, 'conductedPowerDbm') && ~isempty(geom.conductedPowerDbm) && ...
                isfinite(geom.conductedPowerDbm)
            b.conductedPower_dBm = double(geom.conductedPowerDbm);
        end
        nestedParams.bs = b;
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

function [mode, cb] = resolveBeamCodebook(opts)
%RESOLVEBEAMCODEBOOK Read + validate opts.beamSelection / codebookOversample.
%   Default 'ideal' (continuous steering; the byte-identical historical
%   path). Allowed (case-insensitive): 'ideal', 'codebook'. 'codebook'
%   selects the 3GPP TS 38.214 v19.2.0 Sec. 5.2.2.2.1 Type I single-panel
%   oversampled-DFT (PMI) beam grid, applied to the panel-frame steering
%   inside imtAasArrayFactor. opts.codebookOversample is a positive
%   integer scalar or an [O_H O_V] pair; default [4 4] (TS 38.214 Table
%   5.2.2.2.1-2 default oversampling O1 = O2 = 4).
%   Errors:
%       runR23AasEirpCdfGrid:invalidBeamSelection
%       runR23AasEirpCdfGrid:invalidCodebookOversample
    mode = 'ideal';
    if isstruct(opts) && isfield(opts, 'beamSelection') && ...
            ~isempty(opts.beamSelection)
        mode = opts.beamSelection;
    end
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('runR23AasEirpCdfGrid:invalidBeamSelection', ...
            'opts.beamSelection must be a char/string scalar.');
    end
    mode = lower(mode);
    switch mode
        case {'ideal', 'codebook'}
            % ok
        otherwise
            error('runR23AasEirpCdfGrid:invalidBeamSelection', ...
                ['opts.beamSelection must be ''ideal'' or ''codebook'' ', ...
                 '(got ''%s'').'], mode);
    end

    os = [4 4];
    if isstruct(opts) && isfield(opts, 'codebookOversample') && ...
            ~isempty(opts.codebookOversample)
        os = opts.codebookOversample;
    end
    if ~(isnumeric(os) && isreal(os) && all(isfinite(os(:))) && ...
            any(numel(os) == [1 2]) && all(os(:) >= 1) && ...
            all(os(:) == floor(os(:))))
        error('runR23AasEirpCdfGrid:invalidCodebookOversample', ...
            ['opts.codebookOversample must be a positive integer scalar ', ...
             'or an [O_H O_V] pair of positive integers.']);
    end
    os = double(os(:).');
    if isscalar(os)
        os = [os, os];
    end

    if strcmp(mode, 'ideal')
        cb = struct('enable', false);
    else
        cb = struct('enable', true, ...
                    'oversampleH', os(1), ...
                    'oversampleV', os(2));
    end
end

function frame = resolveOutputFrame(opts)
%RESOLVEOUTPUTFRAME Read + validate the optional opts.outputFrame field.
%   Default 'global'. Allowed (case-insensitive): 'global', 'sector'
%   (alias of global), 'panel'. Errors with id
%   'runR23AasEirpCdfGrid:invalidOutputFrame' on any other value.
    frame = 'global';
    if isstruct(opts) && isfield(opts, 'outputFrame') && ~isempty(opts.outputFrame)
        frame = opts.outputFrame;
    end
    if isstring(frame) && isscalar(frame)
        frame = char(frame);
    end
    if ~ischar(frame)
        error('runR23AasEirpCdfGrid:invalidOutputFrame', ...
            'opts.outputFrame must be a char/string scalar.');
    end
    frame = lower(frame);
    switch frame
        case {'global', 'sector', 'panel'}
            % ok
        otherwise
            error('runR23AasEirpCdfGrid:invalidOutputFrame', ...
                ['opts.outputFrame must be one of ''global'', ''sector'', ', ...
                 '''panel'' (got ''%s'').'], frame);
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

function sha = getRepoCommitSha()
%GETREPOCOMMITSHA Best-effort `git rev-parse HEAD` for run provenance.
%   Returns 'unknown' when git or the repo are not available. Never
%   raises -- provenance is observability, not a hard precondition.
    sha = 'unknown';
    thisFile = mfilename('fullpath');
    if isempty(thisFile)
        return;
    end
    matlabDir = fileparts(thisFile);
    repoRoot  = fileparts(matlabDir);
    if isempty(repoRoot) || exist(repoRoot, 'dir') ~= 7
        return;
    end
    try
        cmd = sprintf('git -C "%s" rev-parse HEAD 2>/dev/null', repoRoot);
        [status, raw] = system(cmd);
        if status == 0
            tok = strtrim(raw);
            if ~isempty(tok)
                sha = tok;
            end
        end
    catch
        % Leave as 'unknown' on any failure.
    end
end

function v = getMatlabVersion()
%GETMATLABVERSION Compact MATLAB version string (e.g. '25.2 (R2025b)').
    v = 'unknown';
    try
        relStr = '';
        try
            r = version('-release');
            if ~isempty(r)
                relStr = sprintf(' (R%s)', r);
            end
        catch
        end
        v = sprintf('%s%s', version, relStr);
    catch
    end
end

function p = getPlatformDescription()
%GETPLATFORMDESCRIPTION Compact OS/arch identifier for provenance.
    p = 'unknown';
    try
        archStr = computer('arch');
    catch
        archStr = '';
    end
    try
        if ispc
            osStr = 'pc';
        elseif ismac
            osStr = 'mac';
        elseif isunix
            osStr = 'unix';
        else
            osStr = '';
        end
    catch
        osStr = '';
    end
    parts = {};
    if ~isempty(osStr); parts{end+1} = osStr; end %#ok<AGROW>
    if ~isempty(archStr); parts{end+1} = archStr; end %#ok<AGROW>
    if ~isempty(parts)
        p = strjoin(parts, '-');
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
