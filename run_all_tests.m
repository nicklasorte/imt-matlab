function results = run_all_tests()
%RUN_ALL_TESTS Run the imt-matlab test suite and print a pass/fail summary.
%
%   RESULTS = run_all_tests()
%
%   Runs:
%       test_against_pycraf
%       test_against_pycraf_strict
%       test_aas_monte_carlo_eirp
%       test_export_eirp_percentile_table
%       test_ue_sector_sampler
%       test_runtime_scaling_controls
%
%   The pycraf comparison tests skip cleanly (rather than failing) when
%   Python or pycraf is not available; SKIPPED counts as PASS for the
%   overall summary so that MATLAB-only environments still pass.
%
%   RESULTS is a struct with fields .perTest (one entry per test) and
%   .allPassed (logical).
%
%   Run from the repo root:
%       run_all_tests
%
%   Or programmatically:
%       r = run_all_tests();
%       assert(r.allPassed, 'imt-matlab tests failed');

    here = fileparts(mfilename('fullpath'));
    matlabDir = fullfile(here, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    tests = { ...
        'test_against_pycraf',               ...
        'test_against_pycraf_strict',        ...
        'test_aas_monte_carlo_eirp',         ...
        'test_export_eirp_percentile_table', ...
        'test_ue_sector_sampler',            ...
        'test_runtime_scaling_controls'      ...
    };

    nTests = numel(tests);
    perTest = repmat(struct( ...
        'name',     '', ...
        'passed',   false, ...
        'skipped',  false, ...
        'errored',  false, ...
        'message',  ''), nTests, 1);

    fprintf('============================================================\n');
    fprintf(' imt-matlab :: run_all_tests\n');
    fprintf('============================================================\n');

    for i = 1:nTests
        name = tests{i};
        fprintf('\n>>> %s\n', name);
        entry = struct('name', name, 'passed', false, ...
                       'skipped', false, 'errored', false, 'message', '');
        try
            r = feval(name);
            entry.skipped = isfield(r, 'skipped') && logical(r.skipped);
            if isfield(r, 'passed')
                entry.passed = logical(r.passed);
            else
                entry.passed = true;
            end
            if entry.skipped && isfield(r, 'reason') && ~isempty(r.reason)
                entry.message = char(r.reason);
            end
        catch err
            entry.errored = true;
            entry.message = err.message;
            fprintf('!!! %s threw an error: %s\n', name, err.message);
        end
        perTest(i) = entry;
    end

    fprintf('\n============================================================\n');
    fprintf(' Summary\n');
    fprintf('============================================================\n');

    nPass    = 0;
    nFail    = 0;
    nSkip    = 0;
    nError   = 0;
    for i = 1:nTests
        e = perTest(i);
        if e.errored
            tag = 'ERROR';
            nError = nError + 1;
        elseif e.skipped
            tag = 'SKIP ';
            nSkip = nSkip + 1;
        elseif e.passed
            tag = 'PASS ';
            nPass = nPass + 1;
        else
            tag = 'FAIL ';
            nFail = nFail + 1;
        end
        if isempty(e.message)
            fprintf('  [%s] %s\n', tag, e.name);
        else
            fprintf('  [%s] %s  (%s)\n', tag, e.name, e.message);
        end
    end

    allPassed = (nFail == 0) && (nError == 0);
    fprintf('  -----------------------------------\n');
    fprintf('  total=%d  pass=%d  fail=%d  skip=%d  error=%d\n', ...
        nTests, nPass, nFail, nSkip, nError);
    if allPassed
        fprintf('  RESULT: ALL TESTS PASSED\n');
    else
        fprintf('  RESULT: TESTS FAILED\n');
    end
    fprintf('============================================================\n');

    results = struct('perTest', perTest, 'allPassed', allPassed);
end
