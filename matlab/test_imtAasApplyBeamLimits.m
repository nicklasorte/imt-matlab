function results = test_imtAasApplyBeamLimits()
%TEST_IMTAASAPPLYBEAMLIMITS Focused unit tests for imtAasApplyBeamLimits.
%
%   RESULTS = test_imtAasApplyBeamLimits()
%
%   Covers:
%       1. Steering inside [-60, 60] az and [-10, 0] el is unchanged
%          (wasAzClipped / wasElClipped = false).
%       2. raw el < -10 is clipped to -10 with wasElClipped = true.
%       3. raw el > 0 is clipped to 0 with wasElClipped = true.
%       4. raw az < -60 / > 60 is clipped to [-60, 60].
%       5. Output fields steerAzDeg, steerElDeg, wasAzClipped, wasElClipped,
%          azLimitsDeg, elLimitsDeg are populated with matching shapes.
%       6. Sector pass-through via beam.sector (when no sector arg).
%       7. Missing beam input raises imtAasApplyBeamLimits:missingBeam.
%       8. Missing rawSteer fields raises imtAasApplyBeamLimits:missingFields.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasApplyBeamLimits ---\n');

    sector = imtAasSingleSectorParams('macroUrban');

    % ===== 1. inside envelope: no clipping =====
    beamIn = struct( ...
        'rawSteerAzDeg', [0; -45; 50], ...
        'rawSteerElDeg', [-5; -1; 0], ...
        'sector', sector);
    bIn = imtAasApplyBeamLimits(beamIn, sector);
    assert(isequal(bIn.steerAzDeg, beamIn.rawSteerAzDeg), 'az unchanged');
    assert(isequal(bIn.steerElDeg, beamIn.rawSteerElDeg), 'el unchanged');
    assert(~any(bIn.wasAzClipped), 'no az clip flagged');
    assert(~any(bIn.wasElClipped), 'no el clip flagged');
    fprintf('  [OK] inside-envelope inputs pass through unchanged\n');

    % ===== 2. el below -10 is clamped =====
    beamLo = struct( ...
        'rawSteerAzDeg', [0; 0], ...
        'rawSteerElDeg', [-25; -45], ...
        'sector', sector);
    bLo = imtAasApplyBeamLimits(beamLo, sector);
    assert(all(bLo.steerElDeg == -10), 'el clamped to -10');
    assert(all(bLo.wasElClipped), 'el-clip flags set');
    fprintf('  [OK] el < -10 clamped to -10\n');

    % ===== 3. el above 0 is clamped =====
    beamHi = struct( ...
        'rawSteerAzDeg', [0; 0], ...
        'rawSteerElDeg', [5; 12], ...
        'sector', sector);
    bHi = imtAasApplyBeamLimits(beamHi, sector);
    assert(all(bHi.steerElDeg == 0), 'el clamped to 0');
    assert(all(bHi.wasElClipped), 'el-clip flags set');
    fprintf('  [OK] el > 0 clamped to 0\n');

    % ===== 4. az clipped to [-60, 60] =====
    beamAz = struct( ...
        'rawSteerAzDeg', [-90; 75; 30], ...
        'rawSteerElDeg', [-5; -5; -5], ...
        'sector', sector);
    bAz = imtAasApplyBeamLimits(beamAz, sector);
    assert(bAz.steerAzDeg(1) == -60, 'az(-90) -> -60');
    assert(bAz.steerAzDeg(2) ==  60, 'az(75)  ->  60');
    assert(bAz.steerAzDeg(3) ==  30, 'az(30) unchanged');
    assert(bAz.wasAzClipped(1) && bAz.wasAzClipped(2) && ...
           ~bAz.wasAzClipped(3), 'az-clip flags');
    fprintf('  [OK] az clipped to [-60, 60]\n');

    % ===== 5. output field set =====
    expectedFields = {'steerAzDeg','steerElDeg','wasAzClipped', ...
                      'wasElClipped','azLimitsDeg','elLimitsDeg'};
    for k = 1:numel(expectedFields)
        assert(isfield(bAz, expectedFields{k}), ...
            'missing field "%s"', expectedFields{k});
    end
    assert(isequal(size(bAz.steerAzDeg), size(beamAz.rawSteerAzDeg)), ...
        'output shape mismatch');
    assert(isequal(bAz.azLimitsDeg, sector.azLimitsDeg) && ...
           isequal(bAz.elLimitsDeg, sector.elLimitsDeg), ...
        'limits echoed in output');
    fprintf('  [OK] output field set present with matching shape\n');

    % ===== 6. sector pass-through via beam.sector =====
    bPass = imtAasApplyBeamLimits(beamAz);   % no explicit sector arg
    assert(isequal(bPass.azLimitsDeg, sector.azLimitsDeg), ...
        'beam.sector must be used when sector arg omitted');
    fprintf('  [OK] sector pass-through via beam.sector works\n');

    % ===== 7. missing-beam error =====
    threw = false;
    try
        imtAasApplyBeamLimits([]); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasApplyBeamLimits:missingBeam'), ...
            'expected missingBeam, got %s', err.identifier);
    end
    assert(threw, 'empty beam must error');
    fprintf('  [OK] empty beam raises missingBeam\n');

    % ===== 8. missing fields error =====
    threw = false;
    try
        imtAasApplyBeamLimits(struct('foo', 1), sector); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasApplyBeamLimits:missingFields'), ...
            'expected missingFields, got %s', err.identifier);
    end
    assert(threw, 'missing rawSteer fields must error');
    fprintf('  [OK] missing rawSteer fields raise missingFields\n');

    results.passed = true;
    fprintf('--- test_imtAasApplyBeamLimits PASSED ---\n');
end
