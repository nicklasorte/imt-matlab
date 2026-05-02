function beams = compute_beam_angles_bs_to_ue(bs, uePositions, params)
%COMPUTE_BEAM_ANGLES_BS_TO_UE Raw BS->UE beam steering angles (no clamp).
%
%   BEAMS = compute_beam_angles_bs_to_ue(BS, UEPOSITIONS)
%   BEAMS = compute_beam_angles_bs_to_ue(BS, UEPOSITIONS, PARAMS)
%
%   For each UE, computes the geometric pointing angle from the BS to the
%   UE in the sector frame (relative to BS.azimuth_deg). No clipping is
%   applied here - raw angles can exceed the steering envelope. Use
%   clamp_beam_to_r23_coverage to apply the +/- 60 deg horizontal /
%   -10..0 deg vertical limits.
%
%   Geometry (BS at (BS.position_m(1), BS.position_m(2), BS.height_m)):
%       dx = ue.x_m - bs.x
%       dy = ue.y_m - bs.y
%       dz = ue.z_m - bs.height_m
%       groundRange_m = hypot(dx, dy)
%       azGlobalDeg   = atan2d(dy, dx)
%       rawAzDeg      = wrap-180(azGlobalDeg - BS.azimuth_deg)
%       rawElDeg      = atan2d(dz, groundRange_m)
%
%   Sign convention:
%       rawAzDeg in (-180, 180], 0 = sector boresight.
%       rawElDeg in [-90, 90],   0 = horizon, negative = downtilt
%                                (internal elevation).
%
%   The output also carries the R23 / M.2101 global-theta representation
%   alongside the internal elevation so callers can switch conventions
%   without re-deriving the relationship:
%
%       rawThetaGlobalDeg = 90 - rawElDeg     % R23 global theta
%
%       elevation  0 deg  -> theta  90 deg  (horizon)
%       elevation -5 deg  -> theta  95 deg
%       elevation -10 deg -> theta 100 deg  (10 deg below horizon)
%
%   This conversion is the contract; it is verified by
%   test_single_sector_eirp_mvp and must not be silently flipped.
%
%   Inputs:
%       BS           struct from get_default_bs (or override).
%       UEPOSITIONS  struct from sample_ue_positions_in_sector.
%       PARAMS       optional struct from get_r23_aas_params.
%
%   Output struct fields (column vectors of length UEPOSITIONS.N):
%       rawAzDeg            internal sector-frame azimuth [deg]
%       rawElDeg            internal elevation [deg], 0 = horizon
%       rawThetaGlobalDeg   R23 global theta [deg], 90 = horizon
%       groundRange_m, slantRange_m
%       azGlobalDeg
%       layout      generate_single_sector_layout(BS, PARAMS) passthrough
%       ue          UEPOSITIONS passthrough
%
%   See also: clamp_beam_to_r23_coverage, sample_ue_positions_in_sector.

    if nargin < 1 || isempty(bs)
        bs = get_default_bs();
    end
    if nargin < 2 || isempty(uePositions)
        error('compute_beam_angles_bs_to_ue:missingUe', ...
            'uePositions struct (see sample_ue_positions_in_sector) is required.');
    end
    if nargin < 3 || isempty(params)
        params = get_r23_aas_params();
    end

    layout = generate_single_sector_layout(bs, params);

    x = uePositions.x_m(:);
    y = uePositions.y_m(:);
    z = uePositions.z_m(:);

    dx = x - layout.bsX_m;
    dy = y - layout.bsY_m;
    dz = z - layout.bsHeight_m;

    groundRange_m = hypot(dx, dy);
    slantRange_m  = hypot(groundRange_m, dz);
    azGlobalDeg   = atan2d(dy, dx);
    rawAzDeg      = wrap_to_180(azGlobalDeg - layout.boresightAzDeg);
    rawElDeg      = atan2d(dz, groundRange_m);

    % R23 global-theta representation (90 deg = horizon).
    % Kept alongside rawElDeg so consumers can pick the convention
    % they need without re-deriving 90 - elev each time.
    rawThetaGlobalDeg = 90 - rawElDeg;

    beams = struct();
    beams.rawAzDeg          = rawAzDeg;
    beams.rawElDeg          = rawElDeg;
    beams.rawThetaGlobalDeg = rawThetaGlobalDeg;
    beams.groundRange_m     = groundRange_m;
    beams.slantRange_m      = slantRange_m;
    beams.azGlobalDeg       = azGlobalDeg;
    beams.layout            = layout;
    beams.ue                = uePositions;
end

% =====================================================================

function w = wrap_to_180(a)
    w = mod(a + 180, 360) - 180;
    w(w == -180) = 180;
end
