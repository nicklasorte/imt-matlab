function results = test_imtAasTimeWeightedGrid()
%TEST_IMTAASTIMEWEIGHTEDGRID Self tests for the time-weighted EIRP combine.
%
%   RESULTS = test_imtAasTimeWeightedGrid()
%
%   Covers, for BOTH the TS 38.214 frame path and the legacy simple budget:
%       * avg_dBm / peak_dBm / sweepShareOfAvg are finite,
%       * alphaSweep + alphaUe + alphaIdle == 1,
%       * peak_dBm == max(stats.max_dBm, ssb.envelope_dBm),
%       * sweepShareOfAvg in [0, 1],
%       * back-compat aliases equal their canonical fields,
%   plus that a grid mismatch between STATS and SSB raises an error.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    rng(2024);
    az  = -60:10:60;     % 13
    el  = -12:2:6;       % 10
    Naz = numel(az);
    Nel = numel(el);

    stats = struct();
    stats.azGrid          = az;
    stats.elGrid          = el;
    stats.numUesPerSector = 3;
    stats.mean_lin_mW     = 1 + rand(Naz, Nel);     % strictly positive traffic mean
    stats.max_dBm         = 70 + 5 .* rand(Naz, Nel);

    ssb = struct();
    ssb.azGrid       = az;
    ssb.elGrid       = el;
    ssb.numBeams     = 8;
    ssb.timeAvg_dBm  = 40 + 10 .* rand(Naz, Nel);
    ssb.envelope_dBm = 75 +  3 .* rand(Naz, Nel);

    % ---- frame path ----
    tbFrame = struct('frame', struct('scs_kHz', 30, 'loadFactor', 0.20));
    twF = imtAasTimeWeightedGrid(stats, ssb, tbFrame);
    results = t_common(results, twF, stats, ssb, 'frame');
    results = check(results, isfield(twF, 'budget') && isstruct(twF.budget), ...
        'frame: returns full .budget struct');
    results = check(results, strcmp(twF.timeBudget.path, 'frame'), ...
        'frame: timeBudget.path == ''frame''');

    % ---- legacy path ----
    tbLegacy = struct('numSSB', 8, 'symbolsPerSSB', 4, 'ssbScs_kHz', 30, ...
                      'ssbPeriod_ms', 20, 'dlFraction', 0.75, 'loadFactor', 0.20);
    twL = imtAasTimeWeightedGrid(stats, ssb, tbLegacy);
    results = t_common(results, twL, stats, ssb, 'legacy');
    results = check(results, ~isfield(twL, 'budget'), ...
        'legacy: no .budget struct (frame-only field)');
    results = check(results, strcmp(twL.timeBudget.path, 'legacy'), ...
        'legacy: timeBudget.path == ''legacy''');

    % ---- grid mismatch errors ----
    badSsb = ssb;
    badSsb.azGrid      = az(1:end-1);              % drop one az point
    badSsb.timeAvg_dBm = ssb.timeAvg_dBm(1:end-1, :);
    threw = false;
    try
        imtAasTimeWeightedGrid(stats, badSsb, tbFrame);
    catch e
        threw = strcmp(e.identifier, 'imtAasTimeWeightedGrid:gridMismatch');
    end
    results = check(results, threw, 'grid mismatch raises imtAasTimeWeightedGrid:gridMismatch');

    fprintf('\n--- test_imtAasTimeWeightedGrid summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function r = t_common(r, tw, stats, ssb, tag)
    okFinite = all(isfinite(tw.avg_dBm(:))) && ...
               all(isfinite(tw.peak_dBm(:))) && ...
               all(isfinite(tw.sweepShareOfAvg(:)));
    r = check(r, okFinite, [tag ': avg/peak/share all finite']);

    okSum = abs(tw.alphaSweep + tw.alphaUe + tw.alphaIdle - 1) < 1e-9;
    r = check(r, okSum, [tag ': alphas sum to 1']);

    expectedPeak = max(stats.max_dBm, ssb.envelope_dBm);
    r = check(r, isequaln(tw.peak_dBm, expectedPeak), ...
        [tag ': peak_dBm == max(stats.max_dBm, ssb.envelope_dBm)']);

    okShare = all(tw.sweepShareOfAvg(:) >= -1e-12) && ...
              all(tw.sweepShareOfAvg(:) <= 1 + 1e-12);
    r = check(r, okShare, [tag ': sweepShareOfAvg in [0, 1]']);

    okAlias = isequaln(tw.ssbShareOfAvg, tw.sweepShareOfAvg) && ...
              tw.alphaSsb == tw.alphaSweep && ...
              tw.alphaTr  == tw.alphaUe;
    r = check(r, okAlias, [tag ': back-compat aliases equal canonical fields']);
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
