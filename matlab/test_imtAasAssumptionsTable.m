function results = test_imtAasAssumptionsTable()
%TEST_IMTAASASSUMPTIONSTABLE Self tests for imtAasAssumptionsTable.
%
%   RESULTS = test_imtAasAssumptionsTable()
%
%   Graphics-free deterministic coverage of the up-front assumptions /
%   knobs table assembled from a runR23AasEirpCdfGrid result:
%
%       T1.  Returns a 5-column table (Group, Parameter, Value, Units, Note).
%       T2.  Rows exist (by Parameter name) for the headline knobs:
%            bandwidthMHz, txPowerDbmPer100MHz, tddActivityFactor,
%            networkLoadingFactor, elevationLimitsDeg, beamSelection, numMc,
%            seed, and at least one scope-exclusion row.
%       T3.  Values match the source: bandwidthMHz == 100,
%            tddActivityFactor == 0.75, networkLoadingFactor == 0.20.
%       T4.  Units for txPowerDbmPer100MHz and sectorEirpDbm contain
%            'dBm/100MHz'.
%       T5.  impliedDutyCycleOffset_dB == 10*log10(0.75*0.20) (1e-9).
%       T6.  SSB on -> alphaSweep/alphaUe/alphaIdle rows present and sum to 1;
%            SSB off -> no alphaSweep row.
%       T7.  Markdown + CSV export produce non-empty files.
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  false
%       .reason   ''

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasAssumptionsTable ---\n');

    r = smallRun(struct('seed', 5, 'numMc', 30));
    T = imtAasAssumptionsTable(r, struct('print', false));

    % ===== T1: shape =====
    assert(istable(T), 'imtAasAssumptionsTable must return a table');
    assert(width(T) == 5, 'table must have exactly 5 columns (got %d)', width(T));
    assert(isequal(T.Properties.VariableNames, ...
        {'Group', 'Parameter', 'Value', 'Units', 'Note'}), ...
        'columns must be Group, Parameter, Value, Units, Note');
    assert(height(T) > 0, 'table must have rows');
    fprintf('  [OK] T1: 5-column table with the expected variable names\n');

    % ===== T2: required rows exist =====
    required = {'bandwidthMHz', 'txPowerDbmPer100MHz', 'tddActivityFactor', ...
        'networkLoadingFactor', 'elevationLimitsDeg', 'beamSelection', ...
        'numMc', 'seed'};
    for k = 1:numel(required)
        assert(hasRow(T, required{k}), ...
            'missing required row "%s"', required{k});
    end
    assert(hasRow(T, 'includesPathLoss'), ...
        'missing scope-exclusion row "includesPathLoss"');
    % And confirm the scope-exclusion row is grouped as a scope exclusion.
    idxExcl = rowIndex(T, 'includesPathLoss');
    assert(strcmp(T.Group{idxExcl}, 'Scope exclusions'), ...
        'includesPathLoss must be in the Scope exclusions group');
    assert(strcmpi(valueToStr(T.Value{idxExcl}), 'No'), ...
        'includesPathLoss value must be "No"');
    fprintf('  [OK] T2: all required rows + a scope-exclusion row present\n');

    % ===== T3: values match the source =====
    assert(valueOf(T, 'bandwidthMHz') == 100, ...
        'bandwidthMHz must be 100');
    assert(abs(valueOf(T, 'tddActivityFactor') - 0.75) < 1e-12, ...
        'tddActivityFactor must be 0.75 (read from params.bs)');
    assert(abs(valueOf(T, 'networkLoadingFactor') - 0.20) < 1e-12, ...
        'networkLoadingFactor must be 0.20 (read from params.bs)');
    fprintf('  [OK] T3: bandwidthMHz/tdd/loading values match the source\n');

    % ===== T4: dBm/100MHz units =====
    assert(contains(unitsOf(T, 'txPowerDbmPer100MHz'), 'dBm/100MHz'), ...
        'txPowerDbmPer100MHz units must contain dBm/100MHz');
    assert(contains(unitsOf(T, 'sectorEirpDbm'), 'dBm/100MHz'), ...
        'sectorEirpDbm units must contain dBm/100MHz');
    fprintf('  [OK] T4: power rows carry dBm/100MHz units\n');

    % ===== T5: implied duty-cycle offset =====
    expectedOffset = 10 * log10(0.75 * 0.20);
    assert(abs(valueOf(T, 'impliedDutyCycleOffset_dB') - expectedOffset) < 1e-9, ...
        'impliedDutyCycleOffset_dB must equal 10*log10(0.75*0.20)');
    fprintf('  [OK] T5: impliedDutyCycleOffset_dB = %.4f dB\n', expectedOffset);

    % ===== T6: SSB on adds the alpha rows that sum to 1 =====
    assert(~hasRow(T, 'alphaSweep'), ...
        'non-SSB table must NOT contain an alphaSweep row');
    rSsb = smallRun(struct('seed', 7, 'numMc', 20, 'ssb', struct()));
    Tssb = imtAasAssumptionsTable(rSsb, struct('print', false));
    assert(hasRow(Tssb, 'alphaSweep') && hasRow(Tssb, 'alphaUe') && ...
           hasRow(Tssb, 'alphaIdle'), ...
        'SSB-on table must contain alphaSweep/alphaUe/alphaIdle rows');
    alphaSum = valueOf(Tssb, 'alphaSweep') + valueOf(Tssb, 'alphaUe') + ...
               valueOf(Tssb, 'alphaIdle');
    assert(abs(alphaSum - 1) < 1e-9, ...
        'alphaSweep + alphaUe + alphaIdle must sum to 1 (got %.12g)', alphaSum);
    fprintf('  [OK] T6: SSB-on alphas present and sum to 1; SSB-off has none\n');

    % ===== T7: markdown + CSV export =====
    mdPath  = [tempname, '.md'];
    csvPath = [tempname, '.csv'];
    cleanupMd  = onCleanup(@() tryDelete(mdPath));  %#ok<NASGU>
    cleanupCsv = onCleanup(@() tryDelete(csvPath)); %#ok<NASGU>
    T2 = imtAasAssumptionsTable(r, struct('print', false, ...
        'markdownPath', mdPath, 'csvPath', csvPath));
    assert(istable(T2), 'export call must still return the table');
    assert(isfile(mdPath),  'markdown file must be written');
    assert(isfile(csvPath), 'CSV file must be written');
    md  = dir(mdPath);
    csv = dir(csvPath);
    assert(md.bytes  > 0, 'markdown file must be non-empty');
    assert(csv.bytes > 0, 'CSV file must be non-empty');
    fprintf('  [OK] T7: markdown + CSV exports are non-empty\n');

    results.passed = true;
    fprintf('--- test_imtAasAssumptionsTable PASSED ---\n');
