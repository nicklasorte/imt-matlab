function compositeGainDbi = imtAasCompositeGain(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, params)
%IMTAASCOMPOSITEGAIN Absolute IMT AAS composite gain over an az/el grid.
%
%   COMPOSITEGAINDBI = imtAasCompositeGain(AZGRIDDEG, ELGRIDDEG, ...
%                                          STEERAZDEG, STEERELDEG, PARAMS)
%
%   Combines the single-element pattern (imtAasElementPattern) and the
%   panel-frame array + sub-array factor (imtAasArrayFactor), with the
%   mechanical downtilt PARAMS.mechanicalDowntiltDeg applied as a y-axis
%   coordinate rotation that maps the sector frame into the panel frame
%   (via imt_aas_mechanical_tilt_transform).
%
%   The returned value is an ABSOLUTE composite gain in dBi:
%       compositeGainDbi(az, el) = elementGainDbi + arrayGainDbi
%   At the steered peak this approaches
%       G_Emax  +  10*log10(1 + rho*(N_H*N_V - 1))  +  10*log10(L)
%   = 6.4  +  21.07  +  4.77  =  ~32.24 dBi for the R23 defaults, which
%   matches the R23 reference peak gain of 32.2 dBi.
%
%   Loss treatment:
%   The R23 reference table folds a 2 dB ohmic / array loss into G_E,max
%   = 6.4 dBi (consistent with imt_r23_aas_defaults), so no extra loss
%   term is applied here. If you need to model additional feeder loss,
%   subtract it from the EIRP in the caller.
%
%   Angle conventions (sector frame, before mechanical tilt):
%       azGridDeg   azimuth, [-180, 180] deg, 0 = sector boresight.
%       elGridDeg   elevation, [-90, 90] deg, 0 = horizon, neg = below.
%       steerAzDeg  scalar electronic steering azimuth (sector frame).
%       steerElDeg  scalar electronic steering elevation (sector frame).
%   These are rotated by PARAMS.mechanicalDowntiltDeg about the +y axis
%   (panel-frame transform) before the element pattern and array factor
%   are evaluated.
%
%   Input handling: same as imtAasArrayFactor (scalar / vector / 2-D).

    if nargin < 5 || isempty(params)
        params = imtAasDefaultParams();
    end

    validateSteerAngle(steerAzDeg, -180, 180, 'steerAzDeg');
    validateSteerAngle(steerElDeg,  -90,  90, 'steerElDeg');

    [AZ, EL] = imtAasNormalizeGrid(azGridDeg, elGridDeg);

    if isfield(params, 'mechanicalDowntiltDeg') && ...
            ~isempty(params.mechanicalDowntiltDeg)
        tiltDeg = params.mechanicalDowntiltDeg;
    else
        tiltDeg = 0;
    end

    % Observation-frame selection (non-breaking; default 'global').
    %   'global'/'sector' -> rotate the observation grid into the panel
    %                        frame (historical behavior, byte-identical).
    %   'panel'           -> treat the supplied az/el as already panel-frame
    %                        (skip the observation-grid rotation).
    obsFrame = resolveObservationFrame(params, 'imtAasCompositeGain');

    % External beam set (non-breaking; default absent/disabled).
    %   Absent / empty / enable=false -> byte-identical to the historical
    %   analytic element-pattern + array-factor path below.
    %   enable=true -> the delivered vendor patterns REPLACE both factors.
    extBeamset = resolveExternalBeamset(params, 'imtAasCompositeGain');
    useExternal = ~isempty(extBeamset);

    % The BEAM-STEERING direction is ALWAYS rotated from the sector frame
    % into the panel frame, regardless of the observation-frame choice.
    [steerAzPanel, steerElPanel] = ...
        imt_aas_mechanical_tilt_transform(steerAzDeg, steerElDeg, tiltDeg);

    switch obsFrame
        case {'global', 'sector'}
            % Sector -> panel frame for the observation grid. This is the
            % identical transform line used historically, so the default
            % numeric output is unchanged.
            [AZpanel, ELpanel] = ...
                imt_aas_mechanical_tilt_transform(AZ, EL, tiltDeg);
        case 'panel'
            % Un-rotated (flat) frame: the supplied az/el are interpreted
            % as panel-frame directions, so skip the observation rotation.
            AZpanel = AZ;
            ELpanel = EL;
    end

    % imtAasNormalizeGrid maps two same-length 1xN row vectors to an NxN
    % outer-product grid (its documented behavior for independent axes).
    % After Normalize+tilt above, AZpanel/ELpanel are already paired, so
    % we reshape any [1xN] pair to columns to force the downstream
    % Normalize inside imtAasArrayFactor onto its "pass-through" branch.
    outShape = size(AZpanel);
    reshapeForArrayFactor = isvector(AZpanel) && ~isscalar(AZpanel) ...
        && size(AZpanel, 1) == 1;
    if reshapeForArrayFactor
        AZpanel = AZpanel(:);
        ELpanel = ELpanel(:);
    end

    if useExternal
        % The delivered patterns are ABSOLUTE composite gain: they already
        % contain the element pattern, the sub-array factor and the array
        % factor, so imtAasElementPattern / imtAasArrayFactor are skipped
        % entirely rather than added on top. AZpanel/ELpanel and the
        % steering are PANEL-FRAME, matching the beam set's own
        % convention (its metadata tilt fields are all 0), so the pattern
        % is not rotated a second time here.
        compositeGainDbi = imtAasExternalBeamGain(AZpanel, ELpanel, ...
            steerAzPanel, steerElPanel, extBeamset.beamset, ...
            struct('mode', extBeamset.mode));
    else
        elementDb = imtAasElementPattern(AZpanel, ELpanel, params);
        arrayDb   = imtAasArrayFactor( ...
            AZpanel, ELpanel, steerAzPanel, steerElPanel, params);

        compositeGainDbi = elementDb + arrayDb;
    end
    if reshapeForArrayFactor
        compositeGainDbi = reshape(compositeGainDbi, outShape);
    end
