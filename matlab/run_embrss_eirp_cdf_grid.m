function out = run_embrss_eirp_cdf_grid(category, opts)
%RUN_EMBRSS_EIRP_CDF_GRID EMBRSS-style per-(az,el) EIRP CDF-grid generator.
%
%   OUT = run_embrss_eirp_cdf_grid(CATEGORY)
%   OUT = run_embrss_eirp_cdf_grid(CATEGORY, OPTS)
%
%   Antenna-only first step of the EMBRSS recreation. Drives the existing
%   streaming Monte Carlo runner with a UE-driven sector beam sampler and
%   per-category geometry, then collapses the result into per-(az,el) CDFs
%   and percentile maps. **No** propagation, clutter, FDR, FS/FSS antenna,
%   19-site aggregation, I/N or separation-distance search is performed.
%
%   Inputs
%   ------
%   CATEGORY    char/string scalar; passed to embrss_category_model
%               ('urban_macro' / 'suburban_macro' / 'rural_macro').
%   OPTS        optional struct with overrides:
%       .numMc           default 1000
%       .azGrid          default -180:1:180
%       .elGrid          default  -90:1:90
%       .binEdges        default  -80:1:120 [dBm]
%       .seed            default 1
%       .progressEvery   default 0 (silent)
%       .mcChunkSize     default min(numMc, 500)
%       .numBeams        default model.default_num_beams
%       .combineBeams    'max' | 'sum_mW' (default model.default_combine_beams)
%       .powerMode       'conducted' | 'peak_eirp' (default 'conducted')
%       .txPower_dBm     forwarded to embrss_aas_config (conducted mode)
%       .peakEirp_dBm    forwarded to embrss_aas_config (peak_eirp mode)
%       .peakGain_dBi    forwarded to embrss_aas_config (peak_eirp mode)
%       .percentiles     default [1 5 10 20 50 80 90 95 99]
%       .outputCsvPath   if non-empty, also writes the p000..p100 table
%       .modelOverrides  cell array {name,val,...} forwarded to
%                        embrss_category_model
%       .cfgOverrides    cell array {name,val,...} forwarded to
%                        embrss_aas_config (after powerMode/txPower/etc.)
%
%   Output
%   ------
%   OUT struct:
%       .category          (char) input category
%       .model             struct from embrss_category_model
%       .cfg               struct from embrss_aas_config
%       .mcOpts            mcOpts struct passed to the Monte Carlo runner
%       .stats             stats from run_imt_aas_eirp_monte_carlo
%       .percentileMaps    struct from eirp_percentile_maps
%       .percentileTable   table from export_eirp_percentile_table
%                          (only when opts.outputCsvPath is provided)
%       .metadata          struct with versioning + a short caveat string
%
%   Caveat
%   ------
%   This is an EMBRSS-style antenna/EIRP CDF-grid generator only. It uses
%   UE-driven sector beam pointing as a first approximation, NOT a full
%   SSB / CSI / PMI Quadriga model. A later PR can swap the beam sampler
%   for a true SSB/PDSCH/PMI implementation without touching this driver.

    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('run_embrss_eirp_cdf_grid:badOpts', ...
            'OPTS must be a struct (or omitted).');
    end

    % --- resolve category model --------------------------------------
    if isfield(opts, 'modelOverrides') && ~isempty(opts.modelOverrides)
        if ~iscell(opts.modelOverrides)
            error('run_embrss_eirp_cdf_grid:badModelOverrides', ...
                'opts.modelOverrides must be a cell array of name/value pairs.');
        end
        model = embrss_category_model(category, opts.modelOverrides{:});
    else
        model = embrss_category_model(category);
    end

    % --- resolve antenna config --------------------------------------
    cfgArgs = {};
    if isfield(opts, 'powerMode') && ~isempty(opts.powerMode)
        cfgArgs(end+1:end+2) = {'powerMode', opts.powerMode};
    end
    if isfield(opts, 'txPower_dBm') && ~isempty(opts.txPower_dBm)
        cfgArgs(end+1:end+2) = {'txPower_dBm', opts.txPower_dBm};
    end
    if isfield(opts, 'peakEirp_dBm') && ~isempty(opts.peakEirp_dBm)
        cfgArgs(end+1:end+2) = {'peakEirp_dBm', opts.peakEirp_dBm};
    end
    if isfield(opts, 'peakGain_dBi') && ~isempty(opts.peakGain_dBi)
        cfgArgs(end+1:end+2) = {'peakGain_dBi', opts.peakGain_dBi};
    end
    if isfield(opts, 'cfgOverrides') && ~isempty(opts.cfgOverrides)
        if ~iscell(opts.cfgOverrides)
            error('run_embrss_eirp_cdf_grid:badCfgOverrides', ...
                'opts.cfgOverrides must be a cell array of name/value pairs.');
        end
        cfgArgs = [cfgArgs, opts.cfgOverrides];
    end
    cfg = embrss_aas_config(category, cfgArgs{:});

    % --- build mcOpts ------------------------------------------------
    mcOpts = struct();
    mcOpts.numMc        = getOpt(opts, 'numMc',        1000);
    mcOpts.azGrid       = getOpt(opts, 'azGrid',       -180:1:180);
    mcOpts.elGrid       = getOpt(opts, 'elGrid',        -90:1:90);
    mcOpts.binEdges     = getOpt(opts, 'binEdges',      -80:1:120);
    mcOpts.seed         = getOpt(opts, 'seed',         1);
    mcOpts.progressEvery = getOpt(opts, 'progressEvery', 0);
    mcOpts.mcChunkSize  = getOpt(opts, 'mcChunkSize', ...
                                 min(mcOpts.numMc, 500));
    mcOpts.combineBeams = getOpt(opts, 'combineBeams', ...
                                 model.default_combine_beams);

    numBeams = getOpt(opts, 'numBeams', model.default_num_beams);

    mcOpts.beamSampler = struct( ...
        'mode',                 'ue_sector', ...
        'sector_az_deg',        model.sector_az_deg, ...
        'sector_width_deg',     model.sector_width_deg, ...
        'r_min_m',              model.min_ue_range_m, ...
        'r_max_m',              model.sector_radius_m, ...
        'bs_height_m',          model.bs_height_m, ...
        'ue_height_range_m',    model.ue_height_range_m, ...
        'radial_distribution',  'uniform_area', ...
        'numBeams',             numBeams);

    % --- run streaming Monte Carlo -----------------------------------
    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    % --- collapse into CDF / percentile maps -------------------------
    percentiles = getOpt(opts, 'percentiles', ...
                         [1 5 10 20 50 80 90 95 99]);
    pmaps = eirp_percentile_maps(stats, percentiles);

    out = struct();
    out.category        = char(category);
    out.model           = model;
    out.cfg             = cfg;
    out.mcOpts          = mcOpts;
    out.stats           = stats;
    out.percentileMaps  = pmaps;

    % --- optional CSV export -----------------------------------------
    csvPath = getOpt(opts, 'outputCsvPath', '');
    if ~isempty(csvPath)
        out.percentileTable = export_eirp_percentile_table(stats, csvPath);
    end

    % --- metadata ----------------------------------------------------
    out.metadata = struct( ...
        'generator',     'run_embrss_eirp_cdf_grid', ...
        'step',          'embrss_first_step_antenna_eirp_cdf_grid', ...
        'beamModel',     'ue_sector_first_approximation', ...
        'caveats',       ['Antenna/EIRP CDF-grid only. No propagation, ' ...
                          'clutter, FDR, FS/FSS antenna, multi-site ' ...
                          'aggregation, I/N, or separation-distance ' ...
                          'search. UE-sector beam pointing is a first ' ...
                          'approximation; SSB/PDSCH/PMI is a follow-up.'], ...
        'createdAtIso',  iso8601Now());
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
        s = char(datetime('now','TimeZone','UTC', ...
            'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
    catch
        % datetime may be unavailable in some Octave configs
        s = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
    end
end
