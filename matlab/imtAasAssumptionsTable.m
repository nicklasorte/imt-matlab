function T = imtAasAssumptionsTable(result, opts)
%IMTAASASSUMPTIONSTABLE Up-front knobs / assumptions table for an R23 AAS run.
%
%   T = imtAasAssumptionsTable(RESULT)
%   T = imtAasAssumptionsTable(RESULT, OPTS)
%
%   Assembles the Monte-Carlo knobs and modelling assumptions of a
%   runR23AasEirpCdfGrid result into a single grouped MATLAB table for the
%   DoW review. This is a pure POST-PROCESSING consumer of RESULT: it reads
%   RESULT.metadata / RESULT.params / RESULT.nestedParams /
%   RESULT.timeWeighted and never re-runs or mutates the model.
%
%   T is a table with five columns:
%       Group       grouping label (char)
%       Parameter   knob / assumption name (char)
%       Value       the value (native type: numeric scalar/vector, char, or
%                   logical -- so callers can read numbers programmatically)
%       Units       physical units (char, '' when dimensionless)
%       Note        short clarifying note (char)
%
%   Groups, in order:
%       1) Model & scope
%       2) Frequency & bandwidth
%       3) Deployment
%       4) Antenna geometry
%       5) Coverage limits
%       6) Power
%       7) Monte Carlo
%       8) Duty cycle & loading (POST-PROCESSING)
%       9) Time-weighted (SSB) aggregation   (only when SSB sweep was on)
%      10) Scope exclusions
%
%   The duty-cycle / loading group is flagged POST-PROCESSING: the EIRP grid
%   is the antenna-face value and does NOT bake in the TDD activity or
%   network-loading scaling. The informational "impliedDutyCycleOffset_dB"
%   row reports 10*log10(tdd*load) for downstream studies that choose to
%   apply it. The time-weighted (SSB) group only appears when
%   RESULT.metadata.includesSsbSweep is true.
%
%   OPTS (struct, all optional):
%       .print        logical, default true. Pretty-print the grouped table
%                     to the console with a header line stating the model and
%                     commit SHA.
%       .markdownPath char path. When non-empty, write T as a GitHub-flavored
%                     markdown table to that file.
%       .csvPath      char path. When non-empty, writetable(T, csvPath).
%
%   T is returned in every case.
%
%   Examples:
%       % 1) just build + pretty-print the table
%       r = runR23AasEirpCdfGrid(struct('aasGeometryPreset','r23_1x3_default'));
%       T = imtAasAssumptionsTable(r);
%
%       % 2) build silently and grab the table only
%       T = imtAasAssumptionsTable(r, struct('print', false));
%
%       % 3) build, print, and export to markdown + CSV
%       T = imtAasAssumptionsTable(r, struct( ...
%               'markdownPath', 'assumptions.md', ...
%               'csvPath',      'assumptions.csv'));
%
%   See also: runR23AasEirpCdfGrid, r23DefaultParams, imtAasDefaultParams,
%             plotR23AasEirpCdfGrid, plotR23AasGainHeatmap.

    if nargin < 1 || isempty(result) || ~isstruct(result)
        error('imtAasAssumptionsTable:invalidResult', ...
            'RESULT must be the struct returned by runR23AasEirpCdfGrid.');
    end
    if nargin < 2 || isempty(opts) || ~isstruct(opts)
        opts = struct();
    end
    doPrint      = getf(opts, 'print',        true);
    markdownPath = getf(opts, 'markdownPath', '');
    csvPath      = getf(opts, 'csvPath',      '');

    % ---- source structs (graceful: missing -> empty struct/default) --
    md        = getf(result, 'metadata',     struct());
    nested    = getf(result, 'nestedParams', struct());
    params    = getf(result, 'params',       struct());
    sector    = getf(result, 'sector',       struct());
    tw        = getf(result, 'timeWeighted', struct());
    geo       = getf(md,     'aasGeometry',  struct());
    deploy    = getf(nested, 'deployment',   struct());
    sim       = getf(nested, 'sim',          struct());
    optsRun   = getf(result, 'opts',         struct());
    ssbConfig = getf(md,     'ssbConfig',    struct());

    % TDD / loading live in nestedParams.bs (the task references params.bs;
    % the flat params struct has no .bs, so prefer params.bs then nested.bs).
    paramsBs = getf(params, 'bs', struct());
    nestedBs = getf(nested, 'bs', struct());

    R = cell(0, 5);

    % =================================================================
    % 1) Model & scope
    % =================================================================
    g = 'Model & scope';
    R = addRow(R, g, 'model',         getf(md, 'model', ''),         '', ...
        'antenna-face EIRP / gain study');
    R = addRow(R, g, 'scope',         getf(md, 'scope', ''),         '', '');
    R = addRow(R, g, 'generator',     getf(md, 'generator', ''),     '', '');
    R = addRow(R, g, 'repoCommitSha', getf(md, 'repoCommitSha', ''), '', ...
        'git HEAD at run time');
    R = addRow(R, g, 'createdAtIso',  getf(md, 'createdAtIso', ''),  '', ...
        'ISO 8601 UTC');
    R = addRow(R, g, 'matlabVersion', getf(md, 'matlabVersion', ''), '', '');

    % =================================================================
    % 2) Frequency & bandwidth
    % =================================================================
    g = 'Frequency & bandwidth';
    R = addRow(R, g, 'frequencyMHz',        getf(md, 'frequencyMHz', []), ...
        'MHz', '');
    R = addRow(R, g, 'bandwidthMHz',        getf(md, 'bandwidthMHz', []), ...
        'MHz', 'reference channel bandwidth');
    R = addRow(R, g, 'txPowerDbmPer100MHz', getf(md, 'txPowerDbmPer100MHz', []), ...
        'dBm/100MHz', 'conducted BS power');

    % =================================================================
    % 3) Deployment
    % =================================================================
    g = 'Deployment';
    R = addRow(R, g, 'environment',  getf(md, 'environment', ''), '', '');
    R = addRow(R, g, 'cellRadius_m', getf(md, 'cellRadius_m', []), 'm', '');
    R = addRow(R, g, 'bsHeight_m',   getf(md, 'bsHeight_m', []),   'm', ...
        'base-station antenna height');

    % =================================================================
    % 4) Antenna geometry
    % =================================================================
    g = 'Antenna geometry';
    R = addRow(R, g, 'aasGeometryPreset', getf(md, 'aasGeometryPreset', ''), ...
        '', '');
    R = addRow(R, g, 'numRows x numColumns', ...
        sizeStr(getf(md, 'numRows', []), getf(md, 'numColumns', [])), ...
        'rows x cols', 'N_V x N_H radiating sub-arrays');
    R = addRow(R, g, 'subArrayLayout', ...
        sizeStr(getf(geo, 'subarrayElementRows', []), ...
                getf(geo, 'subarrayElementCols', [])), ...
        'rows x cols', 'vertical sub-array (L elements x 1 col)');
    R = addRow(R, g, 'elementsPerSubArray', ...
        productOr(getf(geo, 'subarrayElementRows', []), ...
                  getf(geo, 'subarrayElementCols', [])), ...
        '', '');
    R = addRow(R, g, 'peakGainDbi', getf(md, 'peakGainDbi', []), 'dBi', ...
        'nominal composite peak gain');
    R = addRow(R, g, 'calculatedAntennaGainDbi', ...
        getf(geo, 'calculatedAntennaGainDbi', []), 'dBi', ...
        'element + sub-array + array gain');
    R = addRow(R, g, 'mechanicalDowntiltDeg', ...
        getf(md, 'mechanicalDowntiltDeg', []), 'deg', '');
    R = addRow(R, g, 'subarrayDowntiltDeg', ...
        getf(md, 'subarrayDowntiltDeg', []), 'deg', ...
        'fixed electrical sub-array downtilt');

    % =================================================================
    % 5) Coverage limits
    % =================================================================
    g = 'Coverage limits';
    azLimits = getf(sector, 'azLimitsDeg', []);
    if isempty(azLimits)
        hw = getf(deploy, 'sectorHalfWidthDeg', []);
        if ~isempty(hw)
            azLimits = [-double(hw), double(hw)];
        end
    end
    R = addRow(R, g, 'azimuthCoverageDeg', azLimits, 'deg', ...
        'sector half-width from boresight');
    R = addRow(R, g, 'elevationLimitsDeg', getf(md, 'elevationLimitsDeg', []), ...
        'deg', 'electronic steering gate');
    R = addRow(R, g, 'clampElevation', onOff(getf(md, 'clampElevation', [])), ...
        '', 'clamp beam elevation into the gate');

    % =================================================================
    % 6) Power
    % =================================================================
    g = 'Power';
    R = addRow(R, g, 'sectorEirpDbm', getf(md, 'sectorEirpDbm', []), ...
        'dBm/100MHz', 'sector peak EIRP');
    R = addRow(R, g, 'perBeamPeakEirpDbm', getf(md, 'perBeamPeakEirpDbm', []), ...
        'dBm/100MHz', 'sector EIRP split across N simultaneous beams');
    R = addRow(R, g, 'splitSectorPower', logical(getf(md, 'splitSectorPower', false)), ...
        '', 'split sector budget across simultaneous beams');

    % =================================================================
    % 7) Monte Carlo
    % =================================================================
    g = 'Monte Carlo';
    R = addRow(R, g, 'numMc', getf(md, 'numMc', []), '', ...
        'Monte Carlo snapshots');
    R = addRow(R, g, 'numUesPerSector', getf(md, 'numUesPerSector', []), ...
        '', 'simultaneous served UEs / beams');
    R = addRow(R, g, 'seed', getf(md, 'seed', []), '', 'RNG seed');
    pct = getf(optsRun, 'percentiles', getf(sim, 'percentiles', []));
    R = addRow(R, g, 'percentiles', pct, '%', 'reported CDF percentiles');
    R = addRow(R, g, 'outputFrame',  getf(md, 'outputFrame', ''),  '', '');
    R = addRow(R, g, 'outputDomain', getf(md, 'outputDomain', ''), '', ...
        'eirp | gain | both');
    beamSel = getf(md, 'beamSelection', '');
    R = addRow(R, g, 'beamSelection', beamSel, '', 'ideal | codebook');
    if ischar(beamSel) && strcmpi(beamSel, 'codebook')
        cb = getf(md, 'beamCodebook', struct());
        R = addRow(R, g, 'codebookOversample', ...
            [getf(cb, 'oversampleH', []), getf(cb, 'oversampleV', [])], ...
            '', '3GPP TS 38.214 Type I oversampling [O_H O_V]');
    end
    R = addRow(R, g, 'pointingSummaryStatistic', ...
        getf(md, 'pointingSummaryStatistic', ''), '', '');

    % =================================================================
    % 8) Duty cycle & loading (POST-PROCESSING)
    % =================================================================
    g = 'Duty cycle & loading (POST-PROCESSING)';
    tdd     = getf(paramsBs, 'tddActivityFactor',    getf(nestedBs, 'tddActivityFactor', []));
    loadFac = getf(paramsBs, 'networkLoadingFactor', getf(nestedBs, 'networkLoadingFactor', []));
    loadOpt = getf(paramsBs, 'networkLoadingOptions', getf(nestedBs, 'networkLoadingOptions', []));
    R = addRow(R, g, 'tddActivityFactor',    tdd,     '', 'TDD DL activity factor');
    R = addRow(R, g, 'networkLoadingFactor', loadFac, '', 'baseline network loading');
    R = addRow(R, g, 'networkLoadingOptions', loadOpt, '', 'studied loading options');
    if isnumeric(tdd) && isscalar(tdd) && isnumeric(loadFac) && isscalar(loadFac) ...
            && isfinite(tdd) && isfinite(loadFac) && tdd > 0 && loadFac > 0
        R = addRow(R, g, 'impliedDutyCycleOffset_dB', ...
            10 * log10(tdd * loadFac), 'dB', ...
            ['Applied in post-processing only; the EIRP grid is the ', ...
             'antenna-face value and does NOT include this scaling.']);
    end

    % =================================================================
    % 9) Time-weighted (SSB) aggregation -- only when SSB sweep was on
    % =================================================================
    if logical(getf(md, 'includesSsbSweep', false))
        g  = 'Time-weighted (SSB) aggregation';
        tb = getf(tw, 'timeBudget', struct());
        R = addRow(R, g, 'alphaSweep', ...
            getf(tb, 'alphaSweep', getf(tw, 'alphaSweep', [])), '', ...
            'sweep-class OFDM-symbol duty fraction');
        R = addRow(R, g, 'alphaUe', ...
            getf(tb, 'alphaUe', getf(tw, 'alphaUe', [])), '', ...
            'UE-class OFDM-symbol duty fraction');
        R = addRow(R, g, 'alphaIdle', ...
            getf(tb, 'alphaIdle', getf(tw, 'alphaIdle', [])), '', ...
            'idle / UL fraction (alphas sum to 1)');
        R = addRow(R, g, 'frameScsKHz', ...
            firstNonEmpty(getf(tb, 'ssbScs_kHz', []), ...
                          nestedGet(tb, {'frame', 'scs_kHz'}, [])), ...
            'kHz', 'sub-carrier spacing');
        R = addRow(R, g, 'ssbBlocksL', ...
            firstNonEmpty(getf(tb, 'numSSB', []), ...
                          nestedGet(tb, {'frame', 'ssb', 'L'}, []), ...
                          getf(ssbConfig, 'numBeams', [])), ...
            '', 'SS/PBCH blocks per burst');
        R = addRow(R, g, 'ssbPeriodMs', ...
            firstNonEmpty(getf(tb, 'ssbPeriod_ms', []), ...
                          nestedGet(tb, {'frame', 'ssb', 'period_ms'}, [])), ...
            'ms', 'SSB burst period');
        R = addRow(R, g, 'sweepBeamCount', getf(ssbConfig, 'numBeams', []), ...
            '', 'deterministic SSB sweep beams');
    end

    % =================================================================
    % 10) Scope exclusions
    % =================================================================
    g = 'Scope exclusions';
    exclNames = { ...
        'includesPathLoss', 'includesReceiverAntenna', ...
        'includesReceiverGain', 'includesPropagation', ...
        'includesCoordinationDistance', 'includesMultiSiteAggregation', ...
        'includesINMetric'};
    for k = 1:numel(exclNames)
        nm = exclNames{k};
        if isfield(md, nm)
            R = addRow(R, g, nm, yesNo(md.(nm)), '', ...
                'not modeled in this antenna-face EIRP/gain study');
        end
    end

    % ---- assemble the table -----------------------------------------
    Group     = R(:, 1);
    Parameter = R(:, 2);
    Value     = R(:, 3);
    Units     = R(:, 4);
    Note      = R(:, 5);
    T = table(Group, Parameter, Value, Units, Note);

    % ---- optional console print -------------------------------------
    if logical(doPrint)
        printGroupedTable(T, getf(md, 'model', ''), getf(md, 'repoCommitSha', ''));
    end

    % ---- optional markdown export -----------------------------------
    if ~isempty(markdownPath)
        writeMarkdownTable(T, char(markdownPath), ...
            getf(md, 'model', ''), getf(md, 'repoCommitSha', ''));
    end

    % ---- optional CSV export ----------------------------------------
    if ~isempty(csvPath)
        ensureParentDir(char(csvPath));
        Tcsv = T;
        Tcsv.Value = cellfun(@valueToString, T.Value, 'UniformOutput', false);
        writetable(Tcsv, char(csvPath));
    end
