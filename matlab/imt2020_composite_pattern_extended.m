function [gain_dBi, rawGain_dBi, rawPeak_dBi] = ...
        imt2020_composite_pattern_extended(azim, elev, azim_i, elev_i, cfg)
%IMT2020_COMPOSITE_PATTERN_EXTENDED Extended AAS composite pattern.
%
%   [GAIN, RAWGAIN, RAWPEAK] = imt2020_composite_pattern_extended( ...
%                                  AZIM, ELEV, AZIM_I, ELEV_I, CFG)
%
%   Implements the R23 / IMT-2020 "Extended AAS Model" composite gain
%   pattern. In addition to the standard horizontal/vertical array
%   factor over an N_H x N_V grid of sub-arrays, each cell of the grid
%   contains a fixed-downtilt vertical sub-array of L elements with
%   internal spacing CFG.subarray.d_V (wavelengths) and a fixed
%   electronic downtilt CFG.subarray.downtiltDeg.
%
%   Mechanical downtilt CFG.mechanicalDowntiltDeg is applied as a y-axis
%   rotation of the observation and beam directions before the pattern
%   is evaluated, via imt_aas_mechanical_tilt_transform. The whole
%   antenna math therefore happens in the panel local frame.
%
%   Inputs (degrees / dB / wavelengths):
%       azim, elev     observation angles (any same-shape array, up to
%                      2-D, matching the existing repo convention)
%       azim_i, elev_i scalar beam-pointing direction in the external
%                      sector frame
%       cfg            struct with at least the fields documented in
%                      imt_r23_aas_defaults; the relevant ones are:
%                          G_Emax, A_m, SLA_nu, phi_3db, theta_3db, k
%                          d_H, d_V, N_H, N_V, rho
%                          mechanicalDowntiltDeg
%                          subarray.numVerticalElements (= L)
%                          subarray.d_V                 (= dSub)
%                          subarray.downtiltDeg         (= thetaSubDeg)
%                          peakGain_dBi
%                          normalizeToPeakGain (logical, default true)
%
%   Outputs:
%       gain_dBi      composite gain [dBi], same size as azim/elev
%       rawGain_dBi   un-normalized extended gain [dBi]
%       rawPeak_dBi   raw gain evaluated at the (panel-frame) beam
%                     direction; the value used to renormalize when
%                     CFG.normalizeToPeakGain is true.
%
%   Math in the panel frame:
%       phi      = azPanel
%       theta    = 90 - elPanel
%       phi_i    = azPanel_i
%       theta_i  = -elPanel_i
%
%   Single-element gain  A_E(phi, theta) from
%       imt2020_single_element_pattern (M.2101 Table 4).
%
%   N_H x N_V sub-array array factor (M.2101 / 3GPP TR 37.840):
%       arg(m,n) = 2*pi * ( n*d_V*cos(theta) + m*d_H*sin(theta)*sin(phi)
%                         + n*d_V*sin(theta_i)
%                         - m*d_H*cos(theta_i)*sin(phi_i) )
%       AF       = | sum_{m,n} exp(j*arg(m,n)) |^2 / (N_H * N_V)
%
%   Vertical sub-array factor (L elements, fixed downtilt thetaSub):
%       argSub(l) = 2*pi * l * dSub * ( cos(theta) + sin(thetaSub) )
%       AFsub     = | sum_l exp(j*argSub(l)) |^2 / L
%
%   Combined raw gain:
%       rawGain = A_E + 10*log10( 1 + rho*(AF - 1) ) + 10*log10(AFsub)
%
%   When normalizeToPeakGain is true, gain = rawGain - rawPeak +
%   peakGain_dBi so the main-beam peak equals cfg.peakGain_dBi exactly.

    if ~isfield(cfg, 'mechanicalDowntiltDeg') || isempty(cfg.mechanicalDowntiltDeg)
        cfg.mechanicalDowntiltDeg = 0;
    end
    if ~isfield(cfg, 'rho') || isempty(cfg.rho); cfg.rho = 1; end
    if ~isfield(cfg, 'k')   || isempty(cfg.k);   cfg.k   = 12; end
    if ~isfield(cfg, 'normalizeToPeakGain') || isempty(cfg.normalizeToPeakGain)
        cfg.normalizeToPeakGain = true;
    end
    if ~isfield(cfg, 'peakGain_dBi') || isempty(cfg.peakGain_dBi)
        cfg.peakGain_dBi = 0;
    end
    if ~isfield(cfg, 'subarray') || ~isstruct(cfg.subarray)
        cfg.subarray = struct();
    end
    if ~isfield(cfg.subarray, 'numVerticalElements') || ...
            isempty(cfg.subarray.numVerticalElements)
        cfg.subarray.numVerticalElements = 1;
    end
    if ~isfield(cfg.subarray, 'd_V') || isempty(cfg.subarray.d_V)
        cfg.subarray.d_V = 0;
    end
    if ~isfield(cfg.subarray, 'downtiltDeg') || isempty(cfg.subarray.downtiltDeg)
        cfg.subarray.downtiltDeg = 0;
    end

    validateattributes(azim_i, {'numeric'}, ...
        {'real','scalar','finite','>=',-180,'<=',180});
    validateattributes(elev_i, {'numeric'}, ...
        {'real','scalar','finite','>=', -90,'<=', 90});
    validateattributes(cfg.N_H, {'numeric'}, {'integer','positive','scalar'});
    validateattributes(cfg.N_V, {'numeric'}, {'integer','positive','scalar'});
    validateattributes(cfg.subarray.numVerticalElements, {'numeric'}, ...
        {'integer','positive','scalar'});

    tilt = cfg.mechanicalDowntiltDeg;

    % --- map observation + beam directions into panel frame ----------
    [azP,   elP  ] = imt_aas_mechanical_tilt_transform(azim,   elev,   tilt);
    [azP_i, elP_i] = imt_aas_mechanical_tilt_transform(azim_i, elev_i, tilt);

    % evaluate the raw extended gain at the requested grid ...
    rawGain_dBi = evalRawExtended(azP, elP, azP_i, elP_i, cfg);

    % ... and at the panel-frame beam direction (a scalar)
    rawPeak_dBi = evalRawExtended(azP_i, elP_i, azP_i, elP_i, cfg);

    if cfg.normalizeToPeakGain
        gain_dBi = rawGain_dBi - rawPeak_dBi + cfg.peakGain_dBi;
    else
        gain_dBi = rawGain_dBi;
    end
