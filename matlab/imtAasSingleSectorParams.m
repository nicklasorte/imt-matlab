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
%                       'macroUrban'    bsHeight = 18 m,  cellRadius = 400 m
%                       'macroSuburban' bsHeight = 20 m,  cellRadius = 800 m
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
%       elLimitsDeg        steering elevation limits [-10, 0] deg
%                          (R23 vertical coverage 90-100 deg global theta
%                          maps to elevation [-10, 0] in this repo's
%                          (az, el) convention)
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

    switch lower(deployment)
        case 'macrourban'
            bsHeight_m   = 18;
            cellRadius_m = 400;
            tag          = 'macroUrban';
        case 'macrosuburban'
            bsHeight_m   = 20;
            cellRadius_m = 800;
            tag          = 'macroSuburban';
        otherwise
            error('imtAasSingleSectorParams:unknownDeployment', ...
                ['Unknown deployment "%s". Supported deployments: ' ...
                 'macroUrban, macroSuburban.'], deployment);
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
    sector.elLimitsDeg     = [-10,  0];
    sector.params          = params;
end