end

% =====================================================================
% Row assembly
% =====================================================================
function R = addRow(R, group, param, value, units, note)
    R(end+1, :) = {group, param, value, units, note}; %#ok<AGROW>
end

% =====================================================================
% Console pretty-print
% =====================================================================
function printGroupedTable(T, modelStr, commitStr)
    fprintf('============================================================\n');
    fprintf(' IMT-AAS Monte-Carlo assumptions\n');
    fprintf('   model : %s\n', valueToString(modelStr));
    fprintf('   commit: %s\n', valueToString(commitStr));
    fprintf('============================================================\n');

    groups    = T.Group;
    params    = T.Parameter;
    values    = T.Value;
    units     = T.Units;
    notes     = T.Note;

    % Align the parameter column for readability.
    pw = 0;
    for i = 1:numel(params)
        pw = max(pw, numel(params{i}));
    end
    pw = max(pw, 8);

    lastGroup = '';
    for i = 1:numel(params)
        if ~strcmp(groups{i}, lastGroup)
            fprintf('\n[%s]\n', groups{i});
            lastGroup = groups{i};
        end
        valStr = valueToString(values{i});
        u = units{i};
        if ~isempty(u)
            valStr = sprintf('%s %s', valStr, u);
        end
        n = notes{i};
        if isempty(n)
            fprintf('  %-*s : %s\n', pw, params{i}, valStr);
        else
            fprintf('  %-*s : %s   (%s)\n', pw, params{i}, valStr, n);
        end
    end
    fprintf('\n');
