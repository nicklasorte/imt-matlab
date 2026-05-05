function params = r23ScenarioPreset(presetName, varargin)
%R23SCENARIOPRESET Named, source-grounded R23 scenario preset builder.
%
%   PARAMS = r23ScenarioPreset(PRESETNAME)
%   PARAMS = r23ScenarioPreset(PRESETNAME, 'Name', Value, ...)
%
%   Lightweight reproducibility / configuration layer on top of
%   r23DefaultParams. Returns a nested params struct ready to pass to
%   runR23AasEirpCdfGrid, with explicit scenario metadata so named R23
%   study scenarios can be run consistently and compared safely.
%
%   This is NOT a new propagation model, scheduler, or network-loading
%   implementation. It is a thin wrapper that selects baseline geometry,
%   stamps scenario / source metadata, and forwards optional field
%   overrides into the existing r23DefaultParams struct.
%
%   Supported PRESETNAME values:
%       "urban-baseline"
%           - environment             = "urban"
%           - cellRadius_m            = 400
%           - bsHeight_m              = 18
%           - bsDensityPerKm2         = 10
%           - numUesPerSector         = 3
%           - maxEirpPerSector_dBm    = 78.3
%           - channelBandwidth_MHz    = 100
%           - randomSeed              = 20260101 (stable, reproducible)
%
%       "suburban-baseline"
%           - environment             = "suburban"
%           - cellRadius_m            = 800
%           - bsHeight_m              = 20
%           - bsDensityPerKm2         = 2.4
%           - numUesPerSector         = 3
%           - maxEirpPerSector_dBm    = 78.3
%           - channelBandwidth_MHz    = 100
%           - randomSeed              = 20260102 (stable, reproducible)
%
%   Optional name-value overrides (forwarded into the corresponding
%   nested params field; unknown names raise an error):
%       'numUesPerSector'        -> params.ue.numUesPerSector
%       'maxEirpPerSector_dBm'   -> params.bs.maxEirpPerSector_dBm
%       'channelBandwidth_MHz'   -> params.bs.channelBandwidth_MHz
%       'cellRadius_m'           -> params.deployment.cellRadius_m
%       'bsHeight_m'             -> params.deployment.bsHeight_m
%       'randomSeed'             -> params.sim.randomSeed
%       'numSnapshots'           -> params.sim.numSnapshots
%
%   Source-grounding:
%       Both presets share the R23 7.125-8.4 GHz Extended AAS macro
%       antenna table (8x16 sub-array, 6.4 dBi element gain, 90/65 deg
%       beamwidths, 30 dB front-to-back, 0.5/2.1/0.7 lambda spacings,
%       3 deg sub-array downtilt, 6 deg mechanical downtilt) and the
%       78.3 dBm / 100 MHz sector peak EIRP (46.1 dBm conducted +
%       32.2 dBi peak gain).
%
%   Reference-only metadata (NOT active in EIRP-grid computation):
%       params.metadata.referenceOnly.networkLoadingFactor = 0.20
%       params.metadata.referenceOnly.bsTddActivityFactor  = 0.75
%       params.metadata.referenceOnly.belowRooftopFraction = (preset)
%
%       These are stamped for traceability against R23 study assumptions.
%       The current MVP does not model network loading, TDD activity,
%       below-rooftop deployment, clutter, or scheduler behaviour.
%
%   Antenna-face EIRP only. No path loss, no clutter, no receiver
%   antenna, no I/N, no multi-site aggregation, no 19-site / 57-sector
%   deployment.
%
%   Examples:
%       params = r23ScenarioPreset("urban-baseline");
%       out    = runR23AasEirpCdfGrid(params);
%
%       params = r23ScenarioPreset("suburban-baseline");
%       out    = runR23AasEirpCdfGrid(params);
%
%       params = r23ScenarioPreset("urban-baseline", ...
%                                  "numUesPerSector", 10);
%       out    = runR23AasEirpCdfGrid(params);
%
%   See also: r23DefaultParams, runR23AasEirpCdfGrid,
%             compareR23ScenarioMetadata, runR23ScenarioPresetExample.

    if nargin < 1 || isempty(presetName)
        error('r23ScenarioPreset:missingPreset', ...
            ['PRESETNAME is required. Supported presets: ' ...
             '"urban-baseline", "suburban-baseline".']);
    end
    if isstring(presetName) && isscalar(presetName)
        presetName = char(presetName);
    end
    if ~ischar(presetName)
        error('r23ScenarioPreset:badPreset', ...
            'PRESETNAME must be a char or scalar string.');
    end

    presetKey = lower(strtrim(presetName));

    switch presetKey
        case {'urban-baseline', 'urban_baseline', 'urbanbaseline'}
            canonicalName     = 'urban-baseline';
            scenarioCategory  = 'baseline';
            environment       = 'urban';
            cellRadius_m      = 400;
            bsHeight_m        = 18;
            bsDensityPerKm2   = 10;
            numUesPerSector   = 3;
            maxEirpDbm        = 78.3;
            channelBwMHz      = 100;
            randomSeed        = 20260101;
            sourceReference   = ['ITU-R R23 7.125-8.4 GHz macro urban ' ...
                                 'baseline assumptions (Extended AAS, ' ...
                                 '8x16 sub-array, 78.3 dBm sector EIRP / ' ...
                                 '100 MHz)'];

        case {'suburban-baseline', 'suburban_baseline', 'suburbanbaseline'}
            canonicalName     = 'suburban-baseline';
            scenarioCategory  = 'baseline';
            environment       = 'suburban';
            cellRadius_m      = 800;
            bsHeight_m        = 20;
            bsDensityPerKm2   = 2.4;
            numUesPerSector   = 3;
            maxEirpDbm        = 78.3;
            channelBwMHz      = 100;
            randomSeed        = 20260102;
            sourceReference   = ['ITU-R R23 7.125-8.4 GHz macro suburban ' ...
                                 'baseline assumptions (Extended AAS, ' ...
                                 '8x16 sub-array, 78.3 dBm sector EIRP / ' ...
                                 '100 MHz)'];

        otherwise
            error('r23ScenarioPreset:unknownPreset', ...
                ['Unknown scenario preset "%s". Supported presets: ' ...
                 '"urban-baseline", "suburban-baseline".'], presetName);
    end

    % ---- build base nested params from r23DefaultParams ---------------
    params = r23DefaultParams(environment);

    % ---- pin baseline canonical fields --------------------------------
    params.deployment.cellRadius_m       = cellRadius_m;
    params.deployment.bsHeight_m         = bsHeight_m;
    params.deployment.bsDensityPerKm2    = bsDensityPerKm2;
    params.deployment.interSiteDistance_m = sqrt(3) * cellRadius_m;

    params.ue.numUesPerSector            = numUesPerSector;
    params.bs.maxEirpPerSector_dBm       = maxEirpDbm;
    params.bs.channelBandwidth_MHz       = channelBwMHz;
    params.sim.randomSeed                = randomSeed;

    % ---- apply caller overrides ---------------------------------------
    overrides = parseOverrides(varargin);
    overrideRecord = struct();
    if isfield(overrides, 'numUesPerSector')
        params.ue.numUesPerSector = overrides.numUesPerSector;
        overrideRecord.numUesPerSector = overrides.numUesPerSector;
    end
    if isfield(overrides, 'maxEirpPerSector_dBm')
        params.bs.maxEirpPerSector_dBm = overrides.maxEirpPerSector_dBm;
        overrideRecord.maxEirpPerSector_dBm = overrides.maxEirpPerSector_dBm;
    end
    if isfield(overrides, 'channelBandwidth_MHz')
        params.bs.channelBandwidth_MHz = overrides.channelBandwidth_MHz;
        overrideRecord.channelBandwidth_MHz = overrides.channelBandwidth_MHz;
    end
    if isfield(overrides, 'cellRadius_m')
        params.deployment.cellRadius_m = overrides.cellRadius_m;
        params.deployment.interSiteDistance_m = ...
            sqrt(3) * overrides.cellRadius_m;
        overrideRecord.cellRadius_m = overrides.cellRadius_m;
    end
    if isfield(overrides, 'bsHeight_m')
        params.deployment.bsHeight_m = overrides.bsHeight_m;
        overrideRecord.bsHeight_m = overrides.bsHeight_m;
    end
    if isfield(overrides, 'randomSeed')
        params.sim.randomSeed = overrides.randomSeed;
        overrideRecord.randomSeed = overrides.randomSeed;
    end
    if isfield(overrides, 'numSnapshots')
        params.sim.numSnapshots = overrides.numSnapshots;
        overrideRecord.numSnapshots = overrides.numSnapshots;
    end

    % ---- stamp scenario metadata --------------------------------------
    if ~isfield(params, 'metadata') || ~isstruct(params.metadata)
        params.metadata = struct();
    end
    params.metadata.scenarioPreset    = canonicalName;
    params.metadata.scenarioCategory  = scenarioCategory;
    params.metadata.sourceReference   = sourceReference;
    params.metadata.reproducible      = true;
    params.metadata.presetOverrides   = overrideRecord;

    % Reference-only metadata for traceability. These fields are NOT
    % active in the current EIRP-grid computation: the runner does not
    % apply network loading, TDD activity, or below-rooftop modeling.
    refOnly = struct();
    refOnly.notes                  = ['reference-only metadata; ' ...
                                       'NOT active in current ' ...
                                       'antenna-face EIRP-grid run'];
    refOnly.networkLoadingFactor   = params.bs.networkLoadingFactor;
    refOnly.bsTddActivityFactor    = params.bs.tddActivityFactor;
    refOnly.belowRooftopFraction   = params.deployment.belowRooftopFraction;
    params.metadata.referenceOnly  = refOnly;
