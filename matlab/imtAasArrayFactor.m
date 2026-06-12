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
%   Optional Type I DFT / PMI beam codebook (PARAMS.beamCodebook):
%   When PARAMS carries a non-empty beamCodebook struct with .enable =
%   true (set by runR23AasEirpCdfGrid via opts.beamSelection =
%   'codebook'), the panel-frame steering spatial frequencies are snapped
%   to the nearest bin of a 3GPP TS 38.214 v19.2.0 Sec. 5.2.2.2.1 Type I
%   single-panel oversampled 2-D DFT beam grid (codebookMode 1) before
%   the array factor is evaluated:
%       a_i -> round(a_i * O_V*N_V) / (O_V*N_V)   (vertical,   i1,2 = m)
%       b_i -> round(b_i * O_H*N_H) / (O_H*N_H)   (horizontal, i1,1 = l)
%   Because this function already operates in the PANEL frame (after the
%   mechanical-tilt transform in imtAasCompositeGain), the codebook is
%   correctly fixed to the array, as on real hardware -- it is NOT
%   re-snapped per observation angle. Only the steering (a_i, b_i) is
%   quantized; the fixed sub-array downtilt phase term is untouched.
%   Notes (keep these in mind before "fixing" anything here):
%   1) The Type I beam direction is set entirely by the PMI pair (l, m)
%      -- a per-dimension oversampled DFT, Kronecker-combined. Nearest-
%      bin snapping IS the max-gain Type I beam: the AF factors into
%      per-dimension Dirichlet kernels and the grid spacing 1/(O*N) is
%      finer than the 1/N main-lobe half-width, so gain is monotone in
%      distance-to-peak within a grid cell (test_imt_aas_codebook T2
%      verifies nearest == exhaustive max-gain search).
%   2) The rank-1 co-phase phi_n = e^{j*pi*n/2} co-phases the two
%      POLARIZATIONS only; it does not change the single-polarization
%      spatial array-factor power. The EIRP envelope here is built from
%      |AF|^2 of one polarization, so phi_n is an EIRP no-op and is
%      deliberately NOT applied -- do not add a polarization term later.
%   3) Honest framing: literal TS 38.214 port configurations stop at 32
%      CSI-RS ports (Table 5.2.2.2.1-2), whereas the R23 sub-array grid
%      is N_H x N_V = 16 x 8 = 128 per polarization. This is the Type I
%      single-panel CONSTRUCTION (oversampled 2-D DFT, default O = 4,
%      codebookMode 1) generalized to the actual N_H x N_V sub-array
%      grid read from PARAMS -- not a standardized PMI table lookup.
%      Model N_H (horizontal, b_i) / N_V (vertical, a_i) map to the two
%      3GPP DFT dimensions N1/N2; the labelling is immaterial since the
%      construction is the Kronecker product of two per-dimension DFTs.
%   4) Aliasing: R23 uses d_V = 2.1 lambda > 0.5 lambda, so the vertical
%      DFT grid has period 1/d_V < 1 in sin-space -- grating / aliased
%      lobes are PHYSICALLY REAL for this geometry. Indices use
%      mod(., O*N) arithmetic (see imt_aas_codebook_select, which also
%      reports an isAliased flag); the lobes are not suppressed.
%   With beamCodebook absent / empty / enable = false this function is
%   byte-identical to the historical (ideal continuous steering) path.
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
%   Optional PARAMS fields:
%       beamCodebook    struct('enable', true/false, 'oversampleH', O_H,
%                       'oversampleV', O_V); absent / [] / enable = false
%                       is the byte-identical no-op (see above).
%
%   Errors:
%       imtAasArrayFactor:invalidSteer          for non-finite or out-of-
%                                               range steering angles.
%       imtAasArrayFactor:invalidBeamCodebook   malformed
%                                               params.beamCodebook.
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

    % --- optional Type I DFT (PMI) codebook quantization ---------------
    % Snap the panel-frame steering to the nearest oversampled-DFT bin
    % (see the header notes). Byte-identical no-op when disabled. Only
    % the steering (a_i, b_i) is quantized -- the fixed sub-array
    % downtilt phase term below is left untouched.
    cbk = resolveBeamCodebook(params, 'imtAasArrayFactor');
    if cbk.enable
        MV  = cbk.oversampleV .* double(N_V);
        MH  = cbk.oversampleH .* double(N_H);
        a_i = round(a_i .* MV) ./ MV;   % vertical steering -> nearest DFT bin
        b_i = round(b_i .* MH) ./ MH;   % horizontal steering -> nearest DFT bin
    end

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

function cb = resolveBeamCodebook(params, funcName)
%RESOLVEBEAMCODEBOOK Resolve the optional params.beamCodebook field.
%   Returns struct('enable', false, ...) when PARAMS has no non-empty
%   beamCodebook field, or when beamCodebook.enable is absent / empty /
%   false -- the byte-identical no-op default. Otherwise validates and
%   returns enable / oversampleH / oversampleV (oversample default 4,
%   the TS 38.214 Table 5.2.2.2.1-2 default).
    cb = struct('enable', false, 'oversampleH', [], 'oversampleV', []);
    if ~isstruct(params) || ~isfield(params, 'beamCodebook') || ...
            isempty(params.beamCodebook)
        return;
    end
    raw = params.beamCodebook;
    if ~(isstruct(raw) && isscalar(raw))
        error([funcName ':invalidBeamCodebook'], ...
            'params.beamCodebook must be a scalar struct (or [] / absent).');
    end
    if ~isfield(raw, 'enable') || isempty(raw.enable)
        return;
    end
    en = raw.enable;
    if ~((islogical(en) || isnumeric(en)) && isscalar(en))
        error([funcName ':invalidBeamCodebook'], ...
            'params.beamCodebook.enable must be a logical scalar.');
    end
    if ~logical(en)
        return;
    end
    cb.enable      = true;
    cb.oversampleH = readCodebookOversample(raw, 'oversampleH', funcName);
    cb.oversampleV = readCodebookOversample(raw, 'oversampleV', funcName);
end

function o = readCodebookOversample(raw, name, funcName)
%READCODEBOOKOVERSAMPLE Positive-integer oversampling factor, default 4.
    o = 4;
    if isfield(raw, name) && ~isempty(raw.(name))
        o = raw.(name);
    end
    if ~(isnumeric(o) && isreal(o) && isscalar(o) && isfinite(o) && ...
            o >= 1 && o == floor(o))
        error([funcName ':invalidBeamCodebook'], ...
            'params.beamCodebook.%s must be a positive integer scalar.', name);
    end
    o = double(o);
end

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
