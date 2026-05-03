function results = test_runtime_scaling_controls()
%TEST_RUNTIME_SCALING_CONTROLS Tests for the runtime / memory / chunking
%controls.
%
%   RESULTS = test_runtime_scaling_controls()
%
%   Coverage:
%       S1. estimate_aas_mc_memory returns positive finite estimates
%       S2. raw cube warning fires when numMc * cells * 8 bytes exceeds
%           the configurable threshold
%       S3. profile_aas_monte_carlo_runtime runs a tiny benchmark without
%           error and reports a positive seconds-per-draw value
%       S4. chunked and unchunked runs with the same seed produce
%           bit-identical streaming statistics (counts, sums, min, max)
%       S5. opts.seed produces repeatable streaming results between two
%           independent calls (reproducibility)
%       S6. opts.progressEvery = 0 disables progress output (no stdout)
%       S7. opts.progressEvery > 0 emits at least one progress line
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    cfg = baseCfg();

    % ---------------- S1. memory estimator basic sanity ----------------
    out = estimate_aas_mc_memory(361, 181, 170, 'uint32');
    fields = {'histCountsBytes', 'streamingSumsBytes', ...
              'percentileTableBytes', 'csvBytes', ...
              'rawCubeBytesPerDraw', 'totalRunningBytes'};
    okFields = true;
    for k = 1:numel(fields)
        v = out.(fields{k});
        if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v > 0)
            okFields = false;
            break;
        end
    end
    results = check(results, okFields, ...
        'estimate_aas_mc_memory: all main byte estimates positive & finite');

    % --- S1b. countType selection scales counts memory linearly --------
    o32 = estimate_aas_mc_memory(50, 50, 100, 'uint32');
    o64 = estimate_aas_mc_memory(50, 50, 100, 'uint64');
    results = check(results, ...
        abs(o64.histCountsBytes - 2 * o32.histCountsBytes) < 1, ...
        'memory estimator: uint64 counts use exactly 2x the bytes of uint32');

    % --- S1c. invalid countType errors clearly --------------------------
    threw = false;
    try
        estimate_aas_mc_memory(10, 10, 10, 'foobar');
    catch
        threw = true;
    end
    results = check(results, threw, ...
        'memory estimator: rejects unknown countType');

    % ---------------- S2. raw cube warning threshold -------------------
    smallOpts = struct('numMc', 10, ...
        'rawCubeWarnThresholdBytes', 1e15);
    smallEst = estimate_aas_mc_memory(20, 20, 50, 'uint32', smallOpts);

    bigOpts = struct('numMc', 1e5, ...
        'rawCubeWarnThresholdBytes', 1024);
    bigEst = estimate_aas_mc_memory(20, 20, 50, 'uint32', bigOpts);

    okWarn = ~smallEst.rawCubeWarning && bigEst.rawCubeWarning;
    results = check(results, okWarn, ...
        'raw cube warning: triggers when raw bytes exceed threshold, otherwise quiet');

    % ---------------- S3. profiler smoke test --------------------------
    profOpts = struct();
    profOpts.cases   = {'small'};
    profOpts.cfg     = miniCfg();      % 2x2 array -> very fast
    profOpts.verbose = false;
    profOpts.quiet   = true;
    threwProf = false;
    profOut = struct();
    try
        profOut = profile_aas_monte_carlo_runtime(profOpts);
    catch err
        threwProf = true;
        profErr = err.message; %#ok<NASGU>
    end
    okProf = ~threwProf ...
        && isfield(profOut, 'cases') ...
        && profOut.cases(1).secondsPerDraw > 0 ...
        && isfield(profOut, 'extrapolation') ...
        && profOut.extrapolation.numMc1e3 > 0;
    results = check(results, okProf, ...
        'profile_aas_monte_carlo_runtime: small case runs and reports timings');

    % ---------------- S4. chunked vs unchunked equivalence -------------
    mcOpts = baseMcOpts();
    mcOpts.numMc       = 25;
    mcOpts.seed        = 1234;
    mcOpts.beamSampler = struct('mode','uniform', ...
        'azim_range', [-30 30], 'elev_range', [-10 0], 'numBeams', 1);

    sUnchunk = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    chunkOpts = mcOpts;
    chunkOpts.mcChunkSize = 7;        % does not divide 25 evenly on purpose
    sChunk   = run_imt_aas_eirp_monte_carlo(cfg, chunkOpts);

    eqCounts = isequal(sUnchunk.counts,     sChunk.counts);
    eqSum    = isequaln(sUnchunk.sum_lin_mW, sChunk.sum_lin_mW);
    eqMin    = isequaln(sUnchunk.min_dBm,    sChunk.min_dBm);
    eqMax    = isequaln(sUnchunk.max_dBm,    sChunk.max_dBm);
    eqN      = sUnchunk.numMc == sChunk.numMc;

    results = check(results, ...
        eqCounts && eqSum && eqMin && eqMax && eqN, ...
        sprintf(['chunked (chunk=%d) and unchunked (numMc=%d) runs ' ...
                 'produce identical streaming stats with the same seed'], ...
                chunkOpts.mcChunkSize, mcOpts.numMc));

    % ---------------- S5. seed reproducibility -------------------------
    s1 = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
    s2 = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);
    results = check(results, ...
        isequal(s1.counts, s2.counts) ...
        && isequaln(s1.sum_lin_mW, s2.sum_lin_mW), ...
        'opts.seed: identical seeds produce identical stats across two runs');

    % --- 5b. different seeds -> different stats ------------------------
    optsA = mcOpts; optsA.seed = 1;
    optsB = mcOpts; optsB.seed = 2;
    sA = run_imt_aas_eirp_monte_carlo(cfg, optsA);
    sB = run_imt_aas_eirp_monte_carlo(cfg, optsB);
    results = check(results, ...
        ~isequal(sA.counts, sB.counts), ...
        'opts.seed: different seeds produce different streaming counts');

    % ---------------- S6. progressEvery = 0 stays quiet ---------------
    quietOpts = mcOpts;
    quietOpts.progressEvery = 0;
    quietOpts.numMc         = 5;
    quietText = capturedRun(cfg, quietOpts);
    results = check(results, ~contains(quietText, '[MC]'), ...
        'progressEvery=0: no [MC] progress lines emitted');

    % --- S6b. progressEvery > 0 emits at least one line ----------------
    loudOpts = mcOpts;
    loudOpts.progressEvery = 1;
    loudOpts.numMc         = 3;
    loudText = capturedRun(cfg, loudOpts);
    results = check(results, contains(loudText, '[MC]') ...
        && contains(loudText, 'ETA='), ...
        'progressEvery>0: prints [MC] lines with elapsed/ETA fields');

    fprintf('\n--- test_runtime_scaling_controls summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    if results.passed
        fprintf('  ALL TESTS PASSED\n');
    else
        fprintf('  TESTS FAILED\n');
    end
end

% ----------------------------------------------------------------------
function r = check(r, cond, msg)
    if cond
        r.summary{end+1} = ['PASS  ' msg];
    else
        r.summary{end+1} = ['FAIL  ' msg];
        r.passed = false;
    end
end

% ----------------------------------------------------------------------
function cfg = baseCfg()
    cfg = struct();
    cfg.G_Emax        = 5;
    cfg.A_m           = 30;
    cfg.SLA_nu        = 30;
    cfg.phi_3db       = 65;
    cfg.theta_3db     = 65;
    cfg.d_H           = 0.5;
    cfg.d_V           = 0.5;
    cfg.N_H           = 4;
    cfg.N_V           = 4;
    cfg.rho           = 1;
    cfg.k             = 12;
    cfg.txPower_dBm   = 40;
    cfg.feederLoss_dB = 3;
end

% ----------------------------------------------------------------------
function cfg = miniCfg()
    cfg = baseCfg();
    cfg.N_H = 2;
    cfg.N_V = 2;
end

% ----------------------------------------------------------------------
function mc = baseMcOpts()
    mc = struct();
    mc.numMc       = 20;
    mc.azGrid      = -30:5:30;
    mc.elGrid      = -20:5:10;
    mc.binEdges    = -50:1:120;
    mc.beamSampler = struct('mode','uniform', ...
        'azim_range', [-30 30], 'elev_range', [-10 0], 'numBeams', 1);
end

% ----------------------------------------------------------------------
function out = capturedRun(cfg, mcOpts)
    % Capture stdout from a single MC run by redirecting via evalc.
    out = evalc('run_imt_aas_eirp_monte_carlo(cfg, mcOpts);');
end
