function out = compute_bs_gain_toward_grid(bs, ueBeams, gridPoints, params)
%COMPUTE_BS_GAIN_TOWARD_GRID Composite BS gain toward each grid point per beam.
%
%   OUT = compute_bs_gain_toward_grid(BS, UEBEAMS, GRIDPOINTS)
%   OUT = compute_bs_gain_toward_grid(BS, UEBEAMS, GRIDPOINTS, PARAMS)
%
%   For each UE beam (one per UE), evaluates the BS composite antenna gain
%   in dBi at each (azimuth, elevation) grid point. The mechanical
%   downtilt rotation (sector -> panel frame) is applied internally via
%   imtAasCompositeGain.
%
%   Inputs:
%       BS          struct from get_default_bs (or override).
%       UEBEAMS     struct from clamp_beam_to_r23_coverage. Must contain
%                   steerAzDeg and steerElDeg column vectors.
%       GRIDPOINTS  struct describing the observation grid:
%                       .azGridDeg   1xNaz vector [deg], sector frame
%                       .elGridDeg   1xNel vector [deg], sector frame
%                   azimuth is wrt sector boresight, elevation is wrt
%                   horizon.
%       PARAMS      optional struct from get_r23_aas_params.
%
%   Output struct fields:
%       compositeGainDbi   Naz x Nel x numBeams [dBi]
%       peakGainDbi        scalar = max over the steered beam at boresight
%       AZ, EL             Naz x Nel ndgrid arrays of az/el [deg]
%       azGridDeg, elGridDeg  vector passthrough [deg]
%       params             passthrough
%       beams              passthrough of UEBEAMS
%
%   The R23 reference peak composite gain is ~32.2 dBi.

    if nargin < 1 || isempty(bs)
        bs = get_default_bs();
    end
    if nargin < 2 || isempty(ueBeams)
        error('compute_bs_gain_toward_grid:missingBeams', ...
            'ueBeams struct (clamp_beam_to_r23_coverage output) is required.');
    end
    if nargin < 3 || isempty(gridPoints)
        error('compute_bs_gain_toward_grid:missingGrid', ...
            'gridPoints struct with azGridDeg / elGridDeg is required.');
    end
    if nargin < 4 || isempty(params)
        params = get_r23_aas_params();
    end

    if ~isfield(ueBeams, 'steerAzDeg') || ~isfield(ueBeams, 'steerElDeg')
        error('compute_bs_gain_toward_grid:badBeams', ...
            ['ueBeams must contain steerAzDeg / steerElDeg ' ...
             '(see clamp_beam_to_r23_coverage).']);
    end
    if ~isfield(gridPoints, 'azGridDeg') || ~isfield(gridPoints, 'elGridDeg')
        error('compute_bs_gain_toward_grid:badGrid', ...
            'gridPoints must contain azGridDeg and elGridDeg vectors.');
    end

    azVec = double(gridPoints.azGridDeg(:).');
    elVec = double(gridPoints.elGridDeg(:).');
    Naz = numel(azVec);
    Nel = numel(elVec);
    [AZ, EL] = ndgrid(azVec, elVec);

    steerAz = double(ueBeams.steerAzDeg(:));
    steerEl = double(ueBeams.steerElDeg(:));
    if numel(steerAz) ~= numel(steerEl)
        error('compute_bs_gain_toward_grid:beamLenMismatch', ...
            'steerAzDeg and steerElDeg must have equal length.');
    end
    nBeams = numel(steerAz);

    % Use the BS height implicitly through params.mechanicalDowntiltDeg
    % handled by imtAasCompositeGain. The BS x/y/z position do not affect
    % the antenna pattern (antenna-face EIRP is measured at the BS face).
    %#ok<INUSL> (bs is part of the public contract; pass-through)
    compositeGainDbi = zeros(Naz, Nel, nBeams);
    for i = 1:nBeams
        compositeGainDbi(:, :, i) = imtAasCompositeGain( ...
            azVec, elVec, steerAz(i), steerEl(i), params);
    end

    out = struct();
    out.compositeGainDbi = compositeGainDbi;
    if nBeams > 0
        out.peakGainDbi  = max(compositeGainDbi(:));
    else
        out.peakGainDbi  = -inf;
    end
    out.AZ          = AZ;
    out.EL          = EL;
    out.azGridDeg   = azVec;
    out.elGridDeg   = elVec;
    out.params      = params;
    out.beams       = ueBeams;
    out.bs          = bs;
end
