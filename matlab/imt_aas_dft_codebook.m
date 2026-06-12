function cb = imt_aas_dft_codebook(params, opts)
%IMT_AAS_DFT_CODEBOOK 3GPP Type I single-panel DFT (PMI) beam grid for the AAS.
%
%   CB = imt_aas_dft_codebook(PARAMS, OPTS)
%
%   Builds / enumerates the discrete beam-steering codebook used by the
%   'codebook' beam-selection option of the R23 AAS EIRP model: a 2-D
%   oversampled-DFT beam grid over the outer N_H x N_V sub-array layout,
%   following the 3GPP TS 38.214 v19.2.0 Sec. 5.2.2.2.1 Type I
%   single-panel construction (codebookMode 1):
%
%       u_m     = [1, e^{j2*pi*m/(O2*N2)}, ..., e^{j2*pi*m*(N2-1)/(O2*N2)}]
%       v_{l,m} = [u_m, e^{j2*pi*l/(O1*N1)} u_m, ...,
%                  e^{j2*pi*l*(N1-1)/(O1*N1)} u_m]^T
%       phi_n   = e^{j*pi*n/2},  n in {0,1,2,3}
%
%   with PMI indices i1,1 = l in {0..O1*N1-1}, i1,2 = m in {0..O2*N2-1}
%   and i2 = n. Default oversampling O1 = O2 = 4 (Table 5.2.2.2.1-2).
%
%   Dimension map (model <-> 3GPP):
%       N_H = PARAMS.numColumns  horizontal, spatial frequency b_i,
%                                3GPP dimension "1" (index l = kH)
%       N_V = PARAMS.numRows     vertical,   spatial frequency a_i,
%                                3GPP dimension "2" (index m = kV)
%   Which dimension is labelled "1" vs "2" is immaterial: the construction
%   is the Kronecker product of two per-dimension oversampled DFTs.
%
%   Notes (deliberate modelling choices -- do not "fix" later):
%   1) The beam DIRECTION is set entirely by (l, m). In this model that is
%      exactly: snap the vertical spatial frequency a_i to the nearest
%      multiple of 1/(O_V*N_V) and the horizontal b_i to the nearest
%      multiple of 1/(O_H*N_H) (see imt_aas_codebook_select /
%      imtAasArrayFactor).
%   2) The rank-1 co-phase phi_n co-phases the two POLARIZATIONS only; it
%      does not change the single-polarization spatial array-factor power.
%      The model's EIRP envelope is built from |AF|^2 of one polarization,
%      so phi_n (and the 1/sqrt(P_CSI-RS) normalization) are EIRP no-ops
%      and are NOT included in the returned weights.
%   3) Honest framing: the literal TS 38.214 port configurations stop at
%      32 CSI-RS ports (Table 5.2.2.2.1-2), whereas the R23 sub-array grid
%      is N_H x N_V = 16 x 8 = 128 per polarization. This function
%      implements the Type I single-panel CONSTRUCTION (oversampled 2-D
%      DFT, default O = 4, codebookMode 1) generalized to the actual
%      N_H x N_V sub-array grid read from PARAMS -- it is NOT a literal
%      standardized PMI table lookup.
%   4) Aliasing: R23 uses d_V = 2.1 lambda > 0.5 lambda, so the vertical
%      DFT grid has period 1/d_V < 1 in sin-space and grating / aliased
%      lobes are physically real for this geometry. The bin grids below
%      are stored on the principal branch [0, 1); see
%      imt_aas_codebook_select for the mod(., O*N) index arithmetic and
%      the isAliased flag.
%
%   Inputs:
%       PARAMS  imtAasDefaultParams()-shaped struct (default if [] /
%               omitted). Reads numColumns (N_H) and numRows (N_V).
%       OPTS    optional struct:
%                   oversampleH    O_H, positive integer (default 4)
%                   oversampleV    O_V, positive integer (default 4)
%                   returnWeights  logical (default false); when true the
%                                  complex v_{l,m} weight matrix is built
%                                  (validation only -- the EIRP runner
%                                  never needs it).
%
%   Output CB struct fields:
%       NH, NV                 per-dimension array sizes (from PARAMS)
%       oversampleH, oversampleV   O_H, O_V
%       MH = O_H*N_H           horizontal grid size (index l = kH)
%       MV = O_V*N_V           vertical grid size   (index m = kV)
%       biBins = (0:MH-1)/MH   quantized horizontal spatial frequencies
%       aiBins = (0:MV-1)/MV   quantized vertical spatial frequencies
%       kHRange, kVRange       [0, MH-1], [0, MV-1] index ranges
%       numBeams               MH * MV
%       weights                (only when returnWeights) complex
%                              [NH*NV x MH x MV]; column (:, l+1, m+1) is
%                              v_{l,m} with element ordering
%                              n = n2 + NV*n1 (vertical index n2 fastest,
%                              matching the nested-u_m form above).
%
%   See also: imt_aas_codebook_select, imtAasArrayFactor,
%             runR23AasEirpCdfGrid, imtAasDefaultParams.

    if nargin < 1 || isempty(params)
        params = imtAasDefaultParams();
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('imt_aas_dft_codebook:invalidOpts', ...
            'OPTS must be a struct (or [] for defaults).');
    end

    N_H = params.numColumns;
    N_V = params.numRows;
    validateattributes(N_H, {'numeric'}, {'integer','positive','scalar'}, ...
        mfilename, 'params.numColumns');
    validateattributes(N_V, {'numeric'}, {'integer','positive','scalar'}, ...
        mfilename, 'params.numRows');

    O_H = readOversample(opts, 'oversampleH');
    O_V = readOversample(opts, 'oversampleV');

    returnWeights = false;
    if isfield(opts, 'returnWeights') && ~isempty(opts.returnWeights)
        if ~((islogical(opts.returnWeights) || isnumeric(opts.returnWeights)) ...
                && isscalar(opts.returnWeights))
            error('imt_aas_dft_codebook:invalidReturnWeights', ...
                'opts.returnWeights must be a logical scalar.');
        end
        returnWeights = logical(opts.returnWeights);
    end

    MH = O_H * double(N_H);
    MV = O_V * double(N_V);

    cb = struct();
    cb.NH          = double(N_H);
    cb.NV          = double(N_V);
    cb.oversampleH = O_H;
    cb.oversampleV = O_V;
    cb.MH          = MH;
    cb.MV          = MV;
    cb.biBins      = (0:(MH - 1)) ./ MH;
    cb.aiBins      = (0:(MV - 1)) ./ MV;
    cb.kHRange     = [0, MH - 1];
    cb.kVRange     = [0, MV - 1];
    cb.numBeams    = MH * MV;

    if returnWeights
        % Per-dimension oversampled DFT vectors, then Kronecker-combined.
        % VH(:, l+1) = [1, e^{j2*pi*l/MH}, ..., e^{j2*pi*l*(NH-1)/MH}]^T
        n1 = (0:(double(N_H) - 1)).';
        n2 = (0:(double(N_V) - 1)).';
        VH = exp(1j .* 2 .* pi .* (n1 * (0:(MH - 1))) ./ MH);   % NH x MH
        VV = exp(1j .* 2 .* pi .* (n2 * (0:(MV - 1))) ./ MV);   % NV x MV

        W = complex(zeros(double(N_H) * double(N_V), MH, MV));
        for l = 1:MH
            for m = 1:MV
                W(:, l, m) = kron(VH(:, l), VV(:, m));
            end
        end
        cb.weights = W;
        cb.weightOrdering = ...
            'element n = n2 + NV*n1 (vertical n2 fastest), kron(vH, vV)';
    end
end

% =====================================================================

function o = readOversample(opts, name)
%READOVERSAMPLE Positive-integer oversampling factor, default 4.
    o = 4;
    if isfield(opts, name) && ~isempty(opts.(name))
        o = opts.(name);
    end
    if ~(isnumeric(o) && isreal(o) && isscalar(o) && isfinite(o) && ...
            o >= 1 && o == floor(o))
        error('imt_aas_dft_codebook:invalidOversample', ...
            'opts.%s must be a positive integer scalar.', name);
    end
    o = double(o);
end
