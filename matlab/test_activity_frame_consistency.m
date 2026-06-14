function results = test_activity_frame_consistency()
%TEST_ACTIVITY_FRAME_CONSISTENCY imtAasActivityFrameConsistency + warning.
%
%   RESULTS = test_activity_frame_consistency()
%
%   Covers the helper that reconciles the two time/activity mechanisms in
%   runR23AasEirpCdfGrid:
%       T1.  Defaults -> the frame-budget UE duty cycle alphaUe (~0.1407)
%            disagrees with the legacy p = tdd*load = 0.15 by ~0.009, which
%            exceeds the 1e-3 tolerance, so .consistent == false and
%            .deltaAlphaUe matches abs(alphaUe - p).
%       T2.  A tuned legacy p (= alphaUe) is reported .consistent == true.
%       T3.  imtAasActivityFrameConsistency input validation errors.
%       T4.  The legacy mismatch WARNING fires when BOTH the activity-
%            weighted CDF and the SSB sweep are enabled under the default
%            activityModel='legacy'.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    % ---- T1: defaults disagree (alphaUe ~0.1407 vs p 0.15) ----------
    frameCfg          = struct();
    frameCfg.ssb      = struct('L', 8);     % imtAasSsbOption default coarseConf [3 3 2]
    frameCfg.csirsUe  = struct('numUes', 3); % r23DefaultParams numUesPerSector
    budget  = imtAasDlFrameTimeBudget(frameCfg);
    pLegacy = 0.75 * 0.20;                   % default tdd*load = 0.15
    info    = imtAasActivityFrameConsistency(budget, pLegacy);

    okAlpha = abs(budget.alphaUe - 0.1407) < 1e-3;
    okDelta = abs(info.deltaAlphaUe - abs(budget.alphaUe - pLegacy)) < 1e-12 && ...
              abs(info.deltaAlphaUe - 0.009257) < 1e-3 && ...
              info.deltaAlphaUe > info.tolerance;
    okCons  = islogical(info.consistent) && info.consistent == false && ...
              abs(info.tolerance - 1e-3) < 1e-15 && ...
              abs(info.pLegacy - pLegacy) < 1e-15;
    ok1 = okAlpha && okDelta && okCons;
    results = check(results, ok1, sprintf( ...
        ['T1: defaults alphaUe=%.4f vs p=%.4f delta=%.4f -> consistent==false ', ...
         '(alpha=%d delta=%d cons=%d)'], ...
        budget.alphaUe, pLegacy, info.deltaAlphaUe, okAlpha, okDelta, okCons));

    % ---- T2: a tuned legacy p == alphaUe is consistent --------------
    info2 = imtAasActivityFrameConsistency(budget, budget.alphaUe);
    ok2 = info2.consistent == true && info2.deltaAlphaUe < info2.tolerance;
    results = check(results, ok2, ...
        'T2: pLegacy == alphaUe -> consistent==true');

    % ---- T3: input validation ---------------------------------------
    okBadBudget = throwsId(@() imtAasActivityFrameConsistency(struct('x',1), 0.15), ...
        'imtAasActivityFrameConsistency:badBudget');
    okBadP1 = throwsId(@() imtAasActivityFrameConsistency(budget, [0.1 0.2]), ...
        'imtAasActivityFrameConsistency:badPLegacy');
    okBadP2 = throwsId(@() imtAasActivityFrameConsistency(budget, Inf), ...
        'imtAasActivityFrameConsistency:badPLegacy');
    ok3 = okBadBudget && okBadP1 && okBadP2;
    results = check(results, ok3, ...
        'T3: bad budget / non-scalar p / non-finite p all throw the specific ids');

    % ---- T4: legacy mismatch warning fires with both layers on ------
    opts = struct();
    opts.numMc       = 8;
    opts.azGridDeg   = -10:10:10;          % 3
    opts.elGridDeg   = -10:5:5;            % 4
    opts.binEdgesDbm = -100:5:120;
    opts.percentiles = [50 95];
    opts.seed        = 3;
    opts.numBeams    = 3;
    opts.activityWeightedCdf = true;       % default activityModel = 'legacy'
    opts.ssb         = struct();           % enable the SSB sweep too
    okWarn = warnsId(@() runR23AasEirpCdfGrid(opts), ...
        'runR23AasEirpCdfGrid:activityModelMismatch');
    results = check(results, okWarn, ...
        'T4: activityModel=legacy + opts.ssb -> activityModelMismatch warning fires');

    fprintf('\n--- test_activity_frame_consistency summary ---\n');
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
%   temporarily promoted to an error so detection is independent of any
%   later warnings overwriting lastwarn.
    tf = false;
    s = warning('error', id); %#ok<CTPCT>
    c = onCleanup(@() warning(s));
    try
        fn();
    catch err
        tf = strcmp(err.identifier, id);
    end
end

function s = ifElse(cond, a, b)
    if cond, s = a; else, s = b; end
end
