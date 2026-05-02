function elementGainDbi = imtAasElementPattern(azDeg, elDeg, params)
%IMTAASELEMENTPATTERN Single-element gain pattern (M.2101 Table 4).
%
%   ELEMENTGAINDBI = imtAasElementPattern(AZDEG, ELDEG, PARAMS)
%
%   Returns the absolute single-element gain in dBi for the IMT AAS sub-
%   array element evaluated at observation angles (AZDEG, ELDEG). The
%   closed form is the standard separable horizontal+vertical attenuation
%   structure of ITU-R Rec. M.2101-0 Annex 1 / Table 4:
%
%       A_EH(phi)   = -min( k * (phi / phi_3dB)^2,        A_m   )
%       A_EV(elev)  = -min( k * (elev / theta_3dB)^2,     SLA_v )
%       A_E         =  G_Emax  -  min( -(A_EH + A_EV),    A_m   )
%
%   The combined attenuation is capped by A_m (the front-to-back ratio),
%   which provides the side / back-lobe floor.
%
%   Angle convention (panel-local frame):
%       azDeg  azimuth offset from panel boresight, [-180, 180] deg
%              (0 deg = pointing along the panel boresight).
%       elDeg  elevation offset from horizon,       [ -90,  90] deg
%              (0 deg = horizon, positive = up).
%       Internally we use the polar angle theta = 90 - elDeg, so that
%       M.2101's `(theta - 90)` term equals `-elDeg`. Squaring removes the
%       sign; the closed form below uses elDeg directly.
%
%   Inputs:
%       azDeg, elDeg   same-shape real arrays. Scalars are accepted.
%       params         struct from imtAasDefaultParams (or a compatible
%                      override). Required fields: elementGainDbi,
%                      hBeamwidthDeg, vBeamwidthDeg, frontToBackDb,
%                      sideLobeAttenuationDb. Optional: k (default 12).
%
%   Output:
%       elementGainDbi single-element absolute gain [dBi], same shape as
%                      azDeg / elDeg.

    if nargin < 3 || isempty(params)
        params = imtAasDefaultParams();
    end
    if ~isequal(size(azDeg), size(elDeg))
        error('imtAasElementPattern:sizeMismatch', ...
            ['azDeg (size %s) and elDeg (size %s) must be the same ' ...
             'size.'], mat2str(size(azDeg)), mat2str(size(elDeg)));
    end
    if any(~isfinite(azDeg(:))) || any(~isfinite(elDeg(:)))
        error('imtAasElementPattern:nonFiniteInput', ...
            'azDeg and elDeg must be finite.');
    end

    G_Emax    = params.elementGainDbi;
    A_m       = params.frontToBackDb;
    SLA_nu    = params.sideLobeAttenuationDb;
    phi_3db   = params.hBeamwidthDeg;
    theta_3db = params.vBeamwidthDeg;
    if isfield(params, 'k') && ~isempty(params.k)
        kFac = params.k;
    else
        kFac = 12;
    end

    A_EH = -min(kFac .* (azDeg ./ phi_3db).^2,  A_m   );
    A_EV = -min(kFac .* (elDeg ./ theta_3db).^2, SLA_nu);

    loss = min(-(A_EH + A_EV), A_m);
    elementGainDbi = G_Emax - loss;
end
