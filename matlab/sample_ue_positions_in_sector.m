function ue = sample_ue_positions_in_sector(bs, params, rngSeed, numUes)
%SAMPLE_UE_POSITIONS_IN_SECTOR Draw UEs uniformly in one R23 sector.
%
%   UE = sample_ue_positions_in_sector(BS)
%   UE = sample_ue_positions_in_sector(BS, PARAMS)
%   UE = sample_ue_positions_in_sector(BS, PARAMS, RNGSEED)
%   UE = sample_ue_positions_in_sector(BS, PARAMS, RNGSEED, NUMUES)
%
%   Samples NUMUES (default 3) UE positions inside the BS sector defined
%   by BS + PARAMS. Radial draws are uniform in area between
%   minUeDistance_m and cellRadius_m, and azimuth draws are uniform inside
%   the steering envelope (default +/- 60 deg). RNGSEED is optional; when
%   provided the global RNG is saved, seeded, and restored on return so
%   the caller's stream is not perturbed.
%
%   The R23 contract enforced here:
%       UE ground range >= 35 m
%       UE inside the +/- hCoverageDeg envelope (default +/- 60 deg)
%       UE antenna height = 1.5 m
%
%   Inputs:
%       BS        struct from get_default_bs (or override).
%       PARAMS    struct from get_r23_aas_params (default if [] / omitted).
%       RNGSEED   optional RNG seed (any rng() seed). When [] / omitted,
%                 the global RNG stream is used as-is.
%       NUMUES    optional positive integer (default 3 to match R23
%                 single-sector "3 UEs" assumption).
%
%   Output struct fields (all column vectors of length NUMUES):
%       x_m, y_m, z_m      UE Cartesian position [m]
%       r_m                ground range from BS [m]
%       slantRange_m       3-D slant range from BS antenna to UE [m]
%       azRelDeg           UE azimuth relative to sector boresight [deg]
%       azGlobalDeg        UE azimuth in world frame [deg]
%       height_m           UE antenna height [m]
%       N                  scalar NUMUES
%       layout             generate_single_sector_layout(BS, PARAMS) output
%
%   See also: get_default_bs, get_r23_aas_params,
%             generate_single_sector_layout, compute_beam_angles_bs_to_ue.

    if nargin < 1 || isempty(bs)
        bs = get_default_bs();
    end
    if nargin < 2 || isempty(params)
        params = get_r23_aas_params();
    end
    if nargin < 3
        rngSeed = [];
    end
    if nargin < 4 || isempty(numUes)
        numUes = 3;
    end
    if ~(isnumeric(numUes) && isscalar(numUes) && isfinite(numUes) && ...
            numUes >= 1 && numUes == floor(numUes))
        error('sample_ue_positions_in_sector:badNumUes', ...
            'numUes must be a positive integer scalar.');
    end

    layout = generate_single_sector_layout(bs, params);

    sampleOpts = struct();
    if ~isempty(rngSeed)
        sampleOpts.seed = rngSeed;
    end
    sampleOpts.ueHeight_m = layout.ueHeight_m;

    sectorAdapter = layout_to_sector(layout);
    raw = imtAasSampleUePositions(numUes, sectorAdapter, sampleOpts);

    ue = struct();
    ue.x_m         = raw.x_m;
    ue.y_m         = raw.y_m;
    ue.z_m         = raw.z_m;
    ue.r_m         = raw.r_m;
    ue.azRelDeg    = raw.azRelDeg;
    ue.azGlobalDeg = raw.azGlobalDeg;
    ue.height_m    = raw.height_m;
    dz = ue.z_m - layout.bsHeight_m;
    ue.slantRange_m = hypot(ue.r_m, dz);
    ue.N      = double(numUes);
    ue.layout = layout;
end

% =====================================================================

function sector = layout_to_sector(layout)
    sector = struct();
    sector.deployment      = layout.environment;
    sector.bsX_m           = layout.bsX_m;
    sector.bsY_m           = layout.bsY_m;
    sector.bsHeight_m      = layout.bsHeight_m;
    sector.ueHeight_m      = layout.ueHeight_m;
    sector.cellRadius_m    = layout.cellRadius_m;
    sector.minUeDistance_m = layout.minUeDistance_m;
    sector.boresightAzDeg  = layout.boresightAzDeg;
    sector.sectorWidthDeg  = layout.sectorWidthDeg;
    sector.azLimitsDeg     = layout.azLimitsDeg;
    sector.elLimitsDeg     = layout.elLimitsDeg;
    sector.params          = layout.params;
end
