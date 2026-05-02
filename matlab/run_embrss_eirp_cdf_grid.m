function out = run_embrss_eirp_cdf_grid(category, opts)
%RUN_EMBRSS_EIRP_CDF_GRID Per-(az,el) EIRP CDF-grid generator (R23 by default).
%
%   OUT = run_embrss_eirp_cdf_grid(CATEGORY)
%   OUT = run_embrss_eirp_cdf_grid(CATEGORY, OPTS)
%
%   By default this function is now a thin wrapper around the source-aligned
%   R23 7/8 GHz Extended AAS runner, runR23AasEirpCdfGrid. Category mapping:
%
%       'urban_macro'    -> deployment 'macroUrban'    (R23 path)
%       'suburban_macro' -> deployment 'macroSuburban' (R23 path)
%       'rural_macro'    -> legacy M.2101 path (no R23 sector preset)
%
%   To force the legacy M.2101 path (the previous default), pass
%   OPTS.legacyM2101 = true. Legacy mode preserves the old behaviour
%   exactly: it drives run_imt_aas_eirp_monte_carlo via embrss_aas_config
%   + the ue_sector beam sampler, and returns OUT with the original
%   .category / .model / .cfg / .mcOpts / .stats / .percentileMaps fields.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna, NO I / N, NO FS / FSS receiver geometry, NO
%   coordination-distance search, and NO multi-site aggregation in
%   either path.
%
%   Inputs (OPTS struct fields, all optional):
%       Common (both paths):
%           .numMc, .seed, .progressEvery, .percentiles,
%           .outputCsvPath
%       R23 path (default for urban_macro / suburban_macro):
%           .azGridDeg or .azGrid, .elGridDeg or .elGrid,
%           .binEdgesDbm or .binEdges,
%           .numBeams, .splitSectorPower, .mcChunkSize,
%           .deployment (overrides the category->deployment mapping)
%       Legacy path (forced via .legacyM2101 = true, or rural_macro):
%           .azGrid, .elGrid, .binEdges, .numBeams, .combineBeams,
%           .powerMode, .txPower_dBm, .peakEirp_dBm, .peakGain_dBi,
%           .modelOverrides, .cfgOverrides
%       Special:
%           .legacyM2101    logical (default false). When true, force
%                           the legacy M.2101 wrapper around
%                           run_imt_aas_eirp_monte_carlo.
%
%   Output (OUT struct):
%       Common:
%           .category, .stats, .percentileMaps, .metadata,
%           .percentileTable (when opts.outputCsvPath is provided).
%       R23 path additionally exposes:
%           .params, .sector, .opts (resolved R23 opts), .pathway = 'r23'.
%       Legacy path additionally exposes:
%           .model, .cfg, .mcOpts, .pathway = 'legacy_m2101'.
%
%   See also: runR23AasEirpCdfGrid, imtAasDefaultParams,
%             imtAasSingleSectorParams, run_imt_aas_eirp_monte_carlo,
%             eirp_percentile_maps, export_eirp_percentile_table.

    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('run_embrss_eirp_cdf_grid:badOpts', ...
            'OPTS must be a struct (or omitted).');
    end

    legacyM2101 = false;
    if isfield(opts, 'legacyM2101') && ~isempty(opts.legacyM2101)
        legacyM2101 = logical(opts.legacyM2101);
    end

    [deployment, deploymentOk] = mapCategoryToDeployment(category);
    if ~deploymentOk
        % rural_macro and any other unsupported category fall back to
        % the legacy path (which has full embrss_category_model support).
        legacyM2101 = true;
    end

    if legacyM2101
        out = legacyRun(category, opts);
    else
        out = r23Run(category, deployment, opts);
    end
end

