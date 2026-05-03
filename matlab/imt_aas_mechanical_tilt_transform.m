function [azPanelDeg, elPanelDeg] = imt_aas_mechanical_tilt_transform( ...
        azDeg, elDeg, tiltDownDeg)
%IMT_AAS_MECHANICAL_TILT_TRANSFORM Map sector az/el into panel az/el.
%
%   [AZP, ELP] = imt_aas_mechanical_tilt_transform(AZDEG, ELDEG, TILTDOWNDEG)
%
%   Applies a y-axis rotation that mechanically downtilts an AAS panel by
%   TILTDOWNDEG degrees and returns the observation direction expressed
%   in the panel's local frame.
%
%   Convention:
%       Sector / global axes:
%           x forward (sector boresight)
%           y to the left
%           z up
%       Direction (AZ, EL) -> unit vector
%           v = [ cos(EL)*cos(AZ); cos(EL)*sin(AZ); sin(EL) ]
%       Positive TILTDOWNDEG tilts the panel boresight downward (toward
%       -z). Equivalently, the panel frame is the global frame rotated
%       about the y axis by TILTDOWNDEG, so a global direction at
%       (AZ, EL) = (0, -TILTDOWNDEG) maps to panel (AZ, EL) = (0, 0).
%
%   Vectorized: AZDEG and ELDEG can be any same-shape arrays (or
%   broadcastable). TILTDOWNDEG is a scalar.
%
%   Returns AZPANELDEG wrapped to [-180, 180] and ELPANELDEG in [-90, 90].
%
%   No toolboxes required.

    validateattributes(tiltDownDeg, {'numeric'}, ...
        {'real','scalar','finite'});

    cosTilt = cosd(tiltDownDeg);
    sinTilt = sind(tiltDownDeg);

    cosEl = cosd(elDeg);
    sinEl = sind(elDeg);
    cosAz = cosd(azDeg);
    sinAz = sind(azDeg);

    % unit vector in global / sector frame
    x = cosEl .* cosAz;
    y = cosEl .* sinAz;
    z = sinEl;

    % rotate by tiltDownDeg about +y so that a global direction at
    % (az, el) = (0, -tilt) ends up at panel (0, 0):
    %     [ x'; y'; z'] = Ry(tilt) * [x; y; z]
    % with Ry(tilt) = [ cos(tilt) 0 -sin(tilt);
    %                   0         1   0       ;
    %                   sin(tilt) 0  cos(tilt) ]
    xp =  x .* cosTilt - z .* sinTilt;
    yp =  y;
    zp =  x .* sinTilt + z .* cosTilt;

    % numerical clamp before asin
    zp = max(min(zp, 1), -1);

    elPanelDeg = asind(zp);
    azPanelDeg = atan2d(yp, xp);

    % wrap to [-180, 180] (atan2d already returns this range; the mod
    % keeps the contract robust to upstream changes / numerical drift).
    azPanelDeg = mod(azPanelDeg + 180, 360) - 180;
end
