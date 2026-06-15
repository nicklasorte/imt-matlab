function results = test_variable_ue_count()
%TEST_VARIABLE_UE_COUNT opts.ueCountModel integration tests.
%
%   RESULTS = test_variable_ue_count()
%
%   Covers the variable per-snapshot UE-count model wiring on
%   runR23AasEirpCdfGrid. The 'fixed' model (default) reproduces today's
%   behaviour byte-for-byte; the 'uniform' / 'poisson' models draw a
%   per-snapshot co-scheduled-UE count.
%       T1.  BACK-COMPAT: the default model is 'fixed' and out.ueCount == [];
%            an explicit ueCountModel='fixed' run has isequal stats and
%            isequal percentileMaps.values vs the default run at the same
%            seed (proves the fixed path draws nothing extra).
%       T2.  UNIFORM spread: the realized count varies within [min,max], the
%            tally sums to numSnapshots, the pmf sums to 1, and the realized
%            mean sits strictly inside (min,max).
%       T3.  POISSON: the realized count respects [min,max] and the realized
%            mean is near the Poisson lambda for large numMc.
%       T4.  REPRODUCIBLE + POWER-BOUNDED: two uniform runs with the SAME
%            seed are isequal (stats and ueCount tally); the realized
%            aggregate EIRP stays bounded by the sector peak.
%       T5.  COMPOSITION: ueCountModel='uniform' composes with opts.prbWeighting
%            and with opts.layering (both run, both produce non-empty outputs).
%       T6.  VALIDATION: maxUesPerSector < minUesPerSector errors;
%            meanUesPerSector <= 0 with 'poisson' errors; an unknown
%            ueCountModel string errors.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    % Small / fast config (small grids, fixed seed).
    baseOpts = struct();
    baseOpts.numMc       = 30;
    baseOpts.azGridDeg   = -60:10:60;      % 13
    baseOpts.elGridDeg   = -12:2:6;         % 10
    baseOpts.binEdgesDbm = -100:1:120;
    baseOpts.percentiles = [5 50 95];
    baseOpts.seed        = 7;
    baseOpts.numBeams    = 3;
    baseOpts.deployment  = 'macroUrban';

    % ---- T1: back-compat (default 'fixed' draws nothing extra) -------
    base = runR23AasEirpCdfGrid(baseOpts);
    fixedOpts = baseOpts;
    fixedOpts.ueCountModel = 'fixed';
    fixedRun = runR23AasEirpCdfGrid(fixedOpts);
    ok1 = isfield(base, 'ueCount') && isempty(base.ueCount) && ...
          strcmp(base.metadata.ueCountModel, 'fixed') && ...
          base.metadata.ueCountRealizedMean == baseOpts.numBeams && ...
          isempty(fixedRun.ueCount) && ...
          isequal(fixedRun.stats.counts,           base.stats.counts) && ...
          isequaln(fixedRun.stats.sum_lin_mW,      base.stats.sum_lin_mW) && ...
          isequaln(fixedRun.stats.max_dBm,         base.stats.max_dBm) && ...
          isequaln(fixedRun.percentileMaps.values, base.percentileMaps.values);
    results = check(results, ok1, ...
        'T1: default/explicit ''fixed'' -> out.ueCount [] and byte-identical stats/maps');

    % ---- T2: uniform spread -----------------------------------------
    uniOpts = baseOpts;
    uniOpts.ueCountModel    = 'uniform';
    uniOpts.minUesPerSector = 1;
    uniOpts.maxUesPerSector = 5;
    uniOpts.numMc           = 200;
    uniOpts.seed            = 7;
    uni = runR23AasEirpCdfGrid(uniOpts);
    U = uni.ueCount;
    ok2 = strcmp(U.model, 'uniform') && ...
          U.realizedMin >= 1 && U.realizedMax <= 5 && U.realizedMax > U.realizedMin && ...
          sum(U.countTally) == U.numSnapshots && U.numSnapshots == 200 && ...
          abs(sum(U.countPmf) - 1) < 1e-9 && ...
          U.realizedMean > 1 && U.realizedMean < 5;
    results = check(results, ok2, sprintf( ...
        ['T2: uniform varies in [1,5] (min %d max %d mean %.2f), tally sums ', ...
         'to %d, pmf sums to 1'], U.realizedMin, U.realizedMax, ...
        U.realizedMean, U.numSnapshots));

    % ---- T3: poisson ------------------------------------------------
    poiOpts = baseOpts;
    poiOpts.ueCountModel     = 'poisson';
    poiOpts.meanUesPerSector = 3;
    poiOpts.minUesPerSector  = 1;
    poiOpts.maxUesPerSector  = 10;
    poiOpts.numMc            = 400;
    poiOpts.seed             = 7;
    poi = runR23AasEirpCdfGrid(poiOpts);
    P = poi.ueCount;
    ok3 = strcmp(P.model, 'poisson') && ...
          P.realizedMin >= 1 && P.realizedMax <= 10 && ...
          abs(P.realizedMean - 3) < 0.6;
    results = check(results, ok3, sprintf( ...
        ['T3: poisson respects [1,10] (min %d max %d) and realized mean ', ...
         '%.2f ~ lambda 3'], P.realizedMin, P.realizedMax, P.realizedMean));

    % ---- T4: reproducible + power-bounded ---------------------------
    uniA = runR23AasEirpCdfGrid(uniOpts);
    uniB = runR23AasEirpCdfGrid(uniOpts);
    sameStats = isequal(uniA.stats.counts, uniB.stats.counts) && ...
                isequaln(uniA.stats.sum_lin_mW, uniB.stats.sum_lin_mW) && ...
                isequal(uniA.ueCount.countTally, uniB.ueCount.countTally);
    pmVals = uniA.percentileMaps.values(:);
    bounded = max(pmVals, [], 'omitnan') <= uniA.metadata.sectorEirpDbm + 1e-6 && ...
              ~strcmp(uniA.selfCheck.powerSemantics.status, 'fail');
    ok4 = sameStats && bounded;
    results = check(results, ok4, ...
        'T4: same-seed uniform runs isequal (stats + tally) and EIRP <= sector peak');

    % ---- T5: composition with prbWeighting and layering -------------
    prbCombo = uniOpts;
    prbCombo.numMc        = 30;
    prbCombo.prbWeighting = struct('mode', 'random', 'spread', 0.5);
    prbRun = runR23AasEirpCdfGrid(prbCombo);
    okPrb = ~isempty(prbRun.ueCount) && isstruct(prbRun.ueCount) && ...
            strcmp(prbRun.ueCount.model, 'uniform') && ...
            ~isempty(prbRun.prbWeighting) && isstruct(prbRun.prbWeighting) && ...
            prbRun.metadata.includesPrbWeighting == true && ...
            prbRun.selfCheck.powerSemantics.observedMaxGridEirp_dBm <= ...
                prbRun.metadata.sectorEirpDbm + 1e-6;

    layCombo = uniOpts;
    layCombo.numMc    = 30;
    layCombo.layering = struct('rank', 2, 'layerSpreadDeg', 1);
    layRun = runR23AasEirpCdfGrid(layCombo);
    okLay = ~isempty(layRun.ueCount) && isstruct(layRun.ueCount) && ...
            ~isempty(layRun.layering) && isstruct(layRun.layering) && ...
            layRun.metadata.includesLayering == true && ...
            ~strcmp(layRun.selfCheck.powerSemantics.status, 'fail');
    ok5 = okPrb && okLay;
    results = check(results, ok5, ...
        'T5: ueCountModel=''uniform'' composes with opts.prbWeighting and opts.layering');

    % ---- T6: validation ---------------------------------------------
    badMax = baseOpts;
    badMax.ueCountModel    = 'uniform';
    badMax.minUesPerSector = 5;
    badMax.maxUesPerSector = 2;
    okMax = throwsId(@() runR23AasEirpCdfGrid(badMax), ...
        'runR23AasEirpCdfGrid:badMaxUesPerSector');

    badMean = baseOpts;
    badMean.ueCountModel     = 'poisson';
    badMean.meanUesPerSector = 0;
    okMean = throwsId(@() runR23AasEirpCdfGrid(badMean), ...
        'runR23AasEirpCdfGrid:badMeanUesPerSector');

    badModel = baseOpts;
    badModel.ueCountModel = 'banana';
    okModel = throwsId(@() runR23AasEirpCdfGrid(badModel), ...
        'runR23AasEirpCdfGrid:ueCountModel');
    ok6 = okMax && okMean && okModel;
    results = check(results, ok6, ...
        'T6: bad max/mean and unknown ueCountModel all error with clear ids');

    fprintf('\n--- test_variable_ue_count summary ---\n');
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

function tf = throwsId(fn, id)
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end
