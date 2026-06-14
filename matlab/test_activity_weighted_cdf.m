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
%   eirp_percentile_maps); off-region percentiles (Pon < 0) take the off
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
        'percentiles',[5 50 95 99], ...
        'activityWeightedCdf',true,'tddActivityFactor',0.75,'networkLoadingFactor',0.25));
    AW = r.activityWeightedPercentileMaps;

    okFrac = abs(AW.activeFraction - 0.1875) < 1e-12;
    okPon  = max(abs(AW.onPercentileEquivalent - ...
        (100 - (100 - r.percentileMaps.percentiles)/0.1875))) < 1e-9;
    okMask = isequal(AW.inOnRegion, AW.onPercentileEquivalent >= 0);

    onMask = AW.inOnRegion;
    exp = eirp_percentile_maps(r.stats, AW.onPercentileEquivalent(onMask));
    okRemap = isequaln(AW.values(:,:,onMask), exp.values);

    okOff = all(isinf(AW.values(:,:,~onMask)), 'all') && ...
            all(AW.values(:,:,~onMask) < 0, 'all');

    ok3 = okFrac && okPon && okMask && okRemap && okOff;
    results = check(results, ok3, sprintf( ...
        ['T3: ITU example p=0.1875 -> exact Pon remapping vs engine, ', ...
         'on/off mask, and -Inf off floor (frac=%d Pon=%d mask=%d remap=%d off=%d)'], ...
        okFrac, okPon, okMask, okRemap, okOff));

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
