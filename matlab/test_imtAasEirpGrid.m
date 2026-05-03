function results = test_imtAasEirpGrid()
%TEST_IMTAASEIRPGRID Self tests for the IMT AAS sector EIRP grid MVP.
%
%   RESULTS = test_imtAasEirpGrid()
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  false
%       .reason   ''
%
%   Tests covered:
%     1. Default params struct contains all required fields.
%     2. EIRP grid dimensions match az/elevation grid dimensions.
%     3. Peak EIRP equals 78.3 dBm under the normalized MVP approach.
%     4. EIRP decreases away from boresight along an azimuth cut at the
%        steered elevation.
%     5. Azimuth symmetry holds for the broadside steering case.
%     6. No NaN or Inf values appear for normal inputs.
%     7. Invalid grid sizes / steering angles fail with clear errors.

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasEirpGrid ---\n');

    % ===== 1. default params has all required fields =====
    p = imtAasDefaultParams();
    requiredFields = { ...
        'elementGainDbi', 'hBeamwidthDeg', 'vBeamwidthDeg', ...
        'frontToBackDb', 'sideLobeAttenuationDb', 'polarization', ...
        'numColumns', 'numRows', 'hSpacingWavelengths', ...
        'vSubarraySpacingWavelengths', 'numElementsPerSubarray', ...
        'elementSpacingWavelengths', 'subarrayDowntiltDeg', ...
        'mechanicalDowntiltDeg', 'hCoverageDeg', ...
        'vCoverageDegGlobalMin', 'vCoverageDegGlobalMax', ...
        'sectorEirpDbm', 'bandwidthMHz', 'frequencyMHz', 'k', 'rho'};
    for i = 1:numel(requiredFields)
        assert(isfield(p, requiredFields{i}), ...
            'imtAasDefaultParams missing field "%s"', requiredFields{i});
    end
    assert(p.numColumns == 16 && p.numRows == 8, ...
        'expected 8 x 16 array (rows x columns), got %d x %d', ...
        p.numRows, p.numColumns);
    assert(abs(p.sectorEirpDbm - 78.3) < eps, ...
        'sectorEirpDbm expected 78.3, got %g', p.sectorEirpDbm);
    fprintf('  [OK] default params has all required fields\n');

    % ===== shared grid for tests 2..6 =====
    azGridDeg = -180:2:180;     % 181 points, symmetric about 0
    elGridDeg =  -90:2:90;      %  91 points, includes 0
    Naz = numel(azGridDeg);
    Nel = numel(elGridDeg);
    steerAz = 0;
    steerEl = -9;               % combined sub (3) + mech (6) downtilt nominal

    eirp = imtAasEirpGrid(azGridDeg, elGridDeg, steerAz, steerEl, ...
        p.sectorEirpDbm, p);

    % ===== 2. EIRP grid dimensions match az/elevation grid dimensions =====
    assert(isequal(size(eirp), [Naz, Nel]), ...
        'EIRP size %s != expected [%d %d]', mat2str(size(eirp)), Naz, Nel);
    fprintf('  [OK] EIRP grid dims = [%d %d]\n', Naz, Nel);

    % ===== 3. peak EIRP equals 78.3 dBm =====
    peak = max(eirp(:));
    assert(abs(peak - p.sectorEirpDbm) < 1e-9, ...
        'peak EIRP %.6f != sectorEirpDbm %.6f', peak, p.sectorEirpDbm);
    fprintf('  [OK] peak EIRP = %.3f dBm/100MHz (sectorEirpDbm = %.3f)\n', ...
        peak, p.sectorEirpDbm);

    % ===== 4. EIRP decreases away from boresight along an azimuth cut =====
    [~, elIdx] = min(abs(elGridDeg - steerEl));
    azCut = eirp(:, elIdx);
    [peakAzVal, azIdxPeak] = max(azCut);
    if azIdxPeak < Naz
        assert(azCut(azIdxPeak + 1) <= peakAzVal + 1e-9, ...
            'EIRP did not decrease right of az peak');
    end
    if azIdxPeak > 1
        assert(azCut(azIdxPeak - 1) <= peakAzVal + 1e-9, ...
            'EIRP did not decrease left of az peak');
    end
    % also check a far-off-axis cell is well below peak
    [~, idxFarAz] = min(abs(azGridDeg - 90));   % 90 deg off boresight
    assert(azCut(idxFarAz) < peakAzVal - 10, ...
        ['EIRP at az = 90 deg should be at least 10 dB below peak; ' ...
         'got delta = %.2f dB'], peakAzVal - azCut(idxFarAz));
    fprintf('  [OK] EIRP decreases away from boresight (az cut, peak at az=%g)\n', ...
        azGridDeg(azIdxPeak));

    % ===== 5. azimuth symmetry for broadside steering =====
    eirpFlipped = flipud(eirp);
    diffAbs = max(abs(eirp(:) - eirpFlipped(:)));
    assert(diffAbs < 1e-6, ...
        'azimuth symmetry violated by %.3g dB', diffAbs);
    fprintf('  [OK] azimuth symmetry holds (max diff = %.3e dB)\n', diffAbs);

    % ===== 6. no NaN / Inf =====
    assert(all(isfinite(eirp(:))), 'EIRP grid contains non-finite values');
    fprintf('  [OK] EIRP grid has no NaN or Inf values\n');

    % ===== 7. invalid inputs raise clear errors =====
    %   Note: vector inputs of different lengths are intentionally
    %   ndgrid'd into a Naz x Nel grid (deterministic vector path), so
    %   the "invalid size" case is two 2-D arrays whose shapes differ.
    threw = false;
    try
        imtAasEirpGrid(zeros(3, 3), zeros(2, 2), 0, 0, p.sectorEirpDbm, p); %#ok<NASGU>
    catch err
        threw = true;
        assert(~isempty(err.message), 'error message missing');
    end
    assert(threw, 'expected error for mismatched 2-D grid shapes was not raised');

    threw = false;
    try
        imtAasEirpGrid(ones(2, 2, 2), [1 2], 0, 0, p.sectorEirpDbm, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for >2-D grid was not raised');

    threw = false;
    try
        imtAasEirpGrid(azGridDeg, elGridDeg, 999, 0, p.sectorEirpDbm, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for invalid steerAz was not raised');

    threw = false;
    try
        imtAasEirpGrid(azGridDeg, elGridDeg, 0, 999, p.sectorEirpDbm, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for invalid steerEl was not raised');

    threw = false;
    try
        imtAasEirpGrid(azGridDeg, elGridDeg, NaN, 0, p.sectorEirpDbm, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for NaN steerAz was not raised');
    fprintf('  [OK] invalid grid/steering inputs raise clear errors\n');

    % ===== bonus: peak gain plausibility check =====
    %   element peak (6.4 dBi) + 10*log10(N_H*N_V) + 10*log10(L)
    %   = 6.4 + 21.07 + 4.77 = ~32.24 dBi  (matches R23 reference 32.2 dBi)
    % Evaluate at the exact steering direction (scalar call) so the result
    % does not depend on whether the steering elevation falls on a grid point.
    peakGainAtSteer = imtAasCompositeGain(steerAz, steerEl, steerAz, steerEl, p);
    expectedPeak = p.elementGainDbi ...
        + 10 * log10(p.numColumns * p.numRows) ...
        + 10 * log10(p.numElementsPerSubarray);
    assert(abs(peakGainAtSteer - expectedPeak) < 0.5, ...
        ['composite peak gain %.3f dBi differs from analytic ' ...
         '%.3f dBi by > 0.5 dB'], peakGainAtSteer, expectedPeak);
    fprintf('  [OK] composite peak gain ~ %.2f dBi (expected ~%.2f dBi)\n', ...
        peakGainAtSteer, expectedPeak);

    results.passed = true;
    fprintf('--- test_imtAasEirpGrid PASSED ---\n');
end
