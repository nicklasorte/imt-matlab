function results = test_imtAasValidationExport()
%TEST_IMTAASVALIDATIONEXPORT Self tests for the AAS-02 validation/export layer.
%
%   RESULTS = test_imtAasValidationExport()
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  false
%       .reason   ''
%
%   Tests covered:
%     1. imtAasPatternCuts returns horizontal-cut length = numel(azGridDeg)
%     2. imtAasPatternCuts returns vertical-cut length   = numel(elGridDeg)
%     3. peakEirpDbm from cuts equals max(eirpGridDbm(:))
%     4. peak EIRP remains 78.3 dBm/100 MHz within 1e-9 dB
%     5. peak (az, el) lies near the steering direction for the default case
%     6. CSV export writes numel(azGridDeg) * numel(elGridDeg) data rows
%     7. CSV header contains the required columns
%     8. CSV metadata sidecar file exists
%     9. plotImtAasPatternCuts returns a struct with two valid figure handles
%    10. invalid grid dimensions fail clearly in cuts and export

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasValidationExport ---\n');

    % ---- shared inputs ------------------------------------------------
    p = imtAasDefaultParams();

    azGridDeg  = -180:2:180;     % 181 points
    elGridDeg  =  -90:2:90;      %  91 points
    Naz = numel(azGridDeg);
    Nel = numel(elGridDeg);
    steerAz = 0;
    steerEl = -9;

    eirp = imtAasEirpGrid(azGridDeg, elGridDeg, steerAz, steerEl, ...
        p.sectorEirpDbm, p);

    % ===== 1 + 2 + 3: cuts shape and peak =============================
    cuts = imtAasPatternCuts(azGridDeg, elGridDeg, eirp, steerAz, steerEl);

    assert(isfield(cuts, 'horizontalCutAtSteerElDbm'), ...
        'cuts struct missing horizontalCutAtSteerElDbm');
    assert(isfield(cuts, 'verticalCutAtSteerAzDbm'), ...
        'cuts struct missing verticalCutAtSteerAzDbm');
    assert(numel(cuts.horizontalCutAtSteerElDbm) == Naz, ...
        'horizontal cut length %d != numel(azGridDeg) %d', ...
        numel(cuts.horizontalCutAtSteerElDbm), Naz);
    assert(numel(cuts.verticalCutAtSteerAzDbm) == Nel, ...
        'vertical cut length %d != numel(elGridDeg) %d', ...
        numel(cuts.verticalCutAtSteerAzDbm), Nel);
    fprintf('  [OK] cuts horizontal length = %d, vertical length = %d\n', ...
        Naz, Nel);

    assert(abs(cuts.peakEirpDbm - max(eirp(:))) < 1e-12, ...
        'cuts.peakEirpDbm %.6f != max(eirp(:)) %.6f', ...
        cuts.peakEirpDbm, max(eirp(:)));
    fprintf('  [OK] cuts.peakEirpDbm matches max(eirp(:))\n');

    % ===== 4: peak EIRP equals 78.3 dBm/100 MHz within tolerance ======
    assert(abs(cuts.peakEirpDbm - p.sectorEirpDbm) < 1e-9, ...
        'peak EIRP %.6f != sectorEirpDbm %.6f', ...
        cuts.peakEirpDbm, p.sectorEirpDbm);
    fprintf('  [OK] peak EIRP = %.3f dBm/100 MHz (sectorEirpDbm = %.3f)\n', ...
        cuts.peakEirpDbm, p.sectorEirpDbm);

    % ===== 5: peak location is near the steering direction ============
    %   With 2-deg sampling and the broadside / nominal steering case the
    %   peak should sit on the closest grid cell to (steerAz, steerEl).
    %   Allow up to one grid cell of slack on each axis (2 deg here).
    assert(abs(cuts.peakAzDeg - steerAz) <= 2 + 1e-9, ...
        'peak az %.2f deg differs from steerAz %.2f deg by > one grid cell', ...
        cuts.peakAzDeg, steerAz);
    assert(abs(cuts.peakElDeg - steerEl) <= 2 + 1e-9, ...
        'peak el %.2f deg differs from steerEl %.2f deg by > one grid cell', ...
        cuts.peakElDeg, steerEl);
    fprintf('  [OK] peak (az, el) = (%.2f, %.2f) deg near steering (%.2f, %.2f)\n', ...
        cuts.peakAzDeg, cuts.peakElDeg, steerAz, steerEl);

    % ===== 6 + 7 + 8: CSV export ======================================
    tmpDir = tempname();
    [okMk, msgMk] = mkdir(tmpDir);
    assert(okMk, 'could not create tmpDir %s (%s)', tmpDir, msgMk);
    cleanupTmp = onCleanup(@() rmdirSafe(tmpDir));

    csvPath = fullfile(tmpDir, 'aas_eirp_grid_test.csv');
    metadata = struct( ...
        'sector_eirp_dbm_per_100mhz', p.sectorEirpDbm, ...
        'bandwidth_mhz',              p.bandwidthMHz, ...
        'frequency_mhz',              p.frequencyMHz, ...
        'steer_az_deg',               steerAz, ...
        'steer_el_deg',               steerEl, ...
        'mechanical_downtilt_deg',    p.mechanicalDowntiltDeg, ...
        'subarray_downtilt_deg',      p.subarrayDowntiltDeg, ...
        'num_rows',                   p.numRows, ...
        'num_columns',                p.numColumns);

    expOut = imtAasExportEirpGridCsv(azGridDeg, elGridDeg, eirp, ...
        csvPath, metadata);

    assert(exist(expOut.csvPath, 'file') == 2, ...
        'CSV %s was not created', expOut.csvPath);
    assert(expOut.numRowsWritten == Naz * Nel, ...
        'numRowsWritten %d != Naz*Nel %d', expOut.numRowsWritten, Naz*Nel);

    % verify the on-disk CSV row count matches numRowsWritten
    fid = fopen(expOut.csvPath, 'r');
    assert(fid >= 0, 'cannot reopen %s for verification', expOut.csvPath);
    nLinesOnDisk = 0;
    headerLine = fgetl(fid);
    while ischar(fgetl(fid))
        nLinesOnDisk = nLinesOnDisk + 1;
    end
    fclose(fid);
    assert(nLinesOnDisk == Naz * Nel, ...
        'on-disk CSV has %d data rows, expected %d', nLinesOnDisk, Naz*Nel);
    fprintf('  [OK] CSV has %d data rows = numel(az)*numel(el)\n', nLinesOnDisk);

    % required columns in header
    requiredColumns = {'az_deg', 'el_deg', 'eirp_dbm_per_100mhz'};
    for i = 1:numel(requiredColumns)
        assert(~isempty(strfind(headerLine, requiredColumns{i})), ...
            'CSV header is missing column "%s"; got "%s"', ...
            requiredColumns{i}, headerLine);
    end
    fprintf('  [OK] CSV header has columns: %s\n', headerLine);

    % metadata sidecar exists
    assert(exist(expOut.metadataPath, 'file') == 2, ...
        'metadata sidecar %s does not exist', expOut.metadataPath);
    fprintf('  [OK] metadata sidecar exists at %s [%s]\n', ...
        expOut.metadataPath, expOut.metadataFormat);

    % ===== 9: plotImtAasPatternCuts returns two valid figure handles ==
    figs = plotImtAasPatternCuts(cuts);
    assert(isstruct(figs), 'plotImtAasPatternCuts must return a struct');
    assert(isfield(figs, 'horizontal') && isfield(figs, 'vertical'), ...
        'figs struct must have .horizontal and .vertical');
    assert(isgraphics(figs.horizontal) && isgraphics(figs.vertical), ...
        'figs.horizontal / .vertical must be valid graphics handles');
    try
        close(figs.horizontal);
        close(figs.vertical);
    catch
        % non-fatal during headless tests
    end
    fprintf('  [OK] plotImtAasPatternCuts returned two valid figure handles\n');

    % ===== 10: invalid grid dimensions fail clearly ===================
    threw = false;
    try
        imtAasPatternCuts(azGridDeg, elGridDeg, ...
            zeros(Naz, Nel + 1), steerAz, steerEl); %#ok<NASGU>
    catch err
        threw = true;
        assert(~isempty(err.message), 'error message missing');
    end
    assert(threw, 'expected size-mismatch error from imtAasPatternCuts not raised');

    threw = false;
    try
        imtAasExportEirpGridCsv(azGridDeg, elGridDeg, ...
            zeros(Naz + 1, Nel), csvPath, metadata); %#ok<NASGU>
    catch err
        threw = true;
        assert(~isempty(err.message), 'error message missing');
    end
    assert(threw, 'expected size-mismatch error from imtAasExportEirpGridCsv not raised');

    threw = false;
    try
        imtAasPatternCuts(azGridDeg, elGridDeg, eirp, NaN, steerEl); %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'expected NaN steer error from imtAasPatternCuts not raised');
    fprintf('  [OK] invalid grid / steering inputs raise clear errors\n');

    clear cleanupTmp; %#ok<CLMVR>

    results.passed = true;
    fprintf('--- test_imtAasValidationExport PASSED ---\n');
end

% =====================================================================

function rmdirSafe(d)
    try
        if exist(d, 'dir') == 7
            rmdir(d, 's');
        end
    catch
        % best effort cleanup
    end
end
