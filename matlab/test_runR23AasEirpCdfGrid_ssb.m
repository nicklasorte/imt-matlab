function results = test_runR23AasEirpCdfGrid_ssb()
%TEST_RUNR23AASEIRPCDFGRID_SSB SSB-sweep option integration tests.
%
%   RESULTS = test_runR23AasEirpCdfGrid_ssb()
%
%   Covers the opts.ssb wiring on runR23AasEirpCdfGrid:
%       T1.  opts.ssb absent -> out has NO .ssb / .timeWeighted fields and
%            metadata.includesSsbSweep == false.
%       T2a. opts.ssb = struct() -> out.ssb + out.timeWeighted present and
%            metadata.includesSsbSweep == true.
%       T2b. DEFAULT-OFF invariant: the traffic streaming aggregator
%            (counts / sum_lin_mW / min_dBm / max_dBm / mean_dBm) and the
%            percentileMaps are byte-identical with the sweep ON vs OFF for
%            a fixed seed -- opts.ssb never mutates the traffic path.
%       T2c. The sweep-ON run is deterministic under a fixed seed.
%       T3.  Mean sweepShareOfAvg in the horizon band (|el| <= 1 deg)
%            exceeds the mean in a steep-down band (el <= -8 deg).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    baseOpts = struct();
    baseOpts.numMc       = 20;
    baseOpts.azGridDeg   = -60:5:60;     % 25
    baseOpts.elGridDeg   = -12:1:6;       % 19 (spans horizon + steep down)
    baseOpts.binEdgesDbm = -100:1:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 4242;
    baseOpts.numBeams    = 3;
    baseOpts.deployment  = 'macroUrban';

    base = runR23AasEirpCdfGrid(baseOpts);

    % ---- T1: sweep absent -> no SSB outputs ----
    ok1 = ~isfield(base, 'ssb') && ~isfield(base, 'timeWeighted') && ...
          isfield(base.metadata, 'includesSsbSweep') && ...
          ~base.metadata.includesSsbSweep;
    results = check(results, ok1, ...
        'T1: opts.ssb absent -> no .ssb/.timeWeighted, includesSsbSweep==false');

    % ---- T2a: sweep present ----
    ssbOpts = baseOpts;
    ssbOpts.ssb = struct();
    withSsb = runR23AasEirpCdfGrid(ssbOpts);

    ok2a = isfield(withSsb, 'ssb') && isstruct(withSsb.ssb) && ...
           isfield(withSsb, 'timeWeighted') && isstruct(withSsb.timeWeighted) && ...
           isfield(withSsb.metadata, 'includesSsbSweep') && ...
           withSsb.metadata.includesSsbSweep == true && ...
           isfield(withSsb.metadata, 'ssbConfig');
    results = check(results, ok2a, ...
        'T2a: opts.ssb=struct() -> out.ssb + out.timeWeighted present, includesSsbSweep==true');

    % ---- T2b: traffic path byte-identical (DEFAULT-OFF invariant) ----
    ok2b = isequal(withSsb.stats.counts,         base.stats.counts) && ...
           isequaln(withSsb.stats.sum_lin_mW,    base.stats.sum_lin_mW) && ...
           isequaln(withSsb.stats.min_dBm,       base.stats.min_dBm) && ...
           isequaln(withSsb.stats.max_dBm,       base.stats.max_dBm) && ...
           isequaln(withSsb.stats.mean_dBm,      base.stats.mean_dBm) && ...
           isequaln(withSsb.percentileMaps.values, base.percentileMaps.values);
    results = check(results, ok2b, ...
        'T2b: traffic stats + percentileMaps byte-identical sweep ON vs OFF (fixed seed)');

    % ---- T2c: determinism with sweep ON ----
    withSsb2 = runR23AasEirpCdfGrid(ssbOpts);
    ok2c = isequal(withSsb.stats.counts,            withSsb2.stats.counts) && ...
           isequaln(withSsb.ssb.timeAvg_dBm,        withSsb2.ssb.timeAvg_dBm) && ...
           isequaln(withSsb.timeWeighted.avg_dBm,   withSsb2.timeWeighted.avg_dBm) && ...
           isequaln(withSsb.timeWeighted.sweepShareOfAvg, withSsb2.timeWeighted.sweepShareOfAvg);
    results = check(results, ok2c, 'T2c: sweep-ON run is deterministic under a fixed seed');

    % ---- T3: horizon band sweepShare > steep-down band ----
    share = withSsb.timeWeighted.sweepShareOfAvg;   % Naz x Nel
    elv   = withSsb.ssb.elGrid;                      % 1 x Nel
    horizonCols = abs(elv) <= 1;
    downCols    = elv <= -8;
    sH = share(:, horizonCols);
    sD = share(:, downCols);
    meanH = mean(sH(:));
    meanD = mean(sD(:));
    ok3 = ~isempty(sH) && ~isempty(sD) && meanH > meanD;
    results = check(results, ok3, sprintf( ...
        'T3: horizon sweepShare (%.3f) > steep-down sweepShare (%.3f)', meanH, meanD));

    fprintf('\n--- test_runR23AasEirpCdfGrid_ssb summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
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
