function out = profile_aas_monte_carlo_runtime(opts)
%PROFILE_AAS_MONTE_CARLO_RUNTIME Benchmark the AAS Monte Carlo engine.
%
%   OUT = profile_aas_monte_carlo_runtime()
%   OUT = profile_aas_monte_carlo_runtime(OPTS)
%
%   Runs a small set of benchmark cases against run_imt_aas_eirp_monte_carlo
%   and reports per-case timings, throughput, and full-grid extrapolations.
%   The full-grid case is a *dry-run estimate*: it never executes a full-
%   grid sweep at default 65,341 cells.
%
%   Each case is run in two modes when OPTS.compareModes is true (default):
%       reference   mcOpts.usePrecomputedGrid = false
%                   (the original imt_aas_bs_eirp / imt2020_composite_pattern path)
%       optimized   mcOpts.usePrecomputedGrid = true
%                   (precomputed grid + factored complex GEMVs)
%
%   The summary table shows wall-clock time, seconds-per-draw, and the
%   speedup factor of optimized over reference. A small numerical
%   max-difference (max abs |EIRP_opt - EIRP_ref|) is reported on the
%   smallest case to confirm the two paths agree to within float noise.
%
%   OPTS fields (all optional):
%       .cases       cell array, subset of {'small','medium'}.
%                    Default: {'small','medium'}. The full-grid extrapolation
%                    always uses the slowest measured case.
%       .cfg         struct. Override the default antenna config.
%       .seed        scalar. RNG seed (default 1).
%       .verbose     logical (default true). Print a summary table.
%       .quiet       logical (default false). Suppress run_imt_..._monte_carlo
%                    progress output (sets progressEvery=0 inside cases).
%       .runFullGrid logical (default false). If true, ACTUALLY runs the
%                    full az=-180:1:180, el=-90:1:90 grid for the numMc
%                    given in opts.fullGridNumMc. Off by default; the
%                    extrapolation result is enough for runtime planning.
%       .fullGridNumMc default 1.
%       .compareModes logical (default true). When true, runs each case
%                     twice (reference, optimized) and reports speedup.
%                     When false, only the optimized path is timed.
%
%   Output struct OUT contains:
%       .cases(k).name, .azGrid, .elGrid, .numAz, .numEl, .numCells,
%                 .numMc, .elapsedSecondsRef, .elapsedSecondsOpt,
%                 .secondsPerDrawRef, .secondsPerDrawOpt,
%                 .secondsPerCellPerDrawRef, .secondsPerCellPerDrawOpt,
%                 .speedupFactor, .memEstimate.
%       .extrapolation.<size>.fullGridSeconds  for numMc = 1e3, 1e4, 1e5
%                                              (uses the optimized path).
%       .extrapolation.basedOnCase
%       .equivalence.maxAbsDiff_dB             max abs(EIRP_opt - EIRP_ref)
%                                              on a small spot-check grid
%       .summary                                multiline string for printing
%
%   This routine does not change the antenna math. It exists purely to
%   help pick numMc and chunk sizes for production runs and to surface
%   regression in the optimized hot path.

    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'cases') || isempty(opts.cases)
        opts.cases = {'small', 'medium'};
    end
    if ~isfield(opts, 'seed') || isempty(opts.seed)
        opts.seed = 1;
    end
    if ~isfield(opts, 'verbose') || isempty(opts.verbose)
        opts.verbose = true;
    end
    if ~isfield(opts, 'quiet') || isempty(opts.quiet)
        opts.quiet = false;
    end
    if ~isfield(opts, 'runFullGrid') || isempty(opts.runFullGrid)
        opts.runFullGrid = false;
    end
    if ~isfield(opts, 'fullGridNumMc') || isempty(opts.fullGridNumMc)
        opts.fullGridNumMc = 1;
    end
    if ~isfield(opts, 'cfg') || isempty(opts.cfg)
        opts.cfg = defaultCfg();
    end
    if ~isfield(opts, 'compareModes') || isempty(opts.compareModes)
        opts.compareModes = true;
    end

    cfg = opts.cfg;
    binEdges = -50:1:120;
    numBins  = numel(binEdges) - 1;

    presets = struct();
    presets.small  = struct( ...
        'azGrid', -30:5:30, ...
        'elGrid', -20:5:10, ...
        'numMc',  100);
    presets.medium = struct( ...
        'azGrid', -90:2:90, ...
        'elGrid', -30:2:10, ...
        'numMc',  500);
    presets.full   = struct( ...
        'azGrid', -180:1:180, ...
        'elGrid', -90:1:90, ...
        'numMc',  opts.fullGridNumMc);

    nCases = numel(opts.cases);
    cases  = repmat(struct(), nCases, 1);

    for k = 1:nCases
        name = opts.cases{k};
        if ~isfield(presets, name)
            error('profile_aas_monte_carlo_runtime:unknownCase', ...
                'Unknown benchmark case "%s".', name);
        end
        p = presets.(name);
        Naz = numel(p.azGrid);
        Nel = numel(p.elGrid);

        % --- optimized path (always run) ---------------------------------
        mcOptsOpt = makeMcOpts(p, binEdges, opts.seed, opts.quiet, true);
        tStart    = tic;
        statsOpt  = run_imt_aas_eirp_monte_carlo(cfg, mcOptsOpt);
        elapsedOpt = toc(tStart);

        % --- reference path (optional) -----------------------------------
        if opts.compareModes
            mcOptsRef = makeMcOpts(p, binEdges, opts.seed, opts.quiet, false);
            tStart    = tic;
            statsRef  = run_imt_aas_eirp_monte_carlo(cfg, mcOptsRef); %#ok<NASGU>
            elapsedRef = toc(tStart);
        else
            elapsedRef = NaN;
        end

        cases(k).name                    = name;
        cases(k).azGrid                  = p.azGrid;
        cases(k).elGrid                  = p.elGrid;
        cases(k).numAz                   = Naz;
        cases(k).numEl                   = Nel;
        cases(k).numCells                = Naz * Nel;
        cases(k).numMc                   = p.numMc;
        cases(k).elapsedSecondsOpt       = elapsedOpt;
        cases(k).secondsPerDrawOpt       = elapsedOpt / p.numMc;
        cases(k).secondsPerCellPerDrawOpt = elapsedOpt / (p.numMc * Naz * Nel);
        cases(k).elapsedSecondsRef       = elapsedRef;
        if isfinite(elapsedRef)
            cases(k).secondsPerDrawRef       = elapsedRef / p.numMc;
            cases(k).secondsPerCellPerDrawRef = elapsedRef / (p.numMc * Naz * Nel);
            cases(k).speedupFactor            = elapsedRef / elapsedOpt;
        else
            cases(k).secondsPerDrawRef       = NaN;
            cases(k).secondsPerCellPerDrawRef = NaN;
            cases(k).speedupFactor            = NaN;
        end
        cases(k).memEstimate           = estimate_aas_mc_memory( ...
            Naz, Nel, numBins, 'uint32', struct('numMc', p.numMc));
        cases(k).antenna               = sprintf('N_H=%d, N_V=%d', cfg.N_H, cfg.N_V);
        cases(k).statsElapsedSecondsOpt = statsOpt.elapsedSeconds;

        % Back-compat aliases for callers that still read the old names.
        cases(k).elapsedSeconds        = elapsedOpt;
        cases(k).secondsPerDraw        = cases(k).secondsPerDrawOpt;
        cases(k).secondsPerCellPerDraw = cases(k).secondsPerCellPerDrawOpt;
        cases(k).statsElapsedSeconds   = statsOpt.elapsedSeconds;
    end

    out = struct();
    out.cases = cases;

    % --- Equivalence spot-check -------------------------------------------
    % Run a tiny grid through both paths with a fixed beam direction to
    % surface any unexpected numerical regression in the optimized path.
    out.equivalence = equivalenceSpotCheck(cfg);

    % --- Extrapolation: pick the slowest *cell-time* case as the basis ---
    if isempty(cases)
        error('profile_aas_monte_carlo_runtime:noCases', ...
            'At least one case must be specified.');
    end
    [~, basisIdx] = max([cases.secondsPerCellPerDrawOpt]);
    basis = cases(basisIdx);

    fullAz = numel(presets.full.azGrid);
    fullEl = numel(presets.full.elGrid);

    extrap = struct();
    extrap.basedOnCase   = basis.name;
    extrap.basedOnSecondsPerCellPerDraw = basis.secondsPerCellPerDrawOpt;
    extrap.fullGridNumAz  = fullAz;
    extrap.fullGridNumEl  = fullEl;
    extrap.fullGridCells  = fullAz * fullEl;
    extrap.numMc1e3      = basis.secondsPerCellPerDrawOpt * fullAz * fullEl * 1e3;
    extrap.numMc1e4      = basis.secondsPerCellPerDrawOpt * fullAz * fullEl * 1e4;
    extrap.numMc1e5      = basis.secondsPerCellPerDrawOpt * fullAz * fullEl * 1e5;
    extrap.fullGridMemEstimate = estimate_aas_mc_memory( ...
        fullAz, fullEl, numBins, 'uint32', struct('numMc', 1e4));

    if opts.runFullGrid
        p = presets.full;
        mcOptsFull = makeMcOpts(p, binEdges, opts.seed, true, true);
        tStart = tic;
        stats  = run_imt_aas_eirp_monte_carlo(cfg, mcOptsFull);
        extrap.measuredFullGridSeconds = toc(tStart);
        extrap.measuredFullGridStatsSeconds = stats.elapsedSeconds;
    end

    out.extrapolation = extrap;
    out.summary       = buildSummary(out);

    if opts.verbose
        fprintf('%s\n', out.summary);
    end
