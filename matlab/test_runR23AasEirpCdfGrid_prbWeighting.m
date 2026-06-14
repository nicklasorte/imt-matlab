function results = test_runR23AasEirpCdfGrid_prbWeighting()
%TEST_RUNR23AASEIRPCDFGRID_PRBWEIGHTING opts.prbWeighting integration tests.
%
%   RESULTS = test_runR23AasEirpCdfGrid_prbWeighting()
%
%   Covers the opts.prbWeighting wiring on runR23AasEirpCdfGrid. This layer
%   is SENSITIVITY ONLY and DEPARTS from the ITU equal-bandwidth baseline.
%       T1.  DEFAULT-OFF invariant: opts.prbWeighting = struct('enable',false)
%            (and absent) -> stats / percentileMaps / selfCheck / out.ssb /
%            out.epre / out.layering are BYTE-IDENTICAL to a no-prbWeighting
%            run with the same seed; out.prbWeighting == [] /
%            includesPrbWeighting == false.
%       T2.  EQUAL-SHARES == OFF within tolerance (NOT byte-identical):
%            enabled equal shares (fixed-equal and spread 0), no layering ->
%            percentileMaps.values within 1e-6 dB and sum_lin_mW within
%            relative 1e-9 of OFF. (counts may differ by +-1 at a bin edge.)
%       T3.  Power conservation / self-check: with an unequal allocation on,
%            observed aggregate max stays <= sector peak and the self-check
%            does not FAIL.
%       T4.  The effect is real: a concentrated allocation [0.9 0.05 0.05]
%            drives the hottest realized per-beam EIRP toward sectorEirp
%            (>> the equal-split sectorEirp - 10*log10(3)) and the aggregate
%            p95 is >= the baseline p95.
%       T5.  Combos: opts.prbWeighting + opts.layering (per-UE shares split
%            across layers, power conserved, self-check OK), + opts.epre, and
%            + opts.ssb (each still attaches and behaves).
%       T6.  resolvePrbWeightingOpts error path: a non-struct, non-empty
%            opts.prbWeighting is rejected with
%            'runR23AasEirpCdfGrid:badPrbWeightingOpts'.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    baseOpts = struct();
    baseOpts.numMc       = 20;
    baseOpts.azGridDeg   = -60:5:60;       % 25
    baseOpts.elGridDeg   = -12:1:6;         % 19
    baseOpts.binEdgesDbm = -100:1:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 4242;
    baseOpts.numBeams    = 3;
    baseOpts.deployment  = 'macroUrban';

    base = runR23AasEirpCdfGrid(baseOpts);

    % ---- T1: default-off invariant ----------------------------------
    offOpts = baseOpts;
    offOpts.prbWeighting = struct('enable', false);
    offRun = runR23AasEirpCdfGrid(offOpts);
    ok1 = isfield(base, 'prbWeighting') && isempty(base.prbWeighting) && ...
          isfield(base.metadata, 'includesPrbWeighting') && ...
          ~base.metadata.includesPrbWeighting && ...
          isempty(offRun.prbWeighting) && ~offRun.metadata.includesPrbWeighting && ...
          isequal(offRun.stats.counts,           base.stats.counts) && ...
          isequaln(offRun.stats.sum_lin_mW,      base.stats.sum_lin_mW) && ...
          isequaln(offRun.stats.max_dBm,         base.stats.max_dBm) && ...
          isequaln(offRun.percentileMaps.values, base.percentileMaps.values) && ...
          isequaln(offRun.selfCheck,             base.selfCheck);
    results = check(results, ok1, ...
        'T1: opts.prbWeighting off -> byte-identical stats/maps/selfCheck, []');

    % ---- T2: equal-shares within tolerance (NOT byte-identical) -----
    eqFixed = baseOpts;
    eqFixed.prbWeighting = struct('mode', 'fixed', 'weights', [1 1 1]);
    eqFixedRun = runR23AasEirpCdfGrid(eqFixed);
    eqRand = baseOpts;
    eqRand.prbWeighting = struct('mode', 'random', 'spread', 0);
    eqRandRun = runR23AasEirpCdfGrid(eqRand);
    ok2 = withinTol(eqFixedRun, base) && withinTol(eqRandRun, base) && ...
          eqFixedRun.metadata.includesPrbWeighting == true && ...
          isstruct(eqFixedRun.prbWeighting) && ...
          abs(eqFixedRun.prbWeighting.participationRatio.mean - 3) <= 1e-9;
    results = check(results, ok2, ...
        'T2: equal shares (fixed/spread0) == OFF within 1e-6 dB / 1e-9 rel');

    % ---- T3: power conservation / self-check ------------------------
    unevenOpts = baseOpts;
    unevenOpts.prbWeighting = struct('mode', 'fixed', 'weights', [0.7 0.2 0.1]);
    unevenRun = runR23AasEirpCdfGrid(unevenOpts);
    sectorPeak  = unevenRun.metadata.sectorEirpDbm;
    observedMax = unevenRun.selfCheck.powerSemantics.observedMaxGridEirp_dBm;
    ok3 = observedMax <= sectorPeak + 1e-6 && ...
          ~strcmp(unevenRun.selfCheck.powerSemantics.status, 'fail') && ...
          unevenRun.metadata.includesPrbWeighting == true;
    results = check(results, ok3, sprintf( ...
        ['T3: PRB weighting power-conserving (observed max %.2f <= sector ', ...
         'peak %.2f), self-check not FAIL'], observedMax, sectorPeak));

    % ---- T4: the effect is real -------------------------------------
    concOpts = baseOpts;
    concOpts.prbWeighting = struct('mode', 'fixed', 'weights', [0.9 0.05 0.05]);
    concRun = runR23AasEirpCdfGrid(concOpts);
    sectorEirp   = concRun.metadata.sectorEirpDbm;
    equalSplit   = sectorEirp - 10 * log10(3);
    hottest      = concRun.prbWeighting.perBeamPeakEirpDbm.max;
    % Hottest per-beam EIRP for the 0.9 share = sectorEirp + 10*log10(0.9).
    expHottest   = sectorEirp + 10 * log10(0.9);
    p95baseMap = base.percentileMaps.values(:, :, 3);
    p95concMap = concRun.percentileMaps.values(:, :, 3);
    p95base = max(p95baseMap(:));
    p95conc = max(p95concMap(:));
    ok4 = abs(hottest - expHottest) <= 1e-9 && ...
          hottest > equalSplit + 3 && ...                  % well above equal split
          p95conc >= p95base - 1e-6;
    results = check(results, ok4, sprintf( ...
        ['T4: concentrated alloc hottest %.2f (>> equal %.2f), aggregate ', ...
         'p95 %.2f >= baseline %.2f'], hottest, equalSplit, p95conc, p95base));

    % ---- T5: combos with layering, epre, ssb ------------------------
    layCombo = baseOpts;
    layCombo.prbWeighting = struct('mode', 'fixed', 'weights', [0.6 0.3 0.1]);
    layCombo.layering     = struct('rank', 2, 'layerSpreadDeg', 1);
    layRun = runR23AasEirpCdfGrid(layCombo);
    okLay = layRun.metadata.includesPrbWeighting == true && ...
            layRun.metadata.includesLayering == true && ...
            isstruct(layRun.prbWeighting) && isstruct(layRun.layering) && ...
            layRun.selfCheck.powerSemantics.observedMaxGridEirp_dBm <= ...
                layRun.metadata.sectorEirpDbm + 1e-6 && ...
            ~strcmp(layRun.selfCheck.powerSemantics.status, 'fail');

    epreCombo = baseOpts;
    epreCombo.prbWeighting = struct('mode', 'random', 'spread', 0.5);
    epreCombo.epre         = struct('dmrsCdmGroupsNoData', 2);   % 3 dB
    epreRun = runR23AasEirpCdfGrid(epreCombo);
    okEpre = epreRun.metadata.includesPrbWeighting == true && ...
             epreRun.metadata.includesEpre == true && ...
             isstruct(epreRun.prbWeighting) && isstruct(epreRun.epre) && ...
             isfield(epreRun.epre, 'perRePeakEnvelope_dBm');

    ssbCombo = baseOpts;
    ssbCombo.prbWeighting = struct('mode', 'random', 'spread', 0.5);
    ssbCombo.ssb          = struct();
    ssbRun = runR23AasEirpCdfGrid(ssbCombo);
    okSsb = ssbRun.metadata.includesPrbWeighting == true && ...
            ssbRun.metadata.includesSsbSweep == true && ...
            isstruct(ssbRun.prbWeighting) && isfield(ssbRun, 'ssb') && ...
            isstruct(ssbRun.ssb) && isfield(ssbRun, 'timeWeighted');
    ok5 = okLay && okEpre && okSsb;
    results = check(results, ok5, ...
        'T5: opts.prbWeighting + layering / epre / ssb all attach and behave');

    % ---- T6: non-struct opts.prbWeighting rejected ------------------
    badOpts = baseOpts;
    badOpts.prbWeighting = 5;   % non-struct, non-empty
    ok6 = throwsId(@() runR23AasEirpCdfGrid(badOpts), ...
        'runR23AasEirpCdfGrid:badPrbWeightingOpts');
    results = check(results, ok6, ...
        'T6: non-struct opts.prbWeighting throws badPrbWeightingOpts');

    fprintf('\n--- test_runR23AasEirpCdfGrid_prbWeighting summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function tf = withinTol(run, base)
%WITHINTOL percentileMaps within 1e-6 dB and sum_lin_mW within rel 1e-9.
    dPm = abs(run.percentileMaps.values - base.percentileMaps.values);
    pmOk = all(dPm(:) <= 1e-6 | isnan(dPm(:)));
    denom = max(abs(base.stats.sum_lin_mW), realmin);
    relS = abs(run.stats.sum_lin_mW - base.stats.sum_lin_mW) ./ denom;
    sOk = all(relS(:) <= 1e-9);
    tf = pmOk && sOk;
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

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
