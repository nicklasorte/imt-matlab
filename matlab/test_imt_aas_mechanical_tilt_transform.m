function results = test_imt_aas_mechanical_tilt_transform()
%TEST_IMT_AAS_MECHANICAL_TILT_TRANSFORM Focused tests for the y-axis rotation.
%
%   RESULTS = test_imt_aas_mechanical_tilt_transform()
%
%   Covers:
%       1. zero tilt is the identity (az, el) -> (az, el).
%       2. A 6 deg downtilt maps a global (az, el) = (0, -6) to panel
%          (0, 0) within numerical tolerance (the R23 default).
%       3. Inverse property: rotating by +tilt and then by -tilt restores
%          the original direction.
%       4. Output az is wrapped into [-180, 180] and el into [-90, 90].
%       5. Vectorized over same-shape inputs (shape-preserving).
%       6. Non-finite or non-scalar tilt raises validateattributes-style
%          error (MATLAB:expected* identifier prefix).
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imt_aas_mechanical_tilt_transform ---\n');

    tol = 1e-9;

    % ===== 1. zero tilt = identity =====
    az = [-30, 0, 45, 120];
    el = [-10,  0,  5, -45];
    [azP, elP] = imt_aas_mechanical_tilt_transform(az, el, 0);
    assert(all(abs(azP - az) < tol), 'zero tilt must preserve az');
    assert(all(abs(elP - el) < tol), 'zero tilt must preserve el');
    fprintf('  [OK] zero tilt is identity\n');

    % ===== 2. R23 default 6 deg tilt brings global (0,-6) to panel (0,0) =====
    [azP, elP] = imt_aas_mechanical_tilt_transform(0, -6, 6);
    assert(abs(azP) < tol, 'panel az expected ~0 deg (got %g)', azP);
    assert(abs(elP) < tol, 'panel el expected ~0 deg (got %g)', elP);
    fprintf('  [OK] global (0,-6) maps to panel (0,0) under 6 deg tilt\n');

    % ===== 3. inverse property: +t then -t restores =====
    az0 = [-50, 10, 80];
    el0 = [-15,  0, 20];
    [a1, e1] = imt_aas_mechanical_tilt_transform(az0, el0, 6);
    [a2, e2] = imt_aas_mechanical_tilt_transform(a1, e1, -6);
    assert(all(abs(a2 - az0) < 1e-9), 'az did not invert');
    assert(all(abs(e2 - el0) < 1e-9), 'el did not invert');
    fprintf('  [OK] +tilt then -tilt restores input direction\n');

    % ===== 4. output ranges =====
    azGrid = linspace(-180, 180, 37);
    elGrid = linspace( -90,  90, 19);
    [AZ, EL] = ndgrid(azGrid, elGrid);
    [azP, elP] = imt_aas_mechanical_tilt_transform(AZ, EL, 6);
    assert(all(azP(:) >= -180 - tol) && all(azP(:) <= 180 + tol), ...
        'panel az must lie in [-180, 180]');
    assert(all(elP(:) >= -90  - tol) && all(elP(:) <= 90  + tol), ...
        'panel el must lie in [-90, 90]');
    assert(isequal(size(azP), size(AZ)), 'output shape must match input');
    fprintf('  [OK] output az in [-180,180], el in [-90,90], shape preserved\n');

    % ===== 5. vectorized shape preservation (column vectors) =====
    [azP, elP] = imt_aas_mechanical_tilt_transform([1;2;3], [-1;-2;-3], 4);
    assert(isequal(size(azP), [3,1]) && isequal(size(elP), [3,1]), ...
        'column-vector inputs must yield column-vector outputs');
    fprintf('  [OK] column-vector shape preserved\n');

    % ===== 6. invalid tilt argument =====
    threw = false;
    try
        imt_aas_mechanical_tilt_transform(0, 0, NaN); %#ok<NASGU>
    catch err
        threw = true;
        % validateattributes raises 'MATLAB:expected*' identifiers.
        assert(~isempty(err.identifier), ...
            'expected non-empty error identifier for NaN tilt');
    end
    assert(threw, 'NaN tilt must error');
    fprintf('  [OK] non-finite tilt is rejected\n');

    threw = false;
    try
        imt_aas_mechanical_tilt_transform(0, 0, [1 2]); %#ok<NASGU>
    catch err
        threw = true;
        assert(~isempty(err.identifier), ...
            'expected non-empty error identifier for non-scalar tilt');
    end
    assert(threw, 'non-scalar tilt must error');
    fprintf('  [OK] non-scalar tilt is rejected\n');

    results.passed = true;
    fprintf('--- test_imt_aas_mechanical_tilt_transform PASSED ---\n');
end
