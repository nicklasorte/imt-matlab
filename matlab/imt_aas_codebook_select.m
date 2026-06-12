function sel = imt_aas_codebook_select(steerAzDeg, steerElDeg, params, opts)
%IMT_AAS_CODEBOOK_SELECT Type I DFT (PMI) beam selection for a panel-frame direction.
%
%   SEL = imt_aas_codebook_select(STEERAZDEG, STEERELDEG, PARAMS, OPTS)
%
%   Given a PANEL-FRAME steering direction (i.e. after the mechanical-tilt
%   transform -- see imtAasCompositeGain), returns the 3GPP TS 38.214
%   v19.2.0 Sec. 5.2.2.2.1 Type I single-panel (codebookMode 1) DFT beam a
%   real gNB would form from the corresponding reported PMI: the
%   continuous steering spatial frequencies
%
%       a_i = d_V * sin(-elRad)                      (vertical,  N_V dim)
%       b_i = d_H * cos(-elRad) * sin(azRad)         (horizontal, N_H dim)
%
%   (same convention as imtAasArrayFactor) are snapped to the nearest bin
%   of the oversampled DFT grid built by imt_aas_dft_codebook:
%
%       aiQuant = round(a_i * O_V*N_V) / (O_V*N_V)
%       biQuant = round(b_i * O_H*N_H) / (O_H*N_H)
%
%   Nearest-bin snapping IS the max-gain Type I beam: the array factor
%   separates into per-dimension Dirichlet kernels and the grid spacing
%   1/(O*N) is finer than the 1/N main-lobe half-width, so gain is
%   monotone in distance-to-peak within a grid cell. OPTS.mode =
%   'exhaustive' verifies this by brute force.
%
%   The rank-1 co-phase phi_n = e^{j*pi*n/2} co-phases the two
%   polarizations only and does not change the single-polarization
%   spatial array-factor power, so it plays no role in beam selection or
%   in the EIRP envelope (see imt_aas_dft_codebook).
%
%   Inputs:
%       STEERAZDEG  scalar panel-frame steering azimuth, [-180, 180] deg.
%       STEERELDEG  scalar panel-frame steering elevation, [-90, 90] deg.
%       PARAMS      imtAasDefaultParams()-shaped struct (default if [] /
%                   omitted). Reads numColumns, numRows,
%                   hSpacingWavelengths, vSubarraySpacingWavelengths.
%       OPTS        optional struct:
%                       mode         'nearest' (default) or 'exhaustive'.
%                                    'exhaustive' evaluates the exact
%                                    Dirichlet product over all MH x MV
%                                    bins and picks the max-gain beam
%                                    (validation that nearest==exhaustive).
%                       oversampleH  O_H, positive integer (default 4)
%                       oversampleV  O_V, positive integer (default 4)
%
%   Output SEL struct fields:
%       kH, kV            integer PMI indices on the principal branch,
%                         kH = mod(round(b_i*MH), MH) in [0, MH-1] and
%                         kV = mod(round(a_i*MV), MV) in [0, MV-1]
%                         (3GPP i1,1 = l = kH, i1,2 = m = kV).
%       aiQuant, biQuant  snapped spatial frequencies, EXACTLY the values
%                         the imtAasArrayFactor codebook hook uses
%                         (round(.*M)./M, no mod -- the array factor is
%                         invariant to integer frequency shifts).
%       aiIdeal, biIdeal  the continuous (un-snapped) spatial frequencies.
%       scanLossDb        gain drop of the snapped beam vs ideal pointing,
%                         computed from the exact outer array factor
%                         |AF|^2 evaluated at the requested direction
%                         (mathematically the product of the two
%                         per-dimension Dirichlet kernels; independent of
%                         element gain and of PARAMS.rho).
%       effSteerAzDeg,    actual pointing of the chosen beam, principal
%       effSteerElDeg     branch: among the grating-shifted main-lobe
%                         solutions sin(el) = (z - aiQuant)/d_V (z integer,
%                         |sin| <= 1) the one closest to the request, then
%                         the analogous horizontal solve at that elevation.
%       isAliased         logical. True when the snapped frequency's
%                         direct (z = 0) reconstruction is unphysical,
%                         i.e. the snapped sin(angle) magnitude would
%                         exceed 1 in either dimension, so the realized
%                         beam direction is a grating-shifted (aliased)
%                         lobe. Reported, never suppressed: with
%                         d_V = 2.1 lambda > 0.5 lambda the vertical
%                         grating lobes are physically real for this
%                         geometry regardless of this flag.
%       isAliasedV, isAliasedH   per-dimension aliasing flags.
%       mode, oversampleH, oversampleV, MH, MV   bookkeeping.
%
%   See also: imt_aas_dft_codebook, imtAasArrayFactor,
%             imtAasCompositeGain, runR23AasEirpCdfGrid.

    if nargin < 3 || isempty(params)
        params = imtAasDefaultParams();
    end
    if nargin < 4 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('imt_aas_codebook_select:invalidOpts', ...
            'OPTS must be a struct (or [] for defaults).');
    end

    validateSteerAngle(steerAzDeg, -180, 180, 'steerAzDeg');
    validateSteerAngle(steerElDeg,  -90,  90, 'steerElDeg');

    mode = 'nearest';
    if isfield(opts, 'mode') && ~isempty(opts.mode)
        mode = opts.mode;
    end
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('imt_aas_codebook_select:invalidMode', ...
            'opts.mode must be a char/string scalar.');
    end
    mode = lower(mode);
    if ~any(strcmp(mode, {'nearest', 'exhaustive'}))
        error('imt_aas_codebook_select:invalidMode', ...
            'opts.mode must be ''nearest'' or ''exhaustive'' (got ''%s'').', ...
            mode);
    end

    cb = imt_aas_dft_codebook(params, opts);
    N_H = cb.NH;
    N_V = cb.NV;
    MH  = cb.MH;
    MV  = cb.MV;
    d_H = params.hSpacingWavelengths;
    d_V = params.vSubarraySpacingWavelengths;

    % --- continuous steering spatial frequencies ----------------------
    % Bit-identical operations to imtAasArrayFactor (phi_i = steerAz,
    % theta_i = -steerEl).
    thi_r = deg2rad(-steerElDeg);
    phi_r = deg2rad(steerAzDeg);
    a_i = d_V .* sin(thi_r);
    b_i = d_H .* cos(thi_r) .* sin(phi_r);

    % --- observation-side terms AT the requested pointing -------------
    % Same formulas the array factor uses for an observation direction
    % (theta = 90 - el), so the scan loss below mirrors the actual AF.
    th_r = deg2rad(90 - steerElDeg);
    ph_r = deg2rad(steerAzDeg);
    a_obs = d_V .* cos(th_r);
    b_obs = d_H .* sin(th_r) .* sin(ph_r);

    % --- bin selection -------------------------------------------------
    switch mode
        case 'nearest'
            % Identical expression to the imtAasArrayFactor hook.
            kVraw = round(a_i .* MV);
            kHraw = round(b_i .* MH);
        case 'exhaustive'
            % Exact per-dimension Dirichlet product over all MH x MV bins.
            gVDb = dirichletPowerDb(N_V, a_obs + cb.aiBins);
            gHDb = dirichletPowerDb(N_H, b_obs - cb.biBins);
            GDb  = gHDb(:) + gVDb(:).';            % MH x MV [dB]
            [~, lin] = max(GDb(:));
            [iH, iV] = ind2sub([MH, MV], lin);
            kH0 = iH - 1;
            kV0 = iV - 1;
            % Map the principal-branch bin back to the frequency branch
            % nearest the continuous steering (integer shift t = whole
            % DFT periods; the array factor is invariant to t).
            kVraw = kV0 + MV .* round(a_i - kV0 ./ MV);
            kHraw = kH0 + MH .* round(b_i - kH0 ./ MH);
    end

    aiQuant = kVraw ./ MV;
    biQuant = kHraw ./ MH;
    kV = mod(kVraw, MV);
    kH = mod(kHraw, MH);

    % --- scan loss (exact outer AF, independent of element gain / rho) -
    idealDb = outerArrayFactorDb(a_obs, b_obs, a_i,     b_i,     N_H, N_V);
    quantDb = outerArrayFactorDb(a_obs, b_obs, aiQuant, biQuant, N_H, N_V);
    scanLossDb = idealDb - quantDb;

    % --- effective pointing + aliasing ---------------------------------
    % Vertical main lobes of the snapped beam: sin(el) = (z - aiQuant)/d_V
    % for integer z with |sin| <= 1. The direct (z = 0) reconstruction is
    % the nominal beam; if its |sin| > 1 the realized lobe is a grating-
    % shifted (aliased) one.
    sinElTarget = sin(deg2rad(steerElDeg));
    sinEl0      = -aiQuant ./ d_V;
    isAliasedV  = abs(sinEl0) > 1;
    zV = ceil(aiQuant - d_V):floor(aiQuant + d_V);
    sinElCand = (zV - aiQuant) ./ d_V;
    sinElCand = sinElCand(abs(sinElCand) <= 1);
    if isempty(sinElCand)
        sinElEff = max(min(sinEl0, 1), -1);
    else
        [~, iBest] = min(abs(sinElCand - sinElTarget));
        sinElEff = sinElCand(iBest);
    end
    effSteerElDeg = asind(sinElEff);

    % Horizontal main lobes at the effective elevation:
    % sin(az) = (biQuant + z) / (d_H * cos(elEff)).
    sinAzTarget = sin(deg2rad(steerAzDeg));
    denomH = d_H .* max(cosd(effSteerElDeg), eps);
    sinAz0 = biQuant ./ denomH;
    isAliasedH = abs(sinAz0) > 1;
    zH = ceil(-biQuant - denomH):floor(denomH - biQuant);
    sinAzCand = (biQuant + zH) ./ denomH;
    sinAzCand = sinAzCand(abs(sinAzCand) <= 1);
    if isempty(sinAzCand)
        sinAzEff = max(min(sinAz0, 1), -1);
    else
        [~, iBest] = min(abs(sinAzCand - sinAzTarget));
        sinAzEff = sinAzCand(iBest);
    end
    effSteerAzDeg = asind(sinAzEff);

    % --- assemble output ------------------------------------------------
    sel = struct();
    sel.mode          = mode;
    sel.kH            = kH;
    sel.kV            = kV;
    sel.aiQuant       = aiQuant;
    sel.biQuant       = biQuant;
    sel.aiIdeal       = a_i;
    sel.biIdeal       = b_i;
    sel.scanLossDb    = scanLossDb;
    sel.effSteerAzDeg = effSteerAzDeg;
    sel.effSteerElDeg = effSteerElDeg;
    sel.isAliased     = isAliasedV || isAliasedH;
    sel.isAliasedV    = isAliasedV;
    sel.isAliasedH    = isAliasedH;
    sel.oversampleH   = cb.oversampleH;
    sel.oversampleV   = cb.oversampleV;
    sel.MH            = MH;
    sel.MV            = MV;
