function out = run_single_sector_eirp_demo(opts)
%RUN_SINGLE_SECTOR_EIRP_DEMO End-to-end R23 single-sector AAS EIRP CDF demo.
%
%   OUT = run_single_sector_eirp_demo()
%   OUT = run_single_sector_eirp_demo(OPTS)
%
%   Drives the R23 single-sector / single-site / 3-UE EIRP CDF MVP
%   end-to-end:
%       (1) get_default_bs                         -> default R23 BS struct
%       (2) get_r23_aas_params                     -> antenna params
%       (3) generate_single_sector_layout          -> sector geometry
%       (4) run_monte_carlo_snapshots              -> EIRP cube
%       (5) compute_cdf_per_grid_point             -> per-cell CDF
%       (6) plot_or_export_results (optional)      -> PNG / CSV
%
%   Inputs (OPTS, all fields optional):
%       .bsOverrides       struct of fields to overlay on get_default_bs.
%       .gridPoints        struct .azGridDeg / .elGridDeg vectors.
%                          Default: az = -90:5:90, el = -30:5:10.
%       .numSnapshots      default 100.
%       .numUes            default 3 (R23).
%       .seed              default 1.
%       .splitSectorPower  default true.
%       .percentiles       default [1 5 10 25 50 75 90 95 99].
%       .savePlot          default false.
%       .saveCsv           default false.
%       .plotPath / .csvPath  override default file locations.
%       .verbose           default true (prints peak / median / P95 EIRP).
%
%   Output struct fields:
%       bs                       resolved BS struct
%       params                   resolved params struct
%       layout                   generate_single_sector_layout output
%       mcOut                    run_monte_carlo_snapshots output
%       cdfOut                   compute_cdf_per_grid_point output
%       summary                  scalar struct (peak / median / P95 EIRP)
%       exportOpts               plot_or_export_results opts (when run)
%
%   Example:
%       out = run_single_sector_eirp_demo();
%       fprintf('peak aggregate EIRP = %.2f dBm/100MHz\n', ...
%           out.summary.peakAggregateEirpDbm);
%
%       % With a 25 m BS height and 30 deg azimuth override:
%       out = run_single_sector_eirp_demo(struct('bsOverrides', ...
%           struct('height_m', 25, 'position_m', [0, 0, 25], ...
%                  'azimuth_deg', 30)));

    if nargin < 1 || isempty(opts)
        opts = struct();
    end

    bs = get_default_bs();
    if isfield(opts, 'bsOverrides') && ~isempty(opts.bsOverrides)
        flds = fieldnames(opts.bsOverrides);
        for i = 1:numel(flds)
            bs.(flds{i}) = opts.bsOverrides.(flds{i});
        end
    end

    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    gridPoints = getOpt(opts, 'gridPoints', ...
        struct('azGridDeg', -90:5:90, 'elGridDeg', -30:5:10));

    simConfig = struct();
    simConfig.numSnapshots     = getOpt(opts, 'numSnapshots',     100);
    simConfig.numUes           = getOpt(opts, 'numUes',           3);
    simConfig.seed             = getOpt(opts, 'seed',             1);
    simConfig.splitSectorPower = getOpt(opts, 'splitSectorPower', true);
    simConfig.progressEvery    = getOpt(opts, 'progressEvery',    0);

    percentiles = getOpt(opts, 'percentiles', ...
        [1 5 10 25 50 75 90 95 99]);

    verbose = getOpt(opts, 'verbose', true);

    mcOut  = run_monte_carlo_snapshots(bs, gridPoints, params, simConfig);
    cdfOut = compute_cdf_per_grid_point(mcOut.eirpGrid, percentiles);

    summary = struct();
    summary.peakAggregateEirpDbm   = max(mcOut.eirpGrid(:));
    summary.medianAggregateEirpDbm = median(mcOut.eirpGrid(:));
    p95Idx = find(abs(percentiles - 95) < 1e-9, 1);
    if ~isempty(p95Idx)
        summary.cellP95MaxDbm = max(reshape( ...
            cdfOut.percentileEirpDbm(:, :, p95Idx), 1, []));
    else
        summary.cellP95MaxDbm = NaN;
    end
    summary.numSnapshots = mcOut.numSnapshots;
    summary.numUes       = mcOut.numUes;
    summary.elapsedSeconds = mcOut.elapsedSeconds;

    if verbose
        fprintf('--- run_single_sector_eirp_demo summary ---\n');
        fprintf('  BS id ............... %s\n', char(string(bs.id)));
        fprintf('  BS position ......... [%g %g %g] m\n', ...
            bs.position_m(1), bs.position_m(2), bs.position_m(3));
        fprintf('  BS azimuth .......... %g deg\n', bs.azimuth_deg);
        fprintf('  Sector EIRP ......... %.2f dBm/100MHz\n', ...
            bs.eirp_dBm_per_100MHz);
        fprintf('  Cell radius ......... %.0f m  (env=%s)\n', ...
            layout.cellRadius_m, layout.environment);
        fprintf('  Snapshots ........... %d\n',  mcOut.numSnapshots);
        fprintf('  UEs per snapshot .... %d\n',  mcOut.numUes);
        fprintf('  Per-beam peak EIRP .. %.2f dBm/100MHz\n', ...
            mcOut.perBeamPeakEirpDbm);
        fprintf('  Peak aggregate EIRP . %.2f dBm/100MHz\n', ...
            summary.peakAggregateEirpDbm);
        fprintf('  Cell-P95 max EIRP ... %.2f dBm/100MHz\n', ...
            summary.cellP95MaxDbm);
        fprintf('  Elapsed ............. %.2f s\n', summary.elapsedSeconds);
    end

    out = struct();
    out.bs        = bs;
    out.params    = params;
    out.layout    = layout;
    out.mcOut     = mcOut;
    out.cdfOut    = cdfOut;
    out.summary   = summary;

    if getOpt(opts, 'savePlot', false) || getOpt(opts, 'saveCsv', false)
        plotOpts = struct();
        plotOpts.savePlot = getOpt(opts, 'savePlot', false);
        plotOpts.saveCsv  = getOpt(opts, 'saveCsv',  false);
        if isfield(opts, 'plotPath') && ~isempty(opts.plotPath)
            plotOpts.plotPath = opts.plotPath;
        end
        if isfield(opts, 'csvPath') && ~isempty(opts.csvPath)
            plotOpts.csvPath = opts.csvPath;
        end
        plotOpts.show = getOpt(opts, 'show', false);
        out.exportOpts = plot_or_export_results(mcOut, cdfOut, plotOpts);
    end
end

% =====================================================================

function v = getOpt(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end
