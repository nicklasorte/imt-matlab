function [azim_i, elev_i, dbg] = sample_aas_beam_direction(opts, rng_state)
%SAMPLE_AAS_BEAM_DIRECTION Draw one or more AAS beam pointings.
%
%   [AZIM_I, ELEV_I]      = sample_aas_beam_direction(OPTS)
%   [AZIM_I, ELEV_I]      = sample_aas_beam_direction(OPTS, RNG_STATE)
%   [AZIM_I, ELEV_I, DBG] = sample_aas_beam_direction(...)
%
%   Sampling models supported via OPTS.mode:
%       'uniform'     azim ~ U(opts.azim_range), elev ~ U(opts.elev_range)
%       'sector'      uniform within a 3-sector cell sector centered at
%                     opts.sector_az with opening opts.sector_az_width [deg],
%                     elevation uniform within opts.elev_range
%       'fixed'       returns opts.azim_i, opts.elev_i (deterministic;
%                     useful for repeatability tests)
%       'list'        draws uniformly from opts.azim_list / opts.elev_list
%       'ue_sector'   draws random UE locations inside a sector and converts
%                     each one to a beam azim/elev relative to the BS:
%                       beamAz_deg = sector_az_deg
%                                    + U(-sector_width_deg/2,
%                                          sector_width_deg/2)
%                       r          = uniform_area or uniform_radius draw
%                                    in [r_min_m, r_max_m]
%                       beamEl_deg = atan2d(ue_height_m - bs_height_m, r)
%                     Geometric inputs (defaults shown):
%                       opts.sector_az_deg     = 0
%                       opts.sector_width_deg  = 120
%                       opts.r_min_m           = 10
%                       opts.r_max_m           = 500
%                       opts.bs_height_m       = 25
%                       opts.ue_height_m       = 1.5
%                       opts.ue_height_range_m = []  (optional)
%                     If opts.ue_height_range_m is a non-empty 2-element
%                     vector [hMin hMax], UE heights are drawn uniformly
%                     in that range (per beam) and opts.ue_height_m is
%                     ignored. Otherwise the scalar opts.ue_height_m is
%                     used for all beams (backward compatible).
%                     Optional distribution controls:
%                       opts.radial_distribution = 'uniform_area' (default)
%                                                | 'uniform_radius'
%                       opts.az_distribution     = 'uniform' (default)
%                       opts.elev_clip_deg       = [-90 90] (default)
%                     The optional third output DBG is populated only for
%                     'ue_sector' and contains:
%                       DBG.ueRange_m  numBeams x 1 BS-to-UE distance [m]
%                       DBG.ueAz_deg   numBeams x 1 BS-to-UE azimuth [deg]
%                       DBG.ueEl_deg   numBeams x 1 BS-to-UE elevation [deg]
%                       DBG.ueX_m      numBeams x 1 UE x coordinate [m]
%                       DBG.ueY_m      numBeams x 1 UE y coordinate [m]
%                       DBG.ueHeight_m numBeams x 1 UE antenna AGL [m]
%
%   OPTS.numBeams (default 1): number of simultaneous beams to draw.
%
%   Returns AZIM_I, ELEV_I as column vectors of length numBeams. They are
%   guaranteed to lie inside [-180,180] / [-90,90] respectively.

    if nargin < 2 || isempty(rng_state)
        rng_state = [];
    end
    if ~isempty(rng_state)
        rng(rng_state);
    end

    if ~isfield(opts, 'mode'); opts.mode = 'uniform'; end
    if ~isfield(opts, 'numBeams') || isempty(opts.numBeams)
        opts.numBeams = 1;
    end
    n = opts.numBeams;

    dbg = struct();

    switch lower(opts.mode)
        case 'uniform'
            azr = getf(opts, 'azim_range', [-60, 60]);
            elr = getf(opts, 'elev_range', [-10, 0]);
            azim_i = azr(1) + (azr(2)-azr(1)) .* rand(n,1);
            elev_i = elr(1) + (elr(2)-elr(1)) .* rand(n,1);

        case 'sector'
            ctr   = getf(opts, 'sector_az',       0);
            width = getf(opts, 'sector_az_width', 120);
            elr   = getf(opts, 'elev_range', [-10, 0]);
            azim_i = ctr + width.*(rand(n,1) - 0.5);
            elev_i = elr(1) + (elr(2)-elr(1)) .* rand(n,1);

        case 'fixed'
            azim_i = getf(opts, 'azim_i', 0) .* ones(n,1);
            elev_i = getf(opts, 'elev_i', 0) .* ones(n,1);

        case 'list'
            azL = opts.azim_list(:);
            elL = opts.elev_list(:);
            assert(numel(azL) == numel(elL), 'azim_list/elev_list size mismatch');
            idx = randi(numel(azL), [n, 1]);
            azim_i = azL(idx);
            elev_i = elL(idx);

        case 'ue_sector'
            sectorAz = getf(opts, 'sector_az_deg',    0);
            sectorW  = getf(opts, 'sector_width_deg', 120);
            rMin     = getf(opts, 'r_min_m',          10);
            rMax     = getf(opts, 'r_max_m',          500);
            hBs      = getf(opts, 'bs_height_m',      25);
            hUeScal  = getf(opts, 'ue_height_m',      1.5);
            hUeRange = getf(opts, 'ue_height_range_m', []);
            radDist  = lower(getf(opts, 'radial_distribution', 'uniform_area'));
            azDist   = lower(getf(opts, 'az_distribution',     'uniform'));
            elClip   = getf(opts, 'elev_clip_deg',    [-90, 90]);

            assert(rMax > rMin && rMin >= 0, ...
                'sample_aas_beam_direction:ue_sector:badRange', ...
                'r_min_m / r_max_m must satisfy 0 <= r_min < r_max');

            switch azDist
                case 'uniform'
                    azOffset = sectorW .* (rand(n,1) - 0.5);
                otherwise
                    error('sample_aas_beam_direction:ue_sector:badAzDist', ...
                        'Unknown az_distribution "%s"', azDist);
            end
            beamAz = sectorAz + azOffset;

            switch radDist
                case 'uniform_area'
                    r = sqrt(rMin.^2 + rand(n,1) .* (rMax.^2 - rMin.^2));
                case 'uniform_radius'
                    r = rMin + rand(n,1) .* (rMax - rMin);
                otherwise
                    error('sample_aas_beam_direction:ue_sector:badRadDist', ...
                        'Unknown radial_distribution "%s"', radDist);
            end

            % UE height: optional uniform draw from a [hMin hMax] range,
            % otherwise scalar opts.ue_height_m (backward compatible).
            if ~isempty(hUeRange)
                if numel(hUeRange) ~= 2 || hUeRange(2) < hUeRange(1)
                    error('sample_aas_beam_direction:ue_sector:badHeightRange', ...
                        ['ue_height_range_m must be [hMin hMax] with ' ...
                         'hMax >= hMin.']);
                end
                hUe = hUeRange(1) + rand(n,1) .* (hUeRange(2) - hUeRange(1));
            else
                hUe = hUeScal .* ones(n,1);
            end

            beamEl = atan2d(hUe - hBs, r);
            beamEl = max(min(beamEl, elClip(2)), elClip(1));

            azim_i = beamAz;
            elev_i = beamEl;

            dbg.ueRange_m  = r;
            dbg.ueAz_deg   = beamAz;
            dbg.ueEl_deg   = beamEl;
            dbg.ueX_m      = r .* cosd(beamAz);
            dbg.ueY_m      = r .* sind(beamAz);
            dbg.ueHeight_m = hUe;

        otherwise
            error('sample_aas_beam_direction:badMode', ...
                  'Unknown mode "%s"', opts.mode);
    end

    azim_i = max(min(azim_i, 180), -180);
    elev_i = max(min(elev_i,  90),  -90);
end

function v = getf(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end
