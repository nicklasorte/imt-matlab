function out = runR23AasEirpCdfGrid(opts)
%RUNR23AASEIRPCDFGRID R23 7/8 GHz Extended AAS EIRP CDF-grid generator.
%
%   OUT = runR23AasEirpCdfGrid(OPTS)
%
%   Source-aligned MVP entry point for the R23 7.125-8.4 GHz Extended AAS
%   per-(azimuth, elevation) EIRP CDF-grid generator. For each Monte
%   Carlo draw the runner samples NUMBEAMS UE-driven beam steering
%   angles, builds the aggregate antenna-face sector EIRP grid via
%   imtAasSectorEirpGridFromBeams (linear-mW summed over the
%   simultaneous beams), and updates a streaming per-cell histogram.
%   The full per-draw EIRP cube is NEVER materialised.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N, NO FS / FSS receiver logic, NO
%   coordination distance, and NO multi-site aggregation in this slice.
%
%   Inputs (OPTS struct, all fields optional):
%       .numMc              positive integer, default 1000.
%       .azGridDeg          azimuth grid [deg], default -180:1:180.
%       .elGridDeg          elevation grid [deg], default -90:1:90.
%       .binEdgesDbm        histogram bin edges [dBm], default
%                           -100:1:120.
%       .percentiles        vector [0,100], default
%                           [1 5 10 20 50 80 90 95 99].
%       .seed               RNG seed (default 1). Seeding is performed
%                           ONCE up front; per-draw beam sampling then
%                           advances the global RNG stream so that
%                           reruns with the same seed are bit-identical.
%       .deployment         char/string, default 'macroUrban'. Passed to
%                           imtAasSingleSectorParams. Supported:
%                           'macroUrban', 'macroSuburban'.
%       .numBeams           positive integer, default
%                           params.numUesPerSector (= 3).
%       .splitSectorPower   logical, default true. When true the sector
%                           EIRP is split across simultaneous beams via
%                              perBeamPeakEirpDbm =
%                                  sectorEirpDbm - 10*log10(numBeams).
%       .progressEvery      integer, default 0 (silent). Print progress
%                           every N draws.
%       .mcChunkSize        integer, default min(numMc, 500). Reserved
%                           for forward compatibility; the streaming
%                           aggregator does not require chunking but
%                           accepting the field keeps a uniform option
%                           surface across runners.
%       .outputCsvPath      optional CSV path; when non-empty the
%                           p000..p100 percentile table is written via
%                           export_eirp_percentile_table.
%       .outputMetadataPath optional sidecar path; when non-empty the
%                           OUT.metadata struct is JSON-encoded (with a
%                           plain-text fallback when jsonencode is
%                           unavailable).
%
%   Output (OUT struct):
%       .params             imtAasDefaultParams() struct used.
%       .sector             imtAasSingleSectorParams(deployment, params).
%       .opts               resolved opts struct (with defaults filled).
%       .stats              streaming aggregator with fields:
%                             .azGrid, .elGrid             [deg]
%                             .binEdges                    [dBm]
%                             .counts        Naz x Nel x Nbin uint32
%                             .sum_lin_mW    Naz x Nel
%                             .min_dBm       Naz x Nel
%                             .max_dBm       Naz x Nel
%                             .numMc         scalar
%                             .mean_lin_mW   Naz x Nel  (linear-mW mean)
%                             .mean_dBm      Naz x Nel  (10*log10 thereof)
%                             .perBeamPeakEirpDbm
%                             .sectorEirpDbm
%                             .numBeams
%                             .deployment
%                             .params, .opts
%                             .elapsedSeconds
%       .percentileMaps     struct from eirp_percentile_maps.
%       .percentileTable    optional table from
%                           export_eirp_percentile_table when
%                           opts.outputCsvPath is provided.
%       .metadata           struct describing the run (generator, model,
%                           scope, no-path-loss/no-receiver caveats).
%
%   Power semantics (R23 macro 7.125-8.4 GHz):
%       sectorEirpDbm        = 78.3   sector peak EIRP [dBm / 100 MHz]
%       txPowerDbmPer100MHz  = 46.1   conducted BS power [dBm / 100 MHz]
%       peakGainDbi          = 32.2   peak composite gain [dBi]
%       46.1 + 32.2 = 78.3
%
%   For 3 simultaneous beams with splitSectorPower = true:
%       perBeamPeakEirpDbm = 78.3 - 10*log10(3)  ~  73.53 dBm / 100 MHz
%
%   See also: imtAasDefaultParams, imtAasSingleSectorParams,
%             imtAasGenerateBeamSet, imtAasSectorEirpGridFromBeams,
%             update_eirp_histograms, eirp_percentile_maps,
%             plotR23AasEirpCdfGrid.

    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('runR23AasEirpCdfGrid:badOpts', ...
            'OPTS must be a struct (or omitted).');
    end

    params = imtAasDefaultParams();

    % ---- resolve opts with defaults ----------------------------------
    opts.numMc       = getOpt(opts, 'numMc',       1000);
    opts.azGridDeg   = getOpt(opts, 'azGridDeg',   -180:1:180);
    opts.elGridDeg   = getOpt(opts, 'elGridDeg',    -90:1:90);
    opts.binEdgesDbm = getOpt(opts, 'binEdgesDbm', -100:1:120);
    opts.percentiles = getOpt(opts, 'percentiles', ...
                                  [1 5 10 20 50 80 90 95 99]);
    opts.seed        = getOpt(opts, 'seed',        1);
    opts.deployment  = getOpt(opts, 'deployment',  'macroUrban');
    opts.numBeams    = getOpt(opts, 'numBeams',    params.numUesPerSector);
    opts.splitSectorPower = getOpt(opts, 'splitSectorPower', true);
    opts.progressEvery = getOpt(opts, 'progressEvery', 0);
    opts.mcChunkSize = getOpt(opts, 'mcChunkSize', ...
                                  min(opts.numMc, 500));
    opts.outputCsvPath      = getOpt(opts, 'outputCsvPath',      '');
    opts.outputMetadataPath = getOpt(opts, 'outputMetadataPath', '');

    if ~(isnumeric(opts.numMc) && isscalar(opts.numMc) && ...
            isfinite(opts.numMc) && opts.numMc >= 1 && ...
            opts.numMc == floor(opts.numMc))
        error('runR23AasEirpCdfGrid:badNumMc', ...
            'opts.numMc must be a positive integer.');
    end
    if ~(isnumeric(opts.numBeams) && isscalar(opts.numBeams) && ...
            isfinite(opts.numBeams) && opts.numBeams >= 1 && ...
            opts.numBeams == floor(opts.numBeams))
        error('runR23AasEirpCdfGrid:badNumBeams', ...
            'opts.numBeams must be a positive integer.');
    end

    azGrid = double(opts.azGridDeg(:).');
    elGrid = double(opts.elGridDeg(:).');
    edges  = double(opts.binEdgesDbm(:).');
    Naz    = numel(azGrid);
    Nel    = numel(elGrid);
    Nbin   = numel(edges) - 1;

    % ---- sector geometry --------------------------------------------
    sector = imtAasSingleSectorParams(opts.deployment, params);

    % ---- per-beam peak EIRP for metadata ----------------------------
    if opts.splitSectorPower
        perBeamPeakEirpDbm = params.sectorEirpDbm ...
            - 10 * log10(double(opts.numBeams));
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
    stats.numBeams           = double(opts.numBeams);
    stats.sectorEirpDbm      = params.sectorEirpDbm;
    stats.perBeamPeakEirpDbm = perBeamPeakEirpDbm;
    stats.params             = params;
    stats.opts               = opts;

    % ---- seed once and advance the global stream from there --------
    if ~isempty(opts.seed)
        rng(opts.seed);
    end

    sectorOpts = struct( ...
        'splitSectorPower', logical(opts.splitSectorPower), ...
        'returnPerBeam',    false);

    progressEvery = opts.progressEvery;
    numMc         = double(opts.numMc);

    tStart = tic;
    for it = 1:numMc
        % imtAasGenerateBeamSet -> imtAasSampleUePositions advances the
        % global RNG when no per-call seed is supplied. We deliberately
        % do not pass a per-draw seed so the stream is monotonic and
        % bit-identical across reruns under the same opts.seed.
        beams = imtAasGenerateBeamSet(opts.numBeams, sector);

        sectorOut = imtAasSectorEirpGridFromBeams( ...
            azGrid, elGrid, beams, params, sectorOpts);

        stats = update_eirp_histograms(stats, sectorOut.aggregateEirpDbm);

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

    % ---- percentile maps --------------------------------------------
    pmaps = eirp_percentile_maps(stats, opts.percentiles);

    % ---- metadata ---------------------------------------------------
    metadata = struct();
    metadata.generator           = 'runR23AasEirpCdfGrid';
    metadata.model               = 'R23 7/8 GHz Extended AAS';
    metadata.scope               = 'antenna-face EIRP CDF-grid only';
    metadata.bandwidthMHz        = params.bandwidthMHz;
    metadata.frequencyMHz        = params.frequencyMHz;
    metadata.deployment          = sector.deployment;
    metadata.numMc               = double(opts.numMc);
    metadata.numBeams            = double(opts.numBeams);
    metadata.sectorEirpDbm       = params.sectorEirpDbm;
    metadata.perBeamPeakEirpDbm  = perBeamPeakEirpDbm;
    metadata.splitSectorPower    = logical(opts.splitSectorPower);
    metadata.txPowerDbmPer100MHz = params.txPowerDbmPer100MHz;
    metadata.peakGainDbi         = params.peakGainDbi;
    metadata.numRows             = params.numRows;
    metadata.numColumns          = params.numColumns;
    metadata.mechanicalDowntiltDeg = params.mechanicalDowntiltDeg;
    metadata.subarrayDowntiltDeg = params.subarrayDowntiltDeg;
    metadata.seed                = opts.seed;
    metadata.includesPathLoss            = false;
    metadata.includesReceiverAntenna     = false;
    metadata.includesReceiverGain        = false;
    metadata.includesINMetric            = false;
    metadata.includesPropagation         = false;
    metadata.includesCoordinationDistance = false;
    metadata.includesMultiSiteAggregation = false;
    metadata.notes = ['R23 Extended AAS antenna-face EIRP CDF-grid only. ', ...
        'No path loss, no receiver antenna gain, no I / N, ', ...
        'no propagation, no coordination distance, no 19-site laydown. ', ...
        'CDF/percentiles describe Monte Carlo source-side snapshots over ', ...
        'UE-driven beam pointings; they are NOT a time-probability ', ...
        'distribution beyond the Monte Carlo ensemble.'];
    metadata.createdAtIso        = iso8601Now();

    % ---- assemble output --------------------------------------------
    out = struct();
    out.params         = params;
    out.sector         = sector;
    out.opts           = opts;
    out.stats          = stats;
    out.percentileMaps = pmaps;
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
        % plain-text fallback (no jsonencode in some Octave configs)
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