end

% =====================================================================
% Markdown export (GitHub-flavored)
% =====================================================================
function writeMarkdownTable(T, mdPath, modelStr, commitStr)
    ensureParentDir(mdPath);
    fid = fopen(mdPath, 'w');
    if fid < 0
        warning('imtAasAssumptionsTable:cannotOpenMarkdown', ...
            'Could not open %s for writing.', mdPath);
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# IMT-AAS Monte-Carlo assumptions\n\n');
    fprintf(fid, '- model: %s\n', valueToString(modelStr));
    fprintf(fid, '- commit: %s\n\n', valueToString(commitStr));

    cols = {'Group', 'Parameter', 'Value', 'Units', 'Note'};
    fprintf(fid, '| %s |\n', strjoin(cols, ' | '));
    fprintf(fid, '| %s |\n', strjoin(repmat({'---'}, 1, numel(cols)), ' | '));

    for i = 1:height(T)
        cells = { ...
            mdEscape(T.Group{i}), ...
            mdEscape(T.Parameter{i}), ...
            mdEscape(valueToString(T.Value{i})), ...
            mdEscape(T.Units{i}), ...
            mdEscape(T.Note{i})};
        fprintf(fid, '| %s |\n', strjoin(cells, ' | '));
    end
end

function s = mdEscape(s)
    s = valueToString(s);
    s = strrep(s, '|', '\|');
    s = strrep(s, char(10), ' ');   % no literal newlines inside a md cell
    s = strrep(s, char(13), ' ');
