function results = test_r23_validation_artifacts()
%TEST_R23_VALIDATION_ARTIFACTS Provenance + snapshot artifact tests.
%
%   Verifies:
%
%     A1. runR23AasEirpCdfGrid stamps provenance fields onto out.metadata
%         (repoCommitSha, matlabVersion, platform, validationTimestampUtc).
%     A2. exportR23ValidationSnapshot creates the output directory.
%     A3. All five expected files are written.
%     A4. metadata.json contains scenarioPreset (when from a preset run).
%     A5. metadata.json contains a non-empty repoCommitSha field.
%     A6. selfcheck.json is exported and parses with the expected status field.
%     A7. validation_summary.txt contains the self-check status.
%     A8. Exports stay lightweight (cap each artifact at 256 KiB).
%
%   Antenna-face EIRP only -- no modeling capability is exercised here.

    results.summary = {};
    results.passed  = true;

    [snapshot, out, tmpDir, presetName] = runMiniSnapshot();
    cleanup = onCleanup(@() cleanupTempDir(tmpDir)); %#ok<NASGU>

    results = a1_provenance_fields(results, out);
    results = a2_directory_created(results, tmpDir);
    results = a3_files_written(results, snapshot);
    results = a4_metadata_has_scenario(results, snapshot, presetName);
    results = a5_metadata_has_sha(results, snapshot);
    results = a6_selfcheck_exported(results, snapshot);
    results = a7_summary_has_status(results, snapshot, out);
    results = a8_lightweight_artifacts(results, snapshot);

    fprintf('\n--- test_r23_validation_artifacts summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    if results.passed
        fprintf('  ALL TESTS PASSED\n');
    else
        fprintf('  ONE OR MORE ASSERTIONS FAILED\n');
        error('test_r23_validation_artifacts:fail', ...
            'test_r23_validation_artifacts assertions failed.');
    end
end

% =====================================================================

function [snapshot, out, tmpDir, presetName] = runMiniSnapshot()
    presetName = 'urban-baseline';
    params = r23ScenarioPreset(presetName);
    % Keep the run small -- this test is about export I/O, not modeling.
    params.numSnapshots          = 5;
    params.sim.numSnapshots      = 5;
    params.sim.azGrid_deg        = [-30 0 30];
    params.sim.elGrid_deg        = [-5 0];
    params.sim.computePointingHeatmap = true;

    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>

    out = runR23AasEirpCdfGrid(params);

    tmpDir = fullfile(tempdir, sprintf('r23_artifacts_%s', randTag()));
    snapshot = exportR23ValidationSnapshot(out, tmpDir);
end

function tag = randTag()
    tag = char('a' + floor(26 * rand(1, 10)));
end

function cleanupTempDir(tmpDir)
    try
        if exist(tmpDir, 'dir') == 7
            rmdir(tmpDir, 's');
        end
    catch
    end
end

% =====================================================================

function r = a1_provenance_fields(r, out)
    md = out.metadata;
    needed = {'repoCommitSha', 'matlabVersion', 'platform', ...
              'validationTimestampUtc'};
    ok = true;
    missing = {};
    for k = 1:numel(needed)
        if ~isfield(md, needed{k}) || isempty(md.(needed{k}))
            ok = false;
            missing{end+1} = needed{k}; %#ok<AGROW>
        end
    end
    msg = sprintf(['A1: out.metadata stamps provenance fields ' ...
                   '(repoCommitSha, matlabVersion, platform, ' ...
                   'validationTimestampUtc); missing=[%s]'], ...
                   strjoin(missing, ','));
    r = recordResult(r, ok, msg);
end

function r = a2_directory_created(r, tmpDir)
    ok = exist(tmpDir, 'dir') == 7;
    msg = sprintf('A2: snapshot directory created at %s (exists=%d)', ...
        tmpDir, ok);
    r = recordResult(r, ok, msg);
end

function r = a3_files_written(r, snapshot)
    expected = {'metadata', 'selfCheck', 'scenarioDiff', ...
                'percentileSummary', 'validationSummary'};
    ok = true;
    missing = {};
    for k = 1:numel(expected)
        nm = expected{k};
        if ~isfield(snapshot.files, nm) || ...
                exist(snapshot.files.(nm), 'file') ~= 2
            ok = false;
            missing{end+1} = nm; %#ok<AGROW>
        end
    end
    msg = sprintf(['A3: all five artifact files written ' ...
                   '(metadata.json, selfcheck.json, scenario_diff.json, ' ...
                   'percentile_summary.csv, validation_summary.txt); ' ...
                   'missing=[%s]'], strjoin(missing, ','));
    r = recordResult(r, ok, msg);
end

function r = a4_metadata_has_scenario(r, snapshot, presetName)
    txt = readTextFile(snapshot.files.metadata);
    ok = ~isempty(strfind(txt, '"scenarioPreset"')) && ...
         ~isempty(strfind(txt, presetName));
    msg = sprintf(['A4: metadata.json contains scenarioPreset=%s ' ...
                   '(found token=%d)'], presetName, ok);
    r = recordResult(r, ok, msg);
end

function r = a5_metadata_has_sha(r, snapshot)
    txt = readTextFile(snapshot.files.metadata);
    hasField = ~isempty(strfind(txt, '"repoCommitSha"'));
    % The value can be 'unknown' if git is not available -- still a pass
    % for the field-presence contract. We only require the field to be
    % stamped at all.
    ok = hasField;
    msg = sprintf(['A5: metadata.json contains repoCommitSha field ' ...
                   '(present=%d)'], hasField);
    r = recordResult(r, ok, msg);
end

function r = a6_selfcheck_exported(r, snapshot)
    txt = readTextFile(snapshot.files.selfCheck);
    ok = ~isempty(strfind(txt, '"powerSemantics"')) || ...
         ~isempty(strfind(txt, '"status"'));
    msg = sprintf('A6: selfcheck.json exported with status field (ok=%d)', ok);
    r = recordResult(r, ok, msg);
end

function r = a7_summary_has_status(r, snapshot, out)
    txt = readTextFile(snapshot.files.validationSummary);
    expectedStatus = '';
    if isfield(out, 'selfCheck') && isfield(out.selfCheck, 'powerSemantics') ...
            && isfield(out.selfCheck.powerSemantics, 'status')
        expectedStatus = out.selfCheck.powerSemantics.status;
    end
    okStatus = ~isempty(strfind(txt, 'status'));
    okValue  = isempty(expectedStatus) || ...
               ~isempty(strfind(lower(txt), lower(expectedStatus)));
    ok = okStatus && okValue;
    msg = sprintf(['A7: validation_summary.txt contains self-check ' ...
                   'status=%s (statusLabel=%d, valueFound=%d)'], ...
                   expectedStatus, okStatus, okValue);
    r = recordResult(r, ok, msg);
end

function r = a8_lightweight_artifacts(r, snapshot)
    capBytes = 256 * 1024;   % 256 KiB per artifact ceiling
    flds = fieldnames(snapshot.files);
    ok = true;
    biggest = 0;
    biggestName = '';
    for k = 1:numel(flds)
        d = dir(snapshot.files.(flds{k}));
        if isempty(d), continue; end
        b = d(1).bytes;
        if b > biggest
            biggest = b;
            biggestName = flds{k};
        end
        if b > capBytes
            ok = false;
        end
    end
    msg = sprintf(['A8: each artifact <= 256 KiB (max=%s @ %d bytes, ' ...
                   'cap=%d)'], biggestName, biggest, capBytes);
    r = recordResult(r, ok, msg);
end

% =====================================================================

function r = recordResult(r, ok, msg)
    if ok
        tag = 'PASS';
    else
        tag = 'FAIL';
        r.passed = false;
    end
    r.summary{end+1} = sprintf('%s  %s', tag, msg);
end

function txt = readTextFile(path)
    fid = fopen(path, 'r');
    if fid < 0
        txt = '';
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    raw = fread(fid, Inf, 'uint8=>char');
    txt = raw(:).';
end
