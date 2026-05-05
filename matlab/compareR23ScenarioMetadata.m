function diff = compareR23ScenarioMetadata(a, b, varargin)
%COMPARER23SCENARIOMETADATA Lightweight scenario-config diff helper.
%
%   DIFF = compareR23ScenarioMetadata(A, B)
%   DIFF = compareR23ScenarioMetadata(A, B, 'Print', false)
%
%   A and B may each be either:
%       - a nested params struct from r23ScenarioPreset / r23DefaultParams
%       - an output struct from runR23AasEirpCdfGrid (uses out.nestedParams
%         when present, otherwise reads metadata + params directly)
%
%   Compares the canonical baseline scenario fields:
%       environment
%       cellRadius_m
%       bsHeight_m
%       numUesPerSector
%       maxEirpPerSector_dBm
%       channelBandwidth_MHz
%       randomSeed
%       scenarioPreset
%       sourceReference
%
%   Returns DIFF as a struct array (one entry per field) with .field,
%   .a, .b, .equal. By default prints a small text table to the
%   command window. Pass 'Print', false to suppress the printout.
%
%   This helper does NOT compare full Monte Carlo statistics. It is
%   intended for quick "how do these two scenarios differ in input
%   configuration?" sanity checks.
%
%   Example:
%       pa = r23ScenarioPreset("urban-baseline");
%       pb = r23ScenarioPreset("suburban-baseline");
%       compareR23ScenarioMetadata(pa, pb);
%
%   See also: r23ScenarioPreset, r23DefaultParams, runR23AasEirpCdfGrid.

    doPrint = true;
    if ~isempty(varargin)
        if mod(numel(varargin), 2) ~= 0
            error('compareR23ScenarioMetadata:badArgs', ...
                'Optional arguments must be Name, Value pairs.');
        end
        for k = 1:2:numel(varargin)
            name = varargin{k};
            if isstring(name) && isscalar(name); name = char(name); end
            value = varargin{k+1};
            switch lower(name)
                case 'print'
                    doPrint = logical(value);
                otherwise
                    error('compareR23ScenarioMetadata:badArgs', ...
                        'Unknown option "%s".', name);
            end
        end
    end

    sa = extractScenarioFields(a, 'A');
    sb = extractScenarioFields(b, 'B');

    fieldsToCompare = { ...
        'scenarioPreset', ...
        'environment', ...
        'cellRadius_m', ...
        'bsHeight_m', ...
        'numUesPerSector', ...
        'maxEirpPerSector_dBm', ...
        'channelBandwidth_MHz', ...
        'randomSeed', ...
        'sourceReference'};

    diff = repmat(struct('field', '', 'a', [], 'b', [], 'equal', false), ...
        numel(fieldsToCompare), 1);

    for k = 1:numel(fieldsToCompare)
        f = fieldsToCompare{k};
        va = getFieldOrEmpty(sa, f);
        vb = getFieldOrEmpty(sb, f);
        diff(k).field = f;
        diff(k).a     = va;
        diff(k).b     = vb;
        diff(k).equal = isEqualLoose(va, vb);
    end

    if doPrint
        printDiffTable(diff, sa, sb);
    end
end

% =====================================================================

