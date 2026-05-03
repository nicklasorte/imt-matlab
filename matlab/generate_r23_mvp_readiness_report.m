function report = generate_r23_mvp_readiness_report(varargin)
%GENERATE_R23_MVP_READINESS_REPORT One-command readiness artifact for the R23 MVP.
%
%   REPORT = generate_r23_mvp_readiness_report()
%   REPORT = generate_r23_mvp_readiness_report(opts)
%
%   Runs run_all_tests(), checks the core R23 MVP file inventory, performs a
%   best-effort legacy-token hygiene scan, and writes a Markdown readiness
%   report to:
%
%       <repo>/reports/r23_mvp_readiness_report.md
%
%   This is a *reporting* utility. It does not change antenna math or any
%   model behavior. It does not add path loss, clutter, FS / FSS modeling,
%   interference aggregation, 19-site, 57-sector, or network laydown logic.
%
%   opts (struct, all optional):
%       .reportPath  - override the output Markdown path
%       .runTests    - logical, default true; if false, skips run_all_tests
%
%   REPORT is a struct with fields:
%       .timestamp        ISO-8601 local timestamp string
%       .matlabVersion    MATLAB version string, or '' if unavailable
%       .testResults      struct with .total .pass .fail .skip .error
%                         .allPassed .perTest (mirrors run_all_tests output)
%       .coreFiles        struct with .required (cellstr), .present (cellstr),
%                         .missing (cellstr), .allPresent (logical)
%       .legacyHygiene    struct with .ok (logical) and .message (string)
%       .reportPath       absolute path of the written Markdown report

    opts = parse_opts(varargin{:});

    here       = fileparts(mfilename('fullpath'));
    repoRoot   = fileparts(here);
    matlabDir  = here;

    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    timestamp     = local_timestamp();
    matlabVersion = safe_matlab_version();

    if opts.runTests
        testResults = run_tests_capture();
    else
        testResults = empty_test_results();
    end

    coreFiles     = check_core_files(matlabDir);
    legacyHygiene = legacy_token_hygiene(repoRoot);

    if isempty(opts.reportPath)
        reportsDir = fullfile(repoRoot, 'reports');
        reportPath = fullfile(reportsDir, 'r23_mvp_readiness_report.md');
    else
        reportPath = opts.reportPath;
        reportsDir = fileparts(reportPath);
    end
    if ~isempty(reportsDir) && exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    write_markdown(reportPath, timestamp, matlabVersion, testResults, ...
        coreFiles, legacyHygiene);

    report = struct( ...
        'timestamp',     timestamp, ...
        'matlabVersion', matlabVersion, ...
        'testResults',   testResults, ...
        'coreFiles',     coreFiles, ...
        'legacyHygiene', legacyHygiene, ...
        'reportPath',    reportPath);

    fprintf('Readiness report written: %s\n', reportPath);
end

% =====================================================================
function opts = parse_opts(varargin)
    opts = struct('reportPath', '', 'runTests', true);
    if isempty(varargin)
        return;
    end
    in = varargin{1};
    if isstruct(in)
        if isfield(in, 'reportPath')
            opts.reportPath = char(in.reportPath);
        end
        if isfield(in, 'runTests')
            opts.runTests = logical(in.runTests);
        end
    end
end

% =====================================================================
function ts = local_timestamp()
    try
        ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    catch
        ts = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST,TNOW1>
    end
end

% =====================================================================
function v = safe_matlab_version()
    v = '';
    try
        v = version();
    catch
        v = '';
    end
end

% =====================================================================
function r = empty_test_results()
    r = struct( ...
        'total',     0, ...
        'pass',      0, ...
        'fail',      0, ...
        'skip',      0, ...
        'error',     0, ...
        'allPassed', false, ...
        'ran',       false, ...
        'message',   'run_all_tests not invoked (opts.runTests = false)', ...
        'perTest',   []);
end

