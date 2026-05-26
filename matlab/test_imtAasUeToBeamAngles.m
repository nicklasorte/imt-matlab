function results = test_imtAasUeToBeamAngles()
%TEST_IMTAASUETOBEAMANGLES Focused unit tests for imtAasUeToBeamAngles.
%
%   RESULTS = test_imtAasUeToBeamAngles()
%
%   Covers:
%       1. UE on boresight at horizontal distance r has
%             rawSteerElDeg = atan2d(ueHeight - bsHeight, r)
%             rawSteerAzDeg = 0.
%       2. UE off-boresight gives non-zero raw azimuth and the analytic
%          atan2d-derived elevation.
%       3. Closer UEs have more-negative raw elevation than far UEs
%          (steeper downtilt as range decreases).
%       4. groundRange_m, slantRange_m, azGlobalDeg are populated as
%          column vectors of length ue.N with finite values.
%       5. azGlobalDeg = sector.boresightAzDeg + ue.azRelDeg (mod 360).
%       6. Pass-through fields ue and sector are present.
%       7. Missing UE input raises imtAasUeToBeamAngles:missingUe.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasUeToBeamAngles ---\n');

    sector = imtAasSingleSectorParams('macroUrban');

    % ===== 1. boresight UE: az = 0, el = atan2d =====
    ueOnAxis = imtAasSampleUePositions(1, sector, ...
        struct('azRelDeg', 0, 'r_m', 400));
    beam = imtAasUeToBeamAngles(ueOnAxis, sector);
    expectedEl = atan2d(sector.ueHeight_m - sector.bsHeight_m, 400);
    assert(abs(beam.rawSteerElDeg - expectedEl) < 1e-9, ...
        'on-axis raw el expected %.6f, got %.6f', ...
        expectedEl, beam.rawSteerElDeg);
    assert(abs(beam.rawSteerAzDeg) < 1e-9, ...
        'on-axis raw az expected 0');
    fprintf('  [OK] boresight UE at r=400 gives az=0, el=%.4f deg\n', expectedEl);

    % ===== 2. off-boresight UE =====
    ueOff = imtAasSampleUePositions(1, sector, ...
        struct('azRelDeg', 30, 'r_m', 200));
    beamOff = imtAasUeToBeamAngles(ueOff, sector);
    assert(abs(beamOff.rawSteerAzDeg - 30) < 1e-9, ...
        'off-axis raw az expected 30 deg, got %.6f', beamOff.rawSteerAzDeg);
    expectedElOff = atan2d(sector.ueHeight_m - sector.bsHeight_m, 200);
    assert(abs(beamOff.rawSteerElDeg - expectedElOff) < 1e-9, ...
        'off-axis raw el mismatch: %.6f vs %.6f', ...
        beamOff.rawSteerElDeg, expectedElOff);
    fprintf('  [OK] off-axis UE gives raw az=30, el=%.4f deg\n', expectedElOff);

    % ===== 3. closer = more-negative elevation =====
    ueClose = imtAasSampleUePositions(1, sector, ...
        struct('azRelDeg', 0, 'r_m', 35));
    beamClose = imtAasUeToBeamAngles(ueClose, sector);
    assert(beamClose.rawSteerElDeg < beam.rawSteerElDeg - 1e-6, ...
        'close UE el (%.4f) should be more negative than far UE el (%.4f)', ...
        beamClose.rawSteerElDeg, beam.rawSteerElDeg);
    fprintf('  [OK] close UE el (%.3f) < far UE el (%.3f)\n', ...
        beamClose.rawSteerElDeg, beam.rawSteerElDeg);

    % ===== 4. column-vector shape and finite values =====
    ueMany = imtAasSampleUePositions(10, sector, struct('seed', 1));
    beamMany = imtAasUeToBeamAngles(ueMany, sector);
    cols = {'rawSteerAzDeg','rawSteerElDeg','groundRange_m','slantRange_m', ...
            'azGlobalDeg'};
    for k = 1:numel(cols)
        v = beamMany.(cols{k});
        assert(iscolumn(v) && numel(v) == 10, ...
            'beam.%s must be 10x1 column', cols{k});
        assert(all(isfinite(v)), 'beam.%s has non-finite entries', cols{k});
    end
    assert(all(beamMany.slantRange_m >= beamMany.groundRange_m - 1e-9), ...
        'slantRange must be >= groundRange');
    fprintf('  [OK] 10x1 column outputs, all finite, slant >= ground\n');

    % ===== 5. azGlobalDeg = boresightAzDeg + azRelDeg =====
    expGlobal = sector.boresightAzDeg + ueMany.azRelDeg;
    deltaDeg = mod(beamMany.azGlobalDeg - expGlobal + 180, 360) - 180;
    assert(all(abs(deltaDeg) < 1e-9), ...
        'azGlobalDeg should equal boresightAzDeg + azRelDeg (mod 360)');
    fprintf('  [OK] azGlobalDeg matches boresight + azRelDeg\n');

    % ===== 6. pass-through fields =====
    assert(isfield(beamMany, 'ue') && isfield(beamMany, 'sector'), ...
        'ue / sector pass-through required');
    fprintf('  [OK] ue / sector pass-through present\n');

    % ===== 7. missing-input error =====
    threw = false;
    try
        imtAasUeToBeamAngles([], sector); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasUeToBeamAngles:missingUe'), ...
            'expected missingUe, got %s', err.identifier);
    end
    assert(threw, 'empty UE must error');
    fprintf('  [OK] empty UE input raises missingUe\n');

    results.passed = true;
    fprintf('--- test_imtAasUeToBeamAngles PASSED ---\n');
end
