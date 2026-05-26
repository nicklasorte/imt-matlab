function results = test_imtAasDefaultParams()
%TEST_IMTAASDEFAULTPARAMS Focused unit tests for imtAasDefaultParams.
%
%   RESULTS = test_imtAasDefaultParams()
%
%   Covers:
%       1. Returns a struct with the R23 macro 7.125-8.4 GHz reference
%          fields and values (sectorEirpDbm = 78.3, peakGainDbi = 32.2,
%          txPowerDbmPer100MHz = 46.1, 8x16 sub-array, k = 12, rho = 1).
%       2. Power semantics invariant: 46.1 + 32.2 == 78.3 dBm (within
%          numerical tolerance).
%       3. All numeric fields are finite scalars.
%       4. Output is independent of repeated calls (deterministic).
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasDefaultParams ---\n');

    p = imtAasDefaultParams();

    % ===== 1. type / required fields =====
    assert(isstruct(p), 'imtAasDefaultParams must return a struct');
    requiredFields = { ...
        'elementGainDbi', 'hBeamwidthDeg', 'vBeamwidthDeg', ...
        'frontToBackDb', 'sideLobeAttenuationDb', 'polarization', ...
        'numColumns', 'numRows', 'hSpacingWavelengths', ...
        'vSubarraySpacingWavelengths', 'numElementsPerSubarray', ...
        'elementSpacingWavelengths', 'subarrayDowntiltDeg', ...
        'mechanicalDowntiltDeg', 'sectorEirpDbm', 'bandwidthMHz', ...
        'frequencyMHz', 'peakGainDbi', 'txPowerDbmPer100MHz', ...
        'k', 'rho'};
    for i = 1:numel(requiredFields)
        assert(isfield(p, requiredFields{i}), ...
            'imtAasDefaultParams missing field "%s"', requiredFields{i});
    end
    fprintf('  [OK] required field set present\n');

    % ===== 2. R23 reference values =====
    assert(abs(p.elementGainDbi - 6.4)  < 1e-12, 'elementGainDbi expected 6.4');
    assert(abs(p.peakGainDbi    - 32.2) < 1e-12, 'peakGainDbi expected 32.2');
    assert(abs(p.txPowerDbmPer100MHz - 46.1) < 1e-12, ...
        'txPowerDbmPer100MHz expected 46.1');
    assert(abs(p.sectorEirpDbm - 78.3) < 1e-12, 'sectorEirpDbm expected 78.3');
    assert(p.numColumns == 16, 'numColumns expected 16 (N_H)');
    assert(p.numRows    == 8,  'numRows expected 8 (N_V)');
    assert(p.numElementsPerSubarray == 3, 'L expected 3');
    assert(p.k == 12, 'k expected 12');
    assert(p.rho == 1, 'rho expected 1');
    assert(p.bandwidthMHz == 100, 'bandwidthMHz expected 100');
    fprintf('  [OK] R23 reference defaults\n');

    % ===== 3. power-semantics invariant =====
    assert(abs((p.txPowerDbmPer100MHz + p.peakGainDbi) - p.sectorEirpDbm) ...
        < 1e-9, ['power semantics: txPower + peakGain must equal ' ...
                 'sectorEirpDbm (78.3 dBm / 100 MHz)']);
    fprintf('  [OK] 46.1 + 32.2 = 78.3 dBm power invariant holds\n');

    % ===== 4. all numeric scalars finite =====
    flds = fieldnames(p);
    for i = 1:numel(flds)
        v = p.(flds{i});
        if isnumeric(v) && isscalar(v)
            assert(isfinite(v), 'field "%s" is non-finite', flds{i});
        end
    end
    fprintf('  [OK] all scalar numeric fields finite\n');

    % ===== 5. deterministic =====
    p2 = imtAasDefaultParams();
    assert(isequaln(p, p2), 'imtAasDefaultParams must be deterministic');
    fprintf('  [OK] deterministic across calls\n');

    results.passed = true;
    fprintf('--- test_imtAasDefaultParams PASSED ---\n');
end
