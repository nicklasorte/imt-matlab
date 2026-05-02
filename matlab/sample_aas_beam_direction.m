function [azim_i, elev_i] = sample_aas_beam_direction(opts, rng_state)
%SAMPLE_AAS_BEAM_DIRECTION Draw one or more AAS beam pointings.
%
%   [AZIM_I, ELEV_I] = sample_aas_beam_direction(OPTS)
%   [AZIM_I, ELEV_I] = sample_aas_beam_direction(OPTS, RNG_STATE)
%
%   Sampling models supported via OPTS.mode:
%       'uniform'     azim ~ U(opts.azim_range), elev ~ U(opts.elev_range)
%       'sector'      uniform within a 3-sector cell sector centered at
%                     opts.sector_az with opening opts.sector_az_width [deg],
%                     elevation uniform within opts.elev_range
%       'fixed'       returns opts.azim_i, opts.elev_i (deterministic;
%                     useful for repeatability tests)
%       'list'        draws uniformly from opts.azim_list / opts.elev_list
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
