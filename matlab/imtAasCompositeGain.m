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

    elementDb = imtAasElementPattern(AZpanel, ELpanel, params);
    arrayDb   = imtAasArrayFactor( ...
        AZpanel, ELpanel, steerAzPanel, steerElPanel, params);

    compositeGainDbi = elementDb + arrayDb;
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
