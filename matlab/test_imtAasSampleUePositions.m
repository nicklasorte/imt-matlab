function results = test_imtAasSampleUePositions()
%TEST_IMTAASSAMPLEUEPOSITIONS Focused unit tests for imtAasSampleUePositions.
%
%   RESULTS = test_imtAasSampleUePositions()
%
%   Covers:
%       1. N random draws populate the documented column-vector fields
%          with the right length and shape.
%       2. Samples stay inside the sector envelope (r in [rMin, rMax],
%          azRelDeg in azLimitsDeg).
%       3. Seeded sampler is deterministic.
%       4. Seeded sampler restores the caller's RNG state on exit.
%       5. Explicit opts.azRelDeg / opts.r_m bypass random sampling.
%       6. r_m draws are uniform in AREA (r^2 is uniformly distributed
%          between rMin^2 and rMax^2 within statistical tolerance).
%       7. Invalid N raises imtAasSampleUePositions:invalidN.
%       8. azRelDeg out of envelope raises imtAasSampleUePositions:azOutOfRange.
%       9. r_m out of envelope raises imtAasSampleUePositions:rOutOfRange.
%      10. Wrong-length explicit azRelDeg raises imtAasSampleUePositions:badAzLen.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasSampleUePositions ---\n');

    sector = imtAasSingleSectorParams('macroUrban');

    % ===== 1. shape / fields =====
    ue = imtAasSampleUePositions(50, sector, struct('seed', 42));
    requiredFields = {'x_m','y_m','z_m','r_m','azRelDeg','azGlobalDeg', ...
                      'height_m','N','sector'};
    for i = 1:numel(requiredFields)
        assert(isfield(ue, requiredFields{i}), ...
            'missing field "%s"', requiredFields{i});
    end
    assert(ue.N == 50, 'ue.N expected 50');
    for f = {'x_m','y_m','z_m','r_m','azRelDeg','azGlobalDeg','height_m'}
        v = ue.(f{1});
        assert(iscolumn(v) && numel(v) == 50, ...
            'ue.%s must be 50x1 column', f{1});
    end
    fprintf('  [OK] N=50 produces documented column-vector fields\n');

    % ===== 2. envelope =====
    assert(all(ue.r_m >= sector.minUeDistance_m - 1e-9) && ...
           all(ue.r_m <= sector.cellRadius_m + 1e-9), 'r_m out of sector');
    assert(all(ue.azRelDeg >= sector.azLimitsDeg(1) - 1e-9) && ...
           all(ue.azRelDeg <= sector.azLimitsDeg(2) + 1e-9), ...
        'azRelDeg out of sector');
    assert(all(ue.height_m == sector.ueHeight_m), ...
        'height_m must default to sector.ueHeight_m');
    fprintf('  [OK] samples lie inside sector envelope\n');

    % ===== 3. seed determinism =====
    ue1 = imtAasSampleUePositions(20, sector, struct('seed', 7));
    ue2 = imtAasSampleUePositions(20, sector, struct('seed', 7));
    assert(isequal(ue1.x_m, ue2.x_m) && isequal(ue1.azRelDeg, ue2.azRelDeg), ...
        'seeded sampler must be deterministic');
    fprintf('  [OK] seeded sampler deterministic\n');

    % ===== 4. RNG state restoration =====
    rng(123);
    sBefore = rng();
    imtAasSampleUePositions(10, sector, struct('seed', 999));
    sAfter = rng();
    assert(isequal(sBefore.State, sAfter.State), ...
        'sampler with seed must restore caller RNG state');
    fprintf('  [OK] seeded sampler restores caller RNG state\n');

    % ===== 5. explicit azRelDeg / r_m bypass =====
    explicitAz = [-30; 0; 45];
    explicitR  = [50; 100; 300];
    ueExpl = imtAasSampleUePositions(3, sector, struct( ...
        'azRelDeg', explicitAz, 'r_m', explicitR));
    assert(isequal(ueExpl.azRelDeg, explicitAz), 'explicit az must round-trip');
    assert(isequal(ueExpl.r_m, explicitR), 'explicit r must round-trip');
    fprintf('  [OK] explicit azRelDeg / r_m bypass random draws\n');

    % ===== 6. uniform-in-area: r^2 is approx uniform =====
    ueBig = imtAasSampleUePositions(5000, sector, struct('seed', 11));
    rMin = sector.minUeDistance_m; rMax = sector.cellRadius_m;
    u = (ueBig.r_m.^2 - rMin^2) ./ (rMax^2 - rMin^2);
    assert(abs(mean(u) - 0.5) < 0.03, ...
        'r^2 uniform mean expected ~0.5, got %.3f', mean(u));
    fprintf('  [OK] r^2 distribution mean ~0.5 (uniform-in-area)\n');

    % ===== 7. invalid N =====
    threw = false;
    try
        imtAasSampleUePositions(-1, sector); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasSampleUePositions:invalidN'), ...
            'expected invalidN, got %s', err.identifier);
    end
    assert(threw, 'negative N must error');
    fprintf('  [OK] negative N raises invalidN\n');

    % ===== 8. azRelDeg out of range =====
    threw = false;
    try
        imtAasSampleUePositions(2, sector, ...
            struct('azRelDeg', [0; 200], 'r_m', [50; 100])); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, ...
            'imtAasSampleUePositions:azOutOfRange'), ...
            'expected azOutOfRange, got %s', err.identifier);
    end
    assert(threw, 'azRelDeg outside sector must error');
    fprintf('  [OK] azRelDeg outside sector raises azOutOfRange\n');

    % ===== 9. r_m out of range =====
    threw = false;
    try
        imtAasSampleUePositions(2, sector, ...
            struct('azRelDeg', [0; 0], 'r_m', [50; 5000])); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, ...
            'imtAasSampleUePositions:rOutOfRange'), ...
            'expected rOutOfRange, got %s', err.identifier);
    end
    assert(threw, 'r_m outside sector must error');
    fprintf('  [OK] r_m outside sector raises rOutOfRange\n');

    % ===== 10. badAzLen =====
    threw = false;
    try
        imtAasSampleUePositions(3, sector, ...
            struct('azRelDeg', [0; 0])); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasSampleUePositions:badAzLen'), ...
            'expected badAzLen, got %s', err.identifier);
    end
    assert(threw, 'mismatched azRelDeg length must error');
    fprintf('  [OK] mismatched explicit azRelDeg length raises badAzLen\n');

    results.passed = true;
    fprintf('--- test_imtAasSampleUePositions PASSED ---\n');
end
