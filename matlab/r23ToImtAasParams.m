function flatParams = r23ToImtAasParams(nestedParams)
%R23TOIMTAASPARAMS Convert nested r23DefaultParams to flat imtAasDefaultParams.
%
%   FLATPARAMS = r23ToImtAasParams(NESTEDPARAMS)
%
%   Translates the nested struct produced by r23DefaultParams into the
%   flat imtAasDefaultParams shape consumed by the existing AAS antenna
%   primitives (imtAasCompositeGain, imtAasEirpGrid,
%   imtAasSectorEirpGridFromBeams, ...).
%
%   This adapter is intentionally one-way and value-only: it does not
%   stash a back-pointer to the nested struct.
%
%   See also: r23DefaultParams, imtAasDefaultParams.

    if nargin < 1 || isempty(nestedParams) || ~isstruct(nestedParams)
        error('r23ToImtAasParams:invalidInput', ...
            'Input must be a struct produced by r23DefaultParams.');
    end

    flat = imtAasDefaultParams();

    % ---- AAS antenna table ------------------------------------------
    if isfield(nestedParams, 'aas') && isstruct(nestedParams.aas)
        a = nestedParams.aas;
        flat = setIfPresent(flat, a, 'elementGain_dBi',                          'elementGainDbi');
        flat = setIfPresent(flat, a, 'elementHorizontal3dBBeamwidth_deg',        'hBeamwidthDeg');
        flat = setIfPresent(flat, a, 'elementVertical3dBBeamwidth_deg',          'vBeamwidthDeg');
        flat = setIfPresent(flat, a, 'frontToBackRatio_dB',                      'frontToBackDb');
        flat = setIfPresent(flat, a, 'sideLobeAttenuation_dB',                   'sideLobeAttenuationDb');
        flat = setIfPresent(flat, a, 'polarization',                             'polarization');
        flat = setIfPresent(flat, a, 'numColumns',                               'numColumns');
        flat = setIfPresent(flat, a, 'numRows',                                  'numRows');
        flat = setIfPresent(flat, a, 'horizontalSpacing_lambda',                 'hSpacingWavelengths');
        flat = setIfPresent(flat, a, 'verticalSubarraySpacing_lambda',           'vSubarraySpacingWavelengths');
        flat = setIfPresent(flat, a, 'numElementRowsInSubarray',                 'numElementsPerSubarray');
        flat = setIfPresent(flat, a, 'verticalElementSeparationInSubarray_lambda', 'elementSpacingWavelengths');
        flat = setIfPresent(flat, a, 'subarrayDowntilt_deg',                     'subarrayDowntiltDeg');
        flat = setIfPresent(flat, a, 'mechanicalDowntilt_deg',                   'mechanicalDowntiltDeg');
        flat = setIfPresent(flat, a, 'k',                                        'k');
        flat = setIfPresent(flat, a, 'rho',                                      'rho');
        flat = setIfPresent(flat, a, 'elementGainIncludesOhmicLoss',             'elementGainIncludesOhmicLoss');

        % Coverage envelope (vertical M.2101 global theta -> el limits)
        if isfield(a, 'horizontalCoverage_deg') && ~isempty(a.horizontalCoverage_deg)
            hcov = double(a.horizontalCoverage_deg);
            if numel(hcov) == 2
                flat.hCoverageDeg = max(abs(hcov));
            else
                flat.hCoverageDeg = double(hcov(1));
            end
        end
        if isfield(a, 'verticalCoverageGlobal_deg') && ~isempty(a.verticalCoverageGlobal_deg)
            vcov = double(a.verticalCoverageGlobal_deg);
            flat.vCoverageDegGlobalMin = min(vcov);
            flat.vCoverageDegGlobalMax = max(vcov);
        end
    end

    % ---- BS power / band --------------------------------------------
    if isfield(nestedParams, 'bs') && isstruct(nestedParams.bs)
        b = nestedParams.bs;
        flat = setIfPresent(flat, b, 'maxEirpPerSector_dBm',  'sectorEirpDbm');
        flat = setIfPresent(flat, b, 'conductedPower_dBm',    'txPowerDbmPer100MHz');
        flat = setIfPresent(flat, b, 'peakGain_dBi',          'peakGainDbi');
        flat = setIfPresent(flat, b, 'channelBandwidth_MHz',  'bandwidthMHz');
        flat = setIfPresent(flat, b, 'frequency_MHz',         'frequencyMHz');
    end

    % ---- UE / sim --------------------------------------------------
    if isfield(nestedParams, 'ue') && isstruct(nestedParams.ue)
        flat = setIfPresent(flat, nestedParams.ue, 'numUesPerSector', 'numUesPerSector');
    end
    if isfield(nestedParams, 'sim') && isstruct(nestedParams.sim)
        flat = setIfPresent(flat, nestedParams.sim, 'splitSectorPower', ...
            'defaultSplitSectorPowerAcrossBeams');
    end

    flatParams = flat;
end

% =====================================================================

function flat = setIfPresent(flat, src, srcField, dstField)
    if isfield(src, srcField) && ~isempty(src.(srcField))
        flat.(dstField) = src.(srcField);
    end
end
