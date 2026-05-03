function results = test_r23_mvp_runtime_memory_guardrails()
%TEST_R23_MVP_RUNTIME_MEMORY_GUARDRAILS Tests for the R23 MVP cube guard.
%
%   RESULTS = test_r23_mvp_runtime_memory_guardrails()
%
%   Pins the lightweight runtime/memory safety checks added on top of the
%   R23 single-sector full-cube Monte Carlo path
%   (run_monte_carlo_snapshots + estimate_r23_mvp_cube_memory). The guard
%   is intentionally narrow: it sizes the Naz x Nel x numSnapshots double
%   cube before allocating it and fails closed when the estimate exceeds
%   simConfig.maxCubeMiB.
%
%   Coverage:
%       G1. Small MVP run still passes through the guard with default
%           thresholds (no behaviour change).
%       G2. estimate_r23_mvp_cube_memory returns the expected dimensions
%           and positive MiB values; eirpCubeBytes matches
%           Naz * Nel * numSnapshots * 8 exactly.
%       G3. An artificially tiny simConfig.maxCubeMiB causes
%           run_monte_carlo_snapshots to fail closed with a clear error
%           id (run_monte_carlo_snapshots:cubeTooLarge) and a message
%           that points the user at the right escape hatch.
%       G4. simConfig.allowLargeCube = true bypasses the guard for a
%           small synthetic case (the run completes and returns the
%           usual eirpGrid).
%       G5. The guard is purely about cube memory: the guardrail and
%           estimator do not introduce any path-loss / clutter / FS-FSS
%           / interference-aggregation tokens (scope guard).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    results = g1_small_mvp_passes(results);
    results = g2_estimator_dimensions(results);
    results = g3_tiny_threshold_fails_closed(results);
    results = g4_allow_large_cube_bypass(results);
    results = g5_no_scope_creep(results);

    fprintf('\n--- test_r23_mvp_runtime_memory_guardrails summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function r = g1_small_mvp_passes(r)
%G1 Small MVP run completes through the guard with default thresholds.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    grid = struct('azGridDeg', -30:15:30, 'elGridDeg', -10:5:5);
    cfg  = struct('numSnapshots', 5, 'numUes', 3, 'seed', 1);

    out = run_monte_carlo_snapshots(bs, grid, p, cfg);

    Naz = numel(grid.azGridDeg);
    Nel = numel(grid.elGridDeg);
    okShape = isequal(size(out.eirpGrid), [Naz, Nel, 5]);
    okMem   = isfield(out, 'memoryEstimate') && ...
              isstruct(out.memoryEstimate) && ...
              isfield(out.memoryEstimate, 'estimatedTotalMiB') && ...
              out.memoryEstimate.estimatedTotalMiB > 0 && ...
              out.memoryEstimate.estimatedTotalMiB < 256;
    okGuard = isfield(out, 'maxCubeMiB') && abs(out.maxCubeMiB - 256) < eps;

    r = check(r, okShape && okMem && okGuard, sprintf( ...
        ['G1: small MVP run passes guard (estimatedTotalMiB = %.6f); '...
         'eirpGrid shape = [Naz, Nel, numSnapshots]'], ...
         out.memoryEstimate.estimatedTotalMiB));
end

% =====================================================================
function r = g2_estimator_dimensions(r)
%G2 Estimator returns expected dimensions and positive MiB values.
    Naz   = 37;
    Nel   = 9;
    nSnap = 100;
    est   = estimate_r23_mvp_cube_memory(Naz, Nel, nSnap);

    okFields = isstruct(est) && all(isfield(est, { ...
        'numGridAz', 'numGridEl', 'numSnapshots', 'numCells', ...
        'eirpCubeBytes', 'eirpCubeMiB', 'estimatedTotalMiB', ...
        'isLarge', 'warningMessage'}));

    okDims = est.numGridAz == Naz && est.numGridEl == Nel && ...
             est.numSnapshots == nSnap && ...
             est.numCells == Naz * Nel;

    expectedCubeBytes = double(Naz) * double(Nel) * double(nSnap) * 8;
    okBytes = abs(est.eirpCubeBytes - expectedCubeBytes) < 1;

    okPositive = est.eirpCubeMiB > 0 && est.estimatedTotalMiB > 0 && ...
                 est.estimatedTotalMiB >= est.eirpCubeMiB;

    okSmallNotLarge = ~est.isLarge && isempty(est.warningMessage);

    % Force a "large" estimate by lowering the threshold and confirm the
    % warning string is non-empty and mentions the streaming workflow.
    estLarge = estimate_r23_mvp_cube_memory(Naz, Nel, nSnap, ...
        struct('largeThresholdMiB', 1e-9));
    okLargeFlag = estLarge.isLarge && ~isempty(estLarge.warningMessage) && ...
        contains(lower(estLarge.warningMessage), 'streaming');

    r = check(r, okFields && okDims && okBytes && okPositive && ...
                 okSmallNotLarge && okLargeFlag, sprintf( ...
        ['G2: estimator dims (%dx%dx%d -> %d cells), eirpCubeBytes = %.0f, '...
         'estimatedTotalMiB = %.6f, isLarge correctly toggles'], ...
         Naz, Nel, nSnap, est.numCells, est.eirpCubeBytes, ...
         est.estimatedTotalMiB));
end

% =====================================================================
function r = g3_tiny_threshold_fails_closed(r)
%G3 Tiny maxCubeMiB causes run_monte_carlo_snapshots to fail closed.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    grid = struct('azGridDeg', -30:15:30, 'elGridDeg', -10:5:5);
    cfg  = struct('numSnapshots', 5, 'numUes', 3, 'seed', 1, ...
                  'maxCubeMiB', 1e-9);   % well below any real cube

    threw   = false;
    errId   = '';
    errMsg  = '';
    try
        run_monte_carlo_snapshots(bs, grid, p, cfg);
    catch err
        threw  = true;
        errId  = err.identifier;
        errMsg = err.message;
    end

    okThrew = threw;
    okId    = strcmp(errId, 'run_monte_carlo_snapshots:cubeTooLarge');
    msgLow  = lower(errMsg);
    % Message must guide the user toward the escape hatches: smaller
    % grid / smaller numSnapshots OR the streaming workflow.
    okMsg = contains(msgLow, 'maxcubemib') && ...
            (contains(msgLow, 'reduce') || contains(msgLow, 'snapshot')) && ...
            (contains(msgLow, 'streaming') || ...
             contains(msgLow, 'runr23aaseirpcdfgrid'));

    r = check(r, okThrew && okId && okMsg, sprintf( ...
        ['G3: tiny maxCubeMiB fails closed (id="%s"); message guides '...
         'user to reduce or stream'], errId));
end

% =====================================================================
function r = g4_allow_large_cube_bypass(r)
%G4 allowLargeCube = true bypasses the guard for a small synthetic case.
    bs   = get_default_bs();
    p    = get_r23_aas_params();
    grid = struct('azGridDeg', -30:15:30, 'elGridDeg', -10:5:5);
    cfg  = struct('numSnapshots', 5, 'numUes', 3, 'seed', 1, ...
                  'maxCubeMiB',     1e-9, ...
                  'allowLargeCube', true);

    threw = false;
    out   = struct();
    try
        out = run_monte_carlo_snapshots(bs, grid, p, cfg);
    catch err
        threw = true; %#ok<NASGU>
    end

    Naz = numel(grid.azGridDeg);
    Nel = numel(grid.elGridDeg);

    okRan         = ~threw && isstruct(out) && isfield(out, 'eirpGrid');
    okShape       = okRan && isequal(size(out.eirpGrid), [Naz, Nel, 5]);
    okFlag        = okRan && isfield(out, 'allowLargeCube') && ...
                    logical(out.allowLargeCube) == true;
    okMemEstFlag  = okRan && isfield(out, 'memoryEstimate') && ...
                    out.memoryEstimate.isLarge == true;

    r = check(r, okRan && okShape && okFlag && okMemEstFlag, ...
        'G4: allowLargeCube=true bypasses the guard and returns a normal eirpGrid');
end

% =====================================================================
function r = g5_no_scope_creep(r)
%G5 New estimator surface introduces no out-of-scope tokens.
%   The guard is purely a memory safety check on top of the existing
%   R23 single-sector MVP. It must NOT smuggle in path-loss, clutter,
%   FS / FSS receiver, interference aggregation, or 19-site / 57-sector
%   modeling - those are explicit non-goals of this MVP and live (or
%   will live) in dedicated modules outside this guardrail pass.
%
%   Only the new estimator file is scanned here. run_monte_carlo_snapshots.m
%   is already covered by test_r23_mvp_acceptance_contract:c6_scope_guard.
%   Scanning this test's own source would yield false positives because
%   the forbidden-token list is spelled out in the source below.

    files = {'estimate_r23_mvp_cube_memory.m'};

    % Forbidden tokens (lower case; matched as case-insensitive substrings).
    forbidden = { ...
        'p2001', ...
        'p2108', ...
        'pathloss', ...
        'clutterloss', ...
        'fsreceiver', ...
        'fssreceiver', ...
        'victimreceiver', ...
        'interferenceaggregation', ...
        'nineteensite', ...
        'fiftysevensector'};

    here = fileparts(mfilename('fullpath'));
    okScope = true;
    badHits = {};
    for i = 1:numel(files)
        fpath = fullfile(here, files{i});
        if exist(fpath, 'file') ~= 2
            okScope = false;
            badHits{end+1} = sprintf('%s: file missing', files{i}); %#ok<AGROW>
            continue;
        end
        txt = lower(fileread(fpath));
        for j = 1:numel(forbidden)
            if ~isempty(strfind(txt, forbidden{j})) %#ok<STREMP>
                okScope = false;
                badHits{end+1} = sprintf('%s:%s', ...
                    files{i}, forbidden{j}); %#ok<AGROW>
            end
        end
    end

    if okScope
        msg = sprintf( ...
            'G5: scope guard clean across %d new guardrail file(s)', ...
            numel(files));
    else
        msg = sprintf('G5: scope guard hits: %s', ...
            strjoin(badHits, ' | '));
    end
    r = check(r, okScope, msg);
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
