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
%           goldenRunOptions = struct() (default path, codebook off).
%
%       "r23-urban-panelframe-small-grid-v1"
%           identical sim config to the urban baseline, but run with
%           goldenRunOptions = struct('outputFrame','panel') so the
%           flat null-band panel frame is exercised (codebook off).
%
%       "r23-ctia-1x6-small-grid-v1"
%           identical sim config to the urban baseline, but run with
%           goldenRunOptions = struct('aasGeometryPreset','ctia_7ghz_1x6')
%           so the CTIA 7 GHz 1x6 geometry is exercised (codebook off).
%
%       "band2p7-urban-small-grid-v1"
%           2.7 GHz band option: r23ScenarioPreset("2p7ghz-urban")
%           (ITU 1 710-4 990 MHz 4x8 AAS, Part 27 85 dBm / 100 MHz,
%           2750 MHz, 20 m / 400 m) with the same small sim config as the
%           urban baseline (numSnapshots=20, az=-60:20:60, el=-10:2:0,
%           same percentiles) and seed 20261101. goldenRunOptions =
%           struct(): the band and its default geometry preset ride the
%           nested params (metadata.band), so no run-time option is needed.
%
%   Every returned scenario carries params.metadata.goldenRunOptions: a
%   struct of extra flat name-value opts the verifier must apply when
%   running this golden (empty struct() means "run with no extra opts").
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
            % Default path: no extra run-time opts, codebook off. Keeping
            % this empty preserves the byte-identical run that the v1
            % urban golden was frozen from.
            goldenRunOptions = struct();

        case 'r23-urban-panelframe-small-grid-v1'
            % Identical sim config to the urban baseline; the only
            % difference is the run-time option that selects the flat
            % null-band panel frame. Codebook stays off.
            canonicalName    = 'r23-urban-panelframe-small-grid-v1';
            goldenVersion    = 1;
            params           = r23ScenarioPreset('urban-baseline');
            params.sim.randomSeed   = 20260101;
            params.sim.numSnapshots = 20;
            params.sim.azGrid_deg   = -60:20:60;
            params.sim.elGrid_deg   = -10:2:0;
            params.sim.percentiles  = [1 5 10 20 50 80 90 95 99];
            goldenRunOptions = struct('outputFrame', 'panel');

        case 'r23-ctia-1x6-small-grid-v1'
            % Identical sim config to the urban baseline; the only
            % difference is the run-time geometry preset (CTIA 1x6).
            % Codebook stays off.
            canonicalName    = 'r23-ctia-1x6-small-grid-v1';
            goldenVersion    = 1;
            params           = r23ScenarioPreset('urban-baseline');
            params.sim.randomSeed   = 20260101;
            params.sim.numSnapshots = 20;
            params.sim.azGrid_deg   = -60:20:60;
            params.sim.elGrid_deg   = -10:2:0;
            params.sim.percentiles  = [1 5 10 20 50 80 90 95 99];
            goldenRunOptions = struct('aasGeometryPreset', 'ctia_7ghz_1x6');

        case 'band2p7-urban-small-grid-v1'
            % 2.7 GHz band option anchor. Same small sim config as the
            % urban baseline; the band comes from the scenario preset.
            canonicalName    = 'band2p7-urban-small-grid-v1';
            goldenVersion    = 1;
            params           = r23ScenarioPreset('2p7ghz-urban');
            params.sim.randomSeed   = 20261101;
            params.sim.numSnapshots = 20;
            params.sim.azGrid_deg   = -60:20:60;
            params.sim.elGrid_deg   = -10:2:0;
            params.sim.percentiles  = [1 5 10 20 50 80 90 95 99];
            goldenRunOptions = struct();

        otherwise
            error('r23GoldenReferenceScenario:unknownGolden', ...
                ['Unknown golden reference "%s". Supported names: ' ...
                 '"r23-urban-baseline-small-grid-v1", ' ...
                 '"r23-urban-panelframe-small-grid-v1", ' ...
                 '"r23-ctia-1x6-small-grid-v1", ' ...
                 '"band2p7-urban-small-grid-v1".'], name);
    end

    if ~isfield(params, 'metadata') || ~isstruct(params.metadata)
        params.metadata = struct();
    end
    params.metadata.goldenReferenceName    = canonicalName;
    params.metadata.goldenReferenceVersion = goldenVersion;
    params.metadata.goldenReferencePurpose = 'regression-anchor';
    params.metadata.goldenRunOptions       = goldenRunOptions;
end
