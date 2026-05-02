function layout = generate_single_sector_layout(bs, params)
%GENERATE_SINGLE_SECTOR_LAYOUT Build sector geometry from a BS input struct.
%
%   LAYOUT = generate_single_sector_layout(BS)
%   LAYOUT = generate_single_sector_layout(BS, PARAMS)
%
%   Converts the R23 BS input contract (see get_default_bs) into a sector
%   layout struct that downstream functions consume. This is the single
%   point in the MVP that resolves "BS height" semantics: BS.position_m(3)
%   and BS.height_m must agree; if they disagree, BS.height_m wins and a
%   warning is issued.
%
%   The R23 single-sector slice fixes:
%       horizontal coverage envelope :  +/- 60 deg from boresight
%                                       (BS.sector_width_deg overrides)
%       vertical coverage envelope   :  R23 global theta 90..100 deg
%                                       <=> internal elevation -10..0 deg
%                                       (conversion: theta = 90 - elev)
%       UE minimum distance          :  35 m (R23)
%       UE height                    :  1.5 m (R23)
%       cell radius                  :  400 m (urban) / 800 m (suburban)
%
%   The vertical envelope is exposed in BOTH conventions on the layout
%   struct so downstream code can use whichever is natural without
%   re-deriving the relationship:
%       elLimitsDeg                    = [-10, 0]    internal elevation
%       verticalCoverageGlobalThetaDeg = [90, 100]   R23 global theta
%   These two fields are kept consistent by construction via
%       verticalCoverageGlobalThetaDeg = 90 - flip(elLimitsDeg).
%
%   Inputs:
%       BS      struct from get_default_bs (or an override).
%       PARAMS  optional struct from get_r23_aas_params (default
%               get_r23_aas_params()).
%
%   Output struct fields:
%       bs                       passthrough of input BS
%       params                   passthrough of PARAMS
%       bsX_m, bsY_m             (x, y) BS position [m]
%       bsHeight_m               BS antenna height [m]
%       boresightAzDeg           sector boresight azimuth [deg]
%       sectorWidthDeg           sector horizontal coverage [deg]
%       azLimitsDeg              [-min, +max] steering envelope [deg]
%                                relative to boresight (R23: +/- 60)
%       elLimitsDeg              [-10, 0] internal elevation envelope
%                                (0 deg = horizon, negative = downtilt)
%       verticalCoverageGlobalThetaDeg
%                                [90, 100] R23 global-theta envelope,
%                                exposed alongside elLimitsDeg as the
%                                explicit conversion (90 - elev)
%       ueHeight_m               default UE height [m] (1.5)
%       cellRadius_m             max UE ground range [m]
%       minUeDistance_m          min UE ground range [m] (R23: 35)
%       environment              passthrough tag
%
%   See also: get_default_bs, get_r23_aas_params,
%             sample_ue_positions_in_sector.

    if nargin < 1 || isempty(bs)
        bs = get_default_bs();
    end
    if nargin < 2 || isempty(params)
        params = get_r23_aas_params();
    end

    validate_bs(bs);
    validate_r23_params(params);

    pos = bs.position_m(:).';
    if numel(pos) ~= 3
        error('generate_single_sector_layout:badPosition', ...
            'bs.position_m must be a 3-element vector [x y z] in meters.');
    end

    if abs(pos(3) - bs.height_m) > 1e-9
        warning('generate_single_sector_layout:heightMismatch', ...
            ['bs.position_m(3) = %g m disagrees with bs.height_m = %g m. ' ...
             'Using bs.height_m.'], pos(3), bs.height_m);
    end

    % R23 environment-driven cell radius.
    envTag = char(string(bs.environment));
    switch lower(envTag)
        case {'urban', 'urban_macro', 'macrourban'}
            cellRadius_m = 400;
        case {'suburban', 'suburban_macro', 'macrosuburban'}
            cellRadius_m = 800;
        otherwise
            error('generate_single_sector_layout:unknownEnvironment', ...
                ['Unsupported environment "%s". Supported: ' ...
                 'urban, suburban.'], envTag);
    end

    layout = struct();
    layout.bs               = bs;
    layout.params           = params;
    layout.bsX_m            = pos(1);
    layout.bsY_m            = pos(2);
    layout.bsHeight_m       = bs.height_m;
    layout.boresightAzDeg   = bs.azimuth_deg;
    layout.sectorWidthDeg   = bs.sector_width_deg;
    layout.azLimitsDeg      = [-params.hCoverageDeg, params.hCoverageDeg];
    layout.elLimitsDeg      = [params.vCoverageDegGlobalMin - 90, ...
                               params.vCoverageDegGlobalMax - 90];
    % Expose the R23 global-theta envelope explicitly so callers don't
    % have to re-derive 90 - elev. By construction this stays consistent
    % with elLimitsDeg (the conversion is monotonically decreasing, so
    % the limits flip).
    layout.verticalCoverageGlobalThetaDeg = ...
        [params.vCoverageDegGlobalMin, params.vCoverageDegGlobalMax];
    layout.ueHeight_m       = 1.5;
    layout.cellRadius_m     = cellRadius_m;
    layout.minUeDistance_m  = 35;
    layout.environment      = envTag;
end

% =====================================================================

function validate_bs(bs)
    if ~isstruct(bs) || ~isscalar(bs)
        error('generate_single_sector_layout:badBs', ...
            'bs must be a scalar struct (see get_default_bs).');
    end
    required = {'position_m', 'azimuth_deg', 'sector_width_deg', ...
                'height_m', 'environment', 'eirp_dBm_per_100MHz'};
    for i = 1:numel(required)
        if ~isfield(bs, required{i})
            error('generate_single_sector_layout:missingBsField', ...
                'bs is missing required field "%s".', required{i});
        end
    end
    if ~(isnumeric(bs.azimuth_deg) && isreal(bs.azimuth_deg) && ...
            isscalar(bs.azimuth_deg) && isfinite(bs.azimuth_deg))
        error('generate_single_sector_layout:badBsField', ...
            'bs.azimuth_deg must be a real finite scalar.');
    end
    if ~(isnumeric(bs.sector_width_deg) && isscalar(bs.sector_width_deg) && ...
            isfinite(bs.sector_width_deg) && bs.sector_width_deg > 0)
        error('generate_single_sector_layout:badBsField', ...
            'bs.sector_width_deg must be a positive finite scalar.');
    end
    if ~(isnumeric(bs.height_m) && isreal(bs.height_m) && ...
            isscalar(bs.height_m) && isfinite(bs.height_m))
        error('generate_single_sector_layout:badBsField', ...
            'bs.height_m must be a real finite scalar.');
    end
    if ~(isnumeric(bs.eirp_dBm_per_100MHz) && isreal(bs.eirp_dBm_per_100MHz) ...
            && isscalar(bs.eirp_dBm_per_100MHz) && ...
            isfinite(bs.eirp_dBm_per_100MHz))
        error('generate_single_sector_layout:badBsField', ...
            'bs.eirp_dBm_per_100MHz must be a real finite scalar.');
    end
end
