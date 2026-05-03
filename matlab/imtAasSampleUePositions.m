function ue = imtAasSampleUePositions(N, sector, opts)
%IMTAASSAMPLEUEPOSITIONS Draw N UE positions inside one AAS sector.
%
%   UE = imtAasSampleUePositions(N)
%   UE = imtAasSampleUePositions(N, SECTOR)
%   UE = imtAasSampleUePositions(N, SECTOR, OPTS)
%
%   Samples N UE ground positions inside the horizontal sector defined by
%   SECTOR (see imtAasSingleSectorParams). Radial draws are uniform in area
%       r = sqrt(r_min^2 + u * (r_max^2 - r_min^2))
%   and azimuth draws are uniform across SECTOR.azLimitsDeg.
%
%   Inputs:
%       N       positive integer scalar (number of UEs).
%       SECTOR  optional sector struct (default imtAasSingleSectorParams()).
%       OPTS    optional struct with fields:
%                 .seed         optional RNG seed (any rng() seed).
%                               If provided, the global RNG state is saved
%                               before seeding and restored on return so
%                               this function does not perturb caller RNG
%                               state.
%                 .azRelDeg     optional explicit length-N vector of UE
%                               azimuths relative to sector boresight [deg].
%                 .r_m          optional explicit length-N vector of UE
%                               ground ranges from BS [m].
%                 .ueHeight_m   optional UE antenna height; scalar or
%                               length-N vector [m]. Default
%                               SECTOR.ueHeight_m.
%
%       If azRelDeg / r_m are provided they are used directly (and
%       validated against the sector limits) instead of random draws.
%
%   Output struct fields (all column vectors of length N unless noted):
%       x_m, y_m, z_m      UE Cartesian coordinates [m]
%       r_m                BS-to-UE ground range [m]
%       azRelDeg           azimuth relative to sector boresight [deg]
%       azGlobalDeg        absolute azimuth in the world frame [deg]
%       height_m           UE antenna height (z_m) [m]
%       N                  scalar N
%       sector             sector struct passthrough
%
%   See also: imtAasSingleSectorParams, imtAasUeToBeamAngles,
%             imtAasGenerateBeamSet.

    if ~(isnumeric(N) && isscalar(N) && isfinite(N) && N > 0 && N == floor(N))
        error('imtAasSampleUePositions:invalidN', ...
            'N must be a positive integer scalar.');
    end
    N = double(N);

    if nargin < 2 || isempty(sector)
        sector = imtAasSingleSectorParams();
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    azLim  = sector.azLimitsDeg;
    rMin   = sector.minUeDistance_m;
    rMax   = sector.cellRadius_m;

    haveAz = isfield(opts, 'azRelDeg') && ~isempty(opts.azRelDeg);
    haveR  = isfield(opts, 'r_m')      && ~isempty(opts.r_m);
    haveSeed = isfield(opts, 'seed')   && ~isempty(opts.seed);

    % Seed handling: save / restore global RNG state so the caller's stream
    % is not permanently perturbed. This matters when the caller is itself
    % running a Monte Carlo sweep with a separate seed.
    rngStateSaved = [];
    if haveSeed
        rngStateSaved = rng();
        rng(opts.seed);
    end

    cleanup = onCleanup(@() restoreRng(rngStateSaved));

    if haveAz
        azRelDeg = opts.azRelDeg(:);
        if numel(azRelDeg) ~= N
            error('imtAasSampleUePositions:badAzLen', ...
                'opts.azRelDeg must have length N=%d (got %d).', ...
                N, numel(azRelDeg));
        end
        if any(~isfinite(azRelDeg)) || ...
                any(azRelDeg < azLim(1) - 1e-9) || ...
                any(azRelDeg > azLim(2) + 1e-9)
            error('imtAasSampleUePositions:azOutOfRange', ...
                ['opts.azRelDeg values must lie within sector ' ...
                 'azLimitsDeg = [%g, %g] deg.'], azLim(1), azLim(2));
        end
    else
        azRelDeg = azLim(1) + (azLim(2) - azLim(1)) .* rand(N, 1);
    end

    if haveR
        r_m = opts.r_m(:);
        if numel(r_m) ~= N
            error('imtAasSampleUePositions:badRLen', ...
                'opts.r_m must have length N=%d (got %d).', N, numel(r_m));
        end
        if any(~isfinite(r_m)) || ...
                any(r_m < rMin - 1e-9) || any(r_m > rMax + 1e-9)
            error('imtAasSampleUePositions:rOutOfRange', ...
                ['opts.r_m values must lie within ' ...
                 '[minUeDistance_m, cellRadius_m] = [%g, %g] m.'], ...
                rMin, rMax);
        end
    else
        u = rand(N, 1);
        r_m = sqrt(rMin.^2 + u .* (rMax.^2 - rMin.^2));
    end

    if isfield(opts, 'ueHeight_m') && ~isempty(opts.ueHeight_m)
        h = opts.ueHeight_m(:);
        if isscalar(h)
            ueHeight_m = h .* ones(N, 1);
        elseif numel(h) == N
            ueHeight_m = h;
        else
            error('imtAasSampleUePositions:badHeightLen', ...
                ['opts.ueHeight_m must be scalar or length-N vector ' ...
                 '(got %d, N=%d).'], numel(h), N);
        end
        if any(~isfinite(ueHeight_m))
            error('imtAasSampleUePositions:badHeightVal', ...
                'opts.ueHeight_m contains non-finite values.');
        end
    else
        ueHeight_m = sector.ueHeight_m .* ones(N, 1);
    end

    azGlobalDeg = sector.boresightAzDeg + azRelDeg;
    x_m = sector.bsX_m + r_m .* cosd(azGlobalDeg);
    y_m = sector.bsY_m + r_m .* sind(azGlobalDeg);
    z_m = ueHeight_m;

    ue = struct();
    ue.x_m         = x_m;
    ue.y_m         = y_m;
    ue.z_m         = z_m;
    ue.r_m         = r_m;
    ue.azRelDeg    = azRelDeg;
    ue.azGlobalDeg = azGlobalDeg;
    ue.height_m    = ueHeight_m;
    ue.N           = N;
    ue.sector      = sector;
end

% =====================================================================

function restoreRng(state)
    if ~isempty(state)
        rng(state);
    end
end
