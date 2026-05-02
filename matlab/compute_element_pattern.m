function gainDbi = compute_element_pattern(theta, phi, params)
%COMPUTE_ELEMENT_PATTERN Single-element AAS gain (M.2101 Table 4 closed form).
%
%   GAINDBI = compute_element_pattern(THETA, PHI, PARAMS)
%
%   Returns absolute single-element gain in dBi. THETA is elevation
%   (0 = horizon, negative = below horizon, in deg) and PHI is azimuth
%   relative to the panel boresight (in deg). PARAMS is the struct from
%   get_r23_aas_params.
%
%   This wraps imtAasElementPattern with a (theta, phi) calling order
%   matching the AAS-01 task description; imtAasElementPattern's native
%   order is (azDeg, elDeg).

    if nargin < 3 || isempty(params)
        params = get_r23_aas_params();
    end
    gainDbi = imtAasElementPattern(phi, theta, params);
end
