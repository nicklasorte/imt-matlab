function results = test_freezeR23GoldenReference()
%TEST_FREEZER23GOLDENREFERENCE Tests for the golden freeze utility.
%
%   Verifies freezeR23GoldenReference end-to-end against TEMP golden
%   directories (never the tracked artifacts):
%
%     F1. freezing a scenario writes the snapshot sidecars +
%         golden_manifest.json into the target directory.
%     F2. golden_manifest.json carries the regression-anchor fields
%         (including goldenRunOptions and the tolerances block) and the
%         goldenRunOptions match the scenario.
%     F3. freeze -> verify round-trip: verifyR23GoldenReference pointed at
%         the just-frozen directory passes (freeze and verify use the same
%         seed / pipeline, so they must agree to within tolerance).
%     F4. the recorded goldenRunOptions actually take effect through the
%         freeze path -- the panel-frame freeze records outputFrame=panel
%         and produces a different observed max than the urban-baseline
%         freeze.
%     F5. bad arguments fail cleanly.
%
%   Antenna-face EIRP only -- no new modeling capability is exercised.

    results.summary = {};
    results.passed  = true;

    results = f1_freeze_writes_artifacts(results);
    results = f2_manifest_fields(results);
    results = f3_freeze_verify_roundtrip(results);
    results = f4_run_options_take_effect(results);
    results = f5_bad_args_fail(results);

    fprintf('\n--- test_freezeR23GoldenReference summary ---\n');
    for k = 1:numel(results.summary)
        fprintf('  %s\n', results.summary{k});
    end
    if results.passed
        fprintf('  ALL TESTS PASSED\n');
    else
        fprintf('  ONE OR MORE ASSERTIONS FAILED\n');
        error('test_freezeR23GoldenReference:fail', ...
            'test_freezeR23GoldenReference assertions failed.');
    end
end

% =====================================================================

function r = f1_freeze_writes_artifacts(r)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    tmp = makeTmpDir();
    guard = onCleanup(@() safeRmdir(tmp)); %#ok<NASGU>

    freezeR23GoldenReference('r23-urban-baseline-small-grid-v1', ...
        'GoldenDir', tmp);

    needed = {'golden_manifest.json', 'metadata.json', 'selfcheck.json', ...
              'scenario_diff.json', 'percentile_summary.csv', ...
              'validation_summary.txt'};
    missing = {};
    for k = 1:numel(needed)
        if exist(fullfile(tmp, needed{k}), 'file') ~= 2
            missing{end+1} = needed{k}; %#ok<AGROW>
        end
    end
    ok = isempty(missing);
    msg = sprintf('F1: freeze writes artifacts; missing=[%s]', ...
        strjoin(missing, ','));
    r = recordResult(r, ok, msg);
end

function r = f2_manifest_fields(r)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    tmp = makeTmpDir();
    guard = onCleanup(@() safeRmdir(tmp)); %#ok<NASGU>

    freezeR23GoldenReference('r23-urban-panelframe-small-grid-v1', ...
        'GoldenDir', tmp);
    m = readJson(fullfile(tmp, 'golden_manifest.json'));

    needed = {'goldenReferenceName', 'goldenReferenceVersion', ...
              'goldenReferencePurpose', 'scenarioPreset', 'randomSeed', ...
              'numSnapshots', 'azGrid_deg', 'elGrid_deg', 'percentiles', ...
              'expectedSelfCheckStatus', 'expectedObservedMaxGridEirp_dBm', ...
              'expectedMaxPercentileAcrossGrid_dBm', 'goldenRunOptions', ...
              'createdBy', 'createdUtc', 'repoCommitSha', 'tolerances'};
    missing = {};
    for k = 1:numel(needed)
        if ~isfield(m, needed{k})
            missing{end+1} = needed{k}; %#ok<AGROW>
        end
    end
    hasFields = isempty(missing);

    okName = isfield(m, 'goldenReferenceName') && strcmp( ...
        char(m.goldenReferenceName), 'r23-urban-panelframe-small-grid-v1');
    okRunOpt = isfield(m, 'goldenRunOptions') && ...
        isstruct(m.goldenRunOptions) && ...
        isfield(m.goldenRunOptions, 'outputFrame') && ...
        strcmp(char(m.goldenRunOptions.outputFrame), 'panel');
    okTol = isfield(m, 'tolerances') && isstruct(m.tolerances) && ...
        isfield(m.tolerances, 'absToleranceDeterministicEirp_dB') && ...
        abs(double(m.tolerances.absToleranceDeterministicEirp_dB) - 1e-6) < 1e-12 && ...
        isfield(m.tolerances, 'absTolerancePercentileBinned_dB') && ...
        abs(double(m.tolerances.absTolerancePercentileBinned_dB) - 0.51) < 1e-12;

    ok = hasFields && okName && okRunOpt && okTol;
    msg = sprintf(['F2: manifest fields (missing=[%s], name=%d, ' ...
                   'runOpt=%d, tol=%d)'], strjoin(missing, ','), ...
                   double(okName), double(okRunOpt), double(okTol));
    r = recordResult(r, ok, msg);
