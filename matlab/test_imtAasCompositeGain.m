function results = test_imtAasCompositeGain()
%TEST_IMTAASCOMPOSITEGAIN Focused unit tests for imtAasCompositeGain.
%
%   RESULTS = test_imtAasCompositeGain()
%
%   Covers:
%       1. With NO mechanical tilt and steering at (0, 0), the composite
%          gain peak over a small az/el grid approaches the R23 reference
%          peak gain of 32.2 dBi (within ~0.1 dB).
%       2. compositeGain = elementPattern + arrayFactor (in dB) at any
%          given panel-frame direction (sanity additive decomposition).
%       3. Output shape: scalar/scalar -> scalar; vectors -> Naz x Nel.
%       4. Output is real and finite over the legal grid.
%       5. Mechanical downtilt = 6 deg shifts the panel-frame peak so that
%          the sector-frame peak occurs at el = -6 deg (R23 default
%          downtilt).
%       6. Invalid steering azimuth raises imtAasCompositeGain:invalidSteer.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasCompositeGain ---\n');

    p = imtAasDefaultParams();

    % ===== 1. peak ~ 32.2 dBi at boresight, no tilt =====
    pNoTilt = p;
    pNoTilt.mechanicalDowntiltDeg = 0;
    pNoTilt.subarrayDowntiltDeg   = 0;
    azFine = -2:0.25:2;
    elFine = -2:0.25:2;
    G = imtAasCompositeGain(azFine, elFine, 0, 0, pNoTilt);
    peak = max(G(:));
    expectedPeak = pNoTilt.elementGainDbi ...
        + 10*log10(1 + pNoTilt.rho * ...
            (pNoTilt.numColumns * pNoTilt.numRows - 1)) ...
        + 10*log10(pNoTilt.numElementsPerSubarray);
    assert(abs(peak - expectedPeak) < 0.05, ...
        'composite peak %.4f dBi vs expected %.4f dBi', peak, expectedPeak);
    fprintf('  [OK] composite peak %.3f dBi matches G_E + AF theory %.3f dBi\n', ...
        peak, expectedPeak);

    % ===== 2. additive decomposition at a sample direction =====
    pNoMech = pNoTilt;
    azS = 0; elS = 0;
    azT = 1; elT = -2;
    gEl   = imtAasElementPattern(azT, elT, pNoMech);
    gArr  = imtAasArrayFactor(azT, elT, azS, elS, pNoMech);
    gComp = imtAasCompositeGain(azT, elT, azS, elS, pNoMech);
    assert(abs(gComp - (gEl + gArr)) < 1e-9, ...
        'compositeGain (%.6f) != elementPattern (%.6f) + arrayFactor (%.6f)', ...
        gComp, gEl, gArr);
    fprintf('  [OK] compositeGain = elementPattern + arrayFactor (dB)\n');

    % ===== 3. shape: scalar -> scalar =====
    s = imtAasCompositeGain(0, 0, 0, 0, p);
    assert(isscalar(s) && isreal(s) && isfinite(s), ...
        'scalar/scalar -> scalar real finite');
    fprintf('  [OK] scalar input -> scalar real finite output\n');

    % ===== 3b. shape: row vectors -> Naz x Nel =====
    az = -10:5:10;
    el = -10:5:0;
    Gv = imtAasCompositeGain(az, el, 0, -p.mechanicalDowntiltDeg, p);
    assert(isequal(size(Gv), [numel(az), numel(el)]), ...
        'vector input must yield Naz x Nel');
    assert(all(isfinite(Gv(:))), 'all composite gains must be finite');
    fprintf('  [OK] vector input -> %s shape, all finite\n', mat2str(size(Gv)));

    % ===== 4. real-valued =====
    assert(isreal(Gv), 'composite gain must be real');
    fprintf('  [OK] real-valued over default grid\n');

    % ===== 5. mechanical downtilt shifts sector-frame peak below horizon =====
    % Sweep elevation at sector az=0 with steering at (0, -mech_tilt) so
    % the outer-array-factor peak lies at panel boresight. The composite
    % peak in sector frame ends up below the horizon, in the vicinity of
    % -(mech_tilt + sub_tilt) deg because the fixed sub-array downtilt
    % also pulls the elevation down. Assert the peak is below horizon and
    % within a few degrees of the expected -(mech_tilt + sub_tilt).
    azSweep = 0;
    elSweep = -20:0.25:5;
    Gtilt = imtAasCompositeGain(azSweep, elSweep, 0, -p.mechanicalDowntiltDeg, p);
    [~, idx] = max(Gtilt(:));
    elPeak = elSweep(idx);
    expectedPeak = -(p.mechanicalDowntiltDeg + p.subarrayDowntiltDeg);
    assert(elPeak < 0, ...
        'composite peak must be below horizon (got %.3f)', elPeak);
    assert(abs(elPeak - expectedPeak) < 4.0, ...
        'sector-frame peak el %.3f deg vs expected ~%.1f deg', ...
        elPeak, expectedPeak);
    fprintf('  [OK] downtilt moves peak to el = %.2f deg (expected ~%.1f)\n', ...
        elPeak, expectedPeak);

    % ===== 6. invalid steer azimuth =====
    threw = false;
    try
        imtAasCompositeGain(0, 0, 200, 0, p); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'imtAasCompositeGain:invalidSteer'), ...
            'expected imtAasCompositeGain:invalidSteer, got %s', err.identifier);
    end
    assert(threw, 'out-of-range steer must error');
    fprintf('  [OK] out-of-range steerAz raises invalidSteer\n');

    results.passed = true;
    fprintf('--- test_imtAasCompositeGain PASSED ---\n');
end