end

% =====================================================================

function gDb = outerArrayFactorDb(a, b, a_i, b_i, N_H, N_V)
%OUTERARRAYFACTORDB Outer N_H x N_V array factor [dB], rho-independent.
%   Same closed form (and the same MATLAB operations / summation order)
%   as the outer array factor in imtAasArrayFactor, without the rho
%   recombination and without the sub-array downtilt term (the latter
%   depends only on the observation direction, so it cancels in any
%   ideal-vs-snapped gain difference). Mathematically this is the product
%   of the per-dimension Dirichlet kernels
%       |D_NV(a + a_i)|^2 * |D_NH(b - b_i)|^2 / (N_H*N_V).
    m = reshape(0:(N_H - 1), [1 1 N_H 1]);
    n = reshape(0:(N_V - 1), [1 1 1 N_V]);
    arg = 2*pi .* (n .* a + m .* b + n .* a_i - m .* b_i);
    S   = sum(sum(exp(1j .* arg), 4), 3);
    AF  = (real(S).^2 + imag(S).^2) ./ (double(N_H) .* double(N_V));
    gDb = 10 .* log10(max(AF, eps));
end

function pDb = dirichletPowerDb(N, x)
%DIRICHLETPOWERDB |sum_{k=0..N-1} exp(j*2*pi*k*x)|^2 in dB, vectorized in x.
    k = (0:(double(N) - 1)).';
    S = sum(exp(1j .* (2*pi .* (k * x(:).'))), 1);
    p = real(S).^2 + imag(S).^2;
    pDb = reshape(10 .* log10(max(p, eps)), size(x));
end

function validateSteerAngle(value, lo, hi, name)
%VALIDATESTEERANGLE Strict scalar / finite / range check for steering.
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        error('imt_aas_codebook_select:invalidSteer', ...
            '%s must be a real finite scalar.', name);
    end
    if value < lo || value > hi
        error('imt_aas_codebook_select:invalidSteer', ...
            '%s = %g is outside the supported range [%g, %g] deg.', ...
            name, value, lo, hi);
    end
end
