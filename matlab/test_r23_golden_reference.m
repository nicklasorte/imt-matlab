function results = test_r23_golden_reference()
%TEST_R23_GOLDEN_REFERENCE Frozen golden-scenario regression anchor tests.
%
%   Verifies:
%
%     G1. r23GoldenReferenceScenario("r23-urban-baseline-small-grid-v1")
%         returns the expected frozen seed / grid / percentile / preset.
%     G2. invalid golden name fails cleanly with the offending name.
%     G3. tracked golden artifacts exist on disk
%         (golden_manifest.json, percentile_summary.csv, ...).
%     G4. verifyR23GoldenReference passes against the tracked artifact.
%     G5. verifyR23GoldenReference fails cleanly when pointed at a
%         missing GoldenDir.
%     G6. golden_manifest.json carries the regression-anchor fields
%         (goldenReferenceName, goldenReferenceVersion,
%         expectedSelfCheckStatus, expectedObservedMaxGridEirp_dBm).
%
%   Antenna-face EIRP only -- no new modeling capability is exercised.

    results.summary = {};
    results.passed  = true;

    results = g1_builder_returns_frozen_params(results);
    results = g2_invalid_name_fails(results);
    results = g3_tracked_artifacts_exist(results);
    results = g4_verifier_passes(results);
    results = g5_verifier_handles_missing_dir(results);
    results = g6_manifest_has_required_fields(results);

    fprintf('\n--- test_r23_golden_reference summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    if results.passed
        fprintf('  ALL TESTS PASSED\n');
    else
        fprintf('  ONE OR MORE ASSERTIONS FAILED\n');
        error('test_r23_golden_reference:fail', ...
            'test_r23_golden_reference assertions failed.');
    end
end

% =====================================================================

function r = g1_builder_returns_frozen_params(r)
    name = 'r23-urban-baseline-small-grid-v1';
    p = r23GoldenReferenceScenario(name);
    okSeed       = isequal(p.sim.randomSeed, 20260101);
    okSnapshots  = isequal(p.sim.numSnapshots, 20);
    okAz         = isequal(double(p.sim.azGrid_deg(:).'), -60:20:60);
    okEl         = isequal(double(p.sim.elGrid_deg(:).'), -10:2:0);
    okPct        = isequal(double(p.sim.percentiles(:).'), ...
                           [1 5 10 20 50 80 90 95 99]);
    okPreset     = isfield(p.metadata, 'scenarioPreset') && ...
                   strcmp(char(p.metadata.scenarioPreset), 'urban-baseline');
    okGolden     = isfield(p.metadata, 'goldenReferenceName') && ...
                   strcmp(char(p.metadata.goldenReferenceName), name);
    okVersion    = isfield(p.metadata, 'goldenReferenceVersion') && ...
                   isequal(p.metadata.goldenReferenceVersion, 1);
    okPurpose    = isfield(p.metadata, 'goldenReferencePurpose') && ...
                   strcmp(char(p.metadata.goldenReferencePurpose), ...
                          'regression-anchor');
    ok = okSeed && okSnapshots && okAz && okEl && okPct && okPreset && ...
         okGolden && okVersion && okPurpose;
    msg = sprintf(['G1: frozen params (seed=%d, snapshots=%d, az=7, ' ...
                   'el=6, pct=9, preset=%d, goldenName=%d, version=%d, ' ...
                   'purpose=%d) all OK=%d'], ...
                   double(okSeed), double(okSnapshots), double(okPreset), ...
                   double(okGolden), double(okVersion), ...
                   double(okPurpose), double(ok));
    r = recordResult(r, ok, msg);
end

function r = g2_invalid_name_fails(r)
    threwExpected = false;
    msgText = '';
    try
        r23GoldenReferenceScenario('totally-not-a-golden-name'); %#ok<NASGU>
    catch err
        threwExpected = strcmp(err.identifier, ...
            'r23GoldenReferenceScenario:unknownGolden');
        msgText = err.message;
    end
    okMessageNamesInput = ~isempty(strfind(msgText, ...
        'totally-not-a-golden-name'));
    ok = threwExpected && okMessageNamesInput;
    msg = sprintf(['G2: unknown golden name fails with id=%d, error ' ...
                   'message names the offending input=%d'], ...
                   double(threwExpected), double(okMessageNamesInput));
    r = recordResult(r, ok, msg);
end

function r = g3_tracked_artifacts_exist(r)
    goldenDir = goldenDirFor('r23_urban_baseline_small_grid_v1');
    needed = {'golden_manifest.json', 'metadata.json', 'selfcheck.json', ...
              'scenario_diff.json', 'percentile_summary.csv', ...
              'validation_summary.txt'};
    missing = {};
    for k = 1:numel(needed)
        if exist(fullfile(goldenDir, needed{k}), 'file') ~= 2
            missing{end+1} = needed{k}; %#ok<AGROW>
        end
    end
    ok = isempty(missing);
    msg = sprintf('G3: tracked golden artifacts present in %s; missing=[%s]', ...
        goldenDir, strjoin(missing, ','));
    r = recordResult(r, ok, msg);
end

function r = g4_verifier_passes(r)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    res = verifyR23GoldenReference('r23-urban-baseline-small-grid-v1');
    ok = logical(res.passed);
    nDiffs = numel(res.differences);
    msg = sprintf(['G4: verifier passes against tracked golden ' ...
                   '(passed=%d, %d compared fields)'], double(ok), nDiffs);
    r = recordResult(r, ok, msg);
end

function r = g5_verifier_handles_missing_dir(r)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    bogusDir = fullfile(tempdir, ...
        sprintf('r23_golden_does_not_exist_%s', char('a' + floor(26*rand(1,8)))));
    res = verifyR23GoldenReference( ...
        'r23-urban-baseline-small-grid-v1', 'GoldenDir', bogusDir);
    failed   = ~res.passed;
    flagged  = false;
    for k = 1:numel(res.differences)
        if any(strcmp(res.differences(k).field, ...
                {'goldenDir', 'goldenManifest'}))
            flagged = true; break;
        end
    end
    ok = failed && flagged;
    msg = sprintf(['G5: verifier reports failure for missing golden ' ...
                   'dir (failed=%d, flagged=%d)'], ...
                   double(failed), double(flagged));
    r = recordResult(r, ok, msg);
end

function r = g6_manifest_has_required_fields(r)
    goldenDir = goldenDirFor('r23_urban_baseline_small_grid_v1');
    manifestPath = fullfile(goldenDir, 'golden_manifest.json');
    txt = readTextFile(manifestPath);
    needed = {'goldenReferenceName', 'goldenReferenceVersion', ...
              'scenarioPreset', 'randomSeed', 'numSnapshots', ...
              'azGrid_deg', 'elGrid_deg', 'percentiles', ...
              'expectedSelfCheckStatus', ...
              'expectedObservedMaxGridEirp_dBm', ...
              'expectedMaxPercentileAcrossGrid_dBm', ...
              'createdBy', 'createdUtc', 'repoCommitSha'};
    missing = {};
    for k = 1:numel(needed)
        if isempty(strfind(txt, needed{k}))
            missing{end+1} = needed{k}; %#ok<AGROW>
        end
    end
    ok = isempty(missing);
    msg = sprintf('G6: golden_manifest.json carries required fields; missing=[%s]', ...
        strjoin(missing, ','));
    r = recordResult(r, ok, msg);
end

% =====================================================================

function p = goldenDirFor(subdir)
    here = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    p = fullfile(repoRoot, 'artifacts', 'golden', subdir);
end

function txt = readTextFile(path)
    txt = '';
    fid = fopen(path, 'r');
    if fid < 0, return; end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    raw = fread(fid, Inf, 'uint8=>char');
    txt = raw(:).';
end

function r = recordResult(r, ok, msg)
    if ok
        tag = 'PASS';
    else
        tag = 'FAIL';
        r.passed = false;
    end
    r.summary{end+1} = sprintf('%s  %s', tag, msg);
end
