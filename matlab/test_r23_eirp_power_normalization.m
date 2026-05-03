function results = test_r23_eirp_power_normalization()
%TEST_R23_EIRP_POWER_NORMALIZATION Deterministic EIRP power-split / aggregation tests.
%
%   RESULTS = test_r23_eirp_power_normalization()
%
%   Locks the R23 single-sector MVP power-accounting contract:
%
%       perBeamPeakEirpDbm = sectorEirpDbm                       (no split)
%       perBeamPeakEirpDbm = sectorEirpDbm - 10*log10(N)         (split)
%       aggregateEirpDbm   = 10*log10(sum(10.^(perBeamEirpDbm/10), 3))
%       maxEnvelopeEirpDbm = max(perBeamEirpDbm, [], 3)
%
%   With those identities in place, the test pins four invariants:
%
%       P1. One UE, splitSectorPower = false, single aligned grid point:
%             - perBeamPeakEirpDbm == bs.eirp_dBm_per_100MHz
%             - aggregateEirpDbm at the aligned cell is finite
%             - output dimensions are [Naz Nel N] / [Naz Nel] as documented
%       P2. Three UEs in the same aligned direction, splitSectorPower = true,
%           single aligned grid point:
%             - perBeamPeakEirpDbm == bs.eirp_dBm_per_100MHz - 10*log10(3)
%             - aggregateEirpDbm at the aligned cell equals the P1 no-split
%               aligned EIRP, within a tight dB tolerance. Three identical
%               beams each carrying 1/3 of the sector budget linearly add
%               back to the full sector EIRP.
%       P3. Sector EIRP override:
%             - run the same one-UE one-cell aligned case with
%               bs.eirp_dBm_per_100MHz = 78.3 and = 75.0
%             - aligned aggregate EIRP shifts by -3.3 dB exactly (the
%               difference of the two overrides)
%             - get_default_bs() defaults are not mutated by either run
%       P4. Three UEs at different azimuths inside the +/-60 deg sector,
%           grid containing each beam direction:
%             - aggregateEirpDbm is finite at every cell
%             - aggregateEirpDbm >= maxEnvelopeEirpDbm at every cell, within
%               tolerance (aggregate is the linear-mW sum across beams, so
%               it can never sit below the per-beam max envelope)
%
%   Scope guard: this file only exercises antenna-face EIRP. There is NO
%   path loss, NO clutter, NO FS / FSS / victim receiver, NO I / N, NO
%   network laydown, NO 19-site / 57-sector aggregation. The aligned UE
%   geometry is the same boresight construction used by the existing
%   ground-truth test (test_r23_ground_truth_antenna_geometry.m) - the
%   200 m / 1.5 m UE sits inside the R23 vertical envelope so no clamp
%   fires and the steered beam coincides with the geometric BS->UE direction.
%
%   Exit contract: RESULTS is a struct with fields .summary (cellstr) and
%   .passed (logical), matching run_all_tests.m.

    results.summary = {};
    results.passed  = true;

    results = p1_one_beam_no_split(results);
    results = p2_three_beam_equal_split(results);
    results = p3_eirp_override(results);
    results = p4_multi_beam_aggregation(results);

    fprintf('\n--- test_r23_eirp_power_normalization summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    fprintf('  %s\n', ifElse(results.passed, ...
        'ALL TESTS PASSED', 'TESTS FAILED'));
end

% =====================================================================

function fix = aligned_fixture(numUes)
%ALIGNED_FIXTURE Boresight UE(s) at (200 m, 0, 1.5) - inside R23 envelope.
%   Returns a fixture with default bs / params / layout, a single aligned
%   grid point at the steered (az, el), and a UE struct of N copies of
%   the boresight UE so each "beam" steers to the exact same direction.
%
%   With N copies all at the same position, every beam shares one steered
%   direction; the only difference between beams is the per-beam EIRP
%   budget after splitSectorPower is applied.

    fix = struct();
    fix.bs     = get_default_bs();
    fix.params = get_r23_aas_params();
    fix.layout = generate_single_sector_layout(fix.bs, fix.params);

    fix.ue = struct();
    fix.ue.x_m         = 200 .* ones(numUes, 1);
    fix.ue.y_m         = zeros(numUes, 1);
    fix.ue.z_m         = fix.layout.ueHeight_m .* ones(numUes, 1);
    fix.ue.r_m         = 200 .* ones(numUes, 1);
    fix.ue.azRelDeg    = zeros(numUes, 1);
    fix.ue.azGlobalDeg = fix.bs.azimuth_deg .* ones(numUes, 1);
    fix.ue.height_m    = fix.ue.z_m;
    fix.ue.slantRange_m = hypot(fix.ue.r_m, ...
        fix.ue.z_m - fix.layout.bsHeight_m);
    fix.ue.N           = numUes;
    fix.ue.layout      = fix.layout;

    raw   = compute_beam_angles_bs_to_ue(fix.bs, fix.ue, fix.params);
    fix.beams = clamp_beam_to_r23_coverage(fix.bs, raw, fix.params);

    % Single aligned grid point at the steered (az, el). All N UEs share
    % the same steered direction, so any of the N steered angles works.
    fix.gridAligned = struct( ...
        'azGridDeg', fix.beams.steerAzDeg(1), ...
        'elGridDeg', fix.beams.steerElDeg(1));