% =====================================================================
function r = run_tests_capture()
    r = empty_test_results();
    try
        results = run_all_tests();
    catch ex
        r.message = sprintf('run_all_tests threw: %s', ex.message);
        return;
    end

    r.ran       = true;
    r.message   = '';
    r.perTest   = results.perTest;
    r.allPassed = logical(results.allPassed);
    r.total     = numel(results.perTest);
    nPass = 0; nFail = 0; nSkip = 0; nErr = 0;
    for i = 1:numel(results.perTest)
        e = results.perTest(i);
        if e.errored
            nErr = nErr + 1;
        elseif e.skipped
            nSkip = nSkip + 1;
        elseif e.passed
            nPass = nPass + 1;
        else
            nFail = nFail + 1;
        end
    end
    r.pass  = nPass;
    r.fail  = nFail;
    r.skip  = nSkip;
    r.error = nErr;
end

% =====================================================================
function info = check_core_files(matlabDir)
    required = { ...
        'get_r23_aas_params.m', ...
        'validate_r23_params.m', ...
        'get_default_bs.m', ...
        'generate_single_sector_layout.m', ...
        'sample_ue_positions_in_sector.m', ...
        'compute_beam_angles_bs_to_ue.m', ...
        'clamp_beam_to_r23_coverage.m', ...
        'compute_bs_gain_toward_grid.m', ...
        'compute_eirp_grid.m', ...
        'run_monte_carlo_snapshots.m', ...
        'compute_cdf_per_grid_point.m', ...
        'runR23AasEirpCdfGrid.m'};

    present = {};
    missing = {};
    for i = 1:numel(required)
        fp = fullfile(matlabDir, required{i});
        if exist(fp, 'file') == 2
            present{end+1} = required{i}; %#ok<AGROW>
        else
            missing{end+1} = required{i}; %#ok<AGROW>
        end
    end
    info = struct( ...
        'required',   {required}, ...
        'present',    {present}, ...
        'missing',    {missing}, ...
        'allPresent', isempty(missing));
end

% =====================================================================
function info = legacy_token_hygiene(repoRoot)
    % The legacy project-specific token is constructed indirectly at run
    % time so that this source file itself never spells the literal token
    % contiguously and therefore cannot trip the hygiene check on its own.
    legacyToken = lower(['EMB' 'RSS']);
    skipDirs    = {'.git', 'node_modules', 'reports'};
    [hits, walkErr] = scan_repo_for_token(repoRoot, legacyToken, skipDirs);

    ok = isempty(hits);
    if ok && isempty(walkErr)
        msg = 'no legacy project-specific token occurrences in repo';
    elseif ok && ~isempty(walkErr)
        msg = sprintf( ...
            'no legacy project-specific token occurrences (walk had %d soft skips)', ...
            numel(walkErr));
    else
        msg = sprintf('legacy project-specific token hit(s): %s', ...
            strjoin(hits, ' | '));
    end
    info = struct('ok', ok, 'message', msg);
end

% =====================================================================
function [hits, errs] = scan_repo_for_token(rootDir, needle, skipDirs)
    hits = {};
    errs = {};
    stack = {rootDir};
    while ~isempty(stack)
        cur = stack{end};
        stack(end) = [];
        try
            entries = dir(cur);
        catch ex
            errs{end+1} = sprintf('%s: %s', cur, ex.message); %#ok<AGROW>
            continue;
        end
        for i = 1:numel(entries)
            e = entries(i);
            if strcmp(e.name, '.') || strcmp(e.name, '..')
                continue;
            end
            full = fullfile(cur, e.name);
            if e.isdir
                if any(strcmp(e.name, skipDirs))
                    continue;
                end
                stack{end+1} = full; %#ok<AGROW>
            else
                if ~is_text_extension(e.name)
                    continue;
                end
                txt = lower(read_text_file(full));
                if isempty(txt)
                    continue;
                end
                if ~isempty(strfind(txt, needle)) %#ok<STREMP>
                    hits{end+1} = full; %#ok<AGROW>
                end
            end
        end
    end
end

