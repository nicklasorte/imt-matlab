function params = r23GoldenReferenceScenario(name)
%R23GOLDENREFERENCESCENARIO Frozen reference scenario builder.
%
%   PARAMS = r23GoldenReferenceScenario(NAME)
%
%   Returns the nested-params struct for one of the frozen golden
%   reference scenarios used as regression anchors for the R23 AAS
%   EIRP MVP. The intent is reproducibility, not a new model -- this
%   helper composes existing functions:
%
%       1. r23ScenarioPreset to seed canonical R23 parameters,
%       2. a small fixed override block per golden name,
%       3. metadata stamping that identifies the run as a golden
%          reference (so verifiers / artifact files can recognise it).
%
%   Supported names:
%
%       "r23-urban-baseline-small-grid-v1"
%           urban-baseline preset, seed=20260101, numSnapshots=20,
%           az=-60:20:60, el=-10:2:0,
%           percentiles=[1 5 10 20 50 80 90 95 99].
%
%   Antenna-face EIRP only -- does not introduce path loss, clutter,
%   rooftop modeling, receiver, I/N, propagation, coordination
%   distance, multi-site aggregation, or scheduler behavior.
%
%   See also: r23ScenarioPreset, runR23AasEirpCdfGrid,
%             exportR23ValidationSnapshot, verifyR23GoldenReference.

    if nargin < 1 || isempty(name)
        error('r23GoldenReferenceScenario:badArgs', ...
            'Usage: r23GoldenReferenceScenario("<golden-name>").');
    end
    if isstring(name) && isscalar(name)
        name = char(name);
    end
    if ~ischar(name)
        error('r23GoldenReferenceScenario:badName', ...
            'Golden reference name must be a char or string scalar.');
    end

    switch lower(strtrim(name))
        case 'r23-urban-baseline-small-grid-v1'
            canonicalName    = 'r23-urban-baseline-small-grid-v1';
            goldenVersion    = 1;
            params           = r23ScenarioPreset('urban-baseline');
            params.sim.randomSeed   = 20260101;
            params.sim.numSnapshots = 20;
            params.sim.azGrid_deg   = -60:20:60;
            params.sim.elGrid_deg   = -10:2:0;
            params.sim.percentiles  = [1 5 10 20 50 80 90 95 99];

        otherwise
            error('r23GoldenReferenceScenario:unknownGolden', ...
                ['Unknown golden reference "%s". Supported names: ' ...
                 '"r23-urban-baseline-small-grid-v1".'], name);
    end

    if ~isfield(params, 'metadata') || ~isstruct(params.metadata)
        params.metadata = struct();
    end
    params.metadata.goldenReferenceName    = canonicalName;
    params.metadata.goldenReferenceVersion = goldenVersion;
    params.metadata.goldenReferencePurpose = 'regression-anchor';
end