end

% =====================================================================

function r = p1_one_beam_no_split(r)
    fix = aligned_fixture(1);

    snap = compute_eirp_grid(fix.bs, fix.ue, fix.gridAligned, ...
        fix.params, struct('splitSectorPower', false));

    % Use per-dim size() to dodge MATLAB's trailing-singleton stripping
    % (size(zeros(1,1,1)) collapses to [1 1] so isequal(size, [1 1 1])
    % would falsely fail here even though dim 3 logically has length N).
    okShapePerBeam = size(snap.perBeamEirpDbm, 1) == 1 && ...
                     size(snap.perBeamEirpDbm, 2) == 1 && ...
                     size(snap.perBeamEirpDbm, 3) == 1;
    okShapeAgg     = isequal(size(snap.aggregateEirpDbm),   [1, 1]);
    okShapeMax     = isequal(size(snap.maxEnvelopeEirpDbm), [1, 1]);

    okPerBeamPeak  = abs(snap.perBeamPeakEirpDbm - ...
                         fix.bs.eirp_dBm_per_100MHz) < 1e-12;
    okSectorPeak   = abs(snap.sectorEirpDbm - ...
                         fix.bs.eirp_dBm_per_100MHz) < 1e-12;
    okSplitFlag    = (snap.splitSectorPower == false);
    okNumBeams     = (snap.numBeams == 1);

    okAggFinite    = isfinite(snap.aggregateEirpDbm);

    % With one beam and a single aligned grid cell, peak normalisation
    % inside imtAasEirpGrid forces the cell value to equal the per-beam
    % peak. This is the cleanest invariant on aligned aggregate EIRP.
    okAlignedAtPeak = abs(snap.aggregateEirpDbm - ...
                          snap.perBeamPeakEirpDbm) < 1e-9;

    okAll = okShapePerBeam && okShapeAgg && okShapeMax && ...
            okPerBeamPeak && okSectorPeak && okSplitFlag && ...
            okNumBeams && okAggFinite && okAlignedAtPeak;
    r = check(r, okAll, sprintf( ...
        ['P1: 1 UE, no split: perBeamPeak=%.6f, aggAligned=%.6f, ' ...
         'shapes [1 1 1]/[1 1]'], ...
         snap.perBeamPeakEirpDbm, snap.aggregateEirpDbm));
end

% =====================================================================

function r = p2_three_beam_equal_split(r)
    % Reuse the no-split aligned reference for the cross-check.
    fix1 = aligned_fixture(1);
    snap1 = compute_eirp_grid(fix1.bs, fix1.ue, fix1.gridAligned, ...
        fix1.params, struct('splitSectorPower', false));
    refAligned = snap1.aggregateEirpDbm;

    fix3 = aligned_fixture(3);
    snap3 = compute_eirp_grid(fix3.bs, fix3.ue, fix3.gridAligned, ...
        fix3.params, struct('splitSectorPower', true));

    okShapePerBeam = size(snap3.perBeamEirpDbm, 1) == 1 && ...
                     size(snap3.perBeamEirpDbm, 2) == 1 && ...
                     size(snap3.perBeamEirpDbm, 3) == 3;
    okShapeAgg     = isequal(size(snap3.aggregateEirpDbm), [1, 1]);
    okNumBeams     = (snap3.numBeams == 3);
    okSplitFlag    = (snap3.splitSectorPower == true);

    expectedPerBeam = fix3.bs.eirp_dBm_per_100MHz - 10 * log10(3);
    okPerBeamPeak   = abs(snap3.perBeamPeakEirpDbm - expectedPerBeam) < 1e-12;

    % Linear-mW sum of three identical 1/3-power beams returns the full
    % sector EIRP exactly. Compare to the no-split single-beam aligned EIRP.
    okAggMatchesRef = abs(snap3.aggregateEirpDbm - refAligned) < 1e-9;
    okAggFinite     = isfinite(snap3.aggregateEirpDbm);

    okAll = okShapePerBeam && okShapeAgg && okNumBeams && okSplitFlag && ...
            okPerBeamPeak && okAggMatchesRef && okAggFinite;
    r = check(r, okAll, sprintf( ...
        ['P2: 3 UEs aligned, split: perBeamPeak=%.6f (expect %.6f), ' ...
         'aggAligned=%.6f vs ref %.6f'], ...
         snap3.perBeamPeakEirpDbm, expectedPerBeam, ...
         snap3.aggregateEirpDbm, refAligned));
end

% =====================================================================

