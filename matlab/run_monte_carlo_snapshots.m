function out = run_monte_carlo_snapshots(bs, gridPoints, params, simConfig)
%RUN_MONTE_CARLO_SNAPSHOTS Monte Carlo EIRP grid snapshots for one sector.
%
%   OUT = run_monte_carlo_snapshots(BS)
%   OUT = run_monte_carlo_snapshots(BS, GRIDPOINTS)
%   OUT = run_monte_carlo_snapshots(BS, GRIDPOINTS, PARAMS)
%   OUT = run_monte_carlo_snapshots(BS, GRIDPOINTS, PARAMS, SIMCONFIG)
%
%   Runs SIMCONFIG.numSnapshots Monte Carlo draws. For each snapshot:
%       (1) sample SIMCONFIG.numUes UE positions in the BS sector
%       (2) compute clamped BS->UE beam steering angles
%       (3) compute the sector-aggregate EIRP grid (per-direction, dBm /
%           100 MHz)
%
%   The MVP returns the full per-snapshot EIRP cube
%       eirpGrid : Naz x Nel x numSnapshots
%   so downstream code (e.g. compute_cdf_per_grid_point) can compute a
%   CDF per grid cell directly. This is intentionally NOT the streaming
%   aggregator used in runR23AasEirpCdfGrid; for very large grids /
%   numMc combinations, prefer that path.
%
%   Inputs:
%       BS          struct from get_default_bs (or override).
%       GRIDPOINTS  struct with .azGridDeg / .elGridDeg vectors.
%                   Defaults: azGridDeg = -90:5:90, elGridDeg = -30:5:10.
%       PARAMS      optional struct from get_r23_aas_params.
%       SIMCONFIG   optional struct:
%                       .numSnapshots      default 100
%                       .numUes            default 3 (R23)
%                       .seed              default 1 (RNG seed)
%                       .splitSectorPower  default true
%                       .progressEvery     default 0 (silent)
%                       .maxCubeMiB        optional cap on the estimated
%                                          full EIRP cube size (MiB).
%                                          Default 256. The estimate is
%                                          produced by
%                                          estimate_r23_mvp_cube_memory.
%                       .allowLargeCube    optional logical (default
%                                          false). When false and the
%                                          estimated cube exceeds
%                                          maxCubeMiB, the call fails
%                                          closed with a clear error
%                                          telling the user to reduce
%                                          the grid / numSnapshots or
%                                          to use the streaming
%                                          runR23AasEirpCdfGrid path.
%
%   Output struct fields:
%       eirpGrid             Naz x Nel x numSnapshots [dBm / 100 MHz]
%       AZ, EL               Naz x Nel ndgrid arrays [deg]
%       azGridDeg, elGridDeg passthroughs
%       perSnapshotBeams     1 x numSnapshots cell array of beam structs
%       perSnapshotUes       1 x numSnapshots cell array of UE structs
%       perBeamPeakEirpDbm   scalar
%       sectorEirpDbm        scalar
%       numSnapshots, numUes
%       params, bs           passthroughs
%       seed                 effective seed used
%       elapsedSeconds       wall-clock runtime
%       memoryEstimate       struct from estimate_r23_mvp_cube_memory
%       maxCubeMiB           effective guard threshold [MiB]
%       allowLargeCube       logical, whether the guard was bypassed
%
%   Example:
%       bs   = get_default_bs();
%       grid = struct('azGridDeg', -90:5:90, 'elGridDeg', -30:5:10);
%       out  = run_monte_carlo_snapshots(bs, grid, [], ...
%                  struct('numSnapshots', 200, 'seed', 42));
%       cdf  = compute_cdf_per_grid_point(out.eirpGrid);

    if nargin < 1 || isempty(bs)
        bs = get_default_bs();
    end
    if nargin < 2 || isempty(gridPoints)
        gridPoints = struct('azGridDeg', -90:5:90, 'elGridDeg', -30:5:10);
    end
    if nargin < 3 || isempty(params)
        params = get_r23_aas_params();
    end
    if nargin < 4 || isempty(simConfig)
        simConfig = struct();
    end

    numSnapshots     = getOpt(simConfig, 'numSnapshots',    100);
    numUes           = getOpt(simConfig, 'numUes',           3);
    seed             = getOpt(simConfig, 'seed',             1);
    splitSectorPower = getOpt(simConfig, 'splitSectorPower', true);
    progressEvery    = getOpt(simConfig, 'progressEvery',    0);
    maxCubeMiB       = getOpt(simConfig, 'maxCubeMiB',       256);
    allowLargeCube   = getOpt(simConfig, 'allowLargeCube',   false);

    if ~(isnumeric(numSnapshots) && isscalar(numSnapshots) && ...
            isfinite(numSnapshots) && numSnapshots >= 1 && ...
            numSnapshots == floor(numSnapshots))
        error('run_monte_carlo_snapshots:badNumSnapshots', ...
            'simConfig.numSnapshots must be a positive integer.');
    end
    if ~(isnumeric(numUes) && isscalar(numUes) && isfinite(numUes) && ...
            numUes >= 1 && numUes == floor(numUes))
        error('run_monte_carlo_snapshots:badNumUes', ...
            'simConfig.numUes must be a positive integer.');
    end
    if ~(isnumeric(maxCubeMiB) && isscalar(maxCubeMiB) && ...
            isfinite(maxCubeMiB) && maxCubeMiB > 0)
        error('run_monte_carlo_snapshots:badMaxCubeMiB', ...
            'simConfig.maxCubeMiB must be a positive finite scalar.');
    end
    if ~(islogical(allowLargeCube) || ...
            (isnumeric(allowLargeCube) && isscalar(allowLargeCube)))
        error('run_monte_carlo_snapshots:badAllowLargeCube', ...
            'simConfig.allowLargeCube must be a logical scalar.');
    end
    allowLargeCube = logical(allowLargeCube);

    azVec = double(gridPoints.azGridDeg(:).');
    elVec = double(gridPoints.elGridDeg(:).');
    Naz = numel(azVec);
    Nel = numel(elVec);
    [AZ, EL] = ndgrid(azVec, elVec);

    % --- Memory guardrail ---------------------------------------------
    % Estimate the full Naz x Nel x numSnapshots double cube before
    % allocating it. Fail closed when the estimate exceeds maxCubeMiB
    % unless allowLargeCube was set. The streaming runR23AasEirpCdfGrid
    % path is the recommended workflow for oversized jobs.
    memEst = estimate_r23_mvp_cube_memory(Naz, Nel, numSnapshots, ...
        struct('largeThresholdMiB', maxCubeMiB));
    if memEst.estimatedTotalMiB > maxCubeMiB && ~allowLargeCube
        error('run_monte_carlo_snapshots:cubeTooLarge', ...
            ['Estimated EIRP cube ~%.2f MiB exceeds maxCubeMiB = '...
             '%.2f MiB (Naz=%d, Nel=%d, numSnapshots=%d). Reduce '...
             'gridPoints or simConfig.numSnapshots, or use the '...
             'streaming runR23AasEirpCdfGrid workflow that never '...
             'materializes the per-draw EIRP cube. To bypass for a '...
             'small intentional run, set simConfig.allowLargeCube = '...
             'true.'], ...
            memEst.estimatedTotalMiB, maxCubeMiB, Naz, Nel, ...
            double(numSnapshots));
    end

    if ~isempty(seed)
        rng(seed);
    end

    sectorEirpDbm = double(bs.eirp_dBm_per_100MHz);
    if splitSectorPower
        perBeamPeakEirpDbm = sectorEirpDbm - 10 * log10(double(numUes));
    else
        perBeamPeakEirpDbm = sectorEirpDbm;
    end

    eirpGrid          = zeros(Naz, Nel, numSnapshots);
    perSnapshotBeams  = cell(1, numSnapshots);
    perSnapshotUes    = cell(1, numSnapshots);

    eirpOpts = struct('splitSectorPower', splitSectorPower);

    tStart = tic;
    for k = 1:numSnapshots
        % Use the rolling global RNG (no per-call seed) so the stream is
        % monotonic and reruns with the same seed are bit-identical.
        ue = sample_ue_positions_in_sector(bs, params, [], numUes);
        snap = compute_eirp_grid(bs, ue, gridPoints, params, eirpOpts);
        eirpGrid(:, :, k) = snap.aggregateEirpDbm;
        perSnapshotBeams{k} = snap.beams;
        perSnapshotUes{k}   = ue;

        if progressEvery > 0 && mod(k, progressEvery) == 0
            tElapsed = toc(tStart);
            tPerDraw = tElapsed / k;
            tRemain  = tPerDraw * (numSnapshots - k);
            fprintf(['[R23-MC] %d / %d (%.1f%%) elapsed=%.2fs ' ...
                     'ETA=%.2fs\n'], k, numSnapshots, ...
                     100 * k / numSnapshots, tElapsed, tRemain);
        end
    end

    out = struct();
    out.eirpGrid             = eirpGrid;
    out.AZ                   = AZ;
    out.EL                   = EL;
    out.azGridDeg            = azVec;
    out.elGridDeg            = elVec;
    out.perSnapshotBeams     = perSnapshotBeams;
    out.perSnapshotUes       = perSnapshotUes;
    out.perBeamPeakEirpDbm   = perBeamPeakEirpDbm;
    out.sectorEirpDbm        = sectorEirpDbm;
    out.numSnapshots         = double(numSnapshots);
    out.numUes               = double(numUes);
    out.splitSectorPower     = splitSectorPower;
    out.params               = params;
    out.bs                   = bs;
    out.seed                 = seed;
    out.elapsedSeconds       = toc(tStart);
    out.memoryEstimate       = memEst;
    out.maxCubeMiB           = double(maxCubeMiB);
    out.allowLargeCube       = allowLargeCube;
end

% =====================================================================

function v = getOpt(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end
