function results = test_embrss_eirp_cdf_grid()
%TEST_EMBRSS_EIRP_CDF_GRID Unit tests for the EMBRSS EIRP CDF-grid step.
%
%   RESULTS = test_embrss_eirp_cdf_grid()
%
%   Covers:
%       E1.  embrss_category_model returns expected radii / heights for
%            urban_macro / suburban_macro / rural_macro.
%       E2.  Invalid category names error.
%       E3.  embrss_aas_config powerMode='conducted' sets txPower_dBm
%            directly and does not double-count antenna gain.
%       E4.  embrss_aas_config powerMode='peak_eirp' subtracts peak gain so
%            txPower_dBm + peakGain_dBi = peakEirp_dBm  (and peak EIRP
%            from imt_aas_bs_eirp at boresight matches the requested
%            value).
%       E5.  ue_sector with ue_height_range_m returns dbg.ueHeight_m
%            inside that range; scalar ue_height_m mode still works.
%       E6.  Two run_embrss_eirp_cdf_grid calls with the same seed produce
%            identical stats.counts and stats.mean_dBm; a different seed
%            changes at least some counts or means.
%       E7.  stats.counts sums to numMc at every (az,el) cell;
%            percentile maps are finite for populated cells and
%            monotonic non-decreasing in percentile.
%       E8.  CSV export round-trips for a tiny grid.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = test_category_model(results);
    results = test_invalid_category(results);
    results = test_aas_config_conducted(results);
    results = test_aas_config_peak_eirp(results);
    results = test_ue_height_range_sampler(results);
    results = test_reproducibility(results);
    results = test_histogram_and_percentiles(results);
    results = test_csv_export(results);

    fprintf('\n--- test_embrss_eirp_cdf_grid summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =========================================================================
% E1. category presets
% =========================================================================
function r = test_category_model(r)
    mU = embrss_category_model('urban_macro');
    mS = embrss_category_model('suburban_macro');
    mR = embrss_category_model('rural_macro');

    okU = strcmp(mU.name, 'urban_macro') && ...
          mU.bs_height_m       == 20    && ...
          mU.sector_radius_m   == 400   && ...
          isequal(mU.ue_height_range_m, [1.5 35]) && ...
          mU.sector_width_deg  == 120   && ...
          mU.min_ue_range_m    == 35    && ...
          mU.num_ues_per_sector == 3;
    r = check(r, okU, 'E1a: urban_macro defaults match EMBRSS presets');

    okS = strcmp(mS.name, 'suburban_macro') && ...
          mS.bs_height_m       == 25    && ...
          mS.sector_radius_m   == 800   && ...
          isequal(mS.ue_height_range_m, [1.5 17]);
    r = check(r, okS, 'E1b: suburban_macro defaults match EMBRSS presets');

    okR = strcmp(mR.name, 'rural_macro') && ...
          mR.bs_height_m       == 35    && ...
          mR.sector_radius_m   == 1600  && ...
          isequal(mR.ue_height_range_m, [1.5 5]);
    r = check(r, okR, 'E1c: rural_macro defaults match EMBRSS presets');

    % Override path
    mOv = embrss_category_model('urban_macro', ...
        'sector_radius_m', 250, 'num_ues_per_sector', 4);
    okOv = mOv.sector_radius_m == 250 && mOv.num_ues_per_sector == 4 && ...
           mOv.bs_height_m == 20;
    r = check(r, okOv, 'E1d: name-value overrides apply on top of preset');
end

function r = test_invalid_category(r)
    threw = false;
    try
        embrss_category_model('not_a_real_category');
    catch err
        threw = strcmp(err.identifier, 'embrss_category_model:badCategory');
    end
    r = check(r, threw, ...
        'E2: invalid category throws embrss_category_model:badCategory');
end

% =========================================================================
% E3. AAS config conducted
% =========================================================================
function r = test_aas_config_conducted(r)
    cfg = embrss_aas_config('urban_macro', 'txPower_dBm', 25);
    okPm = strcmp(cfg.powerMode, 'conducted') && cfg.txPower_dBm == 25;
    r = check(r, okPm, ...
        'E3a: conducted mode preserves txPower_dBm verbatim');

    % EIRP at array boresight under conducted mode = txPower + peakGain
    % (no feeder loss). This catches accidental subtraction or addition
    % of antenna gain in either direction.
    expectedPeakGain = cfg.G_Emax + ...
        10 * log10(double(cfg.N_H) * double(cfg.N_V));
    eirp = imt_aas_bs_eirp(0, 0, 0, 0, cfg);
    expectedEirp = cfg.txPower_dBm + expectedPeakGain - cfg.feederLoss_dB;
    okEirp = abs(eirp - expectedEirp) < 1e-9;
    r = check(r, okEirp, sprintf( ...
        ['E3b: conducted boresight EIRP = txPower + peakGain ' ...
         '(got %.3f dBm, expected %.3f dBm)'], eirp, expectedEirp));

    % Passing peakEirp_dBm in conducted mode must error
    threw = false;
    try
        embrss_aas_config('urban_macro', 'peakEirp_dBm', 60);
    catch err
        threw = strcmp(err.identifier, ...
            'embrss_aas_config:peakEirpInConducted');
    end
    r = check(r, threw, ...
        'E3c: peakEirp_dBm in conducted mode is rejected (no double-count)');
end

% =========================================================================
% E4. AAS config peak_eirp
% =========================================================================
function r = test_aas_config_peak_eirp(r)
    cfg = embrss_aas_config('urban_macro', ...
        'powerMode', 'peak_eirp', 'peakEirp_dBm', 72);

    expectedPeakGain = cfg.G_Emax + ...
        10 * log10(double(cfg.N_H) * double(cfg.N_V));
    okGain = abs(cfg.peakGain_dBi - expectedPeakGain) < 1e-12;
    r = check(r, okGain, sprintf( ...
        'E4a: peak gain default = G_Emax + 10log10(N_H*N_V) (got %.3f, expected %.3f)', ...
        cfg.peakGain_dBi, expectedPeakGain));

    okBack = abs((cfg.txPower_dBm + cfg.peakGain_dBi - cfg.feederLoss_dB) ...
                 - 72) < 1e-9;
    r = check(r, okBack, ...
        'E4b: peak_eirp back-computes txPower so txP + peakGain = peakEirp');

    % EIRP from imt_aas_bs_eirp at array boresight under rho=1 must equal
    % the requested peak EIRP. This is the canonical "no double counting"
    % check across the full evaluation chain.
    eirp = imt_aas_bs_eirp(0, 0, 0, 0, cfg);
    okNoDouble = abs(eirp - 72) < 1e-9;
    r = check(r, okNoDouble, sprintf( ...
        ['E4c: end-to-end boresight EIRP under peak_eirp matches peakEirp_dBm ' ...
         '(got %.3f dBm, expected 72 dBm)'], eirp));

    % Custom peakGain_dBi override
    cfg2 = embrss_aas_config('urban_macro', ...
        'powerMode', 'peak_eirp', 'peakEirp_dBm', 72, ...
        'peakGain_dBi', 30);
    okOv = cfg2.peakGain_dBi == 30 && ...
           abs(cfg2.txPower_dBm - (72 - 30)) < 1e-12;
    r = check(r, okOv, ...
        'E4d: explicit peakGain_dBi override is respected');

    % Missing peakEirp_dBm in peak_eirp mode must error
    threw = false;
    try
        embrss_aas_config('urban_macro', 'powerMode', 'peak_eirp');
    catch err
        threw = strcmp(err.identifier, ...
            'embrss_aas_config:missingPeakEirp');
    end
    r = check(r, threw, ...
        'E4e: peak_eirp mode without peakEirp_dBm is rejected');
end

% =========================================================================
% E5. UE-height-range sampler
% =========================================================================
function r = test_ue_height_range_sampler(r)
    sampler = struct('mode', 'ue_sector', ...
        'sector_az_deg', 0, 'sector_width_deg', 120, ...
        'r_min_m', 35, 'r_max_m', 400, ...
        'bs_height_m', 20, ...
        'ue_height_range_m', [1.5 35], ...
        'numBeams', 1);

    rng(2024);
    n = 2000;
    hs = zeros(n, 1);
    for i = 1:n
        [~, ~, dbg] = sample_aas_beam_direction(sampler);
        hs(i) = dbg.ueHeight_m;
    end
    okRange = all(hs >= 1.5 - 1e-12 & hs <= 35 + 1e-12);
    okSpread = (max(hs) - min(hs)) > 25;   % should span most of the range
    r = check(r, okRange && okSpread, sprintf( ...
        'E5a: ue_height_range_m draws inside [1.5,35] (observed [%.2f,%.2f])', ...
        min(hs), max(hs)));

    % numBeams > 1: ueHeight_m has the right length and stays in range
    samplerN = sampler;
    samplerN.numBeams = 5;
    [~, ~, dbgN] = sample_aas_beam_direction(samplerN, 7);
    okN = numel(dbgN.ueHeight_m) == 5 && ...
          all(dbgN.ueHeight_m >= 1.5 - 1e-12 & ...
              dbgN.ueHeight_m <= 35 + 1e-12);
    r = check(r, okN, ...
        'E5b: ue_height_range_m respects numBeams and stays in range');

    % Scalar ue_height_m fallback (backward compatibility)
    samplerScal = struct('mode', 'ue_sector', ...
        'sector_az_deg', 0, 'sector_width_deg', 120, ...
        'r_min_m', 10, 'r_max_m', 500, ...
        'bs_height_m', 25, 'ue_height_m', 1.5, 'numBeams', 1);
    rng(11);
    [a, e, dbgS] = sample_aas_beam_direction(samplerScal); %#ok<ASGLU>
    expectedEl = atan2d(1.5 - 25, dbgS.ueRange_m);
    okScal = abs(e - expectedEl) < 1e-12 && ...
             dbgS.ueHeight_m == 1.5;
    r = check(r, okScal, ...
        'E5c: scalar ue_height_m mode still works (back compat)');
end

% =========================================================================
% E6. Reproducibility
% =========================================================================
function r = test_reproducibility(r)
    opts = tinyOpts();
    opts.seed = 42;

    out1 = run_embrss_eirp_cdf_grid('urban_macro', opts);
    out2 = run_embrss_eirp_cdf_grid('urban_macro', opts);

    okEq = isequal(out1.stats.counts, out2.stats.counts) && ...
           isequaln(out1.stats.mean_dBm, out2.stats.mean_dBm);
    r = check(r, okEq, ...
        'E6a: same-seed reruns produce identical counts and mean_dBm');

    opts3 = opts; opts3.seed = 1234;
    out3 = run_embrss_eirp_cdf_grid('urban_macro', opts3);
    okDiff = ~isequal(out1.stats.counts, out3.stats.counts) || ...
             ~isequaln(out1.stats.mean_dBm, out3.stats.mean_dBm);
    r = check(r, okDiff, ...
        'E6b: different seed changes at least some counts or means');
end

% =========================================================================
% E7. Histogram + percentile sanity
% =========================================================================
function r = test_histogram_and_percentiles(r)
    opts = tinyOpts();
    opts.seed = 5;
    opts.percentiles = [5 25 50 75 95];

    out = run_embrss_eirp_cdf_grid('urban_macro', opts);
    stats = out.stats;
    pmaps = out.percentileMaps;

    Naz = numel(stats.azGrid);
    Nel = numel(stats.elGrid);
    rowSum = sum(double(stats.counts), 3);
    okSum = all(rowSum(:) == stats.numMc);
    r = check(r, okSum, sprintf( ...
        'E7a: stats.counts sums to numMc=%d at every (az,el) cell', ...
        stats.numMc));

    % populated cells: percentile values should be finite
    populated = rowSum > 0;
    finiteVals = isfinite(pmaps.values);
    okFinite = all(reshape(finiteVals(repmat(populated, [1 1 numel(opts.percentiles)])), 1, []));
    r = check(r, okFinite, ...
        'E7b: percentile map values are finite at every populated cell');

    % monotonic in percentile across populated cells
    valsFlat = reshape(pmaps.values, Naz*Nel, numel(opts.percentiles));
    valsPop  = valsFlat(populated(:), :);
    diffs    = diff(valsPop, 1, 2);
    okMono   = isempty(diffs) || all(diffs(:) >= -1e-9);
    r = check(r, okMono, ...
        'E7c: percentile map is monotonic non-decreasing in percentile');

    % no raw cube anywhere
    flds = fieldnames(out);
    rawNames = {'eirpCube','samples','rawCube'};
    hasRaw = any(ismember(lower(flds), lower(rawNames)));
    r = check(r, ~hasRaw, ...
        'E7d: out struct does not carry a raw EIRP sample cube');
end

% =========================================================================
% E8. CSV export round-trip
% =========================================================================
function r = test_csv_export(r)
    opts = tinyOpts();
    opts.seed = 9;
    tmp = [tempname, '.csv'];
    cleaner = onCleanup(@() removeIfExists(tmp)); %#ok<NASGU>
    opts.outputCsvPath = tmp;

    out = run_embrss_eirp_cdf_grid('urban_macro', opts);

    written = exist(tmp, 'file') == 2;
    okTbl = isfield(out, 'percentileTable') && istable(out.percentileTable);
    if written && okTbl
        Tread = readtable(tmp);
        okShape = height(Tread) == height(out.percentileTable) && ...
                  width(Tread)  == width(out.percentileTable);
    else
        okShape = false;
    end
    r = check(r, written && okTbl && okShape, ...
        'E8: CSV export written and round-trips via readtable');
end

% =========================================================================
% Helpers
% =========================================================================
function opts = tinyOpts()
    opts = struct();
    opts.numMc        = 30;
    opts.azGrid       = -30:10:30;       % 7 cells
    opts.elGrid       = -10:5:10;        % 5 cells
    opts.binEdges     = -80:5:120;
    opts.numBeams     = 1;
    opts.combineBeams = 'max';
    opts.progressEvery = 0;
    opts.percentiles  = [5 50 95];
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

function removeIfExists(p)
    if exist(p, 'file') == 2
        delete(p);
    end
end
