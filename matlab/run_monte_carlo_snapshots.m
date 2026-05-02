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

    azVec = double(gridPoints.azGridDeg(:).');
    elVec = double(gridPoints.elGridDeg(:).');
    Naz = numel(azVec);
    Nel = numel(elVec);
    [AZ, EL] = ndgrid(azVec, elVec);

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
end

% =====================================================================

function v = getOpt(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end
