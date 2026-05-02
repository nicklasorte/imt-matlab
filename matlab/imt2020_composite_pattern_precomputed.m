function A_A = imt2020_composite_pattern_precomputed(grid, azim_i, elev_i, rho, k)
%IMT2020_COMPOSITE_PATTERN_PRECOMPUTED Vectorized AAS composite pattern.
%
%   A_A = imt2020_composite_pattern_precomputed(GRID, AZIM_I, ELEV_I)
%   A_A = imt2020_composite_pattern_precomputed(GRID, AZIM_I, ELEV_I, RHO, K)
%
%   Mathematically equivalent to imt2020_composite_pattern.m but reuses a
%   precomputed observation grid (see prepare_aas_observation_grid). RHO
%   defaults to GRID.rho, K defaults to GRID.k.
%
%   Optimization summary
%   --------------------
%   The exponent of the (m,n) phase tensor in the reference pattern is
%       arg(i,j,m,n) = 2*pi * ( n*(a(i,j) + a_i) + m*(b(i,j) - b_i) ),
%   where a, b are functions of the (azim, elev) grid only and a_i, b_i
%   are scalar functions of the beam pointing only. The (m,n) double sum
%   therefore factors as
%       S(i,j) = (sum_n V_grid(i,j,n) * v_beam(n))
%              * (sum_m H_grid(i,j,m) * h_beam(m)),
%   so we only have to evaluate two complex matrix-vector products per
%   draw instead of building a full [Naz x Nel x N_H x N_V] tensor.
%
%   The reference single-element pattern is independent of beam pointing
%   and is precomputed in GRID.A_E. We rebuild it only if K differs from
%   the value baked into GRID.

    if nargin < 4 || isempty(rho); rho = grid.rho; end
    if nargin < 5 || isempty(k);   k   = grid.k;   end

    validateattributes(azim_i, {'numeric'}, {'real','scalar','>=',-180,'<=',180});
    validateattributes(elev_i, {'numeric'}, {'real','scalar','>=', -90,'<=', 90});
    validateattributes(rho,    {'numeric'}, {'real','scalar','>=',0,'<=',1});

    % Beam-pointing scalars match imt2020_composite_pattern.m exactly.
    phi_i   = azim_i;
    theta_i = -elev_i;
    thi_r   = deg2rad(theta_i);
    phi_r   = deg2rad(phi_i);
    a_i     = grid.d_V .* sin(thi_r);
    b_i     = grid.d_H .* cos(thi_r) .* sin(phi_r);

    two_pi = 2 .* pi;
    % Per-element pointing factors (column vectors).
    eN = exp( 1j .* two_pi .* grid.n_idx .* a_i);   % [N_V x 1]
    eM = exp(-1j .* two_pi .* grid.m_idx .* b_i);   % [N_H x 1]

    % Two complex GEMVs: (Naz*Nel x N_V) * (N_V x 1) and analogous for H.
    Sn = reshape(grid.Vn_flat * eN, grid.Naz, grid.Nel);
    Sm = reshape(grid.Hm_flat * eM, grid.Naz, grid.Nel);

    S  = Sn .* Sm;
    AF = (real(S).^2 + imag(S).^2) ./ (grid.N_H .* grid.N_V);

    if k == grid.k
        A_E = grid.A_E;
    else
        A_E = imt2020_single_element_pattern(grid.AZ, grid.EL, ...
            grid.G_Emax, grid.A_m, grid.SLA_nu, ...
            grid.phi_3db, grid.theta_3db, k);
    end

    A_A = A_E + 10 .* log10(1 + rho .* (AF - 1));
end
