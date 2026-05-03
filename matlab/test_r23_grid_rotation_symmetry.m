function results = test_r23_grid_rotation_symmetry()
%TEST_R23_GRID_ROTATION_SYMMETRY Deterministic grid rotation / symmetry tests.
%
%   RESULTS = test_r23_grid_rotation_symmetry()
%
%   Pins the geometric contract between the world frame, the sector frame
%   and the (az, el) observation grid in the R23 single-sector EIRP MVP.
%   These tests are deterministic - no Monte Carlo, no random seeds - and
%   use fixed UE / grid setups so a silent flip between global and relative
%   azimuth, an asymmetric clamp, or a broken sector-frame rotation cannot
%   pass.
%
%   Coverage:
%       R1. BS azimuth override.
%             A UE placed along global azimuth 0 deg yields rawAzDeg = 0
%             when bs.azimuth_deg = 0, and rawAzDeg = -30 when
%             bs.azimuth_deg = +30. The UE position in the world frame is
%             unchanged between the two runs and get_default_bs() defaults
%             are not mutated.
%       R2. Rotated-equivalent geometry.
%             Setup A (bs.azimuth_deg = 0, UE at global az +30, grid az
%             +30 sector frame) and Setup B (bs.azimuth_deg = +45, UE at
%             global az +75, grid az +30 sector frame) describe the same
%             relative geometry. rawAzDeg, steerAzDeg, and the composite
%             BS gain at the aligned grid cell match within numerical
%             tolerance, as does the per-beam EIRP at that cell.
%       R3. Left/right symmetry around boresight.
%             One UE on boresight (steerAz = 0), grid points at -30 and
%             +30 deg with the same elevation. gain(-30) == gain(+30)
%             and EIRP(-30) == EIRP(+30) within numerical tolerance, as
%             expected from the y-mirror symmetry of the panel-frame
%             array factor (mech tilt is a pure y-axis rotation, so it
%             does not break left/right symmetry).
%       R4. Sector-edge symmetry.
%             Same boresight UE; grid points at -60 and +60. Both edge
%             gains and edge EIRPs match each other, and both sit below
%             the boresight (az = 0) reference.
%       R5. Deterministic dimensions.
%             Every EIRP output produced by R1..R4 is finite and has the
%             documented shape: perBeamEirpDbm is [Naz, Nel, numBeams],
%             aggregateEirpDbm and maxEnvelopeEirpDbm are [Naz, Nel].
%
%   Scope guard: this file only exercises antenna-face EIRP. There is NO
%   path loss, NO clutter, NO FS / FSS / victim receiver, NO I / N, NO
%   network laydown, NO 19-site / 57-sector aggregation. The aligned UE
%   geometry uses a 200 m / 1.5 m UE (default UE height) at default BS
%   height (18 m), which sits inside the R23 [-10, 0] deg vertical
%   envelope so no elevation clamp fires for the boresight cases.
%
%   Exit contract: RESULTS is a struct with fields .summary (cellstr) and
%   .passed (logical), matching run_all_tests.m.

    results.summary = {};
    results.passed  = true;

    results = r1_bs_azimuth_override(results);
    results = r2_rotated_equivalent_geometry(results);
    results = r3_left_right_symmetry(results);
    results = r4_sector_edge_symmetry(results);
    results = r5_deterministic_dimensions(results);

    fprintf('\n--- test_r23_grid_rotation_symmetry summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function ue = make_single_ue(layout, globalAzDeg, range_m)
%MAKE_SINGLE_UE Build a 1-UE struct at a fixed (range, global az, ueHeight).
%   Used to construct deterministic UE positions in the world frame so the
%   bs.azimuth_deg override actually changes the relative azimuth.

    ue = struct();
    ue.x_m         = layout.bsX_m + range_m * cosd(globalAzDeg);
    ue.y_m         = layout.bsY_m + range_m * sind(globalAzDeg);
    ue.z_m         = layout.ueHeight_m;
    ue.r_m         = range_m;
    ue.azGlobalDeg = globalAzDeg;
    ue.azRelDeg    = wrap_to_180(globalAzDeg - layout.boresightAzDeg);
    ue.height_m    = ue.z_m;
    ue.slantRange_m = hypot(ue.r_m, ue.z_m - layout.bsHeight_m);
    ue.N           = 1;
    ue.layout      = layout;
end

% =====================================================================

function r = r1_bs_azimuth_override(r)
    defBefore = get_default_bs();
    params    = get_r23_aas_params();

    % UE fixed at global azimuth 0 (along +x) for both runs.
    range_m = 200;

    % Run A: bs.azimuth_deg = 0  -> rawAzDeg = 0.
    bsA = get_default_bs();
    bsA.azimuth_deg = 0;
    layoutA = generate_single_sector_layout(bsA, params);
    ueA = make_single_ue(layoutA, 0, range_m);
    rawA = compute_beam_angles_bs_to_ue(bsA, ueA, params);

    % Run B: bs.azimuth_deg = 30 -> rawAzDeg = -30.
    bsB = get_default_bs();
    bsB.azimuth_deg = 30;
    layoutB = generate_single_sector_layout(bsB, params);
    ueB = make_single_ue(layoutB, 0, range_m);
    rawB = compute_beam_angles_bs_to_ue(bsB, ueB, params);

    okA = abs(rawA.rawAzDeg - 0)    < 1e-9;
    okB = abs(rawB.rawAzDeg - (-30)) < 1e-9;

    % Global azimuth must NOT depend on bs.azimuth_deg.
    okGlobalA = abs(rawA.azGlobalDeg - 0) < 1e-9;
    okGlobalB = abs(rawB.azGlobalDeg - 0) < 1e-9;

    % UE world position must be identical between the two runs.
    okPosX = abs(ueA.x_m - ueB.x_m) < 1e-9;
    okPosY = abs(ueA.y_m - ueB.y_m) < 1e-9;
    okPosZ = abs(ueA.z_m - ueB.z_m) < 1e-9;

    % Defaults must be intact (override is a local copy).
    defAfter = get_default_bs();
    okDefaultsIntact = isequal(defBefore, defAfter);

    okAll = okA && okB && okGlobalA && okGlobalB && ...
            okPosX && okPosY && okPosZ && okDefaultsIntact;
    r = check(r, okAll, sprintf( ...
        ['R1: bs.azimuth override: az=0 -> rawAz=%.3f (expect 0); ' ...
         'az=30 -> rawAz=%.3f (expect -30); global az fixed at 0; ' ...
         'defaults intact'], rawA.rawAzDeg, rawB.rawAzDeg));
end

% =====================================================================

function r = r2_rotated_equivalent_geometry(r)
    params  = get_r23_aas_params();
    range_m = 200;

    % Setup A: boresight at 0 deg, UE at global az +30 -> rawAz = +30.
    bsA = get_default_bs();
    bsA.azimuth_deg = 0;
    layoutA = generate_single_sector_layout(bsA, params);
    ueA = make_single_ue(layoutA, 30, range_m);
    rawA   = compute_beam_angles_bs_to_ue(bsA, ueA, params);
    beamsA = clamp_beam_to_r23_coverage(bsA, rawA, params);

    % Setup B: boresight at 45 deg, UE at global az +75 -> rawAz = +30.
    bsB = get_default_bs();
    bsB.azimuth_deg = 45;
    layoutB = generate_single_sector_layout(bsB, params);
    ueB = make_single_ue(layoutB, 75, range_m);
    rawB   = compute_beam_angles_bs_to_ue(bsB, ueB, params);
    beamsB = clamp_beam_to_r23_coverage(bsB, rawB, params);

    okRawAzMatch  = abs(rawA.rawAzDeg - rawB.rawAzDeg) < 1e-9;
    okRawElMatch  = abs(rawA.rawElDeg - rawB.rawElDeg) < 1e-9;
    okSteerAzMatch = abs(beamsA.steerAzDeg - beamsB.steerAzDeg) < 1e-9;
    okSteerElMatch = abs(beamsA.steerElDeg - beamsB.steerElDeg) < 1e-9;
    okRawAzValue  = abs(rawA.rawAzDeg - 30) < 1e-9;

    % Aligned grid point in the sector frame is +30 deg azimuth at the
    % steered elevation. The composite gain and per-beam EIRP at this
    % cell must match across the two equivalent setups.
    steerEl = beamsA.steerElDeg;
    grid = struct('azGridDeg', 30, 'elGridDeg', steerEl);

    gA = compute_bs_gain_toward_grid(bsA, beamsA, grid, params);
    gB = compute_bs_gain_toward_grid(bsB, beamsB, grid, params);

    gainA = squeeze(gA.compositeGainDbi);
    gainB = squeeze(gB.compositeGainDbi);
    okGainMatch = abs(gainA - gainB) < 1e-9;
    okGainFinite = isfinite(gainA) && isfinite(gainB);

    snapA = compute_eirp_grid(bsA, ueA, grid, params, ...
        struct('splitSectorPower', true));
    snapB = compute_eirp_grid(bsB, ueB, grid, params, ...
        struct('splitSectorPower', true));

    eirpA = squeeze(snapA.perBeamEirpDbm);
    eirpB = squeeze(snapB.perBeamEirpDbm);
    okEirpMatch  = abs(eirpA - eirpB) < 1e-9;
    okEirpFinite = isfinite(eirpA) && isfinite(eirpB);

    okAll = okRawAzMatch && okRawElMatch && okSteerAzMatch && ...
            okSteerElMatch && okRawAzValue && okGainMatch && ...
            okGainFinite && okEirpMatch && okEirpFinite;
    r = check(r, okAll, sprintf( ...
        ['R2: rotated equivalence: rawAz=%.3f (both), steerAz=%.3f (both); ' ...
         'gain A=%.6f vs B=%.6f dBi; EIRP A=%.6f vs B=%.6f dBm'], ...
        rawA.rawAzDeg, beamsA.steerAzDeg, gainA, gainB, eirpA, eirpB));
end

% =====================================================================

function r = r3_left_right_symmetry(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    % UE on boresight. Default 200 m / 1.5 m UE / 18 m BS gives a small
    % natural downtilt that sits inside [-10, 0] deg, no clamp.
    ue = make_single_ue(layout, bs.azimuth_deg, 200);
    raw   = compute_beam_angles_bs_to_ue(bs, ue, params);
    beams = clamp_beam_to_r23_coverage(bs, raw, params);

    okBoresight = abs(beams.steerAzDeg) < 1e-9;
    steerEl = beams.steerElDeg;

    % Grid az = [-30, +30] at the steered elevation.
    grid = struct('azGridDeg', [-30, 30], 'elGridDeg', steerEl);

    g = compute_bs_gain_toward_grid(bs, beams, grid, params);
    gainSlice = squeeze(g.compositeGainDbi);   % length 2
    gNeg = gainSlice(1);   % az = -30
    gPos = gainSlice(2);   % az = +30
    okGainSym    = abs(gNeg - gPos) < 1e-9;
    okGainFinite = isfinite(gNeg) && isfinite(gPos);

    snap = compute_eirp_grid(bs, ue, grid, params, ...
        struct('splitSectorPower', true));
    eirpSlice = squeeze(snap.perBeamEirpDbm);
    eNeg = eirpSlice(1);
    ePos = eirpSlice(2);
    okEirpSym    = abs(eNeg - ePos) < 1e-9;
    okEirpFinite = isfinite(eNeg) && isfinite(ePos);

    okAll = okBoresight && okGainSym && okGainFinite && ...
            okEirpSym && okEirpFinite;
    r = check(r, okAll, sprintf( ...
        ['R3: left/right symmetry at +/-30 (steerAz=%.3f, steerEl=%.3f): ' ...
         'gain(-30)=%.6f == gain(+30)=%.6f dBi; ' ...
         'EIRP(-30)=%.6f == EIRP(+30)=%.6f dBm'], ...
        beams.steerAzDeg, steerEl, gNeg, gPos, eNeg, ePos));
end

% =====================================================================

function r = r4_sector_edge_symmetry(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    ue = make_single_ue(layout, bs.azimuth_deg, 200);
    raw   = compute_beam_angles_bs_to_ue(bs, ue, params);
    beams = clamp_beam_to_r23_coverage(bs, raw, params);

    okBoresight = abs(beams.steerAzDeg) < 1e-9;
    steerEl = beams.steerElDeg;

    % Grid az = [-60, 0, +60] at the steered elevation.
    grid = struct('azGridDeg', [-60, 0, 60], 'elGridDeg', steerEl);

    g = compute_bs_gain_toward_grid(bs, beams, grid, params);
    gainSlice = squeeze(g.compositeGainDbi);   % length 3
    gNeg = gainSlice(1);   % az = -60
    gMid = gainSlice(2);   % az =   0 (boresight reference)
    gPos = gainSlice(3);   % az = +60
    okGainSym         = abs(gNeg - gPos) < 1e-9;
    okGainFinite      = all(isfinite(gainSlice));
    okEdgeBelowMid    = (gNeg < gMid - 1e-9) && (gPos < gMid - 1e-9);

    snap = compute_eirp_grid(bs, ue, grid, params, ...
        struct('splitSectorPower', true));
    eirpSlice = squeeze(snap.perBeamEirpDbm);
    eNeg = eirpSlice(1);
    eMid = eirpSlice(2);
    ePos = eirpSlice(3);
    okEirpSym         = abs(eNeg - ePos) < 1e-9;
    okEirpFinite      = all(isfinite(eirpSlice));
    okEdgeBelowMidEirp = (eNeg < eMid - 1e-9) && (ePos < eMid - 1e-9);

    okAll = okBoresight && okGainSym && okGainFinite && ...
            okEdgeBelowMid && okEirpSym && okEirpFinite && ...
            okEdgeBelowMidEirp;
    r = check(r, okAll, sprintf( ...
        ['R4: sector edge symmetry at +/-60 (steerAz=%.3f): ' ...
         'gain(-60)=%.6f == gain(+60)=%.6f, both < gain(0)=%.6f dBi; ' ...
         'EIRP(-60)=%.6f == EIRP(+60)=%.6f, both < EIRP(0)=%.6f dBm'], ...
        beams.steerAzDeg, gNeg, gPos, gMid, eNeg, ePos, eMid));
end

% =====================================================================

function r = r5_deterministic_dimensions(r)
%R5_DETERMINISTIC_DIMENSIONS Re-run the four setups and verify EIRP shapes.

    params  = get_r23_aas_params();
    range_m = 200;

    % --- R1 setup (1 UE, 1 az grid point at boresight) ---
    bsR1 = get_default_bs();
    bsR1.azimuth_deg = 30;
    layoutR1 = generate_single_sector_layout(bsR1, params);
    ueR1 = make_single_ue(layoutR1, 0, range_m);
    rawR1   = compute_beam_angles_bs_to_ue(bsR1, ueR1, params);
    beamsR1 = clamp_beam_to_r23_coverage(bsR1, rawR1, params);
    gridR1  = struct( ...
        'azGridDeg', beamsR1.steerAzDeg(1), ...
        'elGridDeg', beamsR1.steerElDeg(1));
    snapR1 = compute_eirp_grid(bsR1, ueR1, gridR1, params, ...
        struct('splitSectorPower', false));

    okShape1 = size(snapR1.perBeamEirpDbm, 1) == 1 && ...
               size(snapR1.perBeamEirpDbm, 2) == 1 && ...
               size(snapR1.perBeamEirpDbm, 3) == 1 && ...
               isequal(size(snapR1.aggregateEirpDbm),   [1, 1]) && ...
               isequal(size(snapR1.maxEnvelopeEirpDbm), [1, 1]);
    okFinite1 = isfinite(snapR1.aggregateEirpDbm) && ...
                isfinite(snapR1.maxEnvelopeEirpDbm) && ...
                all(isfinite(snapR1.perBeamEirpDbm(:)));

    % --- R2 setup (1 UE, 1 az grid point off boresight) ---
    bsR2 = get_default_bs();
    bsR2.azimuth_deg = 45;
    layoutR2 = generate_single_sector_layout(bsR2, params);
    ueR2 = make_single_ue(layoutR2, 75, range_m);
    rawR2   = compute_beam_angles_bs_to_ue(bsR2, ueR2, params);
    beamsR2 = clamp_beam_to_r23_coverage(bsR2, rawR2, params);
    gridR2  = struct('azGridDeg', 30, 'elGridDeg', beamsR2.steerElDeg(1));
    snapR2 = compute_eirp_grid(bsR2, ueR2, gridR2, params, ...
        struct('splitSectorPower', true));

    okShape2 = size(snapR2.perBeamEirpDbm, 1) == 1 && ...
               size(snapR2.perBeamEirpDbm, 2) == 1 && ...
               size(snapR2.perBeamEirpDbm, 3) == 1 && ...
               isequal(size(snapR2.aggregateEirpDbm),   [1, 1]) && ...
               isequal(size(snapR2.maxEnvelopeEirpDbm), [1, 1]);
    okFinite2 = isfinite(snapR2.aggregateEirpDbm) && ...
                isfinite(snapR2.maxEnvelopeEirpDbm) && ...
                all(isfinite(snapR2.perBeamEirpDbm(:)));

    % --- R3/R4 setup (1 UE on boresight, multi-az grid) ---
    bs     = get_default_bs();
    layout = generate_single_sector_layout(bs, params);
    ue     = make_single_ue(layout, bs.azimuth_deg, 200);
    raw    = compute_beam_angles_bs_to_ue(bs, ue, params);
    beams  = clamp_beam_to_r23_coverage(bs, raw, params);
    grid34 = struct( ...
        'azGridDeg', [-60, -30, 0, 30, 60], ...
        'elGridDeg', beams.steerElDeg);
    snap34 = compute_eirp_grid(bs, ue, grid34, params, ...
        struct('splitSectorPower', true));

    Naz34 = numel(grid34.azGridDeg);
    Nel34 = numel(grid34.elGridDeg);
    okShape34 = size(snap34.perBeamEirpDbm, 1) == Naz34 && ...
                size(snap34.perBeamEirpDbm, 2) == Nel34 && ...
                size(snap34.perBeamEirpDbm, 3) == 1 && ...
                isequal(size(snap34.aggregateEirpDbm),   [Naz34, Nel34]) && ...
                isequal(size(snap34.maxEnvelopeEirpDbm), [Naz34, Nel34]);
    okFinite34 = all(isfinite(snap34.perBeamEirpDbm(:))) && ...
                 all(isfinite(snap34.aggregateEirpDbm(:))) && ...
                 all(isfinite(snap34.maxEnvelopeEirpDbm(:)));

    okAll = okShape1 && okFinite1 && okShape2 && okFinite2 && ...
            okShape34 && okFinite34;
    r = check(r, okAll, sprintf( ...
        ['R5: deterministic dimensions: R1/R2 [1 1 1]/[1 1], ' ...
         'R3/R4 [%d %d 1]/[%d %d]; all finite'], ...
        Naz34, Nel34, Naz34, Nel34));
end

% =====================================================================

function w = wrap_to_180(a)
    w = mod(a + 180, 360) - 180;
    w(w == -180) = 180;
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
