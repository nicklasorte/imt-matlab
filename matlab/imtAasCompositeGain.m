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

    % Sector -> panel frame for both observation grid and steering.
    [AZpanel, ELpanel] = imt_aas_mechanical_tilt_transform(AZ, EL, tiltDeg);
    [steerAzPanel, steerElPanel] = ...
        imt_aas_mechanical_tilt_transform(steerAzDeg, steerElDeg, tiltDeg);

    elementDb = imtAasElementPattern(AZpanel, ELpanel, params);
    arrayDb   = imtAasArrayFactor( ...
        AZpanel, ELpanel, steerAzPanel, steerElPanel, params);

    compositeGainDbi = elementDb + arrayDb;
end

% =====================================================================

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
