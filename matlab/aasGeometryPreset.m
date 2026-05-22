function geom = aasGeometryPreset(presetName, varargin)
%AASGEOMETRYPRESET Named AAS subarray/array geometry presets.
%
%   GEOM = aasGeometryPreset(PRESETNAME)
%   GEOM = aasGeometryPreset(PRESETNAME, 'Name', Value, ...)
%
%   Returns a struct describing the AAS radiating geometry used by the
%   IMT EIRP model. The returned struct includes the resolved geometry
%   fields plus deterministic gain accounting (calculatedSubarrayGainDb,
%   calculatedArrayGainDb, calculatedAntennaGainDbi) and the total
%   physical element count across two polarizations.
%
%   Supported PRESETNAME values:
%
%     "r23_1x3_default"
%         Source-aligned ITU-R R23 7.125-8.4 GHz Extended AAS macro
%         baseline used for WRC-27 sharing studies.
%             arrayRows                                   = 8
%             arrayCols                                   = 16
%             subarrayElementRows                         = 3
%             subarrayElementCols                         = 1
%             subarrayElementVerticalSpacingLambda        = 0.7
%             radiatingSubarrayHorizontalSpacingLambda    = 0.5
%             radiatingSubarrayVerticalSpacingLambda      = 2.1
%             subarrayDowntiltDeg                         = 3
%             mechanicalDowntiltDeg                       = 6
%             elementGainDbi                              = 6.4
%             sectorEirpDbm                               = 78.3
%             conductedPowerDbm                           = 46.1
%         Total physical elements across two polarizations = 768.
%         Calculated antenna gain ~= 32.2 dBi.
%
%     "ctia_7ghz_1x6"
%         CTIA 7 GHz AAS design/sensitivity case: 4x16 subarrays per
%         polarization with 6 elements per subarray.
%             arrayRows                                   = 4
%             arrayCols                                   = 16
%             subarrayElementRows                         = 6
%             subarrayElementCols                         = 1
%             subarrayElementVerticalSpacingLambda        = 0.7
%             radiatingSubarrayHorizontalSpacingLambda    = 0.5
%             radiatingSubarrayVerticalSpacingLambda      = 4.2
%               (= 6 * 0.7 lambda; preserves uniform 0.7 lambda spacing
%                across the full vertical aperture)
%             subarrayDowntiltDeg                         = 3
%             mechanicalDowntiltDeg                       = 6
%             elementGainDbi                              = 6.4
%             sectorEirpDbm                               = 90.8
%             conductedPowerDbm                           = 58.6
%         Total physical elements across two polarizations = 768.
%         Calculated antenna gain ~= 32.2 dBi.
%
%     "custom"
%         All required geometry fields must be supplied as Name,Value
%         overrides. Use this for explicit sensitivity studies.
%
%   Optional Name-Value overrides apply on top of the named preset
%   (and are required for "custom"):
%       'arrayRows', 'arrayCols',
%       'subarrayElementRows', 'subarrayElementCols',
%       'subarrayElementVerticalSpacingLambda',
%       'radiatingSubarrayHorizontalSpacingLambda',
%       'radiatingSubarrayVerticalSpacingLambda',
%       'subarrayDowntiltDeg', 'mechanicalDowntiltDeg',
%       'elementGainDbi',
%       'sectorEirpDbm', 'conductedPowerDbm'.
%
%   Returned GEOM fields:
%       presetName
%       arrayRows, arrayCols
%       subarrayElementRows, subarrayElementCols
%       subarrayElementVerticalSpacingLambda
%       radiatingSubarrayHorizontalSpacingLambda
%       radiatingSubarrayVerticalSpacingLambda
%       subarrayDowntiltDeg, mechanicalDowntiltDeg
%       elementGainDbi
%       sectorEirpDbm, conductedPowerDbm
%       calculatedSubarrayGainDb
%       calculatedArrayGainDb
%       calculatedAntennaGainDbi
%       totalPhysicalElementsAcrossPolarizations
%       hasOverrides (logical)
%
%   Notes / scope:
%   * Only transmit-side IMT AAS EIRP geometry is configured here. No
%     propagation, no clutter, no receiver modeling, no UE uplink, no
%     deployment laydown, no coordination distance is touched.
%   * elementGainDbi is treated as already absorbing the R23 reference
%     2 dB ohmic loss; calculatedAntennaGainDbi does NOT subtract
%     ohmic loss again.
%   * Polarization is two by default; calculatedAntennaGainDbi is the
%     per-polarization composite gain (the two-polarization power
%     summation is handled separately via sectorEirpDbm).
%
%   See also: runR23AasEirpCdfGrid, r23DefaultParams, imtAasDefaultParams.

    if nargin < 1 || isempty(presetName)
        presetName = 'r23_1x3_default';
    end
    if isstring(presetName) && isscalar(presetName)
        presetName = char(presetName);
    end
    if ~ischar(presetName)
        error('aasGeometryPreset:badPreset', ...
            'PRESETNAME must be a char or scalar string.');
    end

    key = lower(strtrim(presetName));

    switch key
        case {'r23_1x3_default', 'r23-1x3-default', 'r23'}
            canonical = 'r23_1x3_default';
            base = struct( ...
                'arrayRows',                                8, ...
                'arrayCols',                                16, ...
                'subarrayElementRows',                      3, ...
                'subarrayElementCols',                      1, ...
                'subarrayElementVerticalSpacingLambda',     0.7, ...
                'radiatingSubarrayHorizontalSpacingLambda', 0.5, ...
                'radiatingSubarrayVerticalSpacingLambda',   2.1, ...
                'subarrayDowntiltDeg',                      3, ...
                'mechanicalDowntiltDeg',                    6, ...
                'elementGainDbi',                           6.4, ...
                'sectorEirpDbm',                            78.3, ...
                'conductedPowerDbm',                        46.1);
            requireAllFields = false;

        case {'ctia_7ghz_1x6', 'ctia-7ghz-1x6', 'ctia7ghz1x6', 'ctia'}
            canonical = 'ctia_7ghz_1x6';
            base = struct( ...
                'arrayRows',                                4, ...
                'arrayCols',                                16, ...
                'subarrayElementRows',                      6, ...
                'subarrayElementCols',                      1, ...
                'subarrayElementVerticalSpacingLambda',     0.7, ...
                'radiatingSubarrayHorizontalSpacingLambda', 0.5, ...
                'radiatingSubarrayVerticalSpacingLambda',   4.2, ...
                'subarrayDowntiltDeg',                      3, ...
                'mechanicalDowntiltDeg',                    6, ...
                'elementGainDbi',                           6.4, ...
                'sectorEirpDbm',                            90.8, ...
                'conductedPowerDbm',                        58.6);
            requireAllFields = false;

        case 'custom'
            canonical = 'custom';
            base = struct();
            requireAllFields = true;

        otherwise
            error('aasGeometryPreset:unknownPreset', ...
                ['Unknown aasGeometryPreset "%s". Supported: ' ...
                 '"r23_1x3_default", "ctia_7ghz_1x6", "custom".'], ...
                presetName);
    end

    overrides = parseOverrides(varargin);
    geom = applyOverrides(base, overrides);
    geom.presetName  = canonical;
    geom.hasOverrides = ~isempty(fieldnames(overrides));

    requiredFields = { ...
        'arrayRows', 'arrayCols', ...
        'subarrayElementRows', 'subarrayElementCols', ...
        'subarrayElementVerticalSpacingLambda', ...
        'radiatingSubarrayHorizontalSpacingLambda', ...
        'radiatingSubarrayVerticalSpacingLambda', ...
        'subarrayDowntiltDeg', 'mechanicalDowntiltDeg', ...
        'elementGainDbi'};

    if requireAllFields
        missing = {};
        for k = 1:numel(requiredFields)
            if ~isfield(geom, requiredFields{k})
                missing{end+1} = requiredFields{k}; %#ok<AGROW>
            end
        end
        if ~isempty(missing)
            error('aasGeometryPreset:missingCustomField', ...
                ['Custom preset is missing required field(s): %s. ' ...
                 'Supply all geometry fields as Name,Value pairs.'], ...
                strjoin(missing, ', '));
        end
    end

    validateGeometryFields(geom);

    geom.calculatedSubarrayGainDb = 10 * log10( ...
        double(geom.subarrayElementRows) * double(geom.subarrayElementCols));
    geom.calculatedArrayGainDb    = 10 * log10( ...
        double(geom.arrayRows) * double(geom.arrayCols));
    geom.calculatedAntennaGainDbi = double(geom.elementGainDbi) + ...
        geom.calculatedSubarrayGainDb + geom.calculatedArrayGainDb;

    numPolarizations = 2;
    geom.totalPhysicalElementsAcrossPolarizations = numPolarizations * ...
        double(geom.arrayRows) * double(geom.arrayCols) * ...
        double(geom.subarrayElementRows) * double(geom.subarrayElementCols);

    % Sanity check for the named ctia preset: it should hit 768 total
    % elements unless the caller has explicitly overridden geometry.
    if strcmp(canonical, 'ctia_7ghz_1x6') && ~geom.hasOverrides
        if geom.totalPhysicalElementsAcrossPolarizations ~= 768
            error('aasGeometryPreset:ctiaElementCountMismatch', ...
                ['ctia_7ghz_1x6 preset must yield 768 physical elements ' ...
                 'across two polarizations (got %d). This indicates a ' ...
                 'preset-table regression.'], ...
                geom.totalPhysicalElementsAcrossPolarizations);
        end
    end