function s = extractScenarioFields(x, label)
%EXTRACTSCENARIOFIELDS Pull the canonical scenario fields out of a params
% struct or a runR23AasEirpCdfGrid output struct.
    if ~isstruct(x)
        error('compareR23ScenarioMetadata:badInput', ...
            'Input %s must be a struct.', label);
    end

    nested = [];
    if isfield(x, 'nestedParams') && isstruct(x.nestedParams)
        nested = x.nestedParams;
    elseif isfield(x, 'aas') && isfield(x, 'bs') && isfield(x, 'ue')
        nested = x;
    end

    s = struct();
    s.scenarioPreset       = '';
    s.sourceReference      = '';
    s.environment          = '';
    s.cellRadius_m         = [];
    s.bsHeight_m           = [];
    s.numUesPerSector      = [];
    s.maxEirpPerSector_dBm = [];
    s.channelBandwidth_MHz = [];
    s.randomSeed           = [];

    if ~isempty(nested)
        if isfield(nested, 'metadata') && isstruct(nested.metadata)
            md = nested.metadata;
            if isfield(md, 'scenarioPreset')
                s.scenarioPreset = md.scenarioPreset;
            end
            if isfield(md, 'sourceReference')
                s.sourceReference = md.sourceReference;
            elseif isfield(md, 'sourceDefault')
                s.sourceReference = md.sourceDefault;
            end
        end
        if isfield(nested, 'deployment')
            s.environment   = getFieldOrEmpty(nested.deployment, 'environment');
            s.cellRadius_m  = getFieldOrEmpty(nested.deployment, 'cellRadius_m');
            s.bsHeight_m    = getFieldOrEmpty(nested.deployment, 'bsHeight_m');
        end
        if isfield(nested, 'ue')
            s.numUesPerSector = getFieldOrEmpty(nested.ue, 'numUesPerSector');
        end
        if isfield(nested, 'bs')
            s.maxEirpPerSector_dBm = getFieldOrEmpty(nested.bs, 'maxEirpPerSector_dBm');
            s.channelBandwidth_MHz = getFieldOrEmpty(nested.bs, 'channelBandwidth_MHz');
        end
        if isfield(nested, 'sim')
            s.randomSeed = getFieldOrEmpty(nested.sim, 'randomSeed');
        end
        return;
    end

    % Fallback: pull from a runR23AasEirpCdfGrid output struct.
    if isfield(x, 'metadata') && isstruct(x.metadata)
        md = x.metadata;
        s.scenarioPreset       = getFieldOrEmpty(md, 'scenarioPreset');
        s.environment          = getFieldOrEmpty(md, 'environment');
        s.cellRadius_m         = getFieldOrEmpty(md, 'cellRadius_m');
        s.bsHeight_m           = getFieldOrEmpty(md, 'bsHeight_m');
        s.numUesPerSector      = getFieldOrEmpty(md, 'numUesPerSector');
        s.maxEirpPerSector_dBm = getFieldOrEmpty(md, 'maxEirpPerSector_dBm');
        s.channelBandwidth_MHz = getFieldOrEmpty(md, 'bandwidthMHz');
        s.randomSeed           = getFieldOrEmpty(md, 'randomSeed');
        if isfield(md, 'sourceReference')
            s.sourceReference = md.sourceReference;
        elseif isfield(md, 'sourceDefault')
            s.sourceReference = md.sourceDefault;
        end
    end
end

function v = getFieldOrEmpty(s, name)
    if isstruct(s) && isfield(s, name)
        v = s.(name);
    else
        v = [];
    end
end

function tf = isEqualLoose(a, b)
    if isempty(a) && isempty(b)
        tf = true; return;
    end
    if isempty(a) || isempty(b)
        tf = false; return;
    end
    if (ischar(a) || isstring(a)) && (ischar(b) || isstring(b))
        tf = strcmp(char(a), char(b)); return;
    end
    if isnumeric(a) && isnumeric(b) && isscalar(a) && isscalar(b)
        tf = (a == b) || (abs(double(a) - double(b)) < 1e-12);
        return;
    end
    try
        tf = isequal(a, b);
    catch
        tf = false;
    end
end

function printDiffTable(diff, sa, sb)
    nameA = labelOf(sa, 'A');
    nameB = labelOf(sb, 'B');

    fprintf('---------- compareR23ScenarioMetadata ----------\n');
    fprintf('  A: %s\n', nameA);
    fprintf('  B: %s\n', nameB);
    fprintf('------------------------------------------------\n');
    fprintf('  %-24s  %-24s  %-24s  %s\n', 'field', 'A', 'B', 'equal');
    for k = 1:numel(diff)
        fprintf('  %-24s  %-24s  %-24s  %s\n', ...
            diff(k).field, ...
            valueToStr(diff(k).a), ...
            valueToStr(diff(k).b), ...
            tfStr(diff(k).equal));
    end
    nDiff = sum(~[diff.equal]);
    fprintf('------------------------------------------------\n');
    fprintf('  %d field(s) differ.\n', nDiff);
    fprintf('------------------------------------------------\n');
end

function name = labelOf(s, fallback)
    if isfield(s, 'scenarioPreset') && ~isempty(s.scenarioPreset)
        name = char(s.scenarioPreset);
    else
        name = fallback;
    end
end

function s = valueToStr(v)
    if isempty(v)
        s = '<empty>';
    elseif ischar(v)
        if numel(v) > 22
            s = [v(1:19) '...'];
        else
            s = v;
        end
    elseif isstring(v) && isscalar(v)
        s = valueToStr(char(v));
    elseif islogical(v) && isscalar(v)
        s = tfStr(v);
    elseif isnumeric(v) && isscalar(v)
        if v == floor(v) && abs(v) < 1e9
            s = sprintf('%d', int64(v));
        else
            s = sprintf('%.4g', v);
        end
    else
        s = '<...>';
    end
end

function s = tfStr(tf)
    if tf, s = 'yes'; else, s = 'NO '; end
end
