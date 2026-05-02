function results = test_imtAasReferenceComparison()
%TEST_IMTAASREFERENCECOMPARISON Self tests for the AAS-03 reference harness.
%
%   RESULTS = test_imtAasReferenceComparison()
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  false
%       .reason   ''
%
%   Tests covered:
%     1. imtAasComparePatternCut passes for identical actual/reference
%        vectors at default tolerances.
%     2. imtAasComparePatternCut fails when global max abs error is
%        deliberately pushed above the threshold (a sidelobe-only
%        excursion is enough; the main-lobe gate is not relied on
%        here).
%     3. Reference interpolation produces a small residual error when
%        the reference grid is coarser than the actual grid.
%     4. ignoreBelowDbm suppresses deep-null-only differences (large
%        differences below the floor do not count toward metrics or
%        cause a fail).
%     5. The main-lobe error gate catches a localized main-lobe
%        mismatch even when the global RMS gate would still pass.
%     6. imtAasLoadReferenceCutCsv loads a small temporary CSV with
%        the required columns (and reads optional gain/notes).
%     7. imtAasLoadReferenceCutCsv fails clearly when a required
%        column is missing, when the file is missing, and when the
%        required column contains non-finite values.
%     8. plotImtAasReferenceComparison returns a valid figure handle
%        (figure is closed afterwards in a try block to stay headless).
%     9. runAasReferenceValidation skips cleanly when no reference
%        CSVs exist (verified by pointing the harness at a temporary
%        repo layout via a path-shadowing tempdir trick is too
%        invasive; instead we verify the expected behavior on a
%        repo that does not contain CSVs by checking the function
%        skips when both expected files are absent on disk).

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    repoRoot = fileparts(here);
    examplesDir = fullfile(repoRoot, 'examples');
    if exist(examplesDir, 'dir') == 7
        addpath(examplesDir);
    end

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasReferenceComparison ---\n');

    % ===== 1: identical vectors -> pass =================================
    %   Synthetic concave cut with values strictly above the default
    %   ignoreBelowDbm = -80 dBm, so every point contributes to metrics.
    angle    = -90:1:90;
    actual   = 50 - 0.005 .* angle .^ 2;        % range ~ [9.5, 50]
    cmp      = imtAasComparePatternCut(angle, actual, angle, actual);
    assert(cmp.pass, ...
        'identical vectors did not pass (reasons: %s)', ...
        strjoin(cmp.failReasons, '; '));
    assert(cmp.maxAbsErrorDb == 0 && cmp.rmsErrorDb == 0, ...
        'identical vectors must yield zero error');
    assert(cmp.numCompared == numel(angle), ...
        'numCompared %d != numel(angle) %d', ...
        cmp.numCompared, numel(angle));
    assert(cmp.numIgnored == 0, ...
        'no points should be ignored when all values exceed the floor');
    fprintf('  [OK] identical vectors pass with zero error\n');

    % ===== 2: max-error fail ============================================
    %   Add a 2.0 dB excursion 30 deg away from the peak so it sits
    %   outside the default 20-deg main-lobe window. That way only the
    %   global maxAbsErrorDb gate trips, isolating the gate under test.
    perturbed = actual;
    sidelobeIdx = find(angle == 30, 1);
    assert(~isempty(sidelobeIdx), 'expected angle=30 in test grid');
    perturbed(sidelobeIdx) = perturbed(sidelobeIdx) + 2.0;
    cmp2 = imtAasComparePatternCut(angle, perturbed, angle, actual);
    assert(~cmp2.pass, 'expected fail for a 2.0 dB sidelobe perturbation');
    assert(cmp2.maxAbsErrorDb >= 1.999, ...
        'maxAbsErrorDb %.4f should be ~2.0', cmp2.maxAbsErrorDb);
    assert(any(~cellfun('isempty', strfind(cmp2.failReasons, 'maxAbsErrorDb'))), ...
        'failReasons should mention maxAbsErrorDb');
    fprintf('  [OK] 2.0 dB sidelobe perturbation fails with reason: %s\n', ...
        cmp2.failReasons{1});

    % ===== 3: coarse-reference interpolation ============================
    coarseAngle = -90:5:90;                          % 5x coarser than actual
    coarseRef   = 50 - 0.005 .* coarseAngle .^ 2;    % same function as actual
    cmp3 = imtAasComparePatternCut(angle, actual, coarseAngle, coarseRef);
    assert(cmp3.pass, ...
        ['coarse-reference interpolation should pass for a smooth ', ...
         'concave function (reasons: %s)'], ...
        strjoin(cmp3.failReasons, '; '));
    %   Linear interpolation of a quadratic adds residuals at the
    %   midpoints; bound them well under the default 0.5 dB main-lobe
    %   gate.
    assert(cmp3.maxAbsErrorDb < 0.5, ...
        'coarse-ref maxAbsErrorDb %.4f should be < 0.5 dB', ...
        cmp3.maxAbsErrorDb);
    assert(cmp3.maxAbsErrorDb > 0, ...
        'expected non-zero residual from coarse-ref interpolation');
    fprintf('  [OK] coarse-ref interpolation: maxAbs=%.4f dB, RMS=%.4f dB\n', ...
        cmp3.maxAbsErrorDb, cmp3.rmsErrorDb);

    % ===== 4: ignoreBelowDbm suppresses deep-null differences ===========
    actual4 = zeros(size(angle));
    actual4(angle == 0) = 50;            % main lobe peak at 0 deg
    refOk4 = actual4;                    % matches above the floor
    %   Push a few sample points well below the default -80 dBm floor
    %   on both vectors, but with very different (non-finite-disagreeing)
    %   values so that an unfiltered comparison would yield a large
    %   numerical error.
    deepIdx = [1, 2, numel(angle) - 1, numel(angle)];
    actual4(deepIdx) = -120;
    refOk4(deepIdx)  = -200;
    cmp4 = imtAasComparePatternCut(angle, actual4, angle, refOk4);
    assert(cmp4.pass, ...
        ['ignoreBelowDbm should drop deep-null disagreements; ', ...
         'reasons: %s'], strjoin(cmp4.failReasons, '; '));
    assert(cmp4.numIgnored == numel(deepIdx), ...
        'expected numIgnored = %d, got %d', ...
        numel(deepIdx), cmp4.numIgnored);
    assert(cmp4.maxAbsErrorDb < 1e-9, ...
        'after ignore, maxAbsErrorDb should be ~0, got %.4f', ...
        cmp4.maxAbsErrorDb);
    fprintf('  [OK] ignoreBelowDbm dropped %d deep-null points\n', ...
        cmp4.numIgnored);

    % ===== 5: main-lobe gate catches a localized main-lobe mismatch =====
    %   Same actual / reference baseline, but inject a 0.7 dB error at
    %   the peak (well within the 20-deg main-lobe window). The global
    %   maxAbsErrorDb gate (1.0 dB) and rmsErrorDb gate (0.5 dB) still
    %   pass, but the main-lobe maxAbs gate (0.5 dB) trips.
    actual5 = actual;
    refOk5  = actual;
    [~, peakIdx] = max(actual);
    actual5(peakIdx) = actual5(peakIdx) + 0.7;
    cmp5 = imtAasComparePatternCut(angle, actual5, angle, refOk5);
    assert(~cmp5.pass, 'expected main-lobe gate fail');
    assert(any(~cellfun('isempty', ...
        strfind(cmp5.failReasons, 'maxAbsErrorMainLobeDb'))), ...
        'failReasons should mention main-lobe gate');
    assert(cmp5.maxAbsErrorMainLobeDb > 0.5, ...
        'main-lobe error should exceed threshold, got %.4f', ...
        cmp5.maxAbsErrorMainLobeDb);
    %   Sanity: the global RMS gate would still pass on its own.
    assert(cmp5.rmsErrorDb < 0.5, ...
        'RMS gate should still pass independently, got %.4f', ...
        cmp5.rmsErrorDb);
    fprintf(['  [OK] main-lobe gate caught a 0.7 dB peak error ', ...
             '(main maxAbs=%.4f dB)\n'], cmp5.maxAbsErrorMainLobeDb);

    % ===== 6: loader reads required + optional columns ==================
    tmpDir = tempname();
    [okMk, msgMk] = mkdir(tmpDir);
    assert(okMk, 'could not create tmpDir %s (%s)', tmpDir, msgMk);
    cleanupTmp = onCleanup(@() rmdirSafe(tmpDir));

    csvPath = fullfile(tmpDir, 'sample_ref.csv');
    fid = fopen(csvPath, 'w');
    assert(fid >= 0, 'cannot write %s', csvPath);
    fprintf(fid, '# header line; comment must be ignored\n');
    fprintf(fid, 'angle_deg,eirp_dbm_per_100mhz,gain_dbi,notes\n');
    fprintf(fid, '\n');           % blank line, must be ignored
    fprintf(fid, '-90.0,15.2,3.4,edge\n');
    fprintf(fid, '0.0,78.3,32.2,peak\n');
    fprintf(fid, '90.0,15.2,3.4,edge\n');
    fclose(fid);

    ref = imtAasLoadReferenceCutCsv(csvPath);
    assert(ref.numPoints == 3, 'numPoints %d != 3', ref.numPoints);
    assert(isequal(size(ref.angleDeg), [1, 3]), ...
        'angleDeg should be a 1x3 row vector');
    assert(isequal(ref.angleDeg, [-90, 0, 90]), 'angleDeg mismatch');
    assert(isequal(ref.eirpDbmPer100MHz, [15.2, 78.3, 15.2]), ...
        'eirpDbmPer100MHz mismatch');
    assert(isfield(ref, 'gainDbi'), 'optional gainDbi should be present');
    assert(isequal(ref.gainDbi, [3.4, 32.2, 3.4]), 'gainDbi mismatch');
    assert(isfield(ref, 'notes'), 'optional notes should be present');
    assert(numel(ref.notes) == 3 && strcmp(ref.notes{2}, 'peak'), ...
        'notes column not parsed correctly');
    fprintf('  [OK] loader read 3 rows with optional gain/notes\n');

    % ===== 7a: missing required column =================================
    badPath = fullfile(tmpDir, 'bad_ref.csv');
    fid = fopen(badPath, 'w');
    fprintf(fid, 'angle_deg,gain_dbi\n');     % missing eirp_dbm_per_100mhz
    fprintf(fid, '0.0,32.2\n');
    fclose(fid);
    threw = false;
    try
        imtAasLoadReferenceCutCsv(badPath);
    catch err
        threw = true;
        assert(~isempty(strfind(err.message, 'eirp_dbm_per_100mhz')), ...
            'error message should name the missing column, got: %s', ...
            err.message);
    end
    assert(threw, 'expected missing-column error not raised');
    fprintf('  [OK] loader fails clearly on missing required column\n');

    % ===== 7b: missing file =============================================
    threw = false;
    try
        imtAasLoadReferenceCutCsv(fullfile(tmpDir, 'does_not_exist.csv'));
    catch err
        threw = true;
        assert(~isempty(strfind(err.message, 'not found')) || ...
               ~isempty(strfind(err.message, 'fileNotFound')), ...
            'error should mention "not found", got: %s', err.message);
    end
    assert(threw, 'expected file-not-found error not raised');

    % ===== 7c: non-finite required value ================================
    nanPath = fullfile(tmpDir, 'nan_ref.csv');
    fid = fopen(nanPath, 'w');
    fprintf(fid, 'angle_deg,eirp_dbm_per_100mhz\n');
    fprintf(fid, '0.0,NaN\n');
    fclose(fid);
    threw = false;
    try
        imtAasLoadReferenceCutCsv(nanPath);
    catch
        threw = true;
    end
    assert(threw, 'expected non-finite error not raised');
    fprintf('  [OK] loader fails on missing file and non-finite values\n');

    % ===== 8: plot returns a valid figure handle ========================
    figH = plotImtAasReferenceComparison(cmp, 'identical-vector check');
    assert(isgraphics(figH), 'plot must return a valid graphics handle');
    try
        close(figH);
    catch
        % non-fatal during headless tests
    end
    fprintf('  [OK] plotImtAasReferenceComparison returned a valid handle\n');

    % ===== 9: runAasReferenceValidation skips cleanly w/o references ====
    %   We avoid mutating the live references/aas/ directory. Instead we
    %   verify the harness's skip path by relying on the fact that the
    %   shipped repo does not contain reference CSVs. If a developer has
    %   added local reference CSVs, this branch is reported as a SKIP
    %   (not a failure) below, since the function would then run a real
    %   comparison and we cannot assert on its outcome here.
    if exist('runAasReferenceValidation', 'file') ~= 2
        warning('test_imtAasReferenceComparison:harnessNotOnPath', ...
            ['runAasReferenceValidation is not on the MATLAB path. ', ...
             'Skipping the skip-behavior check.']);
    else
        repoRefDir = fullfile(repoRoot, 'references', 'aas');
        horizRef = fullfile(repoRefDir, 'r23_macro_horizontal_cut.csv');
        vertRef  = fullfile(repoRefDir, 'r23_macro_vertical_cut.csv');
        bothAbsent = (exist(horizRef, 'file') ~= 2) && ...
                     (exist(vertRef,  'file') ~= 2);
        if bothAbsent
            s = runAasReferenceValidation();
            assert(isstruct(s), 'harness must return a struct');
            assert(isfield(s, 'skipped') && s.skipped, ...
                'harness should set summary.skipped=true when no refs exist');
            assert(isfield(s, 'allPassed') && s.allPassed, ...
                'skipped run should report allPassed=true (not a failure)');
            assert(~isfield(s, 'horizontal'), ...
                'skipped run should not produce horizontal comparison');
            assert(~isfield(s, 'vertical'), ...
                'skipped run should not produce vertical comparison');
            fprintf(['  [OK] runAasReferenceValidation skipped cleanly ', ...
                     'with no reference CSVs\n']);
        else
            fprintf(['  [SKIP] reference CSVs are present in %s; ', ...
                     'skip-behavior check not exercised\n'], repoRefDir);
        end
    end

    clear cleanupTmp; %#ok<CLMVR>

    results.passed = true;
    fprintf('--- test_imtAasReferenceComparison PASSED ---\n');
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
