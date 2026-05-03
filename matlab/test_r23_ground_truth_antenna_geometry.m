function results = test_r23_ground_truth_antenna_geometry()
%TEST_R23_GROUND_TRUTH_ANTENNA_GEOMETRY Deterministic known-answer tests.
%
%   RESULTS = test_r23_ground_truth_antenna_geometry()
%
%   Anchors the R23 single-sector EIRP CDF-grid MVP to a small set of
%   geometric "known answer" cases where the expected behaviour is
%   independent of any tuning choice in the antenna model. These tests
%   are intentionally narrow: they pin the conventions and the qualitative
%   shape of the composite pattern, not specific dB numbers (with the one
%   exception of values that follow directly from documented identities,
%   like the global-theta conversion).
%
%   Coverage:
%       G1. Boresight peak.
%             A UE placed directly in front of the sector boresight at
%             default height (1.5 m) gives a small natural downtilt
%             (rawEl ~ -4.72 deg at 200 m range) that sits inside the
%             R23 envelope, so no azimuth or elevation clamp occurs.
%             The composite BS gain evaluated at the steered direction
%             (steerAz = 0, steerEl = rawEl) is the max among coarse
%             azimuth-offset comparison points at the same elevation.
%             The corresponding EIRP is finite and near the per-beam max.
%       G2. Off-axis gain drop.
%             Same steered beam as G1, but evaluate the composite gain
%             at relative azimuth offsets {0, 30, 60} deg at the steered
%             elevation. Expect gain(0) > gain(30) and gain(0) > gain(60).
%             Strict monotonicity gain(30) > gain(60) is NOT enforced:
%             with the R23 default 16-column 0.5 lambda horizontal array
%             steered to boresight, the array factor has an exact null
%             at sin(az) = 4/(N_H * d_H) = 1/2 (i.e. az = 30 deg), so
%             gain(30) can sit below gain(60). The 0-vs-30 and 0-vs-60
%             checks are the safe contract that catches a flipped
%             azimuth or a broken array factor.
%       G3. Vertical convention.
%             (a) UE at the same height as the BS gives rawElDeg ~ 0 and
%                 rawThetaGlobalDeg ~ 90 (horizon).
%             (b) A UE 10 deg below the horizon gives rawElDeg ~ -10 and
%                 rawThetaGlobalDeg ~ 100.
%             (c) The pure conversion thetaGlobalDeg = 90 - elevationDeg
%                 holds element-wise on a constructed elevation vector.
%       G4. Clamp convention.
%             (a) rawElDeg = +5  -> steerElDeg = 0,   steerThetaGlobalDeg = 90
%             (b) rawElDeg = -20 -> steerElDeg = -10, steerThetaGlobalDeg = 100
%             (c) rawAzDeg = +90 -> steerAzDeg = +60 (clipped)
%             (d) rawAzDeg = -75 -> steerAzDeg = -60 (clipped)
%             (e) rawAzDeg = +45 -> steerAzDeg = +45 (untouched, inside +/-60)
%       G5. EIRP sanity.
%             Re-uses the boresight setup. EIRP values at the aligned and
%             off-axis grid points are finite, the aligned EIRP exceeds
%             every off-axis comparison EIRP, and the per-beam EIRP grid
%             has the documented [Naz Nel numBeams] shape.
%
%   These checks are deterministic - no Monte Carlo, no random seeds.
%   Together they guard against silent flips of the elevation sign,
%   silent swaps between internal-elevation and global-theta conventions,
%   accidental azimuth clamp asymmetry, and accidental boresight offsets
%   in the composite gain.

    results.summary = {};
    results.passed  = true;

    results = g1_boresight_peak(results);
    results = g2_off_axis_drop(results);
    results = g3_vertical_convention(results);
    results = g4_clamp_convention(results);
    results = g5_eirp_sanity(results);

    fprintf('\n--- test_r23_ground_truth_antenna_geometry summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function fix = boresight_fixture()
%BORESIGHT_FIXTURE Common UE-on-boresight setup shared by G1, G2, G5.
%   UE at (200 m, 0, 1.5) with default BS at (0, 0, 18) yields:
%       rawAzDeg ~ 0           (azimuth boresight)
%       rawElDeg ~ -4.7235 deg (small natural downtilt, inside [-10, 0])
%   so the clamp leaves both fields untouched and the steered beam
%   coincides with the geometric BS->UE direction.

    fix = struct();
    fix.bs     = get_default_bs();
    fix.params = get_r23_aas_params();
    fix.layout = generate_single_sector_layout(fix.bs, fix.params);

    fix.ue = struct();
    fix.ue.x_m         = 200;
    fix.ue.y_m         = 0;
    fix.ue.z_m         = fix.layout.ueHeight_m;
    fix.ue.r_m         = 200;
    fix.ue.azRelDeg    = 0;
    fix.ue.azGlobalDeg = fix.bs.azimuth_deg;
    fix.ue.height_m    = fix.ue.z_m;
    fix.ue.slantRange_m = hypot(fix.ue.r_m, fix.ue.z_m - fix.layout.bsHeight_m);
    fix.ue.N           = 1;
    fix.ue.layout      = fix.layout;

    raw   = compute_beam_angles_bs_to_ue(fix.bs, fix.ue, fix.params);
    fix.beams = clamp_beam_to_r23_coverage(fix.bs, raw, fix.params);
end

% =====================================================================

function r = g1_boresight_peak(r)
    fix = boresight_fixture();

    okNoAzClamp = ~any(fix.beams.wasAzClipped);
    okNoElClamp = ~any(fix.beams.wasElClipped);
    okAzZero    = abs(fix.beams.steerAzDeg) < 1e-9;
    okElInside  = (fix.beams.steerElDeg >= fix.layout.elLimitsDeg(1) - 1e-9) ...
               && (fix.beams.steerElDeg <= fix.layout.elLimitsDeg(2) + 1e-9);

    % Coarse az sweep at the steered elevation. The aligned cell is the
    % first one (azGridDeg = 0).
    steerEl = fix.beams.steerElDeg;
    grid = struct( ...
        'azGridDeg', [0, 15, 30, 45, 60, -15, -30, -45, -60], ...
        'elGridDeg', steerEl);
    g = compute_bs_gain_toward_grid(fix.bs, fix.beams, grid, fix.params);
    gainSlice = squeeze(g.compositeGainDbi);   % length = numel(azGridDeg)
    [~, peakIdx] = max(gainSlice);
    others = gainSlice; others(1) = [];
    okGridPeak = (peakIdx == 1) && all(gainSlice(1) >= others + 1e-9);

    % Sanity on the absolute level: the aligned gain should be near the
    % R23 reference 32.2 dBi peak (this beam is in the steering envelope
    % but not at the global mech+elec downtilt sweet spot, so allow a
    % loose 3 dB margin so the test does not over-pin numbers).
    okFinite  = isfinite(gainSlice(1));
    okNearMax = gainSlice(1) > 32.2 - 3.0;

    okAll = okNoAzClamp && okNoElClamp && okAzZero && okElInside && ...
            okGridPeak  && okFinite    && okNearMax;
    r = check(r, okAll, sprintf( ...
        ['G1: boresight peak (steerAz=%.3f, steerEl=%.3f, no clamp); ' ...
         'aligned gain %.3f dBi is the max over coarse az offsets'], ...
        fix.beams.steerAzDeg, fix.beams.steerElDeg, gainSlice(1)));
end

% =====================================================================

function r = g2_off_axis_drop(r)
    fix = boresight_fixture();
    steerEl = fix.beams.steerElDeg;

    % Three points at the steered elevation, az offsets {0, 30, 60} deg
    % from boresight. The R23 default 16-column 0.5 lambda horizontal
    % array steered to az = 0 has an exact array-factor null at
    % sin(az) = k/(N_H * d_H) for integer k. With N_H = 16 and d_H = 0.5
    % wavelengths that hits sin(az) = 1/2, i.e. az = 30 deg exactly. So
    % gain(30) can fall BELOW gain(60), which sits between sidelobes.
    % This test therefore enforces the safer contract from the task
    % description: gain(0) > gain(30) AND gain(0) > gain(60), with no
    % ordering imposed between gain(30) and gain(60).
    grid = struct( ...
        'azGridDeg', [0, 30, 60], ...
        'elGridDeg', steerEl);
    g = compute_bs_gain_toward_grid(fix.bs, fix.beams, grid, fix.params);
    gainSlice = squeeze(g.compositeGainDbi);

    g0  = gainSlice(1);
    g30 = gainSlice(2);
    g60 = gainSlice(3);

    okFinite     = all(isfinite(gainSlice));
    okPair0gt30  = g0 > g30 + 1e-9;
    okPair0gt60  = g0 > g60 + 1e-9;
    okAll = okFinite && okPair0gt30 && okPair0gt60;
    r = check(r, okAll, sprintf( ...
        ['G2: off-axis drop at steerEl=%.3f: g(0)=%.3f > g(30)=%.3f, ' ...
         'g(0) > g(60)=%.3f dBi'], steerEl, g0, g30, g60));
end

% =====================================================================

function r = g3_vertical_convention(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    % (a) UE at BS height, on boresight -> rawEl ~ 0, rawTheta ~ 90.
    ueH = struct();
    ueH.x_m = 200; ueH.y_m = 0; ueH.z_m = layout.bsHeight_m;
    ueH.r_m = 200; ueH.azRelDeg = 0; ueH.azGlobalDeg = 0;
    ueH.height_m = ueH.z_m; ueH.N = 1; ueH.layout = layout;
    bH = compute_beam_angles_bs_to_ue(bs, ueH, params);
    okHorizonEl    = abs(bH.rawElDeg)               < 1e-9;
    okHorizonTheta = abs(bH.rawThetaGlobalDeg - 90) < 1e-9;

    % (b) Construct a UE 10 deg below horizon from BS height.
    range = 200;
    dz    = -range * tand(10);   % negative -> downtilt
    ueD = ueH;
    ueD.z_m      = layout.bsHeight_m + dz;
    ueD.height_m = ueD.z_m;
    bD = compute_beam_angles_bs_to_ue(bs, ueD, params);
    okDownEl    = abs(bD.rawElDeg - (-10))        < 1e-9;
    okDownTheta = abs(bD.rawThetaGlobalDeg - 100) < 1e-9;

    % (c) Pure conversion check on a constructed elevation vector.
    elTest = (-10:1:0).';
    thetaTest = 90 - elTest;
    okPureConv = all(abs((90 - elTest) - thetaTest) < 1e-12);
    okEndpoints = abs(thetaTest(1) - 100) < 1e-12 && ...
                  abs(thetaTest(end) - 90) < 1e-12;

    okAll = okHorizonEl && okHorizonTheta && ...
            okDownEl    && okDownTheta    && ...
            okPureConv  && okEndpoints;
    r = check(r, okAll, ...
        'G3: vertical convention: el=0<->theta=90, el=-10<->theta=100');
end

% =====================================================================

function r = g4_clamp_convention(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    beams = struct();
    beams.rawAzDeg = [  0;   0; +90; -75; +45 ];
    beams.rawElDeg = [ +5; -20;  -3;  -3;  -3 ];
    beams.layout   = layout;

    cl = clamp_beam_to_r23_coverage(bs, beams, params);

    % (a) rawEl = +5  -> steerEl = 0,  steerThetaGlobal = 90
    okUpEl    = abs(cl.steerElDeg(1))                  < 1e-12;
    okUpTheta = abs(cl.steerThetaGlobalDeg(1) - 90)    < 1e-12;
    okUpFlag  = cl.wasElClipped(1);

    % (b) rawEl = -20 -> steerEl = -10, steerThetaGlobal = 100
    okDnEl    = abs(cl.steerElDeg(2) - (-10))          < 1e-12;
    okDnTheta = abs(cl.steerThetaGlobalDeg(2) - 100)   < 1e-12;
    okDnFlag  = cl.wasElClipped(2);

    % (c) rawAz = +90 -> steerAz = +60 (clipped)
    okAzPos     = abs(cl.steerAzDeg(3) - 60)           < 1e-12;
    okAzPosFlag = cl.wasAzClipped(3);

    % (d) rawAz = -75 -> steerAz = -60 (clipped)
    okAzNeg     = abs(cl.steerAzDeg(4) - (-60))        < 1e-12;
    okAzNegFlag = cl.wasAzClipped(4);

    % (e) rawAz = +45 (inside +/-60) is left untouched
    okAzMid     = abs(cl.steerAzDeg(5) - 45)           < 1e-12;
    okAzMidFlag = ~cl.wasAzClipped(5);

    % (f) limits surfaced on the output
    okLimits = isequal(cl.azLimitsDeg, [-60, 60]) && ...
               isequal(cl.elLimitsDeg, [-10, 0])  && ...
               isequal(cl.thetaGlobalLimitsDeg, [90, 100]);

    okAll = okUpEl && okUpTheta && okUpFlag    && ...
            okDnEl && okDnTheta && okDnFlag    && ...
            okAzPos && okAzPosFlag             && ...
            okAzNeg && okAzNegFlag             && ...
            okAzMid && okAzMidFlag             && ...
            okLimits;
    r = check(r, okAll, ...
        'G4: clamp: el +5->0/90, -20->-10/100; az +/-90 clipped to +/-60; az 45 untouched');
end

% =====================================================================

function r = g5_eirp_sanity(r)
    fix = boresight_fixture();
    steerEl = fix.beams.steerElDeg;

    grid = struct( ...
        'azGridDeg', [0, 30, 60], ...
        'elGridDeg', steerEl);
    snap = compute_eirp_grid(fix.bs, fix.ue, grid, fix.params, ...
        struct('splitSectorPower', true));

    % Output shape: [Naz Nel numBeams]; with N=1 UE this is [3 1 1].
    okShape = isequal(size(snap.perBeamEirpDbm), [3, 1, 1]);

    % Per-beam EIRP at the aligned vs. off-axis grid points.
    eirpSlice = squeeze(snap.perBeamEirpDbm);   % length 3 vector
    e0  = eirpSlice(1);
    e30 = eirpSlice(2);
    e60 = eirpSlice(3);

    okFinite   = all(isfinite(eirpSlice));
    okOrder    = (e0 > e30 + 1e-9) && (e0 > e60 + 1e-9);
    okPerBeam  = abs(snap.perBeamPeakEirpDbm - fix.bs.eirp_dBm_per_100MHz) < 1e-9;
    okNearPeak = (snap.perBeamPeakEirpDbm - e0) < 3.0;

    okAll = okShape && okFinite && okOrder && okPerBeam && okNearPeak;
    r = check(r, okAll, sprintf( ...
        ['G5: EIRP sanity: shape [3 1 1], finite, e(0)=%.3f > e(30)=%.3f, ' ...
         'e(0) > e(60)=%.3f, per-beam peak %.3f dBm'], ...
        e0, e30, e60, snap.perBeamPeakEirpDbm));
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
