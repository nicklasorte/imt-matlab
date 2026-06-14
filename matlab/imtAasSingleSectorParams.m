function sector = imtAasSingleSectorParams(deployment, params)
%IMTAASSINGLESECTORPARAMS Geometry / steering envelope for one IMT AAS sector.
%
%   SECTOR = imtAasSingleSectorParams()
%   SECTOR = imtAasSingleSectorParams(DEPLOYMENT)
%   SECTOR = imtAasSingleSectorParams(DEPLOYMENT, PARAMS)
%
%   Returns a struct describing the deployment geometry and steering limits
%   for a single macro AAS sector. This layer is intentionally separate from
%   the antenna math: it describes BS / UE positions and the legal
%   electronic-steering envelope only. EIRP is computed downstream by
%   imtAasEirpGrid using PARAMS.
%
%   Inputs:
%       DEPLOYMENT  optional char/string (default 'macroUrban'). Supported
%                   values:
%                       'macroUrban'    bsHeight = 18 m, cellRadius = 400 m,
%                                       elLimits = [-10, 0]
%                       'macroSuburban' bsHeight = 20 m, cellRadius = 800 m,
%                                       elLimits = [-10, 0]
%                       'microUrban'    bsHeight =  6 m, cellRadius = 180 m,
%                                       elLimits = [-30, 0]
%                       'microSuburban' bsHeight =  6 m, cellRadius = 300 m,
%                                       elLimits = [-30, 0]
%       PARAMS      optional imtAasDefaultParams struct (default
%                   imtAasDefaultParams()).
%
%   Output struct fields:
%       deployment         deployment tag (lowercase-normalized to input)
%       bsX_m, bsY_m       base-station coordinates (0, 0) by convention
%       bsHeight_m         base-station antenna height [m]
%       ueHeight_m         default UE antenna height [m] (1.5)
%       cellRadius_m       max UE ground-range from BS [m]
%       minUeDistance_m    min UE ground-range from BS [m] (35)
%       boresightAzDeg     sector boresight azimuth [deg] (0)
%       sectorWidthDeg     sector horizontal coverage [deg] (120)
%       azLimitsDeg        steering azimuth limits relative to boresight
%                          [-60, 60] deg
%       elLimitsDeg        steering elevation limits [deg], deployment-
%                          dependent. Macro: [-10, 0] (R23 vertical
%                          coverage 90-100 deg global theta). Micro:
%                          [-30, 0] (small-cell vertical coverage 90-120
%                          deg global theta). Both map from global theta
%                          to elevation in this repo's (az, el) convention.
%       params             AAS antenna params struct (passthrough)
%
%   See also: imtAasSampleUePositions, imtAasUeToBeamAngles,
%             imtAasApplyBeamLimits, imtAasGenerateBeamSet,
%             imtAasDefaultParams.

    if nargin < 1 || isempty(deployment)
        deployment = 'macroUrban';
    end
    if nargin < 2 || isempty(params)
        params = imtAasDefaultParams();
    end

    if ~(ischar(deployment) || (isstring(deployment) && isscalar(deployment)))
        error('imtAasSingleSectorParams:invalidDeployment', ...
            'deployment must be a char or string scalar.');
    end
    deployment = char(deployment);

    % Steering elevation limits are deployment-dependent: macro sectors
    % cover global theta 90-100 deg ([-10, 0] elevation); micro/small-cell
    % sectors cover 90-120 deg ([-30, 0] elevation).
    switch lower(deployment)
        case 'macrourban'
            bsHeight_m   = 18;
            cellRadius_m = 400;
            elLimitsDeg  = [-10, 0];
            tag          = 'macroUrban';
        case 'macrosuburban'
            bsHeight_m   = 20;
            cellRadius_m = 800;
            elLimitsDeg  = [-10, 0];
            tag          = 'macroSuburban';
        case 'microurban'
            % Micro urban: 6 m BS height. Cell radius derived from the
            % 7 GHz micro density (30 BS/km^2, 1 sector/BS) -> ~180 m
            % area-equivalent radius (confirm with WG; easily overridable).
            bsHeight_m   = 6;
            cellRadius_m = 180;
            elLimitsDeg  = [-30, 0];
            tag          = 'microUrban';
        case 'microsuburban'
            % Micro suburban: 6 m BS height. Cell radius derived from the
            % 7 GHz micro density (10 BS/km^2, 1 sector/BS) -> ~300 m
            % area-equivalent radius (confirm with WG; easily overridable).
            bsHeight_m   = 6;
            cellRadius_m = 300;
            elLimitsDeg  = [-30, 0];
            tag          = 'microSuburban';
        otherwise
            error('imtAasSingleSectorParams:unknownDeployment', ...
                ['Unknown deployment "%s". Supported deployments: ' ...
                 'macroUrban, macroSuburban, microUrban, microSuburban.'], ...
                deployment);
    end

    sector = struct();
    sector.deployment      = tag;
    sector.bsX_m           = 0;
    sector.bsY_m           = 0;
    sector.bsHeight_m      = bsHeight_m;
    sector.ueHeight_m      = 1.5;
    sector.cellRadius_m    = cellRadius_m;
    sector.minUeDistance_m = 35;
    sector.boresightAzDeg  = 0;
    sector.sectorWidthDeg  = 120;
    sector.azLimitsDeg     = [-60, 60];
    sector.elLimitsDeg     = elLimitsDeg;
    sector.params          = params;
end
