function grid = prepare_aas_observation_grid(azGrid, elGrid, cfg)
%PREPARE_AAS_OBSERVATION_GRID Precompute fixed AZ/EL grid quantities for the
%   M.2101 composite array pattern hot path.
%
%   GRID = prepare_aas_observation_grid(AZ_GRID, EL_GRID, CFG)
%
%   Builds the per-grid trigonometric and per-element complex tensors used
%   by imt2020_composite_pattern_precomputed.m. None of the cached terms
%   depend on the beam pointing, so the Monte Carlo loop only has to
%   evaluate per-draw scalar exponentials and two complex matrix-vector
%   products per beam.
%
%   CFG fields (subset of imt_aas_bs_eirp's CFG):
%       G_Emax, A_m, SLA_nu, phi_3db, theta_3db,
%       d_H, d_V, N_H, N_V, rho (default 1), k (default 12)
%
%   The returned GRID struct contains:
%       .azGrid, .elGrid          input vectors mirrored
%       .AZ, .EL                  ndgrid output, both [Naz x Nel]
%       .Naz, .Nel
%       .cosTh, .sinTh, .sinPh    cached trig of the internal angles
%       .a, .b                    grid observation phase terms
%                                 a = d_V*cos(theta), b = d_H*sin(theta)*sin(phi)
%       .m_idx, .n_idx            element indices [N_H x 1] / [N_V x 1]
%       .Hm                       [Naz x Nel x N_H] complex grid exp(j2pi m b)
%       .Vn                       [Naz x Nel x N_V] complex grid exp(j2pi n a)
%       .Hm_flat                  reshape of Hm to [Naz*Nel x N_H]
%       .Vn_flat                  reshape of Vn to [Naz*Nel x N_V]
%       .A_E                      precomputed single-element pattern [Naz x Nel]
%       .N_H, .N_V, .d_H, .d_V    array geometry mirrored
%       .G_Emax, .A_m, .SLA_nu,
%       .phi_3db, .theta_3db,
%       .rho, .k                  CFG mirrored
%
%   See also imt2020_composite_pattern_precomputed,
%   run_imt_aas_eirp_monte_carlo.

    if nargin < 3 || ~isstruct(cfg)
        error('prepare_aas_observation_grid:missingCfg', ...
            'CFG struct is required.');
    end
    validateattributes(azGrid, {'numeric'}, {'real','vector'});
    validateattributes(elGrid, {'numeric'}, {'real','vector'});

    rho = getf(cfg, 'rho', 1);
    k   = getf(cfg, 'k',   12);

    azGrid = azGrid(:).';
    elGrid = elGrid(:).';

    [AZ, EL] = ndgrid(azGrid, elGrid);
    Naz = size(AZ, 1);
    Nel = size(AZ, 2);

    % Internal angles match imt2020_composite_pattern.m exactly. We use
    % deg2rad + cos/sin (rather than cosd/sind) so floating-point ordering
    % is identical to the reference path.
    phi   = AZ;
    theta = 90 - EL;
    th_r  = deg2rad(theta);
    ph_r  = deg2rad(phi);

    cosTh = cos(th_r);
    sinTh = sin(th_r);
    sinPh = sin(ph_r);

    a = cfg.d_V .* cosTh;                 % [Naz Nel]
    b = cfg.d_H .* sinTh .* sinPh;        % [Naz Nel]

    N_H = double(cfg.N_H);
    N_V = double(cfg.N_V);
    m_idx = (0:(N_H - 1)).';              % [N_H x 1]
    n_idx = (0:(N_V - 1)).';              % [N_V x 1]

    two_pi = 2 .* pi;
    % Per-grid complex exponentials. The (m,n) double sum over the [Naz x
    % Nel x N_H x N_V] phase tensor in imt2020_composite_pattern.m is
    % separable because the exponent splits as
    %     n*(a + a_i) + m*(b - b_i).
    % We cache the grid-only halves Vn = exp(j2pi n a) and Hm = exp(j2pi m
    % b) here; the per-draw scalars a_i, b_i become two N-length factor
    % vectors and the (m,n) sum collapses to a product of two GEMVs.
    Hm = exp(1j .* two_pi .* reshape(m_idx, [1 1 N_H]) .* b);
    Vn = exp(1j .* two_pi .* reshape(n_idx, [1 1 N_V]) .* a);

    % The matmul-friendly flat reshapes do not copy data in MATLAB.
    Hm_flat = reshape(Hm, Naz * Nel, N_H);
    Vn_flat = reshape(Vn, Naz * Nel, N_V);

    A_E = imt2020_single_element_pattern(AZ, EL, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, k);

    grid = struct();
    grid.azGrid    = azGrid;
    grid.elGrid    = elGrid;
    grid.AZ        = AZ;
    grid.EL        = EL;
    grid.Naz       = Naz;
    grid.Nel       = Nel;
    grid.cosTh     = cosTh;
    grid.sinTh     = sinTh;
    grid.sinPh     = sinPh;
    grid.a         = a;
    grid.b         = b;
    grid.m_idx     = m_idx;
    grid.n_idx     = n_idx;
    grid.N_H       = N_H;
    grid.N_V       = N_V;
    grid.d_H       = cfg.d_H;
    grid.d_V       = cfg.d_V;
    grid.Hm        = Hm;
    grid.Vn        = Vn;
    grid.Hm_flat   = Hm_flat;
    grid.Vn_flat   = Vn_flat;
    grid.A_E       = A_E;
    grid.G_Emax    = cfg.G_Emax;
    grid.A_m       = cfg.A_m;
    grid.SLA_nu    = cfg.SLA_nu;
    grid.phi_3db   = cfg.phi_3db;
    grid.theta_3db = cfg.theta_3db;
    grid.rho       = rho;
    grid.k         = k;
end

function v = getf(s, name, defaultVal)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultVal;
    end
end
