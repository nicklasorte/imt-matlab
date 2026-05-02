function A_E = imt2020_single_element_pattern(azim, elev, ...
        G_Emax, A_m, SLA_nu, phi_3db, theta_3db, k)
%IMT2020_SINGLE_ELEMENT_PATTERN Single AAS antenna element gain pattern.
%
%   A_E = imt2020_single_element_pattern(AZIM, ELEV, G_EMAX, A_M, SLA_NU,
%                                        PHI_3DB, THETA_3DB, K)
%
%   Implements the single-element antenna pattern of ITU-R Rec. M.2101-0
%   (Table 4 / Annex 1), as also used in 3GPP TR 37.840 sec. 5.4.4.
%
%   Inputs (all in degrees / dB / dBi unless noted):
%       azim       Azimuth, -180..180 [deg], any size
%       elev       Elevation, -90..90 [deg], same size as azim
%       G_Emax     Single-element max gain [dBi]
%       A_m        Front-to-back ratio (horizontal) [dB], >= 0
%       SLA_nu     Side-lobe attenuation (vertical) [dB], >= 0
%       phi_3db    Horizontal 3 dB beamwidth [deg]
%       theta_3db  Vertical 3 dB beamwidth [deg]
%       k          Multiplication factor (default 12, M.2101)
%
%   Output:
%       A_E        Single element gain pattern [dBi], same shape as azim
%
%   Angle conventions (matched to pycraf/M.2101):
%       external azim  in [-180, 180] deg
%       external elev  in [ -90,  90] deg
%       internal theta = 90 - elev
%
%   Equations (M.2101 Table 4):
%       A_EH(phi)   = -min( k * (phi/phi_3db)^2,            A_m   )
%       A_EV(theta) = -min( k * ((theta-90)/theta_3db)^2,   SLA_nu)
%       A_E         = G_Emax - min( -(A_EH + A_EV), A_m )

    if nargin < 8 || isempty(k); k = 12; end

    validateattributes(azim, {'numeric'}, {'real','>=',-180,'<=',180});
    validateattributes(elev, {'numeric'}, {'real','>=', -90,'<=', 90});
    validateattributes(A_m,        {'numeric'}, {'real','>=',0,'scalar'});
    validateattributes(SLA_nu,     {'numeric'}, {'real','>=',0,'scalar'});
    validateattributes(phi_3db,    {'numeric'}, {'real','>',0,'scalar'});
    validateattributes(theta_3db,  {'numeric'}, {'real','>',0,'scalar'});

    phi   = azim;
    theta = 90 - elev;

    A_EH = -min(k .* (phi   ./ phi_3db  ).^2, A_m   );
    A_EV = -min(k .* ((theta - 90) ./ theta_3db).^2, SLA_nu);

    loss = min(-(A_EH + A_EV), A_m);  % combined loss capped at A_m
    A_E  = G_Emax - loss;
end
