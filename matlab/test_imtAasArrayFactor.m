function results = test_imtAasArrayFactor()
%TEST_IMTAASARRAYFACTOR Focused unit tests for imtAasArrayFactor.
%
%   RESULTS = test_imtAasArrayFactor()
%
%   Covers:
%       1. Output shape: scalar/scalar -> scalar; vectors -> Naz x Nel.
%       2. Output is real and finite for the default R23 panel + steering
%          inside the legal envelope.
%       3. The peak array factor (over a small az/el grid containing the
%          steered direction in panel frame) approaches
%             10*log10(1 + rho*(N_H*N_V - 1)) + 10*log10(L)
%          which for R23 defaults is ~25.84 dB.
%       4. Out-of-range steering azimuth (|az| > 180) raises
%          imtAasArrayFactor:invalidSteer.
%       5. Out-of-range steering elevation (|el| > 90) raises
%          imtAasArrayFactor:invalidSteer.
%       6. NaN steering raises imtAasArrayFactor:invalidSteer.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasArrayFactor ---\n');

    p = imtAasDefaultParams();

    % ===== 1. shape: scalar / scalar =====
    af = imtAasArrayFactor(0, 0, 0, 0, p);
    assert(isscalar(af), 'scalar/scalar inputs must yield scalar output');
    assert(isreal(af),   'array factor must be real');
    assert(isfinite(af), 'array factor must be finite');
    fprintf('  [OK] scalar/scalar input -> scalar real finite output\n');

    % ===== 2. shape: row vectors -> Naz x Nel =====
    az = -10:5:10;   % 1x5
    el = -5:5:5;     % 1x3
    AF = imtAasArrayFactor(az, el, 0, 0, p);
    assert(isequal(size(AF), [5, 3]), ...
        'vector inputs must yield Naz x Nel = [5,3], got %s', mat2str(size(AF)));
    assert(all(isfinite(AF(:))), 'all array-factor values must be finite');
    fprintf('  [OK] vector input -> Naz x Nel finite output\n');

    % ===== 3. peak value at steered direction =====
    % To make the theoretical peak land exactly at (0, 0), zero the fixed
    % sub-array electrical downtilt; otherwise the sub-array factor's
    % peak elevation is offset by subarrayDowntiltDeg.
    pFlat = p;
    pFlat.subarrayDowntiltDeg = 0;
    azFine = -2:0.25:2;
    elFine = -2:0.25:2;
    AF0 = imtAasArrayFactor(azFine, elFine, 0, 0, pFlat);
    expectedPeakDb = 10*log10(1 + pFlat.rho * ...
                              (pFlat.numColumns * pFlat.numRows - 1)) ...
                   + 10*log10(pFlat.numElementsPerSubarray);
    peakDb = max(AF0(:));
    assert(abs(peakDb - expectedPeakDb) < 0.05, ...
        'peak array factor %.4f dB vs expected %.4f dB', ...
        peakDb, expectedPeakDb);
    fprintf('  [OK] peak array factor ~%.3f dB matches theory %.3f dB\n', ...
        peakDb, expectedPeakDb);

    % ===== 4. out-of-range steering azimuth =====
    threw = false;
    try
        imtAasArrayFactor(0, 0, 200, 0, p); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasArrayFactor:invalidSteer'), ...
            'expected imtAasArrayFactor:invalidSteer, got %s', err.identifier);
    end
    assert(threw, 'out-of-range steer az must error');
    fprintf('  [OK] steerAz outside [-180,180] raises invalidSteer\n');

    % ===== 5. out-of-range steering elevation =====
    threw = false;
    try
        imtAasArrayFactor(0, 0, 0, 95, p); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasArrayFactor:invalidSteer'), ...
            'expected imtAasArrayFactor:invalidSteer, got %s', err.identifier);
    end
    assert(threw, 'out-of-range steer el must error');
    fprintf('  [OK] steerEl outside [-90,90] raises invalidSteer\n');

    % ===== 6. NaN steering rejected =====
    threw = false;
    try
        imtAasArrayFactor(0, 0, NaN, 0, p); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasArrayFactor:invalidSteer'), ...
            'expected imtAasArrayFactor:invalidSteer, got %s', err.identifier);
    end
    assert(threw, 'NaN steer must error');
    fprintf('  [OK] NaN steering raises invalidSteer\n');

    results.passed = true;
    fprintf('--- test_imtAasArrayFactor PASSED ---\n');
end
