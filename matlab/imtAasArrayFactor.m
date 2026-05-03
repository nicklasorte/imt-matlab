function arrayGainDbi = imtAasArrayFactor(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, params)
%IMTAASARRAYFACTOR Panel-frame array + sub-array factor in dB for the AAS.
%
%   ARRAYGAINDBI = imtAasArrayFactor(AZGRIDDEG, ELGRIDDEG, ...
%                                    STEERAZDEG, STEERELDEG, PARAMS)
%
%   Computes the array-factor contribution (in dB) for the IMT R23 AAS at
%   observation grid (AZGRIDDEG, ELGRIDDEG) when the array is electroni-
%   cally steered to (STEERAZDEG, STEERELDEG). Includes:
%       - the horizontal/vertical N_H x N_V sub-array array factor with
%         electronic steering (M.2101 / 3GPP TR 37.840 closed form),
%       - the L-element vertical sub-array factor with the fixed
%         electrical sub-array downtilt PARAMS.subarrayDowntiltDeg.
%
%   Mechanical downtilt is NOT applied here (this is panel-frame math); it
%   is handled by imtAasCompositeGain, which rotates the observation and
%   steering directions into the panel frame before calling this function.
%
%   The dB-domain combination with the single-element gain is additive:
%       compositeGain = imtAasElementPattern + imtAasArrayFactor   [dBi]
%
%   At the perfect steered direction in panel frame ARRAYGAINDBI peaks at
%       10*log10(1 + rho * (N_H * N_V - 1)) + 10*log10(L)
%   which for the R23 defaults (rho = 1, N_H = 16, N_V = 8, L = 3) is
%   ~25.84 dB. With the 6.4 dBi element gain that puts the composite peak
%   at ~32.24 dBi (matching the R23 reference peak gain of 32.2 dBi).
%
%   Angle conventions (panel local frame):
%       azGridDeg  azimuth from panel boresight, [-180, 180] deg
%       elGridDeg  elevation from horizon,       [ -90,  90] deg
%       Internally phi = az, theta = 90 - el, phi_i = steerAz,
%       theta_i = -steerEl (matching imt2020_composite_pattern).
%
%   Input handling (via imtAasNormalizeGrid):
%       both scalars                -> output is a scalar
%       both vectors                -> output is Naz x Nel (ndgrid'd)
%       both 2-D arrays, same size  -> output is element-wise on that grid
%
%   Required PARAMS fields:
%       numColumns, numRows, hSpacingWavelengths,
%       vSubarraySpacingWavelengths, numElementsPerSubarray,
%       elementSpacingWavelengths, subarrayDowntiltDeg, rho.
%
%   Errors:
%       imtAasArrayFactor:invalidSteer          for non-finite or out-of-
%                                               range steering angles.
%       imtAas:gridSizeMismatch                 mixed scalar/vector/matrix
%                                               or mismatched 2-D grids
%                                               (raised by the normalizer).

    if nargin < 5 || isempty(params)
        params = imtAasDefaultParams();
    end

    validateSteerAngle(steerAzDeg, -180, 180, 'steerAzDeg');
    validateSteerAngle(steerElDeg,  -90,  90, 'steerElDeg');

    [AZ, EL] = imtAasNormalizeGrid(azGridDeg, elGridDeg);

    N_H        = params.numColumns;
    N_V        = params.numRows;
    d_H        = params.hSpacingWavelengths;
    d_V        = params.vSubarraySpacingWavelengths;
    rho        = params.rho;
    L          = params.numElementsPerSubarray;
    d_sub      = params.elementSpacingWavelengths;
    subTiltDeg = params.subarrayDowntiltDeg;

    validateattributes(N_H, {'numeric'}, {'integer','positive','scalar'}, ...
        mfilename, 'params.numColumns');
    validateattributes(N_V, {'numeric'}, {'integer','positive','scalar'}, ...
        mfilename, 'params.numRows');
    validateattributes(L,   {'numeric'}, {'integer','positive','scalar'}, ...
        mfilename, 'params.numElementsPerSubarray');

    % --- internal (M.2101) angles -------------------------------------
    phi     = AZ;
    theta   = 90 - EL;
    phi_i   = steerAzDeg;
    theta_i = -steerElDeg;

    th_r  = deg2rad(theta);
    ph_r  = deg2rad(phi);
    thi_r = deg2rad(theta_i);
    phi_r = deg2rad(phi_i);

    % per-grid-cell quantities (scalar / 2-D friendly)
    a   = d_V .* cos(th_r);
    b   = d_H .* sin(th_r) .* sin(ph_r);
    a_i = d_V .* sin(thi_r);
    b_i = d_H .* cos(thi_r) .* sin(phi_r);

    % --- N_H x N_V outer array factor ---------------------------------
    %   AF = | sum_{m=0..N_H-1} sum_{n=0..N_V-1} exp(j*arg(m,n)) |^2 / (N_H*N_V)
    %   arg(m,n) = 2*pi*( n*d_V*cos(th)
    %                   + m*d_H*sin(th)*sin(ph)
    %                   + n*d_V*sin(th_i)
    %                   - m*d_H*cos(th_i)*sin(ph_i) )
    m = reshape(0:(N_H - 1), [1 1 N_H 1]);
    n = reshape(0:(N_V - 1), [1 1 1 N_V]);

    arg = 2*pi .* (n .* a + m .* b + n .* a_i - m .* b_i);
    S   = sum(sum(exp(1j .* arg), 4), 3);
    AF  = (real(S).^2 + imag(S).^2) ./ (double(N_H) .* double(N_V));

    % Clamp to eps before log10 so perfect array nulls give a large finite
    % negative dB value rather than -Inf (which propagates through the grid).
    outerDb = 10 .* log10(max(1 + rho .* (AF - 1), eps));

    % --- L-element vertical sub-array factor (fixed downtilt) ---------
    %   AFsub = | sum_{l=0..L-1} exp(j*2*pi*l*d_sub*( cos(th) + sin(th_sub) )) |^2 / L
    if L == 1
        subDb = zeros(size(outerDb));
    else
        thiSub_r  = deg2rad(subTiltDeg);
        sub_phase = d_sub .* (cos(th_r) + sin(thiSub_r));     % size of AZ
        l_axis    = reshape(0:(L - 1), [1 1 L]);
        argSub    = 2*pi .* l_axis .* sub_phase;              % broadcast
        Ssub      = sum(exp(1j .* argSub), 3);
        AFsub     = (real(Ssub).^2 + imag(Ssub).^2) ./ double(L);
        subDb     = 10 .* log10(max(AFsub, eps));
    end

    arrayGainDbi = outerDb + subDb;
end

% =====================================================================

function validateSteerAngle(value, lo, hi, name)
%VALIDATESTEERANGLE Strict scalar / finite / range check for steering.
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        error('imtAasArrayFactor:invalidSteer', ...
            '%s must be a real finite scalar.', name);
    end
    if value < lo || value > hi
        error('imtAasArrayFactor:invalidSteer', ...
            '%s = %g is outside the supported range [%g, %g] deg.', ...
            name, value, lo, hi);
    end
end
