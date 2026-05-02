function arrayGainDb = compute_array_factor(theta, phi, steeringAngles, params)
%COMPUTE_ARRAY_FACTOR R23 N_H x N_V + L sub-array factor (panel frame, dB).
%
%   ARRAYGAINDB = compute_array_factor(THETA, PHI, STEERINGANGLES, PARAMS)
%
%   Returns the array factor + sub-array factor in dB at observation
%   angles (THETA, PHI) for an electronic steering described by
%   STEERINGANGLES.
%
%   Inputs:
%       THETA            elevation grid [deg], 0 = horizon, neg = down.
%       PHI              azimuth grid [deg], 0 = panel boresight.
%       STEERINGANGLES   1x2 vector [steerAzDeg, steerElDeg] OR struct
%                        with fields .steerAzDeg / .steerElDeg.
%       PARAMS           struct from get_r23_aas_params.
%
%   Inputs THETA and PHI follow the same scalar / vector / 2-D rules as
%   imtAasArrayFactor.
%
%   The mechanical-tilt rotation is NOT applied here (this is panel-frame
%   math). compute_bs_gain_toward_grid handles the sector -> panel-frame
%   transform for the full BS gain.

    if nargin < 4 || isempty(params)
        params = get_r23_aas_params();
    end

    [steerAzDeg, steerElDeg] = unpack_steering(steeringAngles);

    % imtAasArrayFactor expects (azGrid, elGrid, steerAz, steerEl, params).
    arrayGainDb = imtAasArrayFactor(phi, theta, ...
        steerAzDeg, steerElDeg, params);
end

% =====================================================================

function [steerAzDeg, steerElDeg] = unpack_steering(steeringAngles)
    if isnumeric(steeringAngles) && numel(steeringAngles) == 2
        steerAzDeg = double(steeringAngles(1));
        steerElDeg = double(steeringAngles(2));
        return;
    end
    if isstruct(steeringAngles) && isfield(steeringAngles, 'steerAzDeg') ...
            && isfield(steeringAngles, 'steerElDeg')
        sAz = steeringAngles.steerAzDeg;
        sEl = steeringAngles.steerElDeg;
        if ~(isscalar(sAz) && isscalar(sEl))
            error('compute_array_factor:badSteeringStruct', ...
                ['steeringAngles.steerAzDeg / .steerElDeg must be ' ...
                 'scalars for a single-beam evaluation.']);
        end
        steerAzDeg = double(sAz);
        steerElDeg = double(sEl);
        return;
    end
    error('compute_array_factor:badSteering', ...
        ['steeringAngles must be a 1x2 vector [az, el] or a struct ' ...
         'with .steerAzDeg / .steerElDeg fields.']);
end
