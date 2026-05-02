function stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts)
%RUN_IMT_AAS_EIRP_MONTE_CARLO Streaming Monte Carlo of AAS BS EIRP.
%
%   STATS = run_imt_aas_eirp_monte_carlo(CFG, MCOPTS)
%
%   Runs MCOPTS.numMc Monte Carlo draws of beam pointing(s), evaluates the
%   M.2101 composite-array EIRP on the requested az/el grid, and aggregates
%   per-cell streaming statistics. The full per-draw EIRP cube is NEVER
%   retained.
%
%   CFG fields (see imt_aas_bs_eirp): G_Emax, A_m, SLA_nu, phi_3db,
%       theta_3db, d_H, d_V, N_H, N_V, rho, k, txPower_dBm, feederLoss_dB.
%
%   MCOPTS fields:
%       .numMc           scalar, number of MC iterations (required)
%       .azGrid          1xNaz vector [deg], default -180:1:180
%       .elGrid          1xNel vector [deg], default  -90:1:90
%       .binEdges        1x(Nbin+1) histogram bin edges [dBm],
%                        default -50:1:120
%       .beamSampler     struct passed to sample_aas_beam_direction
%                        (default uniform sector pointing)
%       .seed            scalar RNG seed (optional)
%       .progressEvery   integer, print progress every N draws (default 0).
%                        Output includes percent complete, elapsed time,
%                        and estimated remaining time. Set to 0 to disable.
%       .mcChunkSize     integer, optional. Process Monte Carlo draws in
%                        chunks of this size. Defaults to numMc (single
%                        chunk). Chunking does not change the RNG sequence
%                        and produces results bit-identical to an unchunked
%                        run with the same seed.
%       .combineBeams    'max' (default) or 'sum_mW'. With multiple active
%                        beams per draw, take per-cell maximum EIRP or
%                        linear-power sum across beams before updating.
%       .usePrecomputedGrid
%                        logical (default true). When true the engine
%                        builds a precomputed observation grid once and
%                        evaluates the composite pattern via
%                        imt2020_composite_pattern_precomputed (factored
%                        complex GEMVs). Set false to fall back to the
%                        reference imt_aas_bs_eirp / imt2020_composite_pattern
%                        path (useful for diffing or debugging).
%
%   STATS fields (see update_eirp_histograms for shapes), plus:
%       .elapsedSeconds  wall-clock seconds spent inside the MC loop.

    if nargin < 2 || ~isstruct(mcOpts)
        error('run_imt_aas_eirp_monte_carlo:missingOpts', ...
            'mcOpts struct is required.');
    end
    if ~isfield(mcOpts, 'numMc') || mcOpts.numMc < 1
        error('run_imt_aas_eirp_monte_carlo:badNumMc', ...
            'mcOpts.numMc must be a positive integer.');
    end

    if ~isfield(mcOpts, 'azGrid') || isempty(mcOpts.azGrid)
        mcOpts.azGrid = -180:1:180;
    end
    if ~isfield(mcOpts, 'elGrid') || isempty(mcOpts.elGrid)
        mcOpts.elGrid =  -90:1:90;
    end
    if ~isfield(mcOpts, 'binEdges') || isempty(mcOpts.binEdges)
        mcOpts.binEdges = -50:1:120;
    end
    if ~isfield(mcOpts, 'beamSampler') || isempty(mcOpts.beamSampler)
        mcOpts.beamSampler = struct('mode', 'uniform', ...
            'azim_range', [-60, 60], 'elev_range', [-10, 0], 'numBeams', 1);
    end
    if ~isfield(mcOpts, 'progressEvery') || isempty(mcOpts.progressEvery)
        mcOpts.progressEvery = 0;
    end
    if ~isfield(mcOpts, 'combineBeams') || isempty(mcOpts.combineBeams)
        mcOpts.combineBeams = 'max';
    end
    if ~isfield(mcOpts, 'mcChunkSize') || isempty(mcOpts.mcChunkSize)
        mcOpts.mcChunkSize = mcOpts.numMc;
    end
    if mcOpts.mcChunkSize < 1
        error('run_imt_aas_eirp_monte_carlo:badChunkSize', ...
            'mcOpts.mcChunkSize must be a positive integer.');
    end
    if ~isfield(mcOpts, 'usePrecomputedGrid') || isempty(mcOpts.usePrecomputedGrid)
        mcOpts.usePrecomputedGrid = true;
    end
    if isfield(mcOpts, 'seed') && ~isempty(mcOpts.seed)
        rng(mcOpts.seed);
    end

    % Default a few CFG fields the optimized fast path needs to know up
    % front (imt_aas_bs_eirp does the same defaulting on the slow path).
    if ~isfield(cfg, 'feederLoss_dB') || isempty(cfg.feederLoss_dB)
        cfg.feederLoss_dB = 0;
    end
    if ~isfield(cfg, 'rho') || isempty(cfg.rho); cfg.rho = 1; end
    if ~isfield(cfg, 'k')   || isempty(cfg.k);   cfg.k   = 12; end

    azGrid = mcOpts.azGrid(:).';
    elGrid = mcOpts.elGrid(:).';
    Naz    = numel(azGrid);
    Nel    = numel(elGrid);
    edges  = mcOpts.binEdges(:).';
    Nbin   = numel(edges) - 1;

    % Build az/el grids that match update_eirp_histograms shape
    [AZ, EL] = ndgrid(azGrid, elGrid);   % both [Naz x Nel]

    usePrecomputed = logical(mcOpts.usePrecomputedGrid);
    if usePrecomputed
        grid = prepare_aas_observation_grid(azGrid, elGrid, cfg);
    else
        grid = [];
    end

    % --- init streaming stats --------------------------------------------
    stats = struct();
    stats.azGrid     = azGrid;
    stats.elGrid     = elGrid;
    stats.binEdges   = edges;
    stats.counts     = zeros(Naz, Nel, Nbin, 'uint32');
    stats.sum_lin_mW = zeros(Naz, Nel);
    stats.min_dBm    =  inf(Naz, Nel);
    stats.max_dBm    = -inf(Naz, Nel);
    stats.numMc      = 0;
    stats.cfg        = cfg;
    stats.mcOpts     = mcOpts;

    progressEvery = mcOpts.progressEvery;
    chunkSize     = min(mcOpts.mcChunkSize, mcOpts.numMc);
    numMc         = mcOpts.numMc;

    tStart = tic;

    nDone = 0;
    while nDone < numMc
        nThis = min(chunkSize, numMc - nDone);
        for it = 1:nThis
            iter = nDone + it;

            [azim_i, elev_i] = sample_aas_beam_direction(mcOpts.beamSampler);

            if numel(azim_i) == 1
                if usePrecomputed
                    gain_dBi = imt2020_composite_pattern_precomputed( ...
                        grid, azim_i, elev_i, cfg.rho, cfg.k);
                    eirp_dBm = cfg.txPower_dBm + gain_dBi - cfg.feederLoss_dB;
                else
                    eirp_dBm = imt_aas_bs_eirp(AZ, EL, azim_i, elev_i, cfg);
                end
            else
                if usePrecomputed
                    eirp_dBm = combineMultiBeamPrecomputed(grid, ...
                        azim_i, elev_i, cfg, mcOpts.combineBeams);
                else
                    eirp_dBm = combineMultiBeam(AZ, EL, ...
                        azim_i, elev_i, cfg, mcOpts.combineBeams);
                end
            end

            stats = update_eirp_histograms(stats, eirp_dBm);

            if progressEvery > 0 && mod(iter, progressEvery) == 0
                tElapsed   = toc(tStart);
                tPerDraw   = tElapsed / iter;
                tRemaining = tPerDraw * (numMc - iter);
                fprintf(['[MC] %d / %d (%.1f%%) ' ...
                         'elapsed=%.2fs ETA=%.2fs\n'], ...
                    iter, numMc, 100 * iter / numMc, ...
                    tElapsed, tRemaining);
            end
        end
        nDone = nDone + nThis;
    end

    stats.elapsedSeconds = toc(tStart);

    % derived field convenient for users
    stats.mean_lin_mW = stats.sum_lin_mW ./ max(stats.numMc, 1);
    stats.mean_dBm    = 10 .* log10(stats.mean_lin_mW);