% =====================================================================
% R23 path (default for urban_macro / suburban_macro)
% =====================================================================
function out = r23Run(category, deployment, opts)
    r23Opts = struct();
    r23Opts.deployment = deployment;
    if isfield(opts, 'deployment') && ~isempty(opts.deployment)
        r23Opts.deployment = opts.deployment;
    end
    if isfield(opts, 'numMc') && ~isempty(opts.numMc)
        r23Opts.numMc = opts.numMc;
    end
    % azGridDeg accepts either azGridDeg (new) or azGrid (legacy)
    if isfield(opts, 'azGridDeg') && ~isempty(opts.azGridDeg)
        r23Opts.azGridDeg = opts.azGridDeg;
    elseif isfield(opts, 'azGrid') && ~isempty(opts.azGrid)
        r23Opts.azGridDeg = opts.azGrid;
    end
    if isfield(opts, 'elGridDeg') && ~isempty(opts.elGridDeg)
        r23Opts.elGridDeg = opts.elGridDeg;
    elseif isfield(opts, 'elGrid') && ~isempty(opts.elGrid)
        r23Opts.elGridDeg = opts.elGrid;
    end
    if isfield(opts, 'binEdgesDbm') && ~isempty(opts.binEdgesDbm)
        r23Opts.binEdgesDbm = opts.binEdgesDbm;
    elseif isfield(opts, 'binEdges') && ~isempty(opts.binEdges)
        r23Opts.binEdgesDbm = opts.binEdges;
    end
    if isfield(opts, 'percentiles') && ~isempty(opts.percentiles)
        r23Opts.percentiles = opts.percentiles;
    end
    if isfield(opts, 'seed') && ~isempty(opts.seed)
        r23Opts.seed = opts.seed;
    end
    if isfield(opts, 'numBeams') && ~isempty(opts.numBeams)
        r23Opts.numBeams = opts.numBeams;
    end
    if isfield(opts, 'splitSectorPower') && ~isempty(opts.splitSectorPower)
        r23Opts.splitSectorPower = opts.splitSectorPower;
    end
    if isfield(opts, 'progressEvery') && ~isempty(opts.progressEvery)
        r23Opts.progressEvery = opts.progressEvery;
    end
    if isfield(opts, 'mcChunkSize') && ~isempty(opts.mcChunkSize)
        r23Opts.mcChunkSize = opts.mcChunkSize;
    end
    if isfield(opts, 'outputCsvPath') && ~isempty(opts.outputCsvPath)
        r23Opts.outputCsvPath = opts.outputCsvPath;
    end
    if isfield(opts, 'outputMetadataPath') && ~isempty(opts.outputMetadataPath)
        r23Opts.outputMetadataPath = opts.outputMetadataPath;
    end

    inner = runR23AasEirpCdfGrid(r23Opts);

    out = struct();
    out.category       = char(category);
    out.pathway        = 'r23';
    out.params         = inner.params;
    out.sector         = inner.sector;
    out.opts           = inner.opts;
    out.stats          = inner.stats;
    out.percentileMaps = inner.percentileMaps;
    if isfield(inner, 'percentileTable')
        out.percentileTable = inner.percentileTable;
    end
    out.metadata = inner.metadata;
    out.metadata.wrapper = 'run_embrss_eirp_cdf_grid';
    out.metadata.category = char(category);
end

% =====================================================================
% Legacy M.2101 path (preserved exactly)
% =====================================================================
function out = legacyRun(category, opts)
    if isfield(opts, 'modelOverrides') && ~isempty(opts.modelOverrides)
        if ~iscell(opts.modelOverrides)
            error('run_embrss_eirp_cdf_grid:badModelOverrides', ...
                'opts.modelOverrides must be a cell array of name/value pairs.');
        end
        model = embrss_category_model(category, opts.modelOverrides{:});
    else
        model = embrss_category_model(category);
    end

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

    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    percentiles = getOpt(opts, 'percentiles', ...
                         [1 5 10 20 50 80 90 95 99]);
    pmaps = eirp_percentile_maps(stats, percentiles);

    out = struct();
    out.category        = char(category);
    out.pathway         = 'legacy_m2101';
    out.model           = model;
    out.cfg             = cfg;
    out.mcOpts          = mcOpts;
    out.stats           = stats;
    out.percentileMaps  = pmaps;

    csvPath = getOpt(opts, 'outputCsvPath', '');
    if ~isempty(csvPath)
        out.percentileTable = export_eirp_percentile_table(stats, csvPath);
    end

    out.metadata = struct( ...
        'generator',     'run_embrss_eirp_cdf_grid', ...
        'pathway',       'legacy_m2101', ...
        'step',          'embrss_first_step_antenna_eirp_cdf_grid', ...
        'beamModel',     'ue_sector_first_approximation', ...
        'caveats',       ['Antenna/EIRP CDF-grid only. No propagation, ' ...
                          'clutter, FDR, FS/FSS antenna, multi-site ' ...
                          'aggregation, I/N, or separation-distance ' ...
                          'search. UE-sector beam pointing is a first ' ...
                          'approximation; SSB/PDSCH/PMI is a follow-up.'], ...
        'createdAtIso',  iso8601Now());
end

% =====================================================================
% Helpers
% =====================================================================
function [deployment, ok] = mapCategoryToDeployment(category)
    if isstring(category)
        category = char(category);
    end
    if ~ischar(category)
        deployment = '';
        ok = false;
        return;
    end
    switch lower(category)
        case 'urban_macro'
            deployment = 'macroUrban';  ok = true;
        case 'suburban_macro'
            deployment = 'macroSuburban'; ok = true;
        otherwise
            deployment = '';
            ok = false;
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
        s = char(datetime('now','TimeZone','UTC', ...
            'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
    catch
        s = datestr(now, 'yyyy-mm-ddTHH:MM:SS'); %#ok<DATST,TNOW1>
    end
end
