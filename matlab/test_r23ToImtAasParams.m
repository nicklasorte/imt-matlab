function results = test_r23ToImtAasParams()
%TEST_R23TOIMTAASPARAMS Focused unit tests for r23ToImtAasParams.
%
%   RESULTS = test_r23ToImtAasParams()
%
%   Covers:
%       1. Default nested params (urban) flatten into an imtAasDefaultParams-
%          shaped struct.
%       2. AAS antenna fields round-trip: elementGain, beamwidths, numRows,
%          numColumns, hSpacing, vSpacing, subarrayDowntilt, mechanical
%          downtilt, k, rho.
%       3. BS power fields round-trip: sectorEirpDbm = 78.3,
%          txPowerDbmPer100MHz = 46.1, peakGainDbi = 32.2,
%          bandwidthMHz = 100.
%       4. UE / sim fields round-trip: numUesPerSector, splitSectorPower.
%       5. Modifying nestedParams.bs.maxEirpPerSector_dBm propagates to
%          flatParams.sectorEirpDbm.
%       6. Vertical-coverage min/max are derived from
%          verticalCoverageGlobal_deg if present.
%       7. Non-struct input raises r23ToImtAasParams:invalidInput.
%
%   Returns:
%       struct('passed', logical, 'skipped', false, 'reason', '')

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_r23ToImtAasParams ---\n');

    nested = r23DefaultParams('urban');

    % ===== 1. shape =====
    flat = r23ToImtAasParams(nested);
    assert(isstruct(flat), 'output must be a struct');
    pDef = imtAasDefaultParams();
    defFields = fieldnames(pDef);
    for k = 1:numel(defFields)
        assert(isfield(flat, defFields{k}), ...
            'flat output must contain field "%s"', defFields{k});
    end
    fprintf('  [OK] output struct has all imtAasDefaultParams fields\n');

    % ===== 2. AAS antenna field round-trip =====
    a = nested.aas;
    assert(flat.elementGainDbi == a.elementGain_dBi);
    assert(flat.hBeamwidthDeg  == a.elementHorizontal3dBBeamwidth_deg);
    assert(flat.vBeamwidthDeg  == a.elementVertical3dBBeamwidth_deg);
    assert(flat.numColumns     == a.numColumns);
    assert(flat.numRows        == a.numRows);
    assert(flat.hSpacingWavelengths        == a.horizontalSpacing_lambda);
    assert(flat.vSubarraySpacingWavelengths == a.verticalSubarraySpacing_lambda);
    assert(flat.numElementsPerSubarray     == a.numElementRowsInSubarray);
    assert(flat.subarrayDowntiltDeg == a.subarrayDowntilt_deg);
    assert(flat.mechanicalDowntiltDeg == a.mechanicalDowntilt_deg);
    assert(flat.k == a.k);
    assert(flat.rho == a.rho);
    fprintf('  [OK] AAS antenna fields round-trip\n');

    % ===== 3. BS power fields round-trip =====
    b = nested.bs;
    assert(flat.sectorEirpDbm       == b.maxEirpPerSector_dBm);
    assert(flat.txPowerDbmPer100MHz == b.conductedPower_dBm);
    assert(flat.peakGainDbi         == b.peakGain_dBi);
    assert(flat.bandwidthMHz        == b.channelBandwidth_MHz);
    assert(flat.frequencyMHz        == b.frequency_MHz);
    assert(abs(flat.sectorEirpDbm - 78.3) < 1e-9, 'sectorEirpDbm expected 78.3');
    assert(abs(flat.peakGainDbi   - 32.2) < 1e-9, 'peakGainDbi expected 32.2');
    assert(abs(flat.txPowerDbmPer100MHz - 46.1) < 1e-9, ...
        'txPowerDbmPer100MHz expected 46.1');
    fprintf('  [OK] BS power fields (78.3 / 46.1 / 32.2) round-trip\n');

    % ===== 4. UE / sim round-trip =====
    assert(flat.numUesPerSector == nested.ue.numUesPerSector, ...
        'numUesPerSector round-trip');
    assert(flat.defaultSplitSectorPowerAcrossBeams == ...
           nested.sim.splitSectorPower, 'splitSectorPower round-trip');
    fprintf('  [OK] UE / sim fields round-trip\n');

    % ===== 5. override propagation =====
    nestedOverride = nested;
    nestedOverride.bs.maxEirpPerSector_dBm = 70.0;
    flatOverride = r23ToImtAasParams(nestedOverride);
    assert(flatOverride.sectorEirpDbm == 70.0, ...
        'override on maxEirpPerSector_dBm must propagate to sectorEirpDbm');
    fprintf('  [OK] BS power override propagates\n');

    % ===== 6. vertical coverage derivation =====
    if isfield(nested.aas, 'verticalCoverageGlobal_deg') && ...
            ~isempty(nested.aas.verticalCoverageGlobal_deg)
        vcov = nested.aas.verticalCoverageGlobal_deg;
        assert(flat.vCoverageDegGlobalMin == min(vcov));
        assert(flat.vCoverageDegGlobalMax == max(vcov));
        fprintf('  [OK] vCoverage min/max derived from verticalCoverageGlobal_deg\n');
    else
        fprintf('  [SKIP] verticalCoverageGlobal_deg not present in defaults\n');
    end

    % ===== 7. invalid input =====
    threw = false;
    try
        r23ToImtAasParams([]); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'r23ToImtAasParams:invalidInput'), ...
            'expected invalidInput, got %s', err.identifier);
    end
    assert(threw, 'empty input must error');
    fprintf('  [OK] empty input raises invalidInput\n');

    threw = false;
    try
        r23ToImtAasParams(42); %#ok<NASGU>
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'r23ToImtAasParams:invalidInput'), ...
            'expected invalidInput, got %s', err.identifier);
    end
    assert(threw, 'numeric input must error');
    fprintf('  [OK] numeric input raises invalidInput\n');

    results.passed = true;
    fprintf('--- test_r23ToImtAasParams PASSED ---\n');
end