end

% =====================================================================

function overrides = parseOverrides(args)
%PARSEOVERRIDES Validate and collect supported Name,Value overrides.
    overrides = struct();
    if isempty(args)
        return;
    end
    if mod(numel(args), 2) ~= 0
        error('aasGeometryPreset:badOverrides', ...
            'Overrides must be supplied as Name, Value pairs.');
    end

    supported = { ...
        'arrayRows', 'arrayCols', ...
        'subarrayElementRows', 'subarrayElementCols', ...
        'subarrayElementVerticalSpacingLambda', ...
        'radiatingSubarrayHorizontalSpacingLambda', ...
        'radiatingSubarrayVerticalSpacingLambda', ...
        'subarrayDowntiltDeg', 'mechanicalDowntiltDeg', ...
        'elementGainDbi', ...
        'sectorEirpDbm', 'conductedPowerDbm'};

    for k = 1:2:numel(args)
        name = args{k};
        if isstring(name) && isscalar(name)
            name = char(name);
        end
        if ~ischar(name)
            error('aasGeometryPreset:badOverrideName', ...
                'Override names must be char/string scalars.');
        end
        match = '';
        for s = 1:numel(supported)
            if strcmp(name, supported{s})
                match = supported{s};
                break;
            end
        end
        if isempty(match)
            error('aasGeometryPreset:unknownOverride', ...
                ['Unsupported geometry override "%s". Supported: %s.'], ...
                name, strjoin(supported, ', '));
        end
        overrides.(match) = args{k+1};
    end
