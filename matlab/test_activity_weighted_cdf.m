function results = test_activity_weighted_cdf()
%TEST_ACTIVITY_WEIGHTED_CDF opts.activityWeightedCdf integration tests.
%
%   RESULTS = test_activity_weighted_cdf()
%
%   Covers the opt-in statistical activity-weighted EIRP CDF layer on
%   runR23AasEirpCdfGrid. The layer treats
%       p = tddActivityFactor * networkLoadingFactor
%   as a PROBABILITY OF TRANSMISSION (M.2101-style activity factor): the
%   sector radiates at its FULL peak EIRP a fraction p of the time and is
%   off the rest. The requested percentile Pout maps to the always-on
%   percentile  Pon = 100 - (100 - Pout)/p  (exact under
%   eirp_percentile_maps); off-region percentiles (Pon <= 0) take the off
%   floor. It is computed POST-HOC from the always-on histogram and must
%   never perturb the raw streaming path.
%
%   T1.  Opt-in / back-compat: default (no activityWeightedCdf) ->
%        out.activityWeightedPercentileMaps == [] and
%        metadata.activityWeightedCdf == false; and a non-activity run vs
%        an activity run at the same seed have isequal raw
%        percentileMaps.values and an isequal streaming aggregator
%        (the feature is post-hoc; only the recorded opts differ).
%   T2.  p = 1 sanity: activity-weighted values == raw percentileMaps
%        values exactly.
%   T3.  ITU example (tdd=0.75, load=0.25 -> p=0.1875): activeFraction,
%        the Pon remapping, the on/off mask, the exact remapping vs the
%        tested engine on the SAME stats, and the off-region off floor.
%   T4.  Peak preserved / not a flat shift: the on-region 99th maps to a
%        LOWER always-on percentile, so it is <= the raw 99th and is not a
%        uniform dB offset of it.
%   T5.  Geometry-agnostic: activeFraction and onPercentileEquivalent are
%        IDENTICAL for 'r23_1x3_default' and 'ctia_7ghz_1x6', and the exact
%        remapping holds for each geometry.
%   T6.  Validation: activityWeightedCdf=true with tddActivityFactor=0,
%        networkLoadingFactor=1.5, or tddActivityFactor=-0.1 all error
%        with the specific 'runR23AasEirpCdfGrid:badActivityFactor' id.
%
%   T10. Validation: activityWeightedCdf=true with a bad activityModel
%        (out-of-set string or non-char) errors with the specific
%        'runR23AasEirpCdfGrid:invalidActivityModel' id.
%   T11. Validation: activityWeightedCdf=true with a bad
%        activityOffFloorUses (out-of-set string or non-char), with
%        activityModel at its default, errors with the specific
%        'runR23AasEirpCdfGrid:invalidActivityOffFloorUses' id.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    baseOpts = struct();
    baseOpts.numMc       = 60;
    baseOpts.azGridDeg   = -10:5:10;       % 5
    baseOpts.elGridDeg   = -10:5:5;        % 4
    baseOpts.binEdgesDbm = -100:2:120;
    baseOpts.percentiles = [5 50 95 99];
    baseOpts.seed        = 7;
    baseOpts.numBeams    = 3;
    baseOpts.aasGeometryPreset = 'r23_1x3_default';

    % ---- T1: opt-in / back-compat -----------------------------------
    base = runR23AasEirpCdfGrid(baseOpts);

    awOpts1 = baseOpts;
    awOpts1.activityWeightedCdf  = true;
    awOpts1.tddActivityFactor    = 0.75;
    awOpts1.networkLoadingFactor = 0.25;
    aw1 = runR23AasEirpCdfGrid(awOpts1);

    ok1 = isfield(base, 'activityWeightedPercentileMaps') && ...
          isempty(base.activityWeightedPercentileMaps) && ...
          isfield(base.metadata, 'activityWeightedCdf') && ...
          ~base.metadata.activityWeightedCdf && ...
          isempty(base.metadata.activityActiveFraction) && ...
          isstruct(aw1.activityWeightedPercentileMaps) && ...
          aw1.metadata.activityWeightedCdf && ...
          isequaln(base.percentileMaps.values, aw1.percentileMaps.values) && ...
          isequal(base.stats.counts,      aw1.stats.counts) && ...
          isequaln(base.stats.sum_lin_mW, aw1.stats.sum_lin_mW) && ...
          isequaln(base.stats.min_dBm,    aw1.stats.min_dBm) && ...
          isequaln(base.stats.max_dBm,    aw1.stats.max_dBm) && ...
          isequaln(base.stats.mean_dBm,   aw1.stats.mean_dBm);
    results = check(results, ok1, ...
        'T1: opt-in default off; raw percentileMaps + streaming aggregator post-hoc identical');

    % ---- T2: p = 1 reproduces the raw maps exactly ------------------
    p1Opts = baseOpts;
    p1Opts.activityWeightedCdf  = true;
    p1Opts.tddActivityFactor    = 1;
    p1Opts.networkLoadingFactor = 1;
    rp1 = runR23AasEirpCdfGrid(p1Opts);
    ok2 = abs(rp1.activityWeightedPercentileMaps.activeFraction - 1) < 1e-12 && ...
          isequaln(rp1.activityWeightedPercentileMaps.values, rp1.percentileMaps.values);
    results = check(results, ok2, ...
        'T2: p=1 -> activity-weighted values == raw percentileMaps values exactly');

    % ---- T3: ITU example tdd=0.75, load=0.25 -> p=0.1875 ------------
    r = runR23AasEirpCdfGrid(struct('aasGeometryPreset','r23_1x3_default', ...
        'numMc',60,'seed',7, ...
        'azGridDeg',-10:5:10,'elGridDeg',-10:5:5,'binEdgesDbm',-100:2:120, ...
        'percentiles',[5 50 81.25 95 99], ...
        'activityWeightedCdf',true,'tddActivityFactor',0.75,'networkLoadingFactor',0.25));
    AW = r.activityWeightedPercentileMaps;

    okFrac = abs(AW.activeFraction - 0.1875) < 1e-12;
    okPon  = max(abs(AW.onPercentileEquivalent - ...
        (100 - (100 - r.percentileMaps.percentiles)/0.1875))) < 1e-9;
    okMask = isequal(AW.inOnRegion, AW.onPercentileEquivalent > 0);

    onMask = AW.inOnRegion;
    exp = eirp_percentile_maps(r.stats, AW.onPercentileEquivalent(onMask));
    okRemap = isequaln(AW.values(:,:,onMask), exp.values);

    okOff = all(isinf(AW.values(:,:,~onMask)), 'all') && ...
            all(AW.values(:,:,~onMask) < 0, 'all');

    cutoff = 100 * (1 - AW.activeFraction);
    kCutoff = find(abs(AW.percentiles - cutoff) < 1e-12, 1);
    okBoundary = ~isempty(kCutoff) && ~AW.inOnRegion(kCutoff) && ...
        all(isinf(AW.values(:, :, kCutoff)), 'all') && ...
        all(AW.values(:, :, kCutoff) < 0, 'all');

    ok3 = okFrac && okPon && okMask && okRemap && okOff && okBoundary;
    results = check(results, ok3, sprintf( ...
        ['T3: ITU example p=0.1875 -> exact Pon remapping vs engine, ', ...
         'on/off mask, exact-boundary off floor, and -Inf off floor ', ...
         '(frac=%d Pon=%d mask=%d remap=%d off=%d boundary=%d)'], ...
        okFrac, okPon, okMask, okRemap, okOff, okBoundary));

    % ---- T4: peak preserved / not a flat dB shift -------------------
    k99 = find(r.percentileMaps.percentiles == 99, 1);
    aw99  = AW.values(:,:,k99);
    raw99 = r.percentileMaps.values(:,:,k99);
    finiteMask = isfinite(aw99) & isfinite(raw99);
    leqRaw = all(aw99(finiteMask) <= raw99(finiteMask) + 1e-9);
    % A genuine reshaping (lower-percentile remap), NOT a uniform dB offset
    % of the raw 99th: the activity-weighted 99th does not equal raw99 plus
    % any single constant across cells.
    flatShift = raw99(finiteMask) + 10*log10(AW.activeFraction);
    notFlat = ~isequaln(aw99(finiteMask), flatShift);
    ok4 = AW.inOnRegion(k99) && leqRaw && notFlat;
    results = check(results, ok4, ...
        'T4: on-region 99th <= raw 99th (within bin tol) and not a uniform dB offset');

    % ---- T5: geometry-agnostic active fraction + remapping ----------
    commonNv = {'numMc',60,'seed',7, ...
        'azGridDeg',-10:5:10,'elGridDeg',-10:5:5,'binEdgesDbm',-100:2:120, ...
        'percentiles',[5 50 95 99], ...
        'activityWeightedCdf',true,'tddActivityFactor',0.75,'networkLoadingFactor',0.25};
    rA = runR23AasEirpCdfGrid('aasGeometryPreset','r23_1x3_default', commonNv{:});
    rB = runR23AasEirpCdfGrid('aasGeometryPreset','ctia_7ghz_1x6',   commonNv{:});
    AWa = rA.activityWeightedPercentileMaps;
    AWb = rB.activityWeightedPercentileMaps;

    sameFrac = abs(AWa.activeFraction - AWb.activeFraction) < 1e-12;
    samePon  = isequal(AWa.onPercentileEquivalent, AWb.onPercentileEquivalent);
    expA = eirp_percentile_maps(rA.stats, AWa.onPercentileEquivalent(AWa.inOnRegion));
    expB = eirp_percentile_maps(rB.stats, AWb.onPercentileEquivalent(AWb.inOnRegion));
    remapA = isequaln(AWa.values(:,:,AWa.inOnRegion), expA.values);
    remapB = isequaln(AWb.values(:,:,AWb.inOnRegion), expB.values);
    ok5 = sameFrac && samePon && remapA && remapB;
    results = check(results, ok5, ...
        'T5: activeFraction + onPercentileEquivalent identical for R23 1x3 and CTIA 1x6; remap holds per-geometry');

    % ---- T6: validation of the activity factors ---------------------
    awBadId = 'runR23AasEirpCdfGrid:badActivityFactor';
    okZero    = throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
        struct('activityWeightedCdf',true,'tddActivityFactor',0))), awBadId);
    okTooBig  = throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
        struct('activityWeightedCdf',true,'networkLoadingFactor',1.5))), awBadId);
    okNeg     = throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
        struct('activityWeightedCdf',true,'tddActivityFactor',-0.1))), awBadId);
    ok6 = okZero && okTooBig && okNeg;
    results = check(results, ok6, ...
        'T6: tdd=0, load=1.5, tdd=-0.1 all throw runR23AasEirpCdfGrid:badActivityFactor');

    % ---- T7: activityModel='legacy' == omitting it (regression) -----
    % aw1 above used the default (omitted) activityModel with tdd=0.75,
    % load=0.25. An explicit activityModel='legacy' at the same factors
    % must reproduce the activity-weighted values byte-for-byte.
    legExplicit = awOpts1;
    legExplicit.activityModel = 'legacy';
    rLeg = runR23AasEirpCdfGrid(legExplicit);
    ok7 = isequaln(rLeg.activityWeightedPercentileMaps.values, ...
                   aw1.activityWeightedPercentileMaps.values) && ...
          strcmp(rLeg.activityWeightedPercentileMaps.activityModel, 'legacy') && ...
          abs(rLeg.activityWeightedPercentileMaps.activeFraction - 0.75*0.25) < 1e-12;
    results = check(results, ok7, ...
        'T7: activityModel=''legacy'' byte-identical to omitting it (regression)');

    % ---- T8: activityModel='frame' with SSB -> alphaUe + sweep floor -
    fOpts = baseOpts;
    fOpts.activityWeightedCdf = true;
    fOpts.activityModel       = 'frame';
    fOpts.ssb                 = struct();         % enable the always-on sweep
    rf  = runR23AasEirpCdfGrid(fOpts);
    AWf = rf.activityWeightedPercentileMaps;

    % p must equal the frame-budget alphaUe sourced from the SAME defaults:
    % frame.ssb.L <- realised sweep beam count, csirsUe.numUes <- numBeams.
    expBud = imtAasDlFrameTimeBudget(struct( ...
        'ssb',     struct('L', rf.ssb.numBeams), ...
        'csirsUe', struct('numUes', fOpts.numBeams)));
    okPf = abs(AWf.activeFraction - expBud.alphaUe) < 1e-12 && ...
           strcmp(AWf.activityModel, 'frame');

    offMaskF = ~AWf.inOnRegion;
    okHasOff = any(offMaskF);                      % [5 50] fall in the off region
    okFloor  = okHasOff;
    offIdx   = find(offMaskF);
    for kk = 1:numel(offIdx)
        okFloor = okFloor && isequaln(AWf.values(:, :, offIdx(kk)), rf.ssb.timeAvg_dBm);
    end
    % The off region radiates the (finite) sweep level, NOT -Inf.
    okNotInf = all(isfinite(rf.ssb.timeAvg_dBm(:))) && ...
               ~any(isinf(AWf.values(:, :, offMaskF)), 'all');
    % On-region remap still exact against the tested engine on the SAME stats.
    onMaskF = AWf.inOnRegion;
    expOnF  = eirp_percentile_maps(rf.stats, AWf.onPercentileEquivalent(onMaskF));
    okOnF   = isequaln(AWf.values(:, :, onMaskF), expOnF.values);
    ok8 = okPf && okFloor && okNotInf && okOnF;
    results = check(results, ok8, sprintf( ...
        ['T8: frame model p=alphaUe=%.4f; off-region == out.ssb.timeAvg_dBm (not -Inf) ', ...
         '(p=%d floor=%d notInf=%d on=%d)'], AWf.activeFraction, okPf, okFloor, okNotInf, okOnF));

    % ---- T9: activityModel='frame' with SSB disabled -> warn + fallback
    gOpts = baseOpts;
    gOpts.activityWeightedCdf = true;
    gOpts.activityModel       = 'frame';          % no opts.ssb -> no sweep floor
    okWarn = warnsId(@() runR23AasEirpCdfGrid(gOpts), ...
        'runR23AasEirpCdfGrid:activityFrameNoSweepFloor');

    wprev = warning('off', 'runR23AasEirpCdfGrid:activityFrameNoSweepFloor');
    rg = runR23AasEirpCdfGrid(gOpts);
    warning(wprev);
    AWg = rg.activityWeightedPercentileMaps;
    % Default frame budget still built (L defaults to the 8-beam sweep count).
    expBudG = imtAasDlFrameTimeBudget(struct( ...
        'ssb',     struct('L', 8), ...
        'csirsUe', struct('numUes', gOpts.numBeams)));
    okPg   = abs(AWg.activeFraction - expBudG.alphaUe) < 1e-12;
    okFall = all(isinf(AWg.values(:, :, ~AWg.inOnRegion)), 'all') && ...
             all(AWg.values(:, :, ~AWg.inOnRegion) < 0, 'all');
    ok9 = okWarn && okPg && okFall;
    results = check(results, ok9, sprintf( ...
        ['T9: frame model + no SSB -> activityFrameNoSweepFloor warning, ', ...
         'p=alphaUe=%.4f, scalar -Inf off floor (warn=%d p=%d fall=%d)'], ...
        AWg.activeFraction, okWarn, okPg, okFall));

    % ---- T10: validateActivityModel rejects a bad activityModel -----
    badModelId = 'runR23AasEirpCdfGrid:invalidActivityModel';
    ok10 = throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
            struct('activityWeightedCdf',true,'activityModel','bogus'))), badModelId) && ...
           throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
            struct('activityWeightedCdf',true,'activityModel',5))), badModelId);
    results = check(results, ok10, ...
        'T10: bad activityModel (out-of-set + non-char) throws runR23AasEirpCdfGrid:invalidActivityModel');

    % ---- T11: validateActivityOffFloorUses rejects a bad value ------
    badFloorId = 'runR23AasEirpCdfGrid:invalidActivityOffFloorUses';
    ok11 = throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
            struct('activityWeightedCdf',true,'activityOffFloorUses','bogus'))), badFloorId) && ...
           throwsId(@() runR23AasEirpCdfGrid(mergeOpts(baseOpts, ...
            struct('activityWeightedCdf',true,'activityOffFloorUses',5))), badFloorId);
    results = check(results, ok11, ...
        'T11: bad activityOffFloorUses (out-of-set + non-char) throws runR23AasEirpCdfGrid:invalidActivityOffFloorUses');

    fprintf('\n--- test_activity_weighted_cdf summary ---\n');
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

function tf = throwsId(fn, id)
%THROWSID True when FN throws an MException with identifier ID.
    tf = false;
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end

function tf = warnsId(fn, id)
%WARNSID True when FN raises the warning with identifier ID. The warning is
%   temporarily promoted to an error so detection is robust to any later
%   warnings overwriting lastwarn.
    tf = false;
    s = warning('error', id); %#ok<CTPCT>
    c = onCleanup(@() warning(s));
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end

function o = mergeOpts(base, extra)
%MERGEOPTS Shallow-merge EXTRA fields onto a copy of BASE.
    o = base;
    f = fieldnames(extra);
    for k = 1:numel(f)
        o.(f{k}) = extra.(f{k});
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end