end

% =====================================================================

function rawGain_dBi = evalRawExtended(azP, elP, azP_i, elP_i, cfg)
%EVALRAWEXTENDED Raw extended composite gain in the panel frame.
%
% Inputs are already in the panel frame.

    % single-element gain (panel frame)
    A_E = imt2020_single_element_pattern(azP, elP, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, cfg.k);

    % internal angles, matching imt2020_composite_pattern
    phi     = azP;
    theta   = 90 - elP;
    phi_i   = azP_i;
    theta_i = -elP_i;

    th_r  = deg2rad(theta);
    ph_r  = deg2rad(phi);
    thi_r = deg2rad(theta_i);
    phi_r = deg2rad(phi_i);

    % --- N_H x N_V sub-array array factor ---------------------------
    a   = cfg.d_V .* cos(th_r);
    b   = cfg.d_H .* sin(th_r) .* sin(ph_r);
    a_i = cfg.d_V .* sin(thi_r);
    b_i = cfg.d_H .* cos(thi_r) .* sin(phi_r);

    m = reshape(0:(cfg.N_H - 1), [1 1 cfg.N_H 1]);
    n = reshape(0:(cfg.N_V - 1), [1 1 1 cfg.N_V]);

    arg = 2*pi .* ( n.*a + m.*b + n.*a_i - m.*b_i );
    S   = sum(sum(exp(1j .* arg), 4), 3);
    AF  = (real(S).^2 + imag(S).^2) ./ (double(cfg.N_H) .* double(cfg.N_V));

    % --- vertical sub-array factor (L elements, fixed downtilt) ----
    L          = cfg.subarray.numVerticalElements;
    dSub       = cfg.subarray.d_V;
    thetaSub   = cfg.subarray.downtiltDeg;
    thiSub_r   = deg2rad(thetaSub);

    if L == 1
        % Degenerate sub-array: single element, no extra term.
        sub_term_dB = 0;
    else
        sub_phase = dSub .* cos(th_r) + dSub .* sin(thiSub_r);
        l_idx     = reshape(0:(L - 1), [1 1 1 1 L]);
        arg_sub   = 2*pi .* l_idx .* sub_phase;
        Ssub      = sum(exp(1j .* arg_sub), 5);
        AFsub     = (real(Ssub).^2 + imag(Ssub).^2) ./ double(L);
        sub_term_dB = 10 .* log10(max(AFsub, eps));
    end

    % --- combine -----------------------------------------------------
    % Clamp to eps before log10 so perfect array nulls give a large finite
    % negative dB value rather than -Inf.
    rawGain_dBi = A_E ...
        + 10 .* log10(max(1 + cfg.rho .* (AF - 1), eps)) ...
        + sub_term_dB;
end
