function results = test_single_sector_eirp_mvp()
%TEST_SINGLE_SECTOR_EIRP_MVP Unit tests for the R23 single-sector EIRP MVP.
%
%   RESULTS = test_single_sector_eirp_mvp()
%
%   Covers:
%       S1.  get_default_bs returns the R23 baseline (height 18 m,
%            azimuth 0 deg, 78.3 dBm/100 MHz, 120 deg sector width).
%       S2.  validate_r23_params accepts get_r23_aas_params and rejects
%            an invalid override.
%       S3.  generate_single_sector_layout: cellRadius_m = 400 m for
%            urban / 800 m for suburban; +/- 60 deg az limits, [-10, 0]
%            el limits; height_m wins on position_m mismatch (warning).
%       S4.  sample_ue_positions_in_sector: ground range >= 35 m and <=
%            cellRadius_m; azRelDeg in azLimitsDeg; height_m = 1.5 m;
%            seeded draws are reproducible.
%       S5.  compute_beam_angles_bs_to_ue: rawAzDeg matches
%            atan2d(dy, dx) wrt boresight; rawElDeg < 0 (UE below 18 m
%            BS) for default UE height 1.5 m.
%       S6.  clamp_beam_to_r23_coverage: rawAzDeg = +90 -> steerAzDeg
%            = +60, wasAzClipped = true; rawElDeg = +5 -> steerElDeg = 0,
%            wasElClipped = true.
%       S7.  compute_bs_gain_toward_grid: peakGainDbi within 0.1 dB of
%            R23 32.2 dBi reference for nominal steering (steerAz=0,
%            steerEl=-9 panel-frame -> +(-3) panel after rotation).
%       S8.  compute_eirp_grid: 3-beam aggregate peak EIRP for three
%            identical beams equals sectorEirpDbm exactly.
%       S9.  run_monte_carlo_snapshots: deterministic for fixed seed;
%            different seeds give different cubes; eirpGrid shape
%            [Naz Nel numSnapshots].
%       S10. compute_cdf_per_grid_point: percentile maps are non-
%            decreasing along the percentile axis (CDF monotonicity).
%       S11. BS overrides: bs.height_m = 25 m raises rawElDeg toward 0
%            (less negative downtilt) for the same UE.
%       S12. BS overrides: bs.eirp_dBm_per_100MHz = 70 lowers per-beam
%            peak EIRP by exactly 8.3 dB.
%       S13. End-to-end run_single_sector_eirp_demo runs and produces
%            a non-empty cdfOut.percentileEirpDbm.
%       S14. Vertical-convention contract:
%            (a) layout exposes both elLimitsDeg = [-10, 0] and
%                verticalCoverageGlobalThetaDeg = [90, 100] consistently
%                via theta = 90 - elev.
%            (b) UE at the same height as the BS yields rawElDeg ~ 0 and
%                rawThetaGlobalDeg ~ 90 (horizon).
%            (c) A direction with rawElDeg = -10 corresponds to
%                rawThetaGlobalDeg = 100 (10 deg below horizon).
%            (d) Clamp: rawElDeg = +5 -> steerElDeg = 0 and
%                steerThetaGlobalDeg = 90; rawElDeg = -20 ->
%                steerElDeg = -10 and steerThetaGlobalDeg = 100.
%            (e) thetaGlobalLimitsDeg = [90, 100] on the clamp output.

    results.summary = {};
    results.passed  = true;

    results = s1_default_bs(results);
    results = s2_params_validation(results);
    results = s3_layout(results);
    results = s4_ue_sampling(results);
    results = s5_beam_angles(results);
    results = s6_clamp_beam(results);
    results = s7_peak_gain(results);
    results = s8_three_identical_beams(results);
    results = s9_mc_determinism(results);
    results = s10_cdf_monotonic(results);
    results = s11_bs_height_override(results);
    results = s12_bs_eirp_override(results);
    results = s13_demo_runs(results);
    results = s14_global_theta_convention(results);

    fprintf('\n--- test_single_sector_eirp_mvp summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================
function r = s1_default_bs(r)
    bs = get_default_bs();
    ok = isfield(bs, 'id') && ...
         strcmp(char(string(bs.id)), 'BS_001') && ...
         isequal(bs.position_m, [0 0 18]) && ...
         bs.azimuth_deg == 0 && ...
         bs.sector_width_deg == 120 && ...
         bs.height_m == 18 && ...
         strcmp(char(string(bs.environment)), 'urban') && ...
         abs(bs.eirp_dBm_per_100MHz - 78.3) < 1e-9;
    r = check(r, ok, ...
        'S1: get_default_bs returns R23 baseline (78.3 dBm, h=18, az=0, 120 deg)');
end

% =====================================================================
function r = s2_params_validation(r)
    p = get_r23_aas_params();
    okValid = true;
    try
        validate_r23_params(p);
    catch
        okValid = false;
    end

    bad = p; bad.numColumns = -1;
    threwBad = false;
    try
        validate_r23_params(bad);
    catch err
        threwBad = strcmp(err.identifier, 'validate_r23_params:badType');
    end
    r = check(r, okValid && threwBad, ...
        'S2: validate_r23_params accepts defaults and rejects bad numColumns');
end

% =====================================================================
function r = s3_layout(r)
    bsU = get_default_bs();
    layU = generate_single_sector_layout(bsU);
    okU = abs(layU.cellRadius_m - 400) < 1e-9 && ...
          isequal(layU.azLimitsDeg, [-60 60]) && ...
          isequal(layU.elLimitsDeg, [-10 0]) && ...
          abs(layU.minUeDistance_m - 35) < 1e-9 && ...
          abs(layU.ueHeight_m - 1.5) < 1e-9 && ...
          abs(layU.bsHeight_m - 18) < 1e-9;

    bsS = bsU;
    bsS.environment = "suburban";
    bsS.position_m  = [0 0 20];
    bsS.height_m    = 20;
    layS = generate_single_sector_layout(bsS);
    okS = abs(layS.cellRadius_m - 800) < 1e-9 && ...
          abs(layS.bsHeight_m - 20) < 1e-9;

    % height_m wins on mismatch (warning expected).
    bsBad = bsU;
    bsBad.position_m(3) = 25;
    bsBad.height_m      = 18;
    ws = warning('off', 'generate_single_sector_layout:heightMismatch');
    cleanupWarn = onCleanup(@() warning(ws));
    layBad = generate_single_sector_layout(bsBad);
    okMismatch = abs(layBad.bsHeight_m - 18) < 1e-9;

    r = check(r, okU && okS && okMismatch, ...
        'S3: layout returns R23 limits, env-driven cell radius, and height_m wins');
end

% =====================================================================
function r = s4_ue_sampling(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    ue = sample_ue_positions_in_sector(bs, p, 1, 3);

    layout = generate_single_sector_layout(bs, p);
    okN = numel(ue.r_m) == 3 && ue.N == 3;
    okR = all(ue.r_m >= layout.minUeDistance_m - 1e-6) && ...
          all(ue.r_m <= layout.cellRadius_m + 1e-6);
    okAz = all(ue.azRelDeg >= layout.azLimitsDeg(1) - 1e-6) && ...
           all(ue.azRelDeg <= layout.azLimitsDeg(2) + 1e-6);
    okHeight = all(abs(ue.height_m - layout.ueHeight_m) < 1e-9);

    ue2 = sample_ue_positions_in_sector(bs, p, 1, 3);
    okRepeat = isequal(ue.x_m, ue2.x_m) && isequal(ue.y_m, ue2.y_m);

    ueDiff = sample_ue_positions_in_sector(bs, p, 9999, 3);
    okDiff = ~isequal(ue.x_m, ueDiff.x_m) || ~isequal(ue.y_m, ueDiff.y_m);

    r = check(r, okN && okR && okAz && okHeight && okRepeat && okDiff, ...
        'S4: UE sampling respects 35 m / cellRadius / az limits / 1.5 m height; seed reproducible');
end

% =====================================================================
function r = s5_beam_angles(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, p);

    % Place a UE at (200 m, 50 m) ground -> manual angle check.
    ue = struct();
    ue.x_m = 200; ue.y_m = 50; ue.z_m = layout.ueHeight_m;
    ue.r_m = hypot(200, 50);
    ue.azRelDeg    = atan2d(50, 200);
    ue.azGlobalDeg = ue.azRelDeg + bs.azimuth_deg;
    ue.height_m    = layout.ueHeight_m;
    ue.N           = 1;
    ue.layout      = layout;

    beam = compute_beam_angles_bs_to_ue(bs, ue, p);
    expectedAz = atan2d(50, 200);
    dz = layout.ueHeight_m - layout.bsHeight_m;
    expectedEl = atan2d(dz, hypot(200, 50));
    okAz = abs(beam.rawAzDeg - expectedAz) < 1e-9;
    okEl = abs(beam.rawElDeg - expectedEl) < 1e-9;
    okGround = abs(beam.groundRange_m - hypot(200, 50)) < 1e-9;
    okBelow  = beam.rawElDeg < 0;
    okThetaField = isfield(beam, 'rawThetaGlobalDeg');
    okThetaConv  = okThetaField && ...
                   abs(beam.rawThetaGlobalDeg - (90 - beam.rawElDeg)) < 1e-12;
    r = check(r, okAz && okEl && okGround && okBelow && ...
                 okThetaField && okThetaConv, ...
        'S5: BS->UE raw beam angles match analytic atan2d / negative elev / rawThetaGlobalDeg = 90 - rawElDeg');
end

% =====================================================================
function r = s6_clamp_beam(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, p);
    beams = struct();
    beams.rawAzDeg = [ 30; 90; -75 ];
    beams.rawElDeg = [ -5;  5;  -3 ];
    beams.layout = layout;

    out = clamp_beam_to_r23_coverage(bs, beams, p);
    okAz = isequal(out.steerAzDeg, [30; 60; -60]) && ...
           isequal(out.wasAzClipped, [false; true; true]);
    okEl = isequal(out.steerElDeg, [-5; 0; -3]) && ...
           isequal(out.wasElClipped, [false; true; false]);

    okThetaField = isfield(out, 'steerThetaGlobalDeg') && ...
                   isfield(out, 'thetaGlobalLimitsDeg');
    okThetaConv  = okThetaField && ...
                   isequal(out.steerThetaGlobalDeg, 90 - out.steerElDeg);
    okThetaLim   = okThetaField && ...
                   isequal(out.thetaGlobalLimitsDeg, [90, 100]);

    r = check(r, okAz && okEl && okThetaField && okThetaConv && okThetaLim, ...
        'S6: clamp_beam_to_r23_coverage clips az/el and exposes steerThetaGlobalDeg / thetaGlobalLimitsDeg');
end

% =====================================================================
function r = s7_peak_gain(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    grid = struct( ...
        'azGridDeg', -180:1:180, ...
        'elGridDeg',  -90:1:30);

    % One UE at boresight + nominal R23 downtilt (steerAz=0, steerEl=-9).
    beams = struct();
    beams.steerAzDeg = 0;
    beams.steerElDeg = -9;

    g = compute_bs_gain_toward_grid(bs, beams, grid, p);
    okPeak = abs(g.peakGainDbi - 32.2) < 0.1;
    r = check(r, okPeak, sprintf( ...
        'S7: peakGainDbi ~ 32.2 dBi (got %.3f)', g.peakGainDbi));
end

% =====================================================================
function r = s8_three_identical_beams(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    grid = struct( ...
        'azGridDeg', -180:1:180, ...
        'elGridDeg',  -90:1:30);

    % Hand-craft a UEPOSITIONS struct that pins three identical UEs
    % bypassing sample_* (they all sit at (200, 0, 1.5)).
    layout = generate_single_sector_layout(bs, p);
    ue = struct();
    ue.x_m = 200 .* ones(3,1);
    ue.y_m = zeros(3,1);
    ue.z_m = layout.ueHeight_m .* ones(3,1);
    ue.r_m = 200 .* ones(3,1);
    ue.azRelDeg    = zeros(3,1);
    ue.azGlobalDeg = bs.azimuth_deg + zeros(3,1);
    ue.height_m    = ue.z_m;
    ue.slantRange_m = hypot(ue.r_m, ue.z_m - layout.bsHeight_m);
    ue.N      = 3;
    ue.layout = layout;

    snap = compute_eirp_grid(bs, ue, grid, p, ...
        struct('splitSectorPower', true));

    peakAgg = max(snap.aggregateEirpDbm(:));
    okPeak  = abs(peakAgg - bs.eirp_dBm_per_100MHz) < 1e-6;

    expectedPerBeam = bs.eirp_dBm_per_100MHz - 10*log10(3);
    okPerBeam = abs(snap.perBeamPeakEirpDbm - expectedPerBeam) < 1e-9;

    r = check(r, okPeak && okPerBeam, sprintf( ...
        ['S8: 3 identical beams aggregate peak = %.6f (= sectorEirp), ' ...
         'per-beam peak = %.6f (= sectorEirp - 10log10(3))'], ...
         peakAgg, snap.perBeamPeakEirpDbm));
end

% =====================================================================
function r = s9_mc_determinism(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    grid = struct('azGridDeg', -30:10:30, 'elGridDeg', -10:5:10);
    cfg  = struct('numSnapshots', 7, 'numUes', 3, 'seed', 11);

    a = run_monte_carlo_snapshots(bs, grid, p, cfg);
    b = run_monte_carlo_snapshots(bs, grid, p, cfg);
    okShape = isequal(size(a.eirpGrid), [numel(grid.azGridDeg), ...
                                         numel(grid.elGridDeg), 7]);
    okEq    = isequal(a.eirpGrid, b.eirpGrid);

    cfgDiff = cfg; cfgDiff.seed = 9999;
    c = run_monte_carlo_snapshots(bs, grid, p, cfgDiff);
    okDiff = ~isequal(a.eirpGrid, c.eirpGrid);

    r = check(r, okShape && okEq && okDiff, ...
        'S9: MC eirpGrid shape correct; same seed -> identical; different seed -> different');
end

% =====================================================================
function r = s10_cdf_monotonic(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    grid = struct('azGridDeg', -30:10:30, 'elGridDeg', -10:5:10);
    cfg  = struct('numSnapshots', 25, 'numUes', 3, 'seed', 5);

    mc = run_monte_carlo_snapshots(bs, grid, p, cfg);
    cdf = compute_cdf_per_grid_point(mc.eirpGrid, [5 25 50 75 95]);

    okShape = isequal(size(cdf.percentileEirpDbm), ...
        [numel(grid.azGridDeg), numel(grid.elGridDeg), 5]);

    diffs = diff(cdf.percentileEirpDbm, 1, 3);
    okMono = all(diffs(:) >= -1e-9);

    okMin = all(cdf.minEirpDbm(:) <= cdf.maxEirpDbm(:) + 1e-9);

    r = check(r, okShape && okMono && okMin, ...
        'S10: per-cell percentile maps are non-decreasing across percentiles');
end

% =====================================================================
function r = s11_bs_height_override(r)
    p  = get_r23_aas_params();
    layoutDefault = generate_single_sector_layout(get_default_bs(), p);

    % Same UE position; vary BS height.
    ue = struct();
    ue.x_m = 200; ue.y_m = 0; ue.z_m = layoutDefault.ueHeight_m;
    ue.r_m = 200;
    ue.azRelDeg = 0;
    ue.azGlobalDeg = 0;
    ue.height_m = ue.z_m;
    ue.N = 1;
    ue.layout = layoutDefault;

    bsLow = get_default_bs();
    bsLow.position_m = [0 0 5];
    bsLow.height_m   = 5;
    bsHigh = get_default_bs();
    bsHigh.position_m = [0 0 25];
    bsHigh.height_m   = 25;

    bLow  = compute_beam_angles_bs_to_ue(bsLow,  ue, p);
    bHigh = compute_beam_angles_bs_to_ue(bsHigh, ue, p);

    okHigh = bHigh.rawElDeg < bLow.rawElDeg;  % more downtilt at greater height
    r = check(r, okHigh, sprintf( ...
        'S11: higher BS -> more negative rawElDeg (low=%.3f, high=%.3f)', ...
        bLow.rawElDeg, bHigh.rawElDeg));
end

% =====================================================================
function r = s12_bs_eirp_override(r)
    bs = get_default_bs();
    p  = get_r23_aas_params();
    grid = struct('azGridDeg', -30:5:30, 'elGridDeg', -15:5:5);

    layout = generate_single_sector_layout(bs, p);
    ue = struct();
    ue.x_m = 200 .* ones(3,1);
    ue.y_m = zeros(3,1);
    ue.z_m = layout.ueHeight_m .* ones(3,1);
    ue.r_m = 200 .* ones(3,1);
    ue.azRelDeg    = zeros(3,1);
    ue.azGlobalDeg = zeros(3,1);
    ue.height_m    = ue.z_m;
    ue.slantRange_m = hypot(ue.r_m, ue.z_m - layout.bsHeight_m);
    ue.N = 3;
    ue.layout = layout;

    snapDefault = compute_eirp_grid(bs, ue, grid, p);
    bsLow = bs; bsLow.eirp_dBm_per_100MHz = 70.0;
    snapLow = compute_eirp_grid(bsLow, ue, grid, p);

    delta = snapDefault.perBeamPeakEirpDbm - snapLow.perBeamPeakEirpDbm;
    okDelta = abs(delta - (78.3 - 70.0)) < 1e-6;

    aggDelta = max(snapDefault.aggregateEirpDbm(:)) - ...
               max(snapLow.aggregateEirpDbm(:));
    okAggDelta = abs(aggDelta - 8.3) < 1e-6;

    r = check(r, okDelta && okAggDelta, sprintf( ...
        'S12: bs.eirp override 78.3 -> 70.0 lowers per-beam and aggregate peak by 8.3 dB (got %.6f, %.6f)', ...
        delta, aggDelta));
end

% =====================================================================
function r = s13_demo_runs(r)
    opts = struct( ...
        'numSnapshots', 5, ...
        'numUes',       3, ...
        'seed',         1, ...
        'gridPoints', struct( ...
            'azGridDeg', -30:10:30, ...
            'elGridDeg', -10:5:10), ...
        'verbose',      false);
    out = run_single_sector_eirp_demo(opts);
    okFields = isfield(out, 'cdfOut') && isfield(out.cdfOut, 'percentileEirpDbm');
    okShape  = okFields && all(size(out.cdfOut.percentileEirpDbm) > 0);
    r = check(r, okFields && okShape, ...
        'S13: run_single_sector_eirp_demo runs end-to-end and produces CDF maps');
end

% =====================================================================
function r = s14_global_theta_convention(r)
%S14 Vertical-convention contract: internal elevation <-> R23 global theta.
%
%   The MVP uses internal elevation (0 deg = horizon, negative = downtilt)
%   for every existing antenna call, and exposes the R23 global-theta
%   representation (90 deg = horizon, 100 deg = 10 deg below horizon)
%   side by side. The conversion is one-line and exact:
%       thetaGlobalDeg = 90 - elevationDeg
%   This test pins that contract so future changes cannot silently swap
%   one convention for the other or drop one of the two representations.

    bs = get_default_bs();
    p  = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, p);

    % --- (a) layout exposes both forms consistently ---------------------
    okElLim = isequal(layout.elLimitsDeg, [-10, 0]);
    okThetaLim = isfield(layout, 'verticalCoverageGlobalThetaDeg') && ...
                 isequal(layout.verticalCoverageGlobalThetaDeg, [90, 100]);
    % conversion: theta limits = 90 - flip(elev limits) (monotonic dec.).
    okConv = okThetaLim && isequal(layout.verticalCoverageGlobalThetaDeg, ...
                                   [90 - layout.elLimitsDeg(2), ...
                                    90 - layout.elLimitsDeg(1)]);

    % --- (b) UE at BS height -> rawElDeg ~ 0, rawThetaGlobalDeg ~ 90 ----
    ueH = struct();
    ueH.x_m = 200; ueH.y_m = 0; ueH.z_m = layout.bsHeight_m;
    ueH.r_m = 200;
    ueH.azRelDeg = 0; ueH.azGlobalDeg = 0;
    ueH.height_m = ueH.z_m;
    ueH.N = 1;
    ueH.layout = layout;
    bH = compute_beam_angles_bs_to_ue(bs, ueH, p);
    okHorizonEl    = abs(bH.rawElDeg)               < 1e-9;
    okHorizonTheta = abs(bH.rawThetaGlobalDeg - 90) < 1e-9;

    % --- (c) rawElDeg = -10 <-> rawThetaGlobalDeg = 100 -----------------
    % Drive this geometrically: pick a UE 10 deg below the horizon.
    range = 200;
    dz = -range * tand(10);   % negative dz -> downtilt 10 deg
    ueD = ueH;
    ueD.z_m = layout.bsHeight_m + dz;
    ueD.height_m = ueD.z_m;
    bD = compute_beam_angles_bs_to_ue(bs, ueD, p);
    okDownEl    = abs(bD.rawElDeg - (-10))           < 1e-9;
    okDownTheta = abs(bD.rawThetaGlobalDeg - 100)    < 1e-9;

    % --- (d) clamp: rawElDeg = +5 -> 0 / 90 ; -20 -> -10 / 100 ----------
    beamsRaw = struct();
    beamsRaw.rawAzDeg = [0; 0];
    beamsRaw.rawElDeg = [5; -20];
    beamsRaw.layout = layout;
    cl = clamp_beam_to_r23_coverage(bs, beamsRaw, p);
    okClipUpEl    = abs(cl.steerElDeg(1))           < 1e-12;
    okClipUpTheta = abs(cl.steerThetaGlobalDeg(1) - 90)  < 1e-12;
    okClipDnEl    = abs(cl.steerElDeg(2) - (-10))   < 1e-12;
    okClipDnTheta = abs(cl.steerThetaGlobalDeg(2) - 100) < 1e-12;
    okClipFlags   = isequal(cl.wasElClipped, [true; true]);

    % --- (e) thetaGlobalLimitsDeg surfaced on the clamp output ----------
    okClampLim = isequal(cl.thetaGlobalLimitsDeg, [90, 100]);

    okAll = okElLim && okThetaLim && okConv && ...
            okHorizonEl && okHorizonTheta && ...
            okDownEl && okDownTheta && ...
            okClipUpEl && okClipUpTheta && ...
            okClipDnEl && okClipDnTheta && ...
            okClipFlags && okClampLim;

    r = check(r, okAll, ...
        'S14: vertical convention - internal elev and R23 global theta agree via theta = 90 - elev (horizon, downtilt, clamp)');
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