end

% =====================================================================

function overrides = parseOverrides(args)
%PARSEOVERRIDES Validate and collect supported name-value overrides.
    overrides = struct();
    if isempty(args)
        return;
    end
    if mod(numel(args), 2) ~= 0
        error('r23ScenarioPreset:badOverrides', ...
            'Overrides must be supplied as Name, Value pairs.');
    end

    supported = { ...
        'numUesPerSector', ...
        'maxEirpPerSector_dBm', ...
        'channelBandwidth_MHz', ...
        'cellRadius_m', ...
        'bsHeight_m', ...
        'randomSeed', ...
        'numSnapshots'};

    for k = 1:2:numel(args)
        name = args{k};
        if isstring(name) && isscalar(name)
            name = char(name);
        end
        if ~ischar(name)
            error('r23ScenarioPreset:badOverrideName', ...
                'Override names must be char/string scalars.');
        end
        match = '';
        for s = 1:numel(supported)
            if strcmpi(name, supported{s})
                match = supported{s};
                break;
            end
        end
        if isempty(match)
            error('r23ScenarioPreset:unknownOverride', ...
                ['Unsupported override "%s". Supported overrides: %s'], ...
                name, strjoin(supported, ', '));
        end
        value = args{k+1};
        validateOverrideValue(match, value);
        overrides.(match) = value;
    end
end

function validateOverrideValue(name, value)
    switch name
        case {'numUesPerSector', 'numSnapshots'}
            if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    value >= 1 && value == floor(value))
                error('r23ScenarioPreset:badOverrideValue', ...
                    '%s must be a positive integer.', name);
            end
        case {'maxEirpPerSector_dBm', 'channelBandwidth_MHz', ...
              'cellRadius_m', 'bsHeight_m'}
            if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    value > 0)
                error('r23ScenarioPreset:badOverrideValue', ...
                    '%s must be a finite positive scalar.', name);
            end
        case 'randomSeed'
            if ~(isnumeric(value) && isscalar(value) && isfinite(value))
                error('r23ScenarioPreset:badOverrideValue', ...
                    '%s must be a finite numeric scalar.', name);
            end
    end
end