end

% =====================================================================

function frame = resolveObservationFrame(params, funcName)
%RESOLVEOBSERVATIONFRAME Read + validate the optional observationFrame field.
%   Default 'global'. Allowed (case-insensitive): 'global', 'sector'
%   (alias of global), 'panel'. Errors with id
%   '<funcName>:invalidObservationFrame' on any other value.
    frame = 'global';
    if isstruct(params) && isfield(params, 'observationFrame') && ...
            ~isempty(params.observationFrame)
        frame = params.observationFrame;
    end
    if isstring(frame) && isscalar(frame)
        frame = char(frame);
    end
    if ~ischar(frame)
        error([funcName ':invalidObservationFrame'], ...
            'observationFrame must be a char/string scalar.');
    end
    frame = lower(frame);
    switch frame
        case {'global', 'sector', 'panel'}
            % ok
        otherwise
            error([funcName ':invalidObservationFrame'], ...
                ['observationFrame must be one of ''global'', ''sector'', ', ...
                 '''panel'' (got ''%s'').'], frame);
    end
end

function ext = resolveExternalBeamset(params, funcName)
%RESOLVEEXTERNALBEAMSET Read + validate the optional params.externalBeamset.
%   Returns [] (the historical analytic path) when the field is absent,
%   empty, or has enable = false. Otherwise returns a struct with
%   .beamset (the imtAasLoadExternalBeamset output) and .mode (the
%   imtAasExternalBeamGain selection mode).
%
%   params.beamCodebook.enable and params.externalBeamset.enable are
%   mutually exclusive: the codebook hook snaps the analytic steering to a
%   DFT grid, which is meaningless when the analytic array factor is not
%   evaluated at all.
    ext = [];
    if ~isstruct(params) || ~isfield(params, 'externalBeamset') || ...
            isempty(params.externalBeamset)
        return;
    end
    raw = params.externalBeamset;
    if ~isstruct(raw) || ~isscalar(raw)
        error([funcName ':invalidExternalBeamset'], ...
            'params.externalBeamset must be a scalar struct (or [] / absent).');
    end
    if ~isfield(raw, 'enable') || isempty(raw.enable)
        return;
    end
    if ~((islogical(raw.enable) || isnumeric(raw.enable)) && isscalar(raw.enable))
        error([funcName ':invalidExternalBeamset'], ...
            'params.externalBeamset.enable must be a logical scalar.');
    end
    if ~logical(raw.enable)
        return;
    end

    codebookOn = isstruct(params) && isfield(params, 'beamCodebook') && ...
        ~isempty(params.beamCodebook) && isstruct(params.beamCodebook) && ...
        isfield(params.beamCodebook, 'enable') && ...
        ~isempty(params.beamCodebook.enable) && logical(params.beamCodebook.enable);
    if codebookOn
        error([funcName ':conflictingBeamSelection'], ...
            ['params.beamCodebook.enable and params.externalBeamset.enable ', ...
             'are mutually exclusive: the Type I DFT codebook snaps the ', ...
             'analytic steering, but the external beam set replaces the ', ...
             'analytic array factor entirely. Choose beamSelection ', ...
             '''codebook'' OR ''external'', not both.']);
    end

    if ~isfield(raw, 'beamset') || isempty(raw.beamset)
        error([funcName ':invalidExternalBeamset'], ...
            ['params.externalBeamset.enable is true but ', ...
             'params.externalBeamset.beamset is missing or empty.']);
    end

    mode = 'exhaustive';
    if isfield(raw, 'mode') && ~isempty(raw.mode)
        mode = char(string(raw.mode));
    end

    ext = struct('beamset', raw.beamset, 'mode', mode);
end

function validateSteerAngle(value, lo, hi, name)
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        error('imtAasCompositeGain:invalidSteer', ...
            '%s must be a real finite scalar.', name);
    end
    if value < lo || value > hi
        error('imtAasCompositeGain:invalidSteer', ...
            '%s = %g is outside the supported range [%g, %g] deg.', ...
            name, value, lo, hi);
    end
end
