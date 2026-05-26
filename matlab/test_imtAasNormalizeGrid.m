function results = test_imtAasNormalizeGrid()
%TEST_IMTAASNORMALIZEGRID Focused unit tests for imtAasNormalizeGrid.
%
%   RESULTS = test_imtAasNormalizeGrid()
%
%   Covers:
%       1. Scalar / scalar input -> scalar / scalar (no broadcasting).
%       2. Two row vectors of distinct lengths -> Naz x Nel ndgrid.
%       3. Two row vectors of the SAME length -> Naz x Nel ndgrid
%          (independent axes; documented behavior).
%       4. Two 2-D arrays of the same shape -> pass-through (no
%          re-meshing).
%       5. NaN / Inf input raises imtAas:invalidGrid.
%       6. 3-D input raises imtAas:invalidGrid.
%       7. Non-numeric input raises imtAas:invalidGrid.
%       8. Mismatched 2-D shapes raise imtAas:gridSizeMismatch.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasNormalizeGrid ---\n');

    % ===== 1. scalar / scalar =====
    [AZ, EL] = imtAasNormalizeGrid(5, -3);
    assert(isscalar(AZ) && isscalar(EL), 'scalar inputs must remain scalar');
    assert(AZ == 5 && EL == -3, 'scalar values must round-trip exactly');
    fprintf('  [OK] scalar/scalar pass-through\n');

    % ===== 2. distinct-length row vectors -> ndgrid =====
    az = -10:5:10;   % 1x5
    el = -5:5:5;     % 1x3
    [AZ, EL] = imtAasNormalizeGrid(az, el);
    assert(isequal(size(AZ), [5, 3]), 'AZ shape expected [5,3]');
    assert(isequal(size(EL), [5, 3]), 'EL shape expected [5,3]');
    assert(all(AZ(:, 1) == az(:)), 'AZ rows must equal az axis');
    assert(all(EL(1, :) == el), 'EL columns must equal el axis');
    fprintf('  [OK] distinct-length vectors ndgrid to Naz x Nel\n');

    % ===== 3. same-length row vectors -> ndgrid (independent axes) =====
    same = [-1 0 1];
    [AZ, EL] = imtAasNormalizeGrid(same, same);
    assert(isequal(size(AZ), [3, 3]), ...
        'same-length row vectors must still ndgrid');
    fprintf('  [OK] same-length row vectors ndgrid to NxN\n');

    % ===== 4. matching 2-D arrays pass through =====
    A = [1 2; 3 4];
    B = [5 6; 7 8];
    [AZ, EL] = imtAasNormalizeGrid(A, B);
    assert(isequal(AZ, A) && isequal(EL, B), ...
        'matching 2-D arrays must be pass-through');
    fprintf('  [OK] matching 2-D arrays pass-through\n');

    % ===== 5. NaN / Inf rejection =====
    threw = false;
    try
        imtAasNormalizeGrid([1 NaN 3], [1 2 3]); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAas:invalidGrid'), ...
            'expected imtAas:invalidGrid, got %s', err.identifier);
    end
    assert(threw, 'NaN input must error');
    fprintf('  [OK] NaN / Inf inputs raise imtAas:invalidGrid\n');

    % ===== 6. 3-D input rejection =====
    threw = false;
    try
        imtAasNormalizeGrid(ones(2,2,2), ones(2,2,2)); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAas:invalidGrid'), ...
            'expected imtAas:invalidGrid, got %s', err.identifier);
    end
    assert(threw, '3-D input must error');
    fprintf('  [OK] 3-D inputs raise imtAas:invalidGrid\n');

    % ===== 7. non-numeric rejection =====
    threw = false;
    try
        imtAasNormalizeGrid('abc', [1 2 3]); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAas:invalidGrid'), ...
            'expected imtAas:invalidGrid, got %s', err.identifier);
    end
    assert(threw, 'non-numeric input must error');
    fprintf('  [OK] non-numeric inputs raise imtAas:invalidGrid\n');

    % ===== 8. mismatched 2-D shapes rejection =====
    threw = false;
    try
        imtAasNormalizeGrid([1 2; 3 4], [1 2 3; 4 5 6]); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAas:gridSizeMismatch'), ...
            'expected imtAas:gridSizeMismatch, got %s', err.identifier);
    end
    assert(threw, 'mismatched 2-D shapes must error');
    fprintf('  [OK] mismatched 2-D shapes raise imtAas:gridSizeMismatch\n');

    results.passed = true;
    fprintf('--- test_imtAasNormalizeGrid PASSED ---\n');
end