end

function r = f3_freeze_verify_roundtrip(r)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>
    names = {'r23-urban-baseline-small-grid-v1', ...
             'r23-urban-panelframe-small-grid-v1', ...
             'r23-ctia-1x6-small-grid-v1'};
    allOk = true;
    fails = {};
    for k = 1:numel(names)
        tmp = makeTmpDir();
        guard = onCleanup(@() safeRmdir(tmp)); %#ok<NASGU>
        freezeR23GoldenReference(names{k}, 'GoldenDir', tmp);
        res = verifyR23GoldenReference(names{k}, 'GoldenDir', tmp);
        if ~res.passed
            allOk = false;
            fails{end+1} = names{k}; %#ok<AGROW>
        end
        clear guard; % drop temp dir before next iteration
    end
    msg = sprintf('F3: freeze->verify round-trip passes; failed=[%s]', ...
        strjoin(fails, ','));
    r = recordResult(r, allOk, msg);
end

function r = f4_run_options_take_effect(r)
    s = warning('off', 'runR23AasEirpCdfGrid:powerSelfCheckWarn');
    cleanup = onCleanup(@() warning(s)); %#ok<NASGU>

    tmpBase = makeTmpDir();
    guardB = onCleanup(@() safeRmdir(tmpBase)); %#ok<NASGU>
    mBase = freezeR23GoldenReference('r23-urban-baseline-small-grid-v1', ...
        'GoldenDir', tmpBase);

    tmpPanel = makeTmpDir();
    guardP = onCleanup(@() safeRmdir(tmpPanel)); %#ok<NASGU>
    mPanel = freezeR23GoldenReference('r23-urban-panelframe-small-grid-v1', ...
        'GoldenDir', tmpPanel);

    panelRecorded = isstruct(mPanel.goldenRunOptions) && ...
        isfield(mPanel.goldenRunOptions, 'outputFrame') && ...
        strcmp(char(mPanel.goldenRunOptions.outputFrame), 'panel');
    baseEmpty = ~isstruct(mBase.goldenRunOptions) || ...
        isempty(fieldnames(mBase.goldenRunOptions));
    distinct = abs(double(mPanel.expectedObservedMaxGridEirp_dBm) - ...
        double(mBase.expectedObservedMaxGridEirp_dBm)) > 1e-6;

    ok = panelRecorded && baseEmpty && distinct;
    msg = sprintf(['F4: run options take effect (panelRecorded=%d, ' ...
                   'baseEmpty=%d, distinct=%d: base=%.6g panel=%.6g)'], ...
                   double(panelRecorded), double(baseEmpty), double(distinct), ...
                   double(mBase.expectedObservedMaxGridEirp_dBm), ...
                   double(mPanel.expectedObservedMaxGridEirp_dBm));
    r = recordResult(r, ok, msg);
end

function r = f5_bad_args_fail(r)
    threwNoArg = false;
    try
        freezeR23GoldenReference(); %#ok<NASGU>
    catch err
        threwNoArg = strcmp(err.identifier, 'freezeR23GoldenReference:badArgs');
    end
    threwBadOpt = false;
    try
        freezeR23GoldenReference('r23-urban-baseline-small-grid-v1', ...
            'NotAnOption', 1); %#ok<NASGU>
    catch err
        threwBadOpt = strcmp(err.identifier, ...
            'freezeR23GoldenReference:unknownOpt');
    end
    ok = threwNoArg && threwBadOpt;
    msg = sprintf('F5: bad args fail (noArg=%d, badOpt=%d)', ...
        double(threwNoArg), double(threwBadOpt));
    r = recordResult(r, ok, msg);
end

% =====================================================================

function d = makeTmpDir()
    tag = char('a' + floor(26 * rand(1, 10)));
    d = fullfile(tempdir, sprintf('r23_freeze_test_%s', tag));
    if exist(d, 'dir') ~= 7
        mkdir(d);
    end
end

function safeRmdir(d)
    try
        if exist(d, 'dir') == 7
            rmdir(d, 's');
        end
    catch
    end
end

function m = readJson(path)
    m = struct();
    fid = fopen(path, 'r');
    if fid < 0, return; end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    raw = fread(fid, Inf, 'uint8=>char').';
    try
        m = jsondecode(raw);
    catch
        m = struct();
    end
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
