function results = test_imtAasGenerateBeamSet()
%TEST_IMTAASGENERATEBEAMSET Focused unit tests for imtAasGenerateBeamSet.
%
%   RESULTS = test_imtAasGenerateBeamSet()
%
%   Covers:
%       1. N=10 with default sector returns N column vectors for raw and
%          clamped steering and the documented field set.
%       2. Seeded calls are deterministic.
%       3. Clamped output respects sector azLimits and elLimits.
%       4. With opts.applyLimits=false, only the raw fields are populated
%          and steer*/wasClipped fields are absent.
%       5. Explicit opts.azRelDeg / opts.r_m bypass random sampling.
%       6. Invalid N (e.g. N=0) propagates as imtAasSampleUePositions:invalidN.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasGenerateBeamSet ---\n');

    sector = imtAasSingleSectorParams('macroUrban');
    N = 10;

    % ===== 1. shape / field set =====
    b = imtAasGenerateBeamSet(N, sector, struct('seed', 1));
    expected = {'N','ue','sector','rawSteerAzDeg','rawSteerElDeg', ...
                'groundRange_m','slantRange_m','azGlobalDeg', ...
                'steerAzDeg','steerElDeg','wasAzClipped','wasElClipped', ...
                'azLimitsDeg','elLimitsDeg'};
    for k = 1:numel(expected)
        assert(isfield(b, expected{k}), 'missing field "%s"', expected{k});
    end
    cols = {'rawSteerAzDeg','rawSteerElDeg','groundRange_m','slantRange_m', ...
            'azGlobalDeg','steerAzDeg','steerElDeg','wasAzClipped', ...
            'wasElClipped'};
    for k = 1:numel(cols)
        v = b.(cols{k});
        assert(iscolumn(v) && numel(v) == N, ...
            'beam.%s must be %dx1 column', cols{k}, N);
    end
    assert(b.N == N, 'beams.N must equal N');
    fprintf('  [OK] N=%d produces expected field set and shapes\n', N);

    % ===== 2. seeded determinism =====
    b1 = imtAasGenerateBeamSet(N, sector, struct('seed', 11));
    b2 = imtAasGenerateBeamSet(N, sector, struct('seed', 11));
    assert(isequal(b1.steerAzDeg, b2.steerAzDeg) && ...
           isequal(b1.steerElDeg, b2.steerElDeg), ...
        'seeded calls must be deterministic');
    fprintf('  [OK] seeded calls are deterministic\n');

    % ===== 3. clamped output within sector envelope =====
    assert(all(b.steerAzDeg >= sector.azLimitsDeg(1) - 1e-9) && ...
           all(b.steerAzDeg <= sector.azLimitsDeg(2) + 1e-9), ...
        'steerAzDeg outside sector az limits');
    assert(all(b.steerElDeg >= sector.elLimitsDeg(1) - 1e-9) && ...
           all(b.steerElDeg <= sector.elLimitsDeg(2) + 1e-9), ...
        'steerElDeg outside sector el limits');
    fprintf('  [OK] clamped output inside sector envelope\n');

    % ===== 4. applyLimits=false omits steer* / wasClipped fields =====
    bNoClip = imtAasGenerateBeamSet(5, sector, struct( ...
        'seed', 1, 'applyLimits', false));
    assert(~isfield(bNoClip, 'steerAzDeg'), ...
        'steerAzDeg must NOT be present when applyLimits=false');
    assert(~isfield(bNoClip, 'wasAzClipped'), ...
        'wasAzClipped must NOT be present when applyLimits=false');
    assert(isfield(bNoClip, 'rawSteerAzDeg'), ...
        'rawSteerAzDeg must still be present');
    fprintf('  [OK] applyLimits=false omits clipped fields\n');

    % ===== 5. explicit azRelDeg / r_m =====
    explicitAz = [-50; 0; 45];
    explicitR  = [50; 100; 250];
    bExpl = imtAasGenerateBeamSet(3, sector, struct( ...
        'azRelDeg', explicitAz, 'r_m', explicitR));
    assert(isequal(bExpl.ue.azRelDeg, explicitAz), 'explicit az round-trip');
    assert(isequal(bExpl.ue.r_m, explicitR), 'explicit r round-trip');
    fprintf('  [OK] explicit azRelDeg / r_m bypass random draws\n');

    % ===== 6. invalid N propagates =====
    threw = false;
    try
        imtAasGenerateBeamSet(0, sector); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasSampleUePositions:invalidN'), ...
            'expected imtAasSampleUePositions:invalidN, got %s', ...
            err.identifier);
    end
    assert(threw, 'N=0 must error');
    fprintf('  [OK] invalid N (=0) propagates invalidN\n');

    results.passed = true;
    fprintf('--- test_imtAasGenerateBeamSet PASSED ---\n');
end