function r = p3_eirp_override(r)
    defBefore = get_default_bs();

    fix = aligned_fixture(1);

    bsHi = fix.bs;     bsHi.eirp_dBm_per_100MHz = 78.3;
    bsLo = fix.bs;     bsLo.eirp_dBm_per_100MHz = 75.0;

    snapHi = compute_eirp_grid(bsHi, fix.ue, fix.gridAligned, ...
        fix.params, struct('splitSectorPower', false));
    snapLo = compute_eirp_grid(bsLo, fix.ue, fix.gridAligned, ...
        fix.params, struct('splitSectorPower', false));

    okHiFinite = isfinite(snapHi.aggregateEirpDbm);
    okLoFinite = isfinite(snapLo.aggregateEirpDbm);

    expectedDelta = 75.0 - 78.3;   % -3.3 dB
    actualDelta   = snapLo.aggregateEirpDbm - snapHi.aggregateEirpDbm;
    okDelta       = abs(actualDelta - expectedDelta) < 1e-9;

    okHiPerBeam = abs(snapHi.perBeamPeakEirpDbm - 78.3) < 1e-12;
    okLoPerBeam = abs(snapLo.perBeamPeakEirpDbm - 75.0) < 1e-12;

    defAfter = get_default_bs();
    okDefaultsIntact = isequal(defBefore, defAfter);

    okAll = okHiFinite && okLoFinite && okDelta && ...
            okHiPerBeam && okLoPerBeam && okDefaultsIntact;
    r = check(r, okAll, sprintf( ...
        ['P3: EIRP override: aggAligned 78.3 -> 75.0 shifts by %.6f dB ' ...
         '(expect %.6f); defaults intact'], actualDelta, expectedDelta));
end

% =====================================================================

function r = p4_multi_beam_aggregation(r)
    bs     = get_default_bs();
    params = get_r23_aas_params();
    layout = generate_single_sector_layout(bs, params);

    % Three UEs at three distinct azimuths inside the +/- 60 deg sector,
    % all at default UE height and 200 m ground range. Place them at
    % azRel = -30, 0, +30 deg so each beam picks a different steered
    % direction (the small natural downtilt at 200 m / 1.5 m / 18 m BS
    % stays inside the [-10, 0] elevation envelope, no clamp fires).
    azRel = [-30; 0; 30];
    range = 200;
    ue = struct();
    ue.x_m         = range .* cosd(azRel);
    ue.y_m         = range .* sind(azRel);
    ue.z_m         = layout.ueHeight_m .* ones(3, 1);
    ue.r_m         = range .* ones(3, 1);
    ue.azRelDeg    = azRel;
    ue.azGlobalDeg = azRel + bs.azimuth_deg;
    ue.height_m    = ue.z_m;
    ue.slantRange_m = hypot(ue.r_m, ue.z_m - layout.bsHeight_m);
    ue.N           = 3;
    ue.layout      = layout;

    rawBeams = compute_beam_angles_bs_to_ue(bs, ue, params);
    beams    = clamp_beam_to_r23_coverage(bs, rawBeams, params);

    % Grid: the three steered azimuths plus a couple of off-axis points,
    % at the (single) steered elevation (all three UEs are at ground
    % range 200 m and same height, so they share the same rawElDeg, and
    % therefore the same steered elevation, by construction).
    steerAzList = beams.steerAzDeg(:);
    okOneEl = all(abs(beams.steerElDeg - beams.steerElDeg(1)) < 1e-12);
    if ~okOneEl
        r = check(r, false, ...
            'P4: setup error: identical-range / identical-height UEs gave different steerEl');
        return;
    end
    steerEl = beams.steerElDeg(1);
    azGrid = sort(unique([steerAzList(:); -45; 0; 45]).');
    grid = struct('azGridDeg', azGrid, 'elGridDeg', steerEl);

    snap = compute_eirp_grid(bs, ue, grid, params, ...
        struct('splitSectorPower', true));

    Naz = numel(azGrid);
    Nel = 1;
    okShapePerBeam = size(snap.perBeamEirpDbm, 1) == Naz && ...
                     size(snap.perBeamEirpDbm, 2) == Nel && ...
                     size(snap.perBeamEirpDbm, 3) == 3;
    okShapeAgg     = isequal(size(snap.aggregateEirpDbm),   [Naz, Nel]);
    okShapeMax     = isequal(size(snap.maxEnvelopeEirpDbm), [Naz, Nel]);

    okAggFinite = all(isfinite(snap.aggregateEirpDbm(:)));
    okMaxFinite = all(isfinite(snap.maxEnvelopeEirpDbm(:)));

    % aggregate is the linear-mW sum across beams; max-envelope is the
    % per-cell max over beams. So aggregate >= max-envelope in dB at
    % every cell (within fp tolerance). Equality holds where one beam
    % dominates by many dB; strict ">" holds where multiple beams
    % contribute comparable power. Tolerance is in dB.
    diffDb = snap.aggregateEirpDbm - snap.maxEnvelopeEirpDbm;
    okAggGeMax = all(diffDb(:) >= -1e-9);

    okAll = okShapePerBeam && okShapeAgg && okShapeMax && ...
            okAggFinite && okMaxFinite && okAggGeMax;
    r = check(r, okAll, sprintf( ...
        ['P4: 3 UEs at azRel=[-30 0 30]: shapes [%d %d 3]/[%d %d], ' ...
         'aggregate >= max-envelope at every cell (min diff = %.3e dB)'], ...
         Naz, Nel, Naz, Nel, min(diffDb(:))));
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
