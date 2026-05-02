function beam = imtAasUeToBeamAngles(ue, sector)
%IMTAASUETOBEAMANGLES Convert UE positions to raw AAS beam steering angles.
%
%   BEAM = imtAasUeToBeamAngles(UE)
%   BEAM = imtAasUeToBeamAngles(UE, SECTOR)
%
%   Computes raw beam steering angles (relative to sector boresight) that
%   point from the BS at SECTOR to each UE in UE. No clipping is applied
%   here; raw angles may exceed the sector / R23 steering envelope. Use
%   imtAasApplyBeamLimits to clamp.
%
%   Geometry (BS at (sector.bsX_m, sector.bsY_m, sector.bsHeight_m)):
%       dx = ue.x_m - sector.bsX_m
%       dy = ue.y_m - sector.bsY_m
%       dz = ue.z_m - sector.bsHeight_m
%       groundRange_m = hypot(dx, dy)
%       slantRange_m  = hypot(groundRange_m, dz)
%       azGlobalDeg   = atan2d(dy, dx)
%       rawSteerAzDeg = wrap-180(azGlobalDeg - sector.boresightAzDeg)
%       rawSteerElDeg = atan2d(dz, groundRange_m)
%
%   Sign convention (consistent with the rest of the repo):
%       rawSteerAzDeg in [-180, 180] (relative to sector boresight, 0
%                      points along boresight).
%       rawSteerElDeg in [-90,   90], 0 = horizon, negative = downtilt
%                      (UE below BS antenna).
%
%   Output struct fields (all column vectors of length ue.N):
%       rawSteerAzDeg, rawSteerElDeg
%       groundRange_m, slantRange_m
%       azGlobalDeg
%       ue        (passthrough)
%       sector    (passthrough)
%
%   See also: imtAasSampleUePositions, imtAasApplyBeamLimits,
%             imtAasGenerateBeamSet.

    if nargin < 1 || isempty(ue)
        error('imtAasUeToBeamAngles:missingUe', 'ue struct is required.');
    end
    if nargin < 2 || isempty(sector)
        if isfield(ue, 'sector') && ~isempty(ue.sector)
            sector = ue.sector;
        else
            sector = imtAasSingleSectorParams();
        end
    end

    x = ue.x_m(:);
    y = ue.y_m(:);
    z = ue.z_m(:);

    dx = x - sector.bsX_m;
    dy = y - sector.bsY_m;
    dz = z - sector.bsHeight_m;

    groundRange_m = hypot(dx, dy);
    slantRange_m  = hypot(groundRange_m, dz);

    azGlobalDeg   = atan2d(dy, dx);
    rawSteerAzDeg = wrapTo180Local(azGlobalDeg - sector.boresightAzDeg);
    rawSteerElDeg = atan2d(dz, groundRange_m);

    beam = struct();
    beam.rawSteerAzDeg = rawSteerAzDeg;
    beam.rawSteerElDeg = rawSteerElDeg;
    beam.groundRange_m = groundRange_m;
    beam.slantRange_m  = slantRange_m;
    beam.azGlobalDeg   = azGlobalDeg;
    beam.ue            = ue;
    beam.sector        = sector;
end

% =====================================================================

function w = wrapTo180Local(a)
    % Map a (deg) into (-180, 180]. Uses mod() to avoid the Mapping
    % Toolbox dependency from wrapTo180.
    w = mod(a + 180, 360) - 180;
    % mod yields (-180, 180]; ensure exactly -180 maps to 180 (not strictly
    % required for steering but matches MATLAB's wrapTo180 behavior).
    w(w == -180) = 180;
end
