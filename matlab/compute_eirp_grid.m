function out = compute_eirp_grid(bs, uePositions, gridPoints, params, opts)
%COMPUTE_EIRP_GRID Single-snapshot per-direction EIRP grid (R23, antenna face).
%
%   OUT = compute_eirp_grid(BS, UEPOSITIONS, GRIDPOINTS)
%   OUT = compute_eirp_grid(BS, UEPOSITIONS, GRIDPOINTS, PARAMS)
%   OUT = compute_eirp_grid(BS, UEPOSITIONS, GRIDPOINTS, PARAMS, OPTS)
%
%   For one snapshot of N UEs, computes:
%       (1) raw geometric BS->UE pointing angles
%       (2) clamped beam steering angles (R23 +/- 60 az, -10..0 el)
%       (3) per-beam composite BS gain over the (az, el) grid
%       (4) per-beam EIRP (peak-normalized so peak per beam =
%               sectorEirpDbm - 10*log10(N) when SPLITSECTORPOWER = true,
%               or sectorEirpDbm when false).
%       (5) sector-aggregate EIRP grid via linear-mW summation across the
%               N simultaneous beams.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I / N.
%
%   Inputs:
%       BS           struct from get_default_bs (or override). Sector
%                    EIRP defaults to BS.eirp_dBm_per_100MHz.
%       UEPOSITIONS  struct from sample_ue_positions_in_sector.
%       GRIDPOINTS   struct with .azGridDeg / .elGridDeg vectors [deg].
%       PARAMS       optional struct from get_r23_aas_params.
%       OPTS         optional struct:
%                       .splitSectorPower  default true (R23 power split)
%
%   Output struct fields:
%       perBeamEirpDbm           Naz x Nel x N [dBm / 100 MHz]
%       aggregateEirpDbm         Naz x Nel    [dBm / 100 MHz]
%                                (linear-mW summed over N beams)
%       maxEnvelopeEirpDbm       Naz x Nel    [dBm / 100 MHz]
%                                (max over beams per cell)
%       perBeamPeakEirpDbm       scalar [dBm / 100 MHz]
%       sectorEirpDbm            scalar [dBm / 100 MHz]
%       splitSectorPower         logical
%       numBeams                 scalar
%       AZ, EL                   Naz x Nel grids [deg]
%       azGridDeg, elGridDeg     passthrough vectors
%       beams                    clamp_beam_to_r23_coverage output
%       params, bs               passthroughs

    if nargin < 1 || isempty(bs)
        bs = get_default_bs();
    end
    if nargin < 2 || isempty(uePositions)
        error('compute_eirp_grid:missingUe', ...
            'uePositions struct is required.');
    end
    if nargin < 3 || isempty(gridPoints)
        error('compute_eirp_grid:missingGrid', ...
            'gridPoints struct (azGridDeg / elGridDeg) is required.');
    end
    if nargin < 4 || isempty(params)
        params = get_r23_aas_params();
    end
    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if isfield(opts, 'splitSectorPower') && ~isempty(opts.splitSectorPower)
        splitSectorPower = logical(opts.splitSectorPower);
    else
        splitSectorPower = true;
    end

    rawBeams = compute_beam_angles_bs_to_ue(bs, uePositions, params);
    beams    = clamp_beam_to_r23_coverage(bs, rawBeams, params);

    sectorEirpDbm = double(bs.eirp_dBm_per_100MHz);
    numBeams = numel(beams.steerAzDeg);
    if splitSectorPower
        perBeamPeakEirpDbm = sectorEirpDbm - 10 * log10(double(numBeams));
    else
        perBeamPeakEirpDbm = sectorEirpDbm;
    end

    azVec = double(gridPoints.azGridDeg(:).');
    elVec = double(gridPoints.elGridDeg(:).');
    Naz = numel(azVec);
    Nel = numel(elVec);
    [AZ, EL] = ndgrid(azVec, elVec);

    perBeamEirpDbm = zeros(Naz, Nel, numBeams);
    for i = 1:numBeams
        perBeamEirpDbm(:, :, i) = imtAasEirpGrid( ...
            azVec, elVec, ...
            beams.steerAzDeg(i), beams.steerElDeg(i), ...
            perBeamPeakEirpDbm, params);
    end

    aggregateEirpDbm   = 10 * log10(sum(10 .^ (perBeamEirpDbm / 10), 3));
    maxEnvelopeEirpDbm = max(perBeamEirpDbm, [], 3);

    out = struct();
    out.perBeamEirpDbm     = perBeamEirpDbm;
    out.aggregateEirpDbm   = aggregateEirpDbm;
    out.maxEnvelopeEirpDbm = maxEnvelopeEirpDbm;
    out.perBeamPeakEirpDbm = perBeamPeakEirpDbm;
    out.sectorEirpDbm      = sectorEirpDbm;
    out.splitSectorPower   = splitSectorPower;
    out.numBeams           = numBeams;
    out.AZ                 = AZ;
    out.EL                 = EL;
    out.azGridDeg          = azVec;
    out.elGridDeg          = elVec;
    out.beams              = beams;
    out.params             = params;
    out.bs                 = bs;
end
