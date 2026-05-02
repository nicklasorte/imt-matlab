function results = test_imtAasSectorEirpGridFromBeams()
%TEST_IMTAASSECTOREIRPGRIDFROMBEAMS Self tests for the UE-driven sector EIRP grid.
%
%   RESULTS = test_imtAasSectorEirpGridFromBeams()
%
%   Tests covered:
%     1.  imtAasDefaultParams contains the explicit power-semantics fields
%         (peakGainDbi, txPowerDbmPer100MHz, numUesPerSector,
%         sectorEirpIncludesTwoPolarizations, elementGainIncludesOhmicLoss).
%     2.  numBeams = 1, splitSectorPower = true:
%             perBeamPeakEirpDbm == sectorEirpDbm
%             aggregateEirpDbm equals perBeamEirpDbm
%             peak aggregate ~ 78.3 dBm.
%     3.  numBeams = 3, splitSectorPower = true:
%             perBeamPeakEirpDbm ~ 78.3 - 10*log10(3).
%     4.  Three identical beams, splitSectorPower = true:
%             peak aggregate ~ 78.3 dBm (sum of three -4.77 dB peaks).
%     5.  Three different UE-driven beams:
%             aggregateEirpDbm is finite
%             size = [numel(azGridDeg), numel(elGridDeg)].
%     6.  maxEnvelopeEirpDbm peak == perBeamPeakEirpDbm (split path).
%     7.  dBW/Hz conversion is correct.
%     8.  AAS-04 generated beam set passes through without modification.
%     9.  splitSectorPower = false: each beam peaks at sectorEirpDbm.
%    10.  invalid beams struct fails clearly.
%    11.  invalid grid dimensions fail clearly.
%    12.  no path-loss / receiver / I-N fields appear in the output struct.

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasSectorEirpGridFromBeams ---\n');

    p = imtAasDefaultParams();

    % ===== 1. params has explicit power-semantics fields =====
    requiredFields = { ...
        'peakGainDbi', 'txPowerDbmPer100MHz', 'numUesPerSector', ...
        'sectorEirpIncludesTwoPolarizations', 'elementGainIncludesOhmicLoss', ...
        'defaultSplitSectorPowerAcrossBeams'};
    for i = 1:numel(requiredFields)
        assert(isfield(p, requiredFields{i}), ...
            'imtAasDefaultParams missing field "%s"', requiredFields{i});
    end
    assert(abs(p.peakGainDbi - 32.2) < eps, ...
        'peakGainDbi expected 32.2, got %g', p.peakGainDbi);
    assert(abs(p.txPowerDbmPer100MHz - 46.1) < eps, ...
        'txPowerDbmPer100MHz expected 46.1, got %g', p.txPowerDbmPer100MHz);
    assert(p.numUesPerSector == 3, ...
        'numUesPerSector expected 3, got %d', p.numUesPerSector);
    assert(p.sectorEirpIncludesTwoPolarizations == true, ...
        'sectorEirpIncludesTwoPolarizations expected true');
    assert(p.elementGainIncludesOhmicLoss == true, ...
        'elementGainIncludesOhmicLoss expected true');
    assert(abs((p.txPowerDbmPer100MHz + p.peakGainDbi) - p.sectorEirpDbm) ...
        < 1e-9, ...
        'txPowerDbmPer100MHz + peakGainDbi (= %.3f) != sectorEirpDbm %.3f', ...
        p.txPowerDbmPer100MHz + p.peakGainDbi, p.sectorEirpDbm);
    fprintf('  [OK] default params include explicit power-semantics fields\n');

    azGridDeg = -180:2:180;
    elGridDeg =  -90:2:90;
    Naz = numel(azGridDeg);
    Nel = numel(elGridDeg);

    % ===== 2. one beam, splitSectorPower = true =====
    beams1 = struct('steerAzDeg', 0, 'steerElDeg', -9);
    out1 = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
        beams1, p);
    assert(out1.numBeams == 1, 'numBeams expected 1, got %d', out1.numBeams);
    assert(abs(out1.perBeamPeakEirpDbm - p.sectorEirpDbm) < 1e-12, ...
        'perBeamPeakEirpDbm expected %.6f, got %.6f', ...
        p.sectorEirpDbm, out1.perBeamPeakEirpDbm);
    assert(isequal(size(out1.aggregateEirpDbm), [Naz, Nel]), ...
        'aggregate size %s != [%d %d]', ...
        mat2str(size(out1.aggregateEirpDbm)), Naz, Nel);
    perBeam1 = out1.perBeamEirpDbm(:, :, 1);
    diff1 = max(abs(out1.aggregateEirpDbm(:) - perBeam1(:)));
    assert(diff1 < 1e-9, ...
        '1-beam aggregate != per-beam grid (max diff %.3g dB)', diff1);
    assert(abs(out1.peakAggregateEirpDbm - 78.3) < 1e-6, ...
        '1-beam peak aggregate expected ~78.3 dBm, got %.6f', ...
        out1.peakAggregateEirpDbm);
    fprintf('  [OK] 1 beam, split: perBeamPeak=%.3f, peak agg=%.3f dBm\n', ...
        out1.perBeamPeakEirpDbm, out1.peakAggregateEirpDbm);

    % ===== 3. three beams, splitSectorPower = true =====
    beams3 = struct('steerAzDeg', [-30; 0; 30], 'steerElDeg', [-9; -9; -9]);
    out3 = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, beams3, p);
    expectedPerBeamPeak = p.sectorEirpDbm - 10 * log10(3);
    assert(abs(out3.perBeamPeakEirpDbm - expectedPerBeamPeak) < 1e-9, ...
        'perBeamPeakEirpDbm expected %.6f, got %.6f', ...
        expectedPerBeamPeak, out3.perBeamPeakEirpDbm);
    assert(out3.numBeams == 3, 'numBeams expected 3, got %d', out3.numBeams);
    fprintf('  [OK] 3 beams, split: perBeamPeak=%.3f dBm (78.3 - 10log10(3) = %.3f)\n', ...
        out3.perBeamPeakEirpDbm, expectedPerBeamPeak);

    % ===== 4. three identical beams: aggregate peak ~ 78.3 dBm =====
    beamsId = struct('steerAzDeg', [0; 0; 0], 'steerElDeg', [-9; -9; -9]);
    outId = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, beamsId, p);
    assert(abs(outId.peakAggregateEirpDbm - p.sectorEirpDbm) < 1e-6, ...
        'identical 3-beam peak aggregate expected %.6f, got %.6f', ...
        p.sectorEirpDbm, outId.peakAggregateEirpDbm);
    fprintf('  [OK] 3 identical beams, split: peak aggregate=%.3f dBm (~78.3)\n', ...
        outId.peakAggregateEirpDbm);

    % ===== 5. three different UE-driven beams: finite + correct shape =====
    beamsDiff = struct('steerAzDeg', [-45; 5; 25], ...
                       'steerElDeg', [ -2; -8; -5]);
    outDiff = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
        beamsDiff, p);
    assert(isequal(size(outDiff.aggregateEirpDbm), [Naz, Nel]), ...
        'aggregate size %s != [%d %d]', ...
        mat2str(size(outDiff.aggregateEirpDbm)), Naz, Nel);
    assert(all(isfinite(outDiff.aggregateEirpDbm(:))), ...
        'aggregate contains non-finite values');
    fprintf('  [OK] 3 different beams: aggregate is finite, size = [%d %d]\n', ...
        Naz, Nel);

    % ===== 6. envelope peak == perBeamPeakEirpDbm (split path) =====
    assert(abs(out3.peakEnvelopeEirpDbm - out3.perBeamPeakEirpDbm) < 1e-6, ...
        'envelope peak %.6f != perBeamPeakEirpDbm %.6f', ...
        out3.peakEnvelopeEirpDbm, out3.perBeamPeakEirpDbm);
    fprintf('  [OK] envelope peak = perBeamPeakEirpDbm = %.3f dBm\n', ...
        out3.peakEnvelopeEirpDbm);

    % ===== 7. dBW/Hz conversion =====
    bwHz = p.bandwidthMHz * 1e6;
    expDbwHzAgg = out3.aggregateEirpDbm - 30 - 10 * log10(bwHz);
    expDbwHzEnv = out3.maxEnvelopeEirpDbm - 30 - 10 * log10(bwHz);
    assert(max(abs(out3.eirpAggregateDbwPerHz(:) - expDbwHzAgg(:))) < 1e-9, ...
        'aggregate dBW/Hz conversion incorrect');
    assert(max(abs(out3.eirpEnvelopeDbwPerHz(:) - expDbwHzEnv(:))) < 1e-9, ...
        'envelope dBW/Hz conversion incorrect');
    fprintf('  [OK] dBW/Hz conversion is correct\n');

    % ===== 8. AAS-04 generated beam set flows through =====
    sector = imtAasSingleSectorParams('macroUrban', p);
    beamsGen = imtAasGenerateBeamSet(p.numUesPerSector, sector, ...
        struct('seed', 1));
    outGen = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
        beamsGen, p);
    assert(outGen.numBeams == p.numUesPerSector);
    assert(all(isfinite(outGen.aggregateEirpDbm(:))), ...
        'AAS-04 driven aggregate has non-finite values');
    fprintf('  [OK] AAS-04 generated beams flow into sector grid (numBeams = %d)\n', ...
        outGen.numBeams);

    % ===== 9. splitSectorPower = false =====
    out3NoSplit = imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
        beamsDiff, p, struct('splitSectorPower', false));
    assert(abs(out3NoSplit.perBeamPeakEirpDbm - p.sectorEirpDbm) < 1e-12, ...
        'no-split perBeamPeakEirpDbm expected %.6f, got %.6f', ...
        p.sectorEirpDbm, out3NoSplit.perBeamPeakEirpDbm);
    perBeamPeaks = squeeze(max(max(out3NoSplit.perBeamEirpDbm, [], 1), [], 2));
    assert(max(abs(perBeamPeaks(:) - p.sectorEirpDbm)) < 1e-9, ...
        'no-split per-beam peaks not all equal to sectorEirpDbm');
    fprintf('  [OK] splitSectorPower=false: each beam peaks at %.3f dBm\n', ...
        p.sectorEirpDbm);

    % ===== 10. invalid beam struct =====
    threw = false;
    try
        imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
            struct('steerAzDeg', [0; 0]), p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for missing steerElDeg field');

    threw = false;
    try
        imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
            struct('steerAzDeg', [0; 0; 0], 'steerElDeg', [0; 0]), p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for steerAz/steerEl length mismatch');

    threw = false;
    try
        imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
            struct('steerAzDeg', [0; NaN; 0], ...
                   'steerElDeg', [0;   0; 0]), p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for NaN steerAzDeg');

    threw = false;
    try
        imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, [], p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for empty beams');

    threw = false;
    try
        imtAasSectorEirpGridFromBeams(azGridDeg, elGridDeg, ...
            struct('steerAzDeg', [], 'steerElDeg', []), p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for empty beam vectors');
    fprintf('  [OK] invalid beams structs raise clear errors\n');

    % ===== 11. invalid grid dimensions =====
    threw = false;
    try
        imtAasSectorEirpGridFromBeams([], elGridDeg, beams1, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for empty azGridDeg');

    threw = false;
    try
        imtAasSectorEirpGridFromBeams(azGridDeg, [], beams1, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for empty elGridDeg');

    threw = false;
    try
        imtAasSectorEirpGridFromBeams([NaN, 0], elGridDeg, beams1, p); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected error for NaN azGridDeg');
    fprintf('  [OK] invalid grid dimensions raise clear errors\n');

    % ===== 12. no path-loss / receiver / I-N fields in output =====
    forbidden = { ...
        'pathLoss_dB', 'pathLossDb', 'pathloss', ...
        'receiverGain_dBi', 'rxGain', 'rxGainDbi', ...
        'rxPowerDbm', 'received_power_dbm', ...
        'iOverN', 'i_over_n', 'iOverN_dB', 'iovern_db', ...
        'tddFactor', 'networkLoadingFactor'};
    fns = fieldnames(out3);
    for i = 1:numel(forbidden)
        assert(~any(strcmpi(fns, forbidden{i})), ...
            'output unexpectedly contains field "%s"', forbidden{i});
    end
    fprintf('  [OK] output has no path-loss / receiver / I/N fields\n');

    results.passed = true;
    fprintf('--- test_imtAasSectorEirpGridFromBeams PASSED ---\n');
end
