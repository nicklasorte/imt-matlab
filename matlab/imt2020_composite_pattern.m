function A_A = imt2020_composite_pattern(azim, elev, azim_i, elev_i, ...
        G_Emax, A_m, SLA_nu, phi_3db, theta_3db, ...
        d_H, d_V, N_H, N_V, rho, k)
%IMT2020_COMPOSITE_PATTERN AAS composite (array) gain pattern.
%
%   A_A = imt2020_composite_pattern(AZIM, ELEV, AZIM_I, ELEV_I, G_EMAX,
%       A_M, SLA_NU, PHI_3DB, THETA_3DB, D_H, D_V, N_H, N_V, RHO, K)
%
%   Implements the composite array pattern of ITU-R Rec. M.2101-0 with the
%   correlation-level parameter rho from 3GPP TR 37.840 sec. 5.4.4.1.4.
%
%   Inputs (degrees / dB / wavelengths):
%       azim, elev     observation angles, same size, any shape
%       azim_i, elev_i pointing direction of beam i (scalars)
%       G_Emax         single-element max gain [dBi]
%       A_m            front-to-back ratio (horizontal) [dB]
%       SLA_nu         side-lobe attenuation (vertical) [dB]
%       phi_3db        horizontal 3 dB beamwidth [deg]
%       theta_3db      vertical   3 dB beamwidth [deg]
%       d_H, d_V       element separation [wavelengths]
%       N_H, N_V       number of elements horizontal / vertical
%       rho            correlation level in [0,1] (default 1)
%       k              multiplication factor (default 12)
%
%   Output:
%       A_A   composite gain [dBi], same size as azim/elev
%
%   Angle conventions (matched to pycraf):
%       phi     = azim
%       theta   = 90 - elev          (internal polar)
%       phi_i   = azim_i             (beam azim)
%       theta_i = -elev_i            (beam tilt; sic, see pycraf comment)
%
%   Equations (M.2101 Annex 1):
%       v_{m,n}   superposition vector for element (m,n):
%       arg(m,n) = 2*pi*( n*d_V*cos(theta) + m*d_H*sin(theta)*sin(phi)
%                        + n*d_V*sin(theta_i) - m*d_H*cos(theta_i)*sin(phi_i) )
%       AF       = | sum_{m,n} exp(j*arg(m,n)) |^2 / (N_H*N_V)
%       A_A      = A_E + 10*log10( 1 + rho*(AF - 1) )

    if nargin < 14 || isempty(rho); rho = 1; end
    if nargin < 15 || isempty(k);   k   = 12; end

    validateattributes(azim_i, {'numeric'}, {'real','scalar','>=',-180,'<=',180});
    validateattributes(elev_i, {'numeric'}, {'real','scalar','>=', -90,'<=', 90});
    validateattributes(rho,    {'numeric'}, {'real','scalar','>=',0,'<=',1});
    validateattributes(N_H,    {'numeric'}, {'integer','positive','scalar'});
    validateattributes(N_V,    {'numeric'}, {'integer','positive','scalar'});

    A_E = imt2020_single_element_pattern( ...
        azim, elev, G_Emax, A_m, SLA_nu, phi_3db, theta_3db, k);

    % internal coordinates
    phi     = azim;
    theta   = 90 - elev;
    phi_i   = azim_i;
    theta_i = -elev_i;

    % radians for trig
    th_r    = deg2rad(theta);
    ph_r    = deg2rad(phi);
    thi_r   = deg2rad(theta_i);
    phi_r   = deg2rad(phi_i);

    % per-pixel quantities (broadcast over input grid)
    a = d_V .* cos(th_r);                        % n-axis observation term
    b = d_H .* sin(th_r) .* sin(ph_r);           % m-axis observation term

    % beam-pointing offsets (scalars)
    a_i = d_V .* sin(thi_r);
    b_i = d_H .* cos(thi_r) .* sin(phi_r);

    % indices m=0..N_H-1, n=0..N_V-1
    m = reshape(0:(N_H-1), [1 1 N_H 1]);
    n = reshape(0:(N_V-1), [1 1 1 N_V]);

    % phase argument tensor: size [size(a), N_H, N_V]
    arg = 2*pi .* ( n.*a + m.*b + n.*a_i - m.*b_i );

    % coherent sum over m, n; AF = |sum|^2 / (N_H*N_V)
    S    = sum(sum(exp(1j .* arg), 4), 3);
    AF   = (real(S).^2 + imag(S).^2) ./ (double(N_H) .* double(N_V));

    A_A  = A_E + 10 .* log10(1 + rho .* (AF - 1));
end