end

% ------------------------------------------------------------------------
function mcOpts = makeMcOpts(preset, binEdges, seed, quietProgress, usePrecomputed)
    mcOpts             = struct();
    mcOpts.numMc       = preset.numMc;
    mcOpts.azGrid      = preset.azGrid;
    mcOpts.elGrid      = preset.elGrid;
    mcOpts.binEdges    = binEdges;
    mcOpts.seed        = seed;
    if quietProgress
        mcOpts.progressEvery = 0;
    else
        mcOpts.progressEvery = max(1, round(preset.numMc / 4));
    end
    mcOpts.beamSampler = struct('mode', 'sector', ...
        'sector_az', 0, 'sector_az_width', 120, ...
        'elev_range', [-10, 0], 'numBeams', 1);
    mcOpts.usePrecomputedGrid = usePrecomputed;
end

% ------------------------------------------------------------------------
function eq = equivalenceSpotCheck(cfg)
    eq = struct('maxAbsDiff_dB', NaN, 'azGrid', [], 'elGrid', [], ...
        'beamCases', struct([]));
    azG = -30:5:30;
    elG = -20:5:10;
    [AZ, EL] = ndgrid(azG, elG);
    grid = prepare_aas_observation_grid(azG, elG, cfg);
    beams = struct( ...
        'azim_i', {0,  30, -45}, ...
        'elev_i', {0, -5, -10});

    maxDiff = 0;
    for i = 1:numel(beams)
        gainRef = imt2020_composite_pattern(AZ, EL, ...
            beams(i).azim_i, beams(i).elev_i, ...
            cfg.G_Emax, cfg.A_m, cfg.SLA_nu, ...
            cfg.phi_3db, cfg.theta_3db, ...
            cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, ...
            getf(cfg, 'rho', 1), getf(cfg, 'k', 12));
        gainOpt = imt2020_composite_pattern_precomputed(grid, ...
            beams(i).azim_i, beams(i).elev_i);
        d = gainOpt - gainRef;
        m = isfinite(d);
        if any(m(:))
            maxDiff = max(maxDiff, max(abs(d(m))));
        end
    end
    eq.azGrid = azG;
    eq.elGrid = elG;
    eq.maxAbsDiff_dB = maxDiff;