end

function eirp = combineMultiBeam(AZ, EL, azim_i, elev_i, cfg, combineMode)
    nB = numel(azim_i);
    eirpStack = zeros([size(AZ), nB]);
    for b = 1:nB
        eirpStack(:,:,b) = imt_aas_bs_eirp(AZ, EL, azim_i(b), elev_i(b), cfg);
    end
    eirp = reduceBeams(eirpStack, combineMode);
end

function eirp = combineMultiBeamPrecomputed(grid, azim_i, elev_i, cfg, combineMode)
    nB = numel(azim_i);
    eirpStack = zeros([grid.Naz, grid.Nel, nB]);
    for b = 1:nB
        gain_dBi = imt2020_composite_pattern_precomputed( ...
            grid, azim_i(b), elev_i(b), cfg.rho, cfg.k);
        eirpStack(:,:,b) = cfg.txPower_dBm + gain_dBi - cfg.feederLoss_dB;
    end
    eirp = reduceBeams(eirpStack, combineMode);
end

function eirp = reduceBeams(eirpStack, combineMode)
    switch lower(combineMode)
        case 'max'
            eirp = max(eirpStack, [], 3);
        case 'sum_mw'
            eirp = 10 .* log10(sum(10.^(eirpStack ./ 10), 3));
        otherwise
            error('run_imt_aas_eirp_monte_carlo:badCombine', ...
                'Unknown combineBeams mode "%s"', combineMode);
    end
end