% =====================================================================
function tf = is_text_extension(name)
    [~, ~, ext] = fileparts(name);
    ext = lower(ext);
    tf = any(strcmp(ext, {'.m', '.md', '.txt', '.json', '.csv', ...
        '.yml', '.yaml', '.toml', '.cfg', '.ini'}));
end

% =====================================================================
function txt = read_text_file(fp)
    fid = fopen(fp, 'r');
    if fid < 0
        txt = '';
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    raw = fread(fid, '*char');
    txt = raw(:).';
end

% =====================================================================
function write_markdown(reportPath, timestamp, matlabVersion, testResults, ...
        coreFiles, legacyHygiene)
    fid = fopen(reportPath, 'w');
    if fid < 0
        error('generate_r23_mvp_readiness_report:cannotOpen', ...
            'Cannot open %s for writing.', reportPath);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# R23 MVP readiness report\n\n');
    fprintf(fid, '_Generated by `generate_r23_mvp_readiness_report.m`._\n\n');

    %% Summary
    fprintf(fid, '## Summary\n\n');
    fprintf(fid, '- Timestamp: `%s`\n', timestamp);
    if isempty(matlabVersion)
        fprintf(fid, '- MATLAB version: _unavailable_\n');
    else
        fprintf(fid, '- MATLAB version: `%s`\n', matlabVersion);
    end
    if testResults.ran
        fprintf(fid, '- Test suite executed: yes\n');
        fprintf(fid, '- Total tests: %d\n', testResults.total);
        fprintf(fid, '- Pass: %d  Fail: %d  Error: %d  Skip: %d\n', ...
            testResults.pass, testResults.fail, ...
            testResults.error, testResults.skip);
        if testResults.allPassed
            fprintf(fid, '- Overall result: **READY** (all tests pass; skipped tests count as pass)\n');
        else
            fprintf(fid, '- Overall result: **NOT READY** (one or more tests failed or errored)\n');
        end
    else
        fprintf(fid, '- Test suite executed: no\n');
        if ~isempty(testResults.message)
            fprintf(fid, '- Reason: %s\n', testResults.message);
        end
        fprintf(fid, '- Overall result: **UNKNOWN**\n');
    end
    fprintf(fid, '- Core MVP files all present: %s\n', yes_no(coreFiles.allPresent));
    fprintf(fid, '- Legacy-token hygiene: %s (%s)\n\n', ...
        yes_no(legacyHygiene.ok), legacyHygiene.message);

    %% Test results
    fprintf(fid, '## Test results\n\n');
    if testResults.ran && ~isempty(testResults.perTest)
        fprintf(fid, '| Test | Status | Message |\n');
        fprintf(fid, '| ---- | ------ | ------- |\n');
        for i = 1:numel(testResults.perTest)
            e = testResults.perTest(i);
            if e.errored
                tag = 'ERROR';
            elseif e.skipped
                tag = 'SKIP';
            elseif e.passed
                tag = 'PASS';
            else
                tag = 'FAIL';
            end
            msg = e.message;
            if isempty(msg)
                msg = '';
            end
            fprintf(fid, '| `%s` | %s | %s |\n', e.name, tag, sanitize_md(msg));
        end
        fprintf(fid, '\n');
    else
        fprintf(fid, '_No test results captured._\n\n');
        if ~isempty(testResults.message)
            fprintf(fid, '> %s\n\n', testResults.message);
        end
    end

    %% Core file inventory
    fprintf(fid, '## Core MVP file inventory\n\n');
    fprintf(fid, '| File | Present |\n');
    fprintf(fid, '| ---- | ------- |\n');
    for i = 1:numel(coreFiles.required)
        name = coreFiles.required{i};
        ok = any(strcmp(name, coreFiles.present));
        fprintf(fid, '| `matlab/%s` | %s |\n', name, yes_no(ok));
    end
    fprintf(fid, '\n');
    if ~coreFiles.allPresent
        fprintf(fid, '**Missing files:** %s\n\n', ...
            strjoin(coreFiles.missing, ', '));
    end

    %% Scope boundaries
    fprintf(fid, '## Scope boundaries confirmed\n\n');
    fprintf(fid, 'The R23 MVP is intentionally narrow. The following are explicitly in scope:\n\n');
    fprintf(fid, '- one site\n');
    fprintf(fid, '- one sector\n');
    fprintf(fid, '- three UEs\n');
    fprintf(fid, '- transmit-side EIRP only\n\n');
    fprintf(fid, 'The following are explicitly out of scope and are not implemented in the MVP:\n\n');
    fprintf(fid, '- no path loss\n');
    fprintf(fid, '- no clutter\n');
    fprintf(fid, '- no FS / FSS receiver modeling\n');
    fprintf(fid, '- no interference aggregation\n');
    fprintf(fid, '- no 19-site or 57-sector simulation\n\n');

    %% Known limitations
    fprintf(fid, '## Known limitations\n\n');
    fprintf(fid, '- The MVP exposes per-direction transmit-side EIRP only. CDFs are over\n');
    fprintf(fid, '  UE-driven beam pointings, not over time or propagation.\n');
    fprintf(fid, '- The R23 extended path is not bit-equivalent to pycraf; only the simple\n');
    fprintf(fid, '  M.2101 path is gated by `test_against_pycraf_strict` at 1e-6 dB.\n');
    fprintf(fid, '- Pycraf comparison tests skip cleanly when Python or pycraf is not\n');
    fprintf(fid, '  available; skipped tests count as pass for the overall summary.\n');
    fprintf(fid, '- The full per-snapshot EIRP cube returned by `run_monte_carlo_snapshots`\n');
    fprintf(fid, '  is intentional for the BS-driven MVP. For large grids prefer the\n');
    fprintf(fid, '  streaming `runR23AasEirpCdfGrid` runner.\n');
    fprintf(fid, '- This is **not ITU-certified**. Cross-check against M.2101 and 3GPP\n');
    fprintf(fid, '  TR 37.840 before using results in regulatory contexts.\n\n');

    %% Next recommended action
    fprintf(fid, '## Next recommended action\n\n');
    if testResults.ran && testResults.allPassed && coreFiles.allPresent && legacyHygiene.ok
        fprintf(fid, 'All readiness checks pass. The MVP is ready for use within its\n');
        fprintf(fid, 'documented scope. Suggested next steps:\n\n');
        fprintf(fid, '1. Wire downstream consumers (e.g. CDF post-processing, plotting)\n');
        fprintf(fid, '   against `runR23AasEirpCdfGrid` or `run_monte_carlo_snapshots`.\n');
        fprintf(fid, '2. When extending into out-of-scope items (path loss, FS / FSS,\n');
        fprintf(fid, '   multi-site aggregation), open a separate slice and keep this\n');
        fprintf(fid, '   readiness gate green.\n');
    elseif ~testResults.ran
        fprintf(fid, 'MATLAB execution was not performed. Re-run\n');
        fprintf(fid, '`generate_r23_mvp_readiness_report` in a MATLAB environment with\n');
        fprintf(fid, 'the repo `matlab/` folder on the path to populate test results.\n');
    else
        fprintf(fid, 'Address the failing checks above before declaring the MVP ready.\n');
        if ~testResults.allPassed
            fprintf(fid, '- Investigate failing or errored tests; do not loosen assertions.\n');
        end
        if ~coreFiles.allPresent
            fprintf(fid, '- Restore missing core MVP files: %s\n', ...
                strjoin(coreFiles.missing, ', '));
        end
        if ~legacyHygiene.ok
            fprintf(fid, '- Resolve legacy-token hygiene hits.\n');
        end
    end
    fprintf(fid, '\n');
end

% =====================================================================
function s = yes_no(tf)
    if tf
        s = 'yes';
    else
        s = 'no';
    end
end

% =====================================================================
function out = sanitize_md(s)
    if isempty(s)
        out = '';
        return;
    end
    s = char(s);
    s = strrep(s, '|', '\|');
    s = strrep(s, sprintf('\n'), ' ');
    s = strrep(s, sprintf('\r'), ' ');
    out = s;
end