end

% ------------------------------------------------------------------------
function v = getf(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end

% ------------------------------------------------------------------------
function cfg = defaultCfg()
    cfg = struct();
    cfg.G_Emax        = 5;
    cfg.A_m           = 30;
    cfg.SLA_nu        = 30;
    cfg.phi_3db       = 65;
    cfg.theta_3db     = 65;
    cfg.d_H           = 0.5;
    cfg.d_V           = 0.5;
    cfg.N_H           = 8;
    cfg.N_V           = 8;
    cfg.rho           = 1;
    cfg.k             = 12;
    cfg.txPower_dBm   = 40;
    cfg.feederLoss_dB = 3;
end

% ------------------------------------------------------------------------
function s = buildSummary(out)
    lines = {};
    lines{end+1} = '================ AAS MC runtime profile ================';
    for k = 1:numel(out.cases)
        c = out.cases(k);
        lines{end+1} = sprintf('case "%s" (%s)', c.name, c.antenna); %#ok<*AGROW>
        lines{end+1} = sprintf('  grid              : %d az x %d el = %d cells', ...
            c.numAz, c.numEl, c.numCells);
        lines{end+1} = sprintf('  numMc             : %d', c.numMc);
        if isfinite(c.elapsedSecondsRef)
            lines{end+1} = sprintf('  elapsed (ref/opt) : %.3f s / %.3f s', ...
                c.elapsedSecondsRef, c.elapsedSecondsOpt);
            lines{end+1} = sprintf('  s/draw  (ref/opt) : %.3e s / %.3e s', ...
                c.secondsPerDrawRef, c.secondsPerDrawOpt);
            lines{end+1} = sprintf('  s/cell  (ref/opt) : %.3e s / %.3e s', ...
                c.secondsPerCellPerDrawRef, c.secondsPerCellPerDrawOpt);
            lines{end+1} = sprintf('  speedup (ref/opt) : %.2fx', c.speedupFactor);
        else
            lines{end+1} = sprintf('  elapsed           : %.3f s (optimized)', ...
                c.elapsedSecondsOpt);
            lines{end+1} = sprintf('  seconds per draw  : %.3e s', c.secondsPerDrawOpt);
            lines{end+1} = sprintf('  seconds per cell  : %.3e s/cell/draw', ...
                c.secondsPerCellPerDrawOpt);
        end
        lines{end+1} = sprintf('  histogram memory  : %s', humanBytes(c.memEstimate.histCountsBytes));
        lines{end+1} = sprintf('  pctile table mem  : %s', humanBytes(c.memEstimate.percentileTableBytes));
    end
    if isfield(out, 'equivalence') && isfinite(out.equivalence.maxAbsDiff_dB)
        lines{end+1} = sprintf('reference vs optimized max|EIRP diff|: %.3e dB', ...
            out.equivalence.maxAbsDiff_dB);
    end
    e = out.extrapolation;
    lines{end+1} = '----- full-grid extrapolation (optimized path) -----';
    lines{end+1} = sprintf('basis case          : %s (%.3e s/cell/draw)', ...
        e.basedOnCase, e.basedOnSecondsPerCellPerDraw);
    lines{end+1} = sprintf('full grid           : %d x %d = %d cells', ...
        e.fullGridNumAz, e.fullGridNumEl, e.fullGridCells);
    lines{end+1} = sprintf('numMc=1e3 estimate  : %s', humanSeconds(e.numMc1e3));
    lines{end+1} = sprintf('numMc=1e4 estimate  : %s', humanSeconds(e.numMc1e4));
    lines{end+1} = sprintf('numMc=1e5 estimate  : %s', humanSeconds(e.numMc1e5));
    lines{end+1} = sprintf('histogram memory    : %s', ...
        humanBytes(e.fullGridMemEstimate.histCountsBytes));
    lines{end+1} = sprintf('pctile table memory : %s', ...
        humanBytes(e.fullGridMemEstimate.percentileTableBytes));
    lines{end+1} = sprintf('pctile CSV on disk  : %s', ...
        humanBytes(e.fullGridMemEstimate.csvBytes));
    lines{end+1} = sprintf('NOTE: %s', e.fullGridMemEstimate.warning);
    if isfield(e, 'measuredFullGridSeconds')
        lines{end+1} = sprintf('measured full-grid run: %.3f s', ...
            e.measuredFullGridSeconds);
    end
    lines{end+1} = '=========================================================';
    s = strjoin(lines, sprintf('\n'));
end

% ------------------------------------------------------------------------
function s = humanBytes(b)
    units = {'B','KiB','MiB','GiB','TiB'};
    i = 1; v = double(b);
    while v >= 1024 && i < numel(units)
        v = v / 1024; i = i + 1;
    end
    if i == 1
        s = sprintf('%d %s', round(v), units{i});
    else
        s = sprintf('%.2f %s', v, units{i});
    end
end

% ------------------------------------------------------------------------
function s = humanSeconds(t)
    if t < 60
        s = sprintf('%.2f s', t);
    elseif t < 3600
        s = sprintf('%.2f min (%.0f s)', t / 60, t);
    elseif t < 86400
        s = sprintf('%.2f h (%.0f s)', t / 3600, t);
    else
        s = sprintf('%.2f d (%.0f s)', t / 86400, t);
    end
end
