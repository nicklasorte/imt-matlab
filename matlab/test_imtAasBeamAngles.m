function results = test_imtAasBeamAngles()
%TEST_IMTAASBEAMANGLES Self tests for the UE-driven AAS beam angle layer.
%
%   RESULTS = test_imtAasBeamAngles()
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed  logical
%       .skipped false
%       .reason  ''
%
%   Covers:
%     1. imtAasSingleSectorParams macroUrban / macroSuburban defaults.
%     2. unknown deployment errors clearly.
%     3. imtAasSampleUePositions deterministic with fixed seed and
%        respects [r_min, r_max] / az limits.
%     4. seeded sampler does not perturb caller RNG state.
%     5. imtAasUeToBeamAngles agrees with the analytic
%        atan2d(dz, r) elevation for a UE at (r=400 m, az=0 deg).
%     6. close UE at r = 35 m gives more negative raw elevation than
%        far UE at r = 400 m.
%     7. imtAasApplyBeamLimits clips elevation below -10 to -10.
%     8. imtAasApplyBeamLimits clips azimuth outside +/-60 deg.
%     9. imtAasGenerateBeamSet returns N column-vector beams.
%    10. no NaN / Inf in normal generated outputs.
%    11. clipped beams plug into imtAasEirpGrid and still peak at
%        78.3 dBm / 100 MHz.

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasBeamAngles ---\n');

    % ===== 1. macroUrban / macroSuburban defaults =====
    sUrban = imtAasSingleSectorParams();   % default = macroUrban
    assert(strcmp(sUrban.deployment, 'macroUrban'), ...
        'default deployment must be macroUrban');
    assert(sUrban.bsHeight_m == 18, 'macroUrban bsHeight_m expected 18');
    assert(sUrban.cellRadius_m == 400, 'macroUrban cellRadius_m expected 400');
    assert(sUrban.minUeDistance_m == 35, 'minUeDistance_m expected 35');
    assert(isequal(sUrban.azLimitsDeg, [-60 60]), 'azLimitsDeg expected [-60 60]');
    assert(isequal(sUrban.elLimitsDeg, [-10 0]), 'elLimitsDeg expected [-10 0]');
    assert(sUrban.boresightAzDeg == 0, 'boresightAzDeg expected 0');
    assert(sUrban.sectorWidthDeg == 120, 'sectorWidthDeg expected 120');
    assert(sUrban.ueHeight_m == 1.5, 'ueHeight_m expected 1.5');
    assert(isfield(sUrban, 'params') && isstruct(sUrban.params), ...
        'sector.params expected to be the AAS params struct');
    fprintf('  [OK] macroUrban defaults\n');

    sSub = imtAasSingleSectorParams('macroSuburban');
    assert(strcmp(sSub.deployment, 'macroSuburban'), 'tag expected macroSuburban');
    assert(sSub.bsHeight_m == 20, 'macroSuburban bsHeight_m expected 20');
    assert(sSub.cellRadius_m == 800, 'macroSuburban cellRadius_m expected 800');
    fprintf('  [OK] macroSuburban defaults\n');

    % ===== 2. unknown deployment fails clearly =====
    threw = false;
    try
        imtAasSingleSectorParams('macroFestival'); %#ok<NASGU>
    catch err
        threw = true;
        assert(contains(err.identifier, 'unknownDeployment'), ...
            'expected error id to mention unknownDeployment, got %s', ...
            err.identifier);
    end
    assert(threw, 'expected unknown deployment to error');
    fprintf('  [OK] unknown deployment errors clearly\n');

    % ===== 3. seeded sampler is deterministic / respects sector limits =====
    sector = imtAasSingleSectorParams('macroUrban');
    ue1 = imtAasSampleUePositions(50, sector, struct('seed', 42));
    ue2 = imtAasSampleUePositions(50, sector, struct('seed', 42));
    assert(isequal(ue1.x_m, ue2.x_m) && isequal(ue1.y_m, ue2.y_m) && ...
           isequal(ue1.r_m, ue2.r_m) && isequal(ue1.azRelDeg, ue2.azRelDeg), ...
        'seeded sampler must be deterministic');
    assert(iscolumn(ue1.x_m) && iscolumn(ue1.y_m) && iscolumn(ue1.r_m), ...
        'sampler outputs must be column vectors');
    assert(numel(ue1.r_m) == 50, 'expected 50 UEs');
    assert(all(ue1.r_m >= sector.minUeDistance_m - 1e-9) && ...
           all(ue1.r_m <= sector.cellRadius_m + 1e-9), ...
        'r_m out of [%g, %g]', sector.minUeDistance_m, sector.cellRadius_m);
    assert(all(ue1.azRelDeg >= sector.azLimitsDeg(1) - 1e-9) && ...
           all(ue1.azRelDeg <= sector.azLimitsDeg(2) + 1e-9), ...
        'azRelDeg out of sector limits');
    fprintf('  [OK] seeded sampler deterministic and within sector limits\n');

    % ===== 4. seeded sampler restores caller RNG state =====
    rng(7);
    before = rng();
    ueIgnored = imtAasSampleUePositions(10, sector, struct('seed', 99)); %#ok<NASGU>
    after = rng();
    assert(isequal(before.Type, after.Type) && ...
           isequal(before.Seed, after.Seed) && ...
           isequal(before.State, after.State), ...
        'seeded sampler must restore caller RNG state');
    fprintf('  [OK] seeded sampler restores caller RNG state\n');

    % ===== 5. explicit (r=400, az=0) elevation matches atan2d(dz, r) =====
    ueAxis = imtAasSampleUePositions(1, sector, struct( ...
        'azRelDeg', 0, 'r_m', 400));
    beamAxis = imtAasUeToBeamAngles(ueAxis, sector);
    expectedEl = atan2d(sector.ueHeight_m - sector.bsHeight_m, 400);
    assert(abs(beamAxis.rawSteerElDeg - expectedEl) < 1e-9, ...
        'expected raw el %.6f deg, got %.6f deg', ...
        expectedEl, beamAxis.rawSteerElDeg);
    assert(abs(beamAxis.rawSteerAzDeg) < 1e-9, ...
        'raw az should be 0 for boresight UE');
    fprintf('  [OK] raw el(r=400 m, az=0) = atan2d(%.1f, 400) = %.4f deg\n', ...
        sector.ueHeight_m - sector.bsHeight_m, expectedEl);

    % ===== 6. close UE at 35 m has more negative raw el than far UE =====
    ueClose = imtAasSampleUePositions(1, sector, struct('azRelDeg', 0, 'r_m', 35));
    beamClose = imtAasUeToBeamAngles(ueClose, sector);
    assert(beamClose.rawSteerElDeg < beamAxis.rawSteerElDeg - 1e-6, ...
        ['close UE elevation (%.4f) should be more negative than ' ...
         'far UE elevation (%.4f)'], ...
        beamClose.rawSteerElDeg, beamAxis.rawSteerElDeg);
    fprintf('  [OK] close UE el (%.3f deg) < far UE el (%.3f deg)\n', ...
        beamClose.rawSteerElDeg, beamAxis.rawSteerElDeg);

    % ===== 7. apply-limits clips el below -10 to -10 =====
    rawBeam = struct( ...
        'rawSteerAzDeg', [0; 0], ...
        'rawSteerElDeg', [-25; 5], ...
        'sector', sector);
    clipped = imtAasApplyBeamLimits(rawBeam, sector);
    assert(abs(clipped.steerElDeg(1) - (-10)) < 1e-12, ...
        'expected steerElDeg(1) clipped to -10, got %g', clipped.steerElDeg(1));
    assert(clipped.wasElClipped(1), 'expected wasElClipped(1) true');
    assert(abs(clipped.steerElDeg(2) - 0) < 1e-12, ...
        'expected steerElDeg(2) clipped to 0, got %g', clipped.steerElDeg(2));
    assert(clipped.wasElClipped(2), 'expected wasElClipped(2) true');
    fprintf('  [OK] elevation clipping at [-10, 0]\n');

    % ===== 8. apply-limits clips az outside +/-60 deg =====
    rawBeamAz = struct( ...
        'rawSteerAzDeg', [-90; 75; 30], ...
        'rawSteerElDeg', [-5;  -5; -5], ...
        'sector', sector);
    clippedAz = imtAasApplyBeamLimits(rawBeamAz, sector);
    assert(abs(clippedAz.steerAzDeg(1) - (-60)) < 1e-12, ...
        'expected -90 clipped to -60');
    assert(clippedAz.wasAzClipped(1), 'expected -90 flagged clipped');
    assert(abs(clippedAz.steerAzDeg(2) - 60) < 1e-12, ...
        'expected 75 clipped to 60');
    assert(clippedAz.wasAzClipped(2), 'expected 75 flagged clipped');
    assert(abs(clippedAz.steerAzDeg(3) - 30) < 1e-12, ...
        'expected 30 unchanged');
    assert(~clippedAz.wasAzClipped(3), 'expected 30 not flagged clipped');
    fprintf('  [OK] azimuth clipping at [-60, 60]\n');

    % ===== 9. imtAasGenerateBeamSet returns N column vectors =====
    N = 100;
    beams = imtAasGenerateBeamSet(N, sector, struct('seed', 1));
    assert(beams.N == N, 'expected N=%d, got %d', N, beams.N);
    fields = {'rawSteerAzDeg', 'rawSteerElDeg', ...
              'steerAzDeg', 'steerElDeg', ...
              'wasAzClipped', 'wasElClipped', ...
              'groundRange_m', 'slantRange_m', 'azGlobalDeg'};
    for i = 1:numel(fields)
        v = beams.(fields{i});
        assert(iscolumn(v) && numel(v) == N, ...
            'beams.%s expected Nx1 column vector, got size %s', ...
            fields{i}, mat2str(size(v)));
    end
    assert(all(beams.steerAzDeg >= sector.azLimitsDeg(1) - 1e-9) && ...
           all(beams.steerAzDeg <= sector.azLimitsDeg(2) + 1e-9), ...
        'steerAzDeg out of clamped range');
    assert(all(beams.steerElDeg >= sector.elLimitsDeg(1) - 1e-9) && ...
           all(beams.steerElDeg <= sector.elLimitsDeg(2) + 1e-9), ...
        'steerElDeg out of clamped range');
    fprintf('  [OK] generateBeamSet returns N=%d column vectors\n', N);

    % ===== 10. no NaN / Inf in normal outputs =====
    for i = 1:numel(fields)
        v = beams.(fields{i});
        assert(all(isfinite(v)), 'beams.%s contains non-finite values', ...
            fields{i});
    end
    ueFields = {'x_m', 'y_m', 'z_m', 'r_m', 'azRelDeg', 'azGlobalDeg', ...
                'height_m'};
    for i = 1:numel(ueFields)
        v = beams.ue.(ueFields{i});
        assert(all(isfinite(v)), 'beams.ue.%s has non-finite values', ...
            ueFields{i});
    end
    fprintf('  [OK] no NaN / Inf in normal outputs\n');

    % ===== 11. (clipped) beams produce 78.3 dBm peak EIRP =====
    azGridDeg = -180:2:180;
    elGridDeg =  -90:2:90;
    p = sector.params;
    pickIdxs = unique([1, ceil(N/2), N]);
    clippedIdx = find(beams.wasElClipped, 1);
    if ~isempty(clippedIdx)
        pickIdxs = unique([pickIdxs, clippedIdx]);
    end
    % Always include an explicitly clipped beam: a UE at r = 35 m on
    % boresight raw-elevates to -26.6 deg and is clipped to -10 deg, so
    % the resulting EIRP grid must still peak at sectorEirpDbm.
    forcedBeams = imtAasGenerateBeamSet(1, sector, struct( ...
        'azRelDeg', 0, 'r_m', sector.minUeDistance_m));
    assert(forcedBeams.wasElClipped(1), ...
        'forced close UE on boresight should be el-clipped');
    forcedEirp = imtAasEirpGrid(azGridDeg, elGridDeg, ...
        forcedBeams.steerAzDeg(1), forcedBeams.steerElDeg(1), ...
        p.sectorEirpDbm, p);
    forcedPeak = max(forcedEirp(:));
    assert(abs(forcedPeak - p.sectorEirpDbm) < 1e-9, ...
        'forced clipped beam EIRP peak %.6f != %.6f', ...
        forcedPeak, p.sectorEirpDbm);

    for idx = pickIdxs(:).'
        eirp = imtAasEirpGrid(azGridDeg, elGridDeg, ...
            beams.steerAzDeg(idx), beams.steerElDeg(idx), ...
            p.sectorEirpDbm, p);
        peak = max(eirp(:));
        assert(abs(peak - p.sectorEirpDbm) < 1e-9, ...
            ['EIRP peak %.6f != sectorEirpDbm %.6f for beam idx=%d ' ...
             '(steerAz=%.3f, steerEl=%.3f)'], ...
            peak, p.sectorEirpDbm, idx, ...
            beams.steerAzDeg(idx), beams.steerElDeg(idx));
    end
    fprintf('  [OK] clipped beams still peak at %.1f dBm/100MHz via imtAasEirpGrid\n', ...
        p.sectorEirpDbm);

    results.passed = true;
    fprintf('--- test_imtAasBeamAngles PASSED ---\n');
end
