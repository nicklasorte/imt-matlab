function validate_r23_params(params)
%VALIDATE_R23_PARAMS Sanity-check an R23 AAS parameter struct.
%
%   validate_r23_params(PARAMS)
%
%   Throws a clear error if PARAMS is missing required fields or if any
%   field has an invalid type / range. PARAMS is the struct returned by
%   get_r23_aas_params (or an override of it).
%
%   Required fields, types, and ranges:
%       elementGainDbi              real finite scalar
%       hBeamwidthDeg               real finite positive scalar
%       vBeamwidthDeg               real finite positive scalar
%       frontToBackDb               real finite positive scalar
%       sideLobeAttenuationDb       real finite positive scalar
%       numColumns                  positive integer scalar (N_H)
%       numRows                     positive integer scalar (N_V)
%       hSpacingWavelengths         real finite positive scalar
%       vSubarraySpacingWavelengths real finite positive scalar
%       numElementsPerSubarray      positive integer scalar (L)
%       elementSpacingWavelengths   real finite positive scalar
%       subarrayDowntiltDeg         real finite scalar in [-90, 90]
%       mechanicalDowntiltDeg       real finite scalar in [-90, 90]
%       hCoverageDeg                real finite scalar in (0, 180]
%       vCoverageDegGlobalMin       real finite scalar
%       vCoverageDegGlobalMax       real finite scalar > vCoverageDegGlobalMin
%       sectorEirpDbm               real finite scalar
%       bandwidthMHz                real finite positive scalar
%       frequencyMHz                real finite positive scalar
%       k                           real finite positive scalar
%       rho                         real scalar in [0, 1]

    if ~isstruct(params) || ~isscalar(params)
        error('validate_r23_params:badType', ...
            'params must be a scalar struct.');
    end

    requireRealScalar(params, 'elementGainDbi');
    requireRealPositiveScalar(params, 'hBeamwidthDeg');
    requireRealPositiveScalar(params, 'vBeamwidthDeg');
    requireRealPositiveScalar(params, 'frontToBackDb');
    requireRealPositiveScalar(params, 'sideLobeAttenuationDb');

    requirePositiveInteger(params, 'numColumns');
    requirePositiveInteger(params, 'numRows');
    requirePositiveInteger(params, 'numElementsPerSubarray');

    requireRealPositiveScalar(params, 'hSpacingWavelengths');
    requireRealPositiveScalar(params, 'vSubarraySpacingWavelengths');
    requireRealPositiveScalar(params, 'elementSpacingWavelengths');

    requireRealScalarRange(params, 'subarrayDowntiltDeg',  -90,  90);
    requireRealScalarRange(params, 'mechanicalDowntiltDeg', -90,  90);

    requireRealPositiveScalar(params, 'hCoverageDeg');
    if params.hCoverageDeg > 180
        error('validate_r23_params:badRange', ...
            'params.hCoverageDeg = %g is outside (0, 180].', ...
            params.hCoverageDeg);
    end

    requireRealScalar(params, 'vCoverageDegGlobalMin');
    requireRealScalar(params, 'vCoverageDegGlobalMax');
    if params.vCoverageDegGlobalMax <= params.vCoverageDegGlobalMin
        error('validate_r23_params:badRange', ...
            ['params.vCoverageDegGlobalMax (%g) must be strictly ' ...
             'greater than vCoverageDegGlobalMin (%g).'], ...
            params.vCoverageDegGlobalMax, params.vCoverageDegGlobalMin);
    end

    requireRealScalar(params, 'sectorEirpDbm');
    requireRealPositiveScalar(params, 'bandwidthMHz');
    requireRealPositiveScalar(params, 'frequencyMHz');

    requireRealPositiveScalar(params, 'k');
    requireRealScalarRange(params, 'rho', 0, 1);
end

% =====================================================================

function requireField(s, name)
    if ~isfield(s, name)
        error('validate_r23_params:missingField', ...
            'params is missing required field "%s".', name);
    end
end

function requireRealScalar(s, name)
    requireField(s, name);
    v = s.(name);
    if ~(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v))
        error('validate_r23_params:badType', ...
            'params.%s must be a real finite scalar.', name);
    end
end

function requireRealPositiveScalar(s, name)
    requireRealScalar(s, name);
    if s.(name) <= 0
        error('validate_r23_params:badRange', ...
            'params.%s = %g must be strictly positive.', ...
            name, s.(name));
    end
end

function requireRealScalarRange(s, name, lo, hi)
    requireRealScalar(s, name);
    if s.(name) < lo || s.(name) > hi
        error('validate_r23_params:badRange', ...
            'params.%s = %g is outside [%g, %g].', ...
            name, s.(name), lo, hi);
    end
end

function requirePositiveInteger(s, name)
    requireField(s, name);
    v = s.(name);
    if ~(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v) && ...
            v >= 1 && v == floor(v))
        error('validate_r23_params:badType', ...
            'params.%s must be a positive integer scalar.', name);
    end
end