end

function s = applyOverrides(base, overrides)
    s = base;
    flds = fieldnames(overrides);
    for k = 1:numel(flds)
        s.(flds{k}) = overrides.(flds{k});
    end
end

function validateGeometryFields(geom)
    requirePositiveInteger(geom, 'arrayRows');
    requirePositiveInteger(geom, 'arrayCols');
    requirePositiveInteger(geom, 'subarrayElementRows');
    requirePositiveInteger(geom, 'subarrayElementCols');

    requireNonnegativeFinite(geom, 'subarrayElementVerticalSpacingLambda');
    requireNonnegativeFinite(geom, 'radiatingSubarrayHorizontalSpacingLambda');
    requireNonnegativeFinite(geom, 'radiatingSubarrayVerticalSpacingLambda');

    requireFiniteScalar(geom, 'subarrayDowntiltDeg');
    requireFiniteScalar(geom, 'mechanicalDowntiltDeg');
    requireFiniteScalar(geom, 'elementGainDbi');

    if isfield(geom, 'sectorEirpDbm')
        requireFiniteScalar(geom, 'sectorEirpDbm');
    end
    if isfield(geom, 'conductedPowerDbm')
        requireFiniteScalar(geom, 'conductedPowerDbm');
    end

    % The array-factor primitive only supports a 1-column vertical
    % subarray (L vertical elements). Reject 2-D subarrays explicitly
    % so callers cannot silently mis-model the geometry.
    if double(geom.subarrayElementCols) ~= 1
        error('aasGeometryPreset:unsupportedSubarrayCols', ...
            ['subarrayElementCols must be 1 (the AAS array-factor ' ...
             'primitive supports only 1xL vertical subarrays); got %g.'], ...
            double(geom.subarrayElementCols));
    end
end

function requirePositiveInteger(geom, name)
    if ~isfield(geom, name)
        error('aasGeometryPreset:missingField', ...
            'Geometry field "%s" is required.', name);
    end
    v = geom.(name);
    if ~(isnumeric(v) && isscalar(v) && isfinite(v) && isreal(v) && ...
            v >= 1 && v == floor(v))
        error('aasGeometryPreset:badGeometryValue', ...
            '%s must be a positive integer (got %s).', name, valueToStr(v));
    end
end

function requireNonnegativeFinite(geom, name)
    if ~isfield(geom, name)
        error('aasGeometryPreset:missingField', ...
            'Geometry field "%s" is required.', name);
    end
    v = geom.(name);
    if ~(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v >= 0)
        error('aasGeometryPreset:badGeometryValue', ...
            '%s must be a finite non-negative scalar (got %s).', ...
            name, valueToStr(v));
    end
end

function requireFiniteScalar(geom, name)
    if ~isfield(geom, name)
        error('aasGeometryPreset:missingField', ...
            'Geometry field "%s" is required.', name);
    end
    v = geom.(name);
    if ~(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v))
        error('aasGeometryPreset:badGeometryValue', ...
            '%s must be a finite real scalar (got %s).', name, valueToStr(v));
    end
end

function s = valueToStr(v)
    try
        if isnumeric(v) && isscalar(v)
            s = num2str(v);
        else
            s = class(v);
        end
    catch
        s = '<unprintable>';
    end
end
