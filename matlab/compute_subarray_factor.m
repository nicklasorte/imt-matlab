function subFactorDb = compute_subarray_factor(theta, phi, params)
%COMPUTE_SUBARRAY_FACTOR L-element vertical sub-array factor (R23, dB).
%
%   SUBFACTORDB = compute_subarray_factor(THETA, PHI, PARAMS)
%
%   Returns the vertical sub-array factor in dB for L vertically-stacked
%   elements with intra-sub-array spacing PARAMS.elementSpacingWavelengths
%   and the fixed sub-array electrical downtilt
%   PARAMS.subarrayDowntiltDeg. PHI is accepted for API symmetry but the
%   sub-array factor only depends on the elevation angle THETA (deg).
%
%   Closed form (M.2101 / 3GPP TR 37.840):
%       AFsub = | sum_{l=0..L-1} exp(j 2 pi l d_sub (cos(theta_polar)
%                                                  + sin(theta_sub))) |^2
%               / L
%       SUBFACTORDB = 10 * log10(AFsub)
%
%   At THETA = -PARAMS.subarrayDowntiltDeg the factor peaks at
%   10*log10(L), which is +4.77 dB for the R23 default L = 3.

    if nargin < 3 || isempty(params)
        params = get_r23_aas_params();
    end

    % Validate shapes (theta, phi same size, even if scalar / vector / 2-D).
    if ~isequal(size(theta), size(phi))
        error('compute_subarray_factor:sizeMismatch', ...
            'theta and phi must be the same size.');
    end

    L          = params.numElementsPerSubarray;
    d_sub      = params.elementSpacingWavelengths;
    subTiltDeg = params.subarrayDowntiltDeg;

    if L == 1
        subFactorDb = zeros(size(theta));
        return;
    end

    th_polar_r = deg2rad(90 - theta);            % polar theta, M.2101
    sub_phase  = d_sub .* (cos(th_polar_r) + sin(deg2rad(subTiltDeg)));
    l_axis     = reshape(0:(L - 1), [1 1 L]);
    argSub     = 2*pi .* l_axis .* sub_phase;
    Ssub       = sum(exp(1j .* argSub), 3);
    AFsub      = (real(Ssub).^2 + imag(Ssub).^2) ./ double(L);
    subFactorDb = 10 .* log10(AFsub);
end