end

% =====================================================================
% Helpers
% =====================================================================
function r = smallRun(extra)
    opts = struct();
    opts.aasGeometryPreset = 'r23_1x3_default';
    opts.numMc             = 30;
    opts.seed              = 5;
    opts.azGridDeg         = -30:10:30;   % 7
    opts.elGridDeg         = -10:5:10;    % 5
    opts.binEdgesDbm       = -80:5:120;
    opts.percentiles       = [1 5 50 95 99];
    flds = fieldnames(extra);
    for k = 1:numel(flds)
        opts.(flds{k}) = extra.(flds{k});
    end
    r = runR23AasEirpCdfGrid(opts);
end

function tf = hasRow(T, paramName)
    tf = any(strcmp(T.Parameter, paramName));
end

function idx = rowIndex(T, paramName)
    idx = find(strcmp(T.Parameter, paramName), 1, 'first');
    assert(~isempty(idx), 'row "%s" not found', paramName);
end

function v = valueOf(T, paramName)
    v = T.Value{rowIndex(T, paramName)};
end

function u = unitsOf(T, paramName)
    u = T.Units{rowIndex(T, paramName)};
end

function s = valueToStr(v)
    if ischar(v)
        s = v;
    elseif isnumeric(v) && isscalar(v)
        s = num2str(v);
    else
        s = '';
    end
end

function tryDelete(p)
    if exist(p, 'file') == 2
        delete(p);
    end
end
