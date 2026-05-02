function results = test_runR23AasEirpCdfGrid()
%TEST_RUNR23AASEIRPCDFGRID Self tests for the R23 AAS EIRP CDF-grid runner.
%
%   RESULTS = test_runR23AasEirpCdfGrid()
%
%   Covers:
%       T1.  runR23AasEirpCdfGrid returns stats and percentileMaps.
%       T2.  stats grid size matches azGridDeg x elGridDeg.
%       T3.  stats.numMc equals requested numMc.
%       T4.  percentileMaps.values size is [Naz, Nel, P].
%       T5.  Default numBeams equals params.numUesPerSector (= 3).
%       T6.  For three identical beams via imtAasSectorEirpGridFromBeams,
%            aggregate peak EIRP is approximately 78.3 dBm / 100 MHz.
%       T7.  For 3-beam UE-driven draws perBeamPeakEirpDbm is
%            approximately 73.53 dBm / 100 MHz.
%       T8.  out.metadata says 'R23 Extended AAS'.
%       T9.  No output / metadata fields advertise path loss, receiver
%            gain, or I / N.
%       T10. run_embrss_eirp_cdf_grid('urban_macro') uses the R23 runner
%            by default; opts.legacyM2101 = true falls back to legacy
%            (or fails with a clear error).
%       T11. Legacy mode is reachable and runs (or errors clearly).
%       T12. Deterministic seed gives repeatable percentile maps.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = t_returns_stats_and_percentiles(results);
    results = t_grid_size(results);
    results = t_num_mc(results);
    results = t_percentile_size(results);
    results = t_default_num_beams(results);
    results = t_three_identical_beams_peak(results);
    results = t_three_beam_per_beam_peak(results);
    results = t_metadata_says_r23(results);
    results = t_no_path_loss_fields(results);
    results = t_embrss_wrapper_uses_r23(results);
    results = t_legacy_mode(results);
    results = t_seed_repeatable(results);

    fprintf('\n--- test_runR23AasEirpCdfGrid summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% T1
% =====================================================================
function r = t_returns_stats_and_percentiles(r)
    out = runSmall(struct('seed', 1));
    ok = isfield(out, 'stats') && isstruct(out.stats) && ...
         isfield(out, 'percentileMaps') && isstruct(out.percentileMaps);
    r = check(r, ok, 'T1: runR23AasEirpCdfGrid returns stats and percentileMaps');
end

% =====================================================================
% T2
% =====================================================================
function r = t_grid_size(r)
    opts = smallOpts();
    opts.azGridDeg = -30:10:30;   % 7
    opts.elGridDeg = -10:5:10;    % 5
    out = runR23AasEirpCdfGrid(opts);
    Naz = numel(opts.azGridDeg);
    Nel = numel(opts.elGridDeg);
    okMean = isequal(size(out.stats.mean_dBm), [Naz, Nel]);
    okSum  = isequal(size(out.stats.sum_lin_mW), [Naz, Nel]);
    okMin  = isequal(size(out.stats.min_dBm),    [Naz, Nel]);
    okMax  = isequal(size(out.stats.max_dBm),    [Naz, Nel]);
    okCounts = size(out.stats.counts, 1) == Naz && ...
               size(out.stats.counts, 2) == Nel;
    r = check(r, okMean && okSum && okMin && okMax && okCounts, ...
        sprintf('T2: stats grid size matches az x el = %d x %d', Naz, Nel));
end

% =====================================================================
% T3
% =====================================================================
function r = t_num_mc(r)
    opts = smallOpts();
    opts.numMc = 25;
    out = runR23AasEirpCdfGrid(opts);
    okMc  = out.stats.numMc == 25;
    cellSums = sum(double(out.stats.counts), 3);
    okSums = all(cellSums(:) == 25);
    r = check(r, okMc && okSums, ...
        'T3: stats.numMc == requested numMc and counts sum to numMc');
end

% =====================================================================
% T4
% =====================================================================
function r = t_percentile_size(r)
    opts = smallOpts();
    opts.percentiles = [5 25 50 75 95];
    out = runR23AasEirpCdfGrid(opts);
    Naz = numel(opts.azGridDeg);
    Nel = numel(opts.elGridDeg);
    P   = numel(opts.percentiles);
    okShape = isequal(size(out.percentileMaps.values), [Naz, Nel, P]);
    r = check(r, okShape, ...
        sprintf('T4: percentileMaps.values size = [%d %d %d]', Naz, Nel, P));
end

% =====================================================================
% T5
% =====================================================================
function r = t_default_num_beams(r)
    params = imtAasDefaultParams();
    out = runR23AasEirpCdfGrid(struct( ...
        'numMc', 2, ...
        'azGridDeg', -10:10:10, ...
        'elGridDeg', -10:5:0, ...
        'binEdgesDbm', -80:5:120, ...
        'seed', 11));
    okDefault = out.stats.numBeams == params.numUesPerSector && ...
                params.numUesPerSector == 3;
    r = check(r, okDefault, sprintf( ...
        'T5: default numBeams = params.numUesPerSector = %d', ...
        params.numUesPerSector));
end

% =====================================================================
% T6: three identical beams aggregate peak ~ sectorEirpDbm
% =====================================================================
function r = t_three_identical_beams_peak(r)
    params = imtAasDefaultParams();
    az = -180:1:180;
    el =  -90:1:30;
    steerAz = 0;
    steerEl = -9;
    beams = struct( ...
        'steerAzDeg', repmat(steerAz, 3, 1), ...
        'steerElDeg', repmat(steerEl, 3, 1));
    sectorOut = imtAasSectorEirpGridFromBeams(az, el, beams, params, ...
        struct('splitSectorPower', true));
    peak = max(sectorOut.aggregateEirpDbm(:));
    okPeak = abs(peak - params.sectorEirpDbm) < 1e-6;
    r = check(r, okPeak, sprintf( ...
        ['T6: three identical beams aggregate peak ~ %.2f dBm/100MHz ' ...
         '(got %.6f, expected %.6f)'], ...
        params.sectorEirpDbm, peak, params.sectorEirpDbm));
end

% =====================================================================
% T7: 3-beam UE-driven perBeamPeakEirpDbm ~ 73.53 dBm
% =====================================================================
function r = t_three_beam_per_beam_peak(r)
    params = imtAasDefaultParams();
    expected = params.sectorEirpDbm - 10 * log10(3);
    out = runR23AasEirpCdfGrid(struct( ...
        'numMc',     5, ...
        'numBeams',  3, ...
        'azGridDeg', -30:10:30, ...
        'elGridDeg', -10:5:10, ...
        'binEdgesDbm', -80:5:120, ...
        'seed', 7));
    got = out.stats.perBeamPeakEirpDbm;
    okPerBeam = abs(got - expected) < 1e-9;
    r = check(r, okPerBeam, sprintf( ...
        ['T7: 3-beam perBeamPeakEirpDbm ~ %.4f dBm (got %.6f, ' ...
         'expected %.6f)'], expected, got, expected));
end

% =====================================================================
% T8
% =====================================================================
function r = t_metadata_says_r23(r)
    out = runSmall(struct('seed', 13));
    md = out.metadata;
    okGen   = isfield(md, 'generator') && ...
              strcmp(md.generator, 'runR23AasEirpCdfGrid');
    okModel = isfield(md, 'model') && ...
              ~isempty(strfind(lower(md.model), 'r23')) && ...        %#ok<STREMP>
              ~isempty(strfind(lower(md.model), 'extended aas'));      %#ok<STREMP>
    r = check(r, okGen && okModel, ...
        'T8: metadata generator + model identify R23 Extended AAS');
end

% =====================================================================
% T9: no path-loss / receiver / I/N output fields
% =====================================================================
function r = t_no_path_loss_fields(r)
    out = runSmall(struct('seed', 13));

    % Forbidden tokens for output / stats / percentileMaps fields
    % (the metadata struct deliberately carries explicit boolean flags
    % to declare absence of these features and is checked separately).
    bannedTokens = {'pathloss', 'rxgain', 'rxantenna', ...
        'iovern', 'i_over_n', 'inratio', 'coordination'};

    okOutTop  = ~hasBannedFieldExcept(out, bannedTokens, {'metadata'});
    okStats   = ~hasBannedField(out.stats, bannedTokens);
    okPmaps   = ~hasBannedField(out.percentileMaps, bannedTokens);

    md = out.metadata;
    okMd = isfield(md, 'includesPathLoss')        && ~md.includesPathLoss && ...
           isfield(md, 'includesReceiverAntenna') && ~md.includesReceiverAntenna && ...
           isfield(md, 'includesReceiverGain')    && ~md.includesReceiverGain && ...
           isfield(md, 'includesINMetric')        && ~md.includesINMetric;

    r = check(r, okOutTop && okStats && okPmaps && okMd, ...
        'T9: no output field advertises path loss / receiver gain / I / N (metadata declares absence)');
end

% =====================================================================
% T10: embrss wrapper uses R23 by default
% =====================================================================
function r = t_embrss_wrapper_uses_r23(r)
    opts = struct();
    opts.numMc       = 5;
    opts.azGrid      = -30:10:30;
    opts.elGrid      = -10:5:10;
    opts.binEdges    = -80:5:120;
    opts.seed        = 21;
    opts.numBeams    = 1;
    opts.percentiles = [5 50 95];

    out = run_embrss_eirp_cdf_grid('urban_macro', opts);
    okPathway = isfield(out, 'pathway') && strcmp(out.pathway, 'r23');
    okSector  = isfield(out, 'sector') && ...
                strcmp(out.sector.deployment, 'macroUrban');
    r = check(r, okPathway && okSector, ...
        'T10: run_embrss_eirp_cdf_grid uses R23 runner by default');
end

% =====================================================================
% T11: legacy mode reachable
% =====================================================================
function r = t_legacy_mode(r)
    opts = struct();
    opts.numMc       = 5;
    opts.azGrid      = -30:10:30;
    opts.elGrid      = -10:5:10;
    opts.binEdges    = -80:5:120;
    opts.seed        = 21;
    opts.numBeams    = 1;
    opts.percentiles = [5 50 95];
    opts.legacyM2101 = true;

    threwClearly = false;
    okLegacy = false;
    try
        out = run_embrss_eirp_cdf_grid('urban_macro', opts);
        okLegacy = isfield(out, 'pathway') && ...
                   strcmp(out.pathway, 'legacy_m2101') && ...
                   isfield(out, 'cfg') && isfield(out, 'model');
    catch err
        % An explicit, documented error is also acceptable per the
        % task spec ("at least fails with a clear documented error").
        if ~isempty(err.identifier)
            ident = err.identifier;
            threwClearly = startsWith(ident, 'run_embrss_eirp_cdf_grid:') || ...
                           startsWith(ident, 'embrss_aas_config:') || ...
                           startsWith(ident, 'embrss_category_model:') || ...
                           startsWith(ident, 'run_imt_aas_eirp_monte_carlo:');
        end
    end
    r = check(r, okLegacy || threwClearly, ...
        'T11: legacy mode runs successfully or fails with a clear error');
end

% =====================================================================
% T12: deterministic seed
% =====================================================================
function r = t_seed_repeatable(r)
    opts = smallOpts();
    opts.seed = 42;
    out1 = runR23AasEirpCdfGrid(opts);
    out2 = runR23AasEirpCdfGrid(opts);

    okEq = isequal(out1.stats.counts, out2.stats.counts) && ...
           isequaln(out1.stats.mean_dBm, out2.stats.mean_dBm) && ...
           isequaln(out1.percentileMaps.values, out2.percentileMaps.values);

    optsDiff = opts; optsDiff.seed = 1234;
    out3 = runR23AasEirpCdfGrid(optsDiff);
    okDiff = ~isequal(out1.stats.counts, out3.stats.counts) || ...
             ~isequaln(out1.stats.mean_dBm, out3.stats.mean_dBm);

    r = check(r, okEq && okDiff, ...
        'T12: same seed -> identical maps; different seed -> different maps');
end

% =====================================================================
% Helpers
% =====================================================================
function opts = smallOpts()
    opts = struct();
    opts.numMc       = 8;
    opts.azGridDeg   = -30:10:30;     % 7
    opts.elGridDeg   = -10:5:10;      % 5
    opts.binEdgesDbm = -80:5:120;
    opts.percentiles = [5 50 95];
    opts.seed        = 1;
    opts.numBeams    = 3;
    opts.deployment  = 'macroUrban';
end

function out = runSmall(extra)
    opts = smallOpts();
    flds = fieldnames(extra);
    for k = 1:numel(flds)
        opts.(flds{k}) = extra.(flds{k});
    end
    out = runR23AasEirpCdfGrid(opts);
end

function tf = hasBannedField(s, tokens)
    tf = hasBannedFieldExcept(s, tokens, {});
end

function tf = hasBannedFieldExcept(s, tokens, exceptFields)
    if ~isstruct(s)
        tf = false;
        return;
    end
    flds = fieldnames(s);
    lf = lower(flds);
    tf = false;
    for k = 1:numel(lf)
        if any(strcmpi(flds{k}, exceptFields))
            continue;
        end
        for t = 1:numel(tokens)
            if ~isempty(strfind(lf{k}, tokens{t})) %#ok<STREMP>
                tf = true;
                return;
            end
        end
    end
end

function r = check(r, cond, msg)
    if cond
        r.summary{end+1} = ['PASS  ' msg];
    else
        r.summary{end+1} = ['FAIL  ' msg];
        r.passed = false;
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end
