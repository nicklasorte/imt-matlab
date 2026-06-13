function results = test_imtAasDlFrameTimeBudget()
%TEST_IMTAASDLFRAMETIMEBUDGET Self tests for the TS 38.214 DL time budget.
%
%   RESULTS = test_imtAasDlFrameTimeBudget()
%
%   Covers (defaults: 30 kHz, TDD DDDSU [3,10,1,period 5], load 0.20,
%   ssb.L = 8):
%       T1.  Per-term breakdown alphas match the hand-computed reference
%            (ssb 0.0571, sib 0.0214, pdcchCss 0.0114, trs 0.0071,
%            csirsUe 0.0054, pdcchUss 0.0091, pdsch 0.1262).
%       T2.  Class alphas: alphaSweep 0.0971, alphaUe 0.1407,
%            alphaIdle 0.7621; they sum to exactly 1.
%       T3.  frame.dlSymbolFraction 0.7429; dwell.ssbBeam_us ~143;
%            dwell.pdschAlloc_us (L=12) ~429.
%       T4.  Calling with all-default cfg reproduces the explicit cfg.
%       T5.  alphaUe scales ~linearly with loadFactor while alphaSweep is
%            load-independent.
%       T6.  pdsch.L=15 (Type A) raises a length warning; L=12 does not.
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    tol = 1e-3;
    b   = imtAasDlFrameTimeBudget(defaultFrameCfg());

    % ---- T1: per-term breakdown ----
    results = check(results, abs(b.breakdown.ssb.alpha      - 0.0571) < tol, 'T1: breakdown.ssb.alpha   ~ 0.0571');
    results = check(results, abs(b.breakdown.sib.alpha      - 0.0214) < tol, 'T1: breakdown.sib.alpha   ~ 0.0214');
    results = check(results, abs(b.breakdown.pdcchCss.alpha - 0.0114) < tol, 'T1: breakdown.pdcchCss    ~ 0.0114');
    results = check(results, abs(b.breakdown.trs.alpha      - 0.0071) < tol, 'T1: breakdown.trs.alpha   ~ 0.0071');
    results = check(results, abs(b.breakdown.csirsUe.alpha  - 0.0054) < tol, 'T1: breakdown.csirsUe     ~ 0.0054');
    results = check(results, abs(b.breakdown.pdcchUss.alpha - 0.0091) < tol, 'T1: breakdown.pdcchUss    ~ 0.0091');
    results = check(results, abs(b.breakdown.pdsch.alpha    - 0.1262) < tol, 'T1: breakdown.pdsch.alpha ~ 0.1262');

    % ---- T2: class alphas + partition ----
    results = check(results, abs(b.alphaSweep - 0.0971) < tol, 'T2: alphaSweep ~ 0.0971');
    results = check(results, abs(b.alphaUe    - 0.1407) < tol, 'T2: alphaUe    ~ 0.1407');
    results = check(results, abs(b.alphaIdle  - 0.7621) < tol, 'T2: alphaIdle  ~ 0.7621');
    results = check(results, abs(b.alphaSweep + b.alphaUe + b.alphaIdle - 1) < 1e-12, ...
        'T2: alphaSweep + alphaUe + alphaIdle == 1');

    % ---- T3: frame + dwell ----
    results = check(results, abs(b.frame.dlSymbolFraction - 0.7429) < tol, ...
        'T3: frame.dlSymbolFraction ~ 0.7429');
    results = check(results, abs(b.dwell.ssbBeam_us    - 4  / 28000 * 1e6) < 1e-6, ...
        'T3: dwell.ssbBeam_us ~ 143 us');
    results = check(results, abs(b.dwell.pdschAlloc_us - 12 / 28000 * 1e6) < 1e-6, ...
        'T3: dwell.pdschAlloc_us (L=12) ~ 429 us');

    % ---- T4: defaults reproduce the explicit cfg ----
    bDef = imtAasDlFrameTimeBudget(struct());
    okDef = abs(bDef.alphaSweep - b.alphaSweep) < 1e-12 && ...
            abs(bDef.alphaUe    - b.alphaUe)    < 1e-12 && ...
            abs(bDef.alphaIdle  - b.alphaIdle)  < 1e-12;
    results = check(results, okDef, 'T4: all-default cfg reproduces the explicit reference cfg');

    % ---- T5: load scaling ----
    results = t_load_scaling(results);

    % ---- T6: pdsch.L validation warning ----
    results = t_pdsch_length_warning(results);

    fprintf('\n--- test_imtAasDlFrameTimeBudget summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, 'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% T5: alphaUe ~linear in loadFactor; alphaSweep load-independent
% =====================================================================
function r = t_load_scaling(r)
    c1 = defaultFrameCfg(); c1.loadFactor = 0.10;
    c2 = defaultFrameCfg(); c2.loadFactor = 0.20;
    c3 = defaultFrameCfg(); c3.loadFactor = 0.30;
    b1 = imtAasDlFrameTimeBudget(c1);
    b2 = imtAasDlFrameTimeBudget(c2);
    b3 = imtAasDlFrameTimeBudget(c3);

    okSweep = abs(b1.alphaSweep - b2.alphaSweep) < 1e-12 && ...
              abs(b2.alphaSweep - b3.alphaSweep) < 1e-12;
    r = check(r, okSweep, 'T5: alphaSweep is load-independent');

    okMono = b1.alphaUe < b2.alphaUe && b2.alphaUe < b3.alphaUe;
    r = check(r, okMono, 'T5: alphaUe increases monotonically with loadFactor');

    % near-linear: the load=0.2 point sits close to the 0.1/0.3 midpoint.
    linMid = 0.5 * (b1.alphaUe + b3.alphaUe);
    r = check(r, abs(b2.alphaUe - linMid) < 5e-3, ...
        'T5: alphaUe ~ linear in loadFactor (within 5e-3 of midpoint)');
end

% =====================================================================
% T6: pdsch.L outside Table 5.1.2.1-1 raises a warning
% =====================================================================
function r = t_pdsch_length_warning(r)
    warnId = 'imtAasDlFrameTimeBudget:pdschLengthOutOfRange';

    % L = 15 (Type A valid range 3..14) must warn. Let the warning fire so
    % lastwarn reliably captures it (console noise is acceptable in tests).
    lastwarn('', '');
    cfg15 = defaultFrameCfg(); cfg15.pdsch = struct('mappingType', 'A', 'L', 15);
    imtAasDlFrameTimeBudget(cfg15);
    [~, id15] = lastwarn();
    r = check(r, strcmp(id15, warnId), 'T6: pdsch.L=15 (Type A) raises length warning');

    % L = 12 must NOT warn.
    lastwarn('', '');
    cfg12 = defaultFrameCfg(); cfg12.pdsch = struct('mappingType', 'A', 'L', 12);
    imtAasDlFrameTimeBudget(cfg12);
    [~, id12] = lastwarn();
    r = check(r, isempty(id12), 'T6: pdsch.L=12 (Type A) raises no warning');
end

% =====================================================================
% Helpers
% =====================================================================
function cfg = defaultFrameCfg()
%DEFAULTFRAMECFG The headline 30 kHz DDDSU reference cfg (matches defaults).
    cfg = struct();
    cfg.scs_kHz       = 30;
    cfg.loadFactor    = 0.20;
    cfg.tdd           = struct('dlSlots', 3, 'specialDlSymbols', 10, ...
                               'ulSlots', 1, 'periodSlots', 5);
    cfg.ssb           = struct('L', 8, 'symbolsPerBlock', 4, 'period_ms', 20);
    cfg.sib           = struct('enable', true, 'symbolsPerSsbPeriod', 12);
    cfg.pdcch         = struct('coresetSymbols', 1, 'broadcastShare', 0.2);
    cfg.trs           = struct('enable', true, 'numSets', 1, 'symbolsPerSet', 4, ...
                               'period_ms', 20, 'mapClass', 'sweep');
    cfg.csirsUe       = struct('enable', true, 'numUes', 3, 'symbolsPerUe', 1, ...
                               'period_slots', 40);
    cfg.csirsBeamMgmt = struct('enable', false, 'symbolsPerPeriod', 8, 'period_ms', 20);
    cfg.prs           = struct('enable', false, 'symbolsPerPeriod', 0, 'period_slots', 320);
    cfg.pdsch         = struct('mappingType', 'A', 'L', 12);
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
