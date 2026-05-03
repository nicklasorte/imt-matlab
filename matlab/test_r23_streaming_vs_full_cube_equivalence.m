function results = test_r23_streaming_vs_full_cube_equivalence()
%TEST_R23_STREAMING_VS_FULL_CUBE_EQUIVALENCE Cross-check streaming vs full-cube R23 paths.
%
%   RESULTS = test_r23_streaming_vs_full_cube_equivalence()
%
%   The R23 single-sector EIRP CDF MVP exposes two parallel runners that
%   must agree on a small validation case:
%
%     full-cube path : run_monte_carlo_snapshots
%                      -> sample_ue_positions_in_sector
%                      -> compute_eirp_grid
%                      -> compute_cdf_per_grid_point
%       Returns the full Naz x Nel x numSnapshots EIRP cube. Used for
%       small validation runs (e.g. the MVP acceptance contract).
%
%     streaming path : runR23AasEirpCdfGrid
%                      -> imtAasGenerateBeamSet
%                      -> imtAasSectorEirpGridFromBeams
%                      -> update_eirp_histograms
%                      -> eirp_percentile_maps
%       Never materialises the per-draw EIRP cube. Used for larger runs.
%
%   Both paths share the same antenna primitives (imtAasEirpGrid) and the
%   same UE sampler (imtAasSampleUePositions); the BS height, sector
%   coverage, sector EIRP, and steering envelope all line up between
%   get_default_bs / get_r23_aas_params and
%   imtAasSingleSectorParams('macroUrban') / imtAasDefaultParams.
%
%   This test exercises a small deterministic case and verifies:
%       E1.  Metadata / shape consistency (grid, numBeams, sectorEirp,
%            splitSectorPower) between the two runners.
%       E2.  Linear-mW mean EIRP maps agree within a broad tolerance.
%            Both runners SHOULD produce bit-equivalent EIRP cubes when
%            seeded the same (same RNG stream, same antenna math, same
%            clamp envelope) so this is normally an exact-match check;
%            we keep the tolerance broad in case the two beam-sampling
%            wrappers diverge in the future. See the in-test TODO note.
%       E3.  Selected percentile maps from the two paths agree within a
%            tolerance tied to the streaming-path histogram bin width
%            (the streaming path returns bin midpoints, the full-cube
%            path interpolates raw sorted EIRP values).
%       E4.  Outputs are finite and the right shape on both sides.
%       E5.  Power-budget invariants are preserved (perBeamPeakEirpDbm
%            and sectorEirpDbm match between the two paths).
%
%   Returns struct with .passed (logical) and .summary (cellstr).

    results.summary = {};
    results.passed  = true;

    % --- Small deterministic case (kept tiny to keep run_all_tests fast) ---
    cfg = struct();
    cfg.azGrid       = -30:10:30;        % 7
    cfg.elGrid       = -10:5:10;         % 5
    cfg.numDraws     = 10;
    cfg.numBeams     = 3;
    cfg.seed         = 42;
    cfg.splitSectorPower = true;
    % 1 dB bins, range chosen wide enough that the smallest-bin midpoint
    % cannot drift more than half a bin from the raw EIRP value (deep
    % array-factor nulls can drop well below -100 dBm; we keep a generous
    % floor so percentiles do not clip into the lowest bin and break the
    % bin-width comparison in E3).
    cfg.binEdgesDbm  = -300:1:120;
    cfg.percentiles  = [10 50 90];

    % Run both paths once up front. Subsequent tests reuse these results.
    [resCube, resStream] = run_both_paths(cfg);

    results = e1_metadata(results, cfg, resCube, resStream);
    results = e2_mean_match(results, cfg, resCube, resStream);
    results = e3_percentile_match(results, cfg, resCube, resStream);
    results = e4_finite_and_shape(results, cfg, resCube, resStream);
    results = e5_power_budget(results, resCube, resStream);

    fprintf('\n--- test_r23_streaming_vs_full_cube_equivalence summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
% Driver
% =====================================================================

function [resCube, resStream] = run_both_paths(cfg)
%RUN_BOTH_PATHS Run the full-cube and streaming runners on a matched case.
%
%   The two runners must see matched inputs:
%     - full-cube path uses get_default_bs (urban macro, 18 m, 78.3 dBm)
%       which generate_single_sector_layout resolves to the same urban
%       macro layout that imtAasSingleSectorParams('macroUrban') exposes
%       to the streaming path.
%     - both paths default to splitSectorPower = true.
%     - both paths default to numBeams / numUes = 3 (params.numUesPerSector).
%     - both paths share the same RNG seeding contract: rng(seed) is
%       called once at the start, then imtAasSampleUePositions is invoked
%       once per draw with no per-call seed, advancing the global stream.

    bs   = get_default_bs();
    par  = get_r23_aas_params();
    grid = struct( ...
        'azGridDeg', cfg.azGrid, ...
        'elGridDeg', cfg.elGrid);

    cubeCfg = struct( ...
        'numSnapshots',     cfg.numDraws, ...
        'numUes',           cfg.numBeams, ...
        'seed',             cfg.seed, ...
        'splitSectorPower', cfg.splitSectorPower, ...
        'progressEvery',    0);
    resCube = run_monte_carlo_snapshots(bs, grid, par, cubeCfg);

    streamOpts = struct( ...
        'numMc',            cfg.numDraws, ...
        'azGridDeg',        cfg.azGrid, ...
        'elGridDeg',        cfg.elGrid, ...
        'binEdgesDbm',      cfg.binEdgesDbm, ...
        'percentiles',      cfg.percentiles, ...
        'seed',             cfg.seed, ...
        'deployment',       'macroUrban', ...
        'numBeams',         cfg.numBeams, ...
        'splitSectorPower', cfg.splitSectorPower, ...
        'progressEvery',    0);
    resStream = runR23AasEirpCdfGrid(streamOpts);
end

% =====================================================================
% E1 :: metadata + grid agreement
% =====================================================================

function r = e1_metadata(r, cfg, resCube, resStream)
    okAz = isequal(double(resCube.azGridDeg(:).'), ...
                   double(resStream.stats.azGrid(:).'));
    okEl = isequal(double(resCube.elGridDeg(:).'), ...
                   double(resStream.stats.elGrid(:).'));
    okNumDraws = (resCube.numSnapshots == cfg.numDraws) && ...
                 (resStream.stats.numMc   == cfg.numDraws);
    okNumBeams = (resCube.numUes == cfg.numBeams) && ...
                 (resStream.stats.numBeams == cfg.numBeams);
    okSplit    = (logical(resCube.splitSectorPower) == cfg.splitSectorPower) && ...
                 (logical(resStream.stats.opts.splitSectorPower) == ...
                  cfg.splitSectorPower);

    msg = sprintf( ...
        ['E1: az/el grids match (%d x %d), numDraws=%d, numBeams=%d, ' ...
         'splitSectorPower=%d on both paths'], ...
        numel(cfg.azGrid), numel(cfg.elGrid), cfg.numDraws, ...
        cfg.numBeams, cfg.splitSectorPower);
    r = check(r, okAz && okEl && okNumDraws && okNumBeams && okSplit, msg);
end

% =====================================================================
% E2 :: linear-mW mean EIRP agreement
% =====================================================================

function r = e2_mean_match(r, cfg, resCube, resStream) %#ok<INUSL>
%E2 Mean (linear-mW) EIRP must agree between the two paths.
%
%   In principle the two paths should produce bit-equivalent EIRP cubes
%   for the same seed because:
%     - both seed the global RNG once with cfg.seed
%     - both consume the same number of rand() calls per draw
%       (azimuth and ground-range for N UEs)
%     - both call imtAasSampleUePositions with identical
%       (rMin, rMax, azLimits, ueHeight) for the urban macro
%     - both clamp to the same azLimits = [-60, 60], elLimits = [-10, 0]
%     - both call imtAasEirpGrid with the same per-beam peak EIRP
%     - both aggregate by linear-mW summation across beams
%
%   We still allow a generous tolerance so a future divergence between
%   the legacy (compute_*) and new (imtAas*) beam-sampling wrappers does
%   not silently break this test. If the two paths ever drift apart the
%   absolute difference here will widen and the test will surface it.
%
%   TODO(SAMPLER-MISMATCH): if a future change introduces a different
%   beam-sampling order between sample_ue_positions_in_sector and
%   imtAasGenerateBeamSet (or different clamping behaviour), tighten /
%   loosen the tolerance below and document the source of the drift.

    cubeMean_mW  = mean(10 .^ (resCube.eirpGrid ./ 10), 3);
    cubeMean_dBm = 10 .* log10(cubeMean_mW);

    streamMean_dBm = resStream.stats.mean_dBm;

    % Shape sanity (defensive; e4 also asserts this).
    okShape = isequal(size(cubeMean_dBm), size(streamMean_dBm));

    if ~okShape
        r = check(r, false, sprintf( ...
            ['E2: full-cube and streaming mean_dBm shapes differ ' ...
             '(cube=%s, stream=%s)'], ...
            mat2str(size(cubeMean_dBm)), mat2str(size(streamMean_dBm))));
        return;
    end

    diffMap = abs(cubeMean_dBm - streamMean_dBm);
    maxAbs  = max(diffMap(:));

    % Broad tolerance (1e-6 dB is the tight sanity floor; we keep 1e-3 dB
    % as the documented guard so floating-point reordering between the
    % two sum strategies does not flake the test).
    tolDb = 1e-3;
    okFinite = all(isfinite(streamMean_dBm(:))) && ...
               all(isfinite(cubeMean_dBm(:)));
    okClose  = okFinite && (maxAbs <= tolDb);

    msg = sprintf( ...
        ['E2: linear-mW mean EIRP maps match within %.1e dB ' ...
         '(max abs diff = %.3e dB)'], tolDb, maxAbs);
    r = check(r, okClose, msg);
end

% =====================================================================
% E3 :: percentile / CDF shape agreement (bin-width tolerance)
% =====================================================================

function r = e3_percentile_match(r, cfg, resCube, resStream)
%E3 Percentile maps from the two paths must match within bin-width tol.
%
%   The streaming path returns bin midpoints from the per-cell histogram
%   so it discretises to the bin grid (binEdgesDbm). The full-cube path
%   interpolates between sorted EIRP values directly. The two will not be
%   exactly equal even if the underlying EIRP cubes are bit-equivalent;
%   the discrepancy is bounded by the bin width.

    cubeCdf = compute_cdf_per_grid_point(resCube.eirpGrid, cfg.percentiles);

    % eirp_percentile_maps was already invoked inside runR23AasEirpCdfGrid
    % with the runner's percentile vector; rebuild here using cfg's
    % percentiles to keep the comparison axis explicit.
    streamPmaps = eirp_percentile_maps(resStream.stats, cfg.percentiles);

    cubeVals   = cubeCdf.percentileEirpDbm;     % Naz x Nel x P
    streamVals = streamPmaps.values;             % Naz x Nel x P

    okShape = isequal(size(cubeVals), size(streamVals));
    if ~okShape
        r = check(r, false, sprintf( ...
            ['E3: percentile-map shapes differ (cube=%s, stream=%s)'], ...
            mat2str(size(cubeVals)), mat2str(size(streamVals))));
        return;
    end

    binWidth = max(diff(cfg.binEdgesDbm));    % nominally 1 dB
    % Streaming returns the bin midpoint of the first bin that crosses
    % the target CDF level; the discretisation error is bounded by one
    % full bin (the bin midpoint of the chosen bin can sit a bin-width
    % away from the empirical-CDF interpolated value when the small
    % numSnapshots case lands a percentile right at a bin boundary).
    % We keep a small additive cushion so floating-point edge effects
    % do not flake the check.
    tolDb = binWidth + 1e-9;

    diffVals = abs(cubeVals - streamVals);
    maxAbs   = max(diffVals(:));
    okFinite = all(isfinite(cubeVals(:))) && all(isfinite(streamVals(:)));
    okClose  = okFinite && (maxAbs <= tolDb);

    msg = sprintf( ...
        ['E3: percentile maps (p=%s) match within bin-width tol = %.3f dB ' ...
         '(max abs diff = %.3f dB)'], ...
        num2str(cfg.percentiles), tolDb, maxAbs);
    r = check(r, okClose, msg);
end

% =====================================================================
% E4 :: shape and finiteness (fail-safe on either side)
% =====================================================================

function r = e4_finite_and_shape(r, cfg, resCube, resStream)
    Naz = numel(cfg.azGrid);
    Nel = numel(cfg.elGrid);

    okCubeShape = isequal(size(resCube.eirpGrid), [Naz, Nel, cfg.numDraws]);
    okStreamShape = isequal(size(resStream.stats.mean_dBm), [Naz, Nel]) && ...
                    size(resStream.stats.counts, 1) == Naz && ...
                    size(resStream.stats.counts, 2) == Nel;

    okCubeFinite   = all(isfinite(resCube.eirpGrid(:)));
    okStreamFinite = all(isfinite(resStream.stats.mean_dBm(:))) && ...
                     all(isfinite(resStream.stats.sum_lin_mW(:)));

    msg = sprintf( ...
        ['E4: cube=[%d %d %d], streaming aggregator (%d x %d), ' ...
         'all outputs finite on both paths'], ...
        Naz, Nel, cfg.numDraws, Naz, Nel);
    r = check(r, okCubeShape && okStreamShape && okCubeFinite && okStreamFinite, msg);
end

% =====================================================================
% E5 :: power budget (perBeamPeak / sectorEirp) match
% =====================================================================

function r = e5_power_budget(r, resCube, resStream)
%E5 Both paths must agree on the R23 power budget metadata.
%
%   The full-cube path takes sectorEirpDbm from bs.eirp_dBm_per_100MHz;
%   the streaming path takes it from params.sectorEirpDbm. Both are
%   pinned to 78.3 dBm / 100 MHz by the R23 defaults. With
%   splitSectorPower = true and numBeams = 3, the per-beam peak should
%   be 78.3 - 10*log10(3) ~ 73.5288 dBm / 100 MHz on both sides.

    okSector = abs(resCube.sectorEirpDbm - resStream.stats.sectorEirpDbm) < 1e-9;
    okBeam   = abs(resCube.perBeamPeakEirpDbm - ...
                   resStream.stats.perBeamPeakEirpDbm) < 1e-9;

    expected = 78.3 - 10 * log10(3);
    okExpected = abs(resStream.stats.perBeamPeakEirpDbm - expected) < 1e-6;

    msg = sprintf( ...
        ['E5: sectorEirpDbm matches (%.3f vs %.3f) and perBeamPeakEirpDbm ' ...
         'matches (%.4f vs %.4f, expected %.4f)'], ...
        resCube.sectorEirpDbm, resStream.stats.sectorEirpDbm, ...
        resCube.perBeamPeakEirpDbm, resStream.stats.perBeamPeakEirpDbm, ...
        expected);
    r = check(r, okSector && okBeam && okExpected, msg);
end

% =====================================================================
% Helpers
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