end

% =====================================================================
% Value formatting
% =====================================================================
function s = valueToString(v)
    if ischar(v)
        s = v;
    elseif isstring(v)
        if isscalar(v)
            s = char(v);
        else
            s = ['[' char(strjoin(v(:).', ' ')) ']'];
        end
    elseif islogical(v)
        if isscalar(v)
            s = ternary(v, 'true', 'false');
        else
            parts = arrayfun(@(x) ternary(x, 'true', 'false'), ...
                v(:).', 'UniformOutput', false);
            s = ['[' strjoin(parts, ' ') ']'];
        end
    elseif isnumeric(v)
        if isempty(v)
            s = '';
        elseif isscalar(v)
            s = num2str(v, '%g');
        else
            parts = arrayfun(@(x) num2str(x, '%g'), v(:).', ...
                'UniformOutput', false);
            s = ['[' strjoin(parts, ' ') ']'];
        end
    else
        s = '<unprintable>';
    end
end

% =====================================================================
% Small helpers
% =====================================================================
function v = getf(s, name, default)
%GETF Struct field read with default for missing / empty fields.
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end

function v = nestedGet(s, path, default)
%NESTEDGET Nested struct read; default for any missing / empty link.
    v = default;
    cur = s;
    for k = 1:numel(path)
        if isstruct(cur) && isfield(cur, path{k}) && ~isempty(cur.(path{k}))
            cur = cur.(path{k});
        else
            return;
        end
    end
    v = cur;
end

function v = firstNonEmpty(varargin)
%FIRSTNONEMPTY Return the first non-empty argument, else [].
    v = [];
    for k = 1:nargin
        if ~isempty(varargin{k})
            v = varargin{k};
            return;
        end
    end
end

function s = sizeStr(a, b)
%SIZESTR 'a x b' for two numeric scalars; '' when either is missing.
    if isnumeric(a) && isscalar(a) && isnumeric(b) && isscalar(b)
        s = sprintf('%g x %g', double(a), double(b));
    else
        s = '';
    end
end

function v = productOr(a, b)
%PRODUCTOR a*b for two numeric scalars; [] when either is missing.
    if isnumeric(a) && isscalar(a) && isnumeric(b) && isscalar(b)
        v = double(a) * double(b);
    else
        v = [];
    end
end

function s = onOff(v)
%ONOFF 'on' / 'off' for a logical-ish value; '' when missing.
    if isempty(v)
        s = '';
    elseif logical(v)
        s = 'on';
    else
        s = 'off';
    end
end

function s = yesNo(v)
%YESNO 'Yes' / 'No' for a logical-ish value; '' when missing.
    if isempty(v)
        s = '';
    elseif logical(v)
        s = 'Yes';
    else
        s = 'No';
    end
end

function s = ternary(cond, a, b)
    if cond
        s = a;
    else
        s = b;
    end
end

function ensureParentDir(p)
    [d, ~, ~] = fileparts(p);
    if ~isempty(d) && exist(d, 'dir') ~= 7
        mkdir(d);
    end
end
