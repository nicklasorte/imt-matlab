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
%
%   Output struct OUT contains:
%       .cases(k).name, .azGrid, .elGrid, .numAz, .numEl, .numCells,
%                 .numMc, .elapsedSeconds, .secondsPerDraw,
%                 .secondsPerCellPerDraw, .memEstimate (struct from
%                 estimate_aas_mc_memory).
%       .extrapolation.<size>.fullGridSeconds   for numMc = 1e3, 1e4, 1e5
%       .extrapolation.fullGridMemEstimate
%       .extrapolation.basedOnCase
%       .summary  multiline string suitable for printing
%
%   This routine does not change the antenna math. It exists purely to help
%   pick numMc and chunk sizes for production runs.

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

        mcOpts             = struct();
        mcOpts.numMc       = p.numMc;
        mcOpts.azGrid      = p.azGrid;
        mcOpts.elGrid      = p.elGrid;
        mcOpts.binEdges    = binEdges;
        mcOpts.seed        = opts.seed;
        if opts.quiet
            mcOpts.progressEvery = 0;
        else
            mcOpts.progressEvery = max(1, round(p.numMc / 4));
        end
        mcOpts.beamSampler = struct('mode', 'sector', ...
            'sector_az', 0, 'sector_az_width', 120, ...
            'elev_range', [-10, 0], 'numBeams', 1);

        Naz = numel(p.azGrid);
        Nel = numel(p.elGrid);

        tStart = tic;
        stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
        elapsed = toc(tStart);

        cases(k).name                 = name;
        cases(k).azGrid               = p.azGrid;
        cases(k).elGrid               = p.elGrid;
        cases(k).numAz                = Naz;
        cases(k).numEl                = Nel;
        cases(k).numCells             = Naz * Nel;
        cases(k).numMc                = p.numMc;
        cases(k).elapsedSeconds       = elapsed;
        cases(k).secondsPerDraw       = elapsed / p.numMc;
        cases(k).secondsPerCellPerDraw = elapsed / (p.numMc * Naz * Nel);
        cases(k).memEstimate          = estimate_aas_mc_memory( ...
            Naz, Nel, numBins, 'uint32', struct('numMc', p.numMc));
        cases(k).antenna              = sprintf('N_H=%d, N_V=%d', cfg.N_H, cfg.N_V);
        cases(k).statsElapsedSeconds  = stats.elapsedSeconds;
    end

    out = struct();
    out.cases = cases;

    % --- Extrapolation: pick the slowest *cell-time* case as the basis -----
    if isempty(cases)
        error('profile_aas_monte_carlo_runtime:noCases', ...
            'At least one case must be specified.');
    end
    [~, basisIdx] = max([cases.secondsPerCellPerDraw]);
    basis = cases(basisIdx);

    fullAz = numel(presets.full.azGrid);
    fullEl = numel(presets.full.elGrid);

    extrap = struct();
    extrap.basedOnCase   = basis.name;
    extrap.basedOnSecondsPerCellPerDraw = basis.secondsPerCellPerDraw;
    extrap.fullGridNumAz  = fullAz;
    extrap.fullGridNumEl  = fullEl;
    extrap.fullGridCells  = fullAz * fullEl;
    extrap.numMc1e3      = basis.secondsPerCellPerDraw * fullAz * fullEl * 1e3;
    extrap.numMc1e4      = basis.secondsPerCellPerDraw * fullAz * fullEl * 1e4;
    extrap.numMc1e5      = basis.secondsPerCellPerDraw * fullAz * fullEl * 1e5;
    extrap.fullGridMemEstimate = estimate_aas_mc_memory( ...
        fullAz, fullEl, numBins, 'uint32', struct('numMc', 1e4));

    if opts.runFullGrid
        p = presets.full;
        mcOpts             = struct();
        mcOpts.numMc       = p.numMc;
        mcOpts.azGrid      = p.azGrid;
        mcOpts.elGrid      = p.elGrid;
        mcOpts.binEdges    = binEdges;
        mcOpts.seed        = opts.seed;
        mcOpts.progressEvery = 0;
        mcOpts.beamSampler = struct('mode', 'sector', ...
            'sector_az', 0, 'sector_az_width', 120, ...
            'elev_range', [-10, 0], 'numBeams', 1);
        tStart = tic;
        stats  = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
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
        lines{end+1} = sprintf('case "%s" (%s)', c.name, c.antenna);
        lines{end+1} = sprintf('  grid              : %d az x %d el = %d cells', ...
            c.numAz, c.numEl, c.numCells);
        lines{end+1} = sprintf('  numMc             : %d', c.numMc);
        lines{end+1} = sprintf('  elapsed           : %.3f s', c.elapsedSeconds);
        lines{end+1} = sprintf('  seconds per draw  : %.3e s', c.secondsPerDraw);
        lines{end+1} = sprintf('  seconds per cell  : %.3e s/cell/draw', ...
            c.secondsPerCellPerDraw);
        lines{end+1} = sprintf('  histogram memory  : %s', humanBytes(c.memEstimate.histCountsBytes));
        lines{end+1} = sprintf('  pctile table mem  : %s', humanBytes(c.memEstimate.percentileTableBytes));
    end
    e = out.extrapolation;
    lines{end+1} = '----- full-grid extrapolation -----';
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
