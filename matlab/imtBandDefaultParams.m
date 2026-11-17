function params = imtBandDefaultParams(band, environment)
%IMTBANDDEFAULTPARAMS Nested IMT AAS parameters for a named frequency band.
%
%   PARAMS = imtBandDefaultParams(BAND)
%   PARAMS = imtBandDefaultParams(BAND, ENVIRONMENT)
%
%   Returns the nested parameter struct consumed by runR23AasEirpCdfGrid
%   (same layout as r23DefaultParams) for the requested band.
%
%   BAND (case-insensitive):
%       '7ghz'    | 'r23' | '7.125-8.4ghz' | '8ghz'
%           Returns r23DefaultParams(ENVIRONMENT) UNCHANGED (isequal).
%       '2p7ghz'  | '2.7ghz' | '2700-2800mhz'
%           2.7 GHz TDD macro case, 2700-2800 MHz, centre 2750 MHz,
%           100 MHz channel.
%
%   ENVIRONMENT: as for r23DefaultParams. The 2.7 GHz band supports only
%   'urban' / 'macroUrban' and 'suburban' / 'macroSuburban'.
%
%   2.7 GHz parameter sources:
%     * Antenna: ITU-R WP 5D, Doc. 5D/716 Annex 4.4, "Beamforming antenna
%       characteristics for IMT in 1 710-4 990 MHz": 4x8 sub-arrays,
%       3 elements per sub-array, 0.5/2.1 lambda sub-array spacing,
%       0.7 lambda element spacing, 3 deg sub-array tilt, 6 deg mechanical
%       tilt, 6.4 dBi element gain (2 dB ohmic loss absorbed).
%     * Power: 47 CFR Part 27 base-station limit, 65 dBm/MHz EIRP (used
%       for both urban and suburban), over 100 MHz -> 85 dBm sector peak
%       EIRP / 100 MHz. Conducted power = 85 - 26.22 dBi = 58.78 dBm.
%       This departs from the ITU table value of 72.28 dBm by design.
%     * Deployment: BS height and cell radius ONLY, from the 5D/716
%       Annex 4.4 deployment table for bands between 2 and 3 GHz
%       (urban 20 m / 0.4 km, suburban 25 m / 0.8 km). Every other
%       deployment field is inherited from r23DefaultParams.
%     * TDD activity factor 0.75 and network loading 0.20 are unchanged.
%
%   The antenna geometry written here matches aasGeometryPreset(
%   'itu_2p7ghz_4x8'), which runR23AasEirpCdfGrid selects by default when
%   the band is '2p7ghz'.
%
%   Antenna-face EIRP only: no path loss, clutter, receiver, I/N, or
%   multi-site aggregation.
%
%   Example:
%       params = imtBandDefaultParams('2p7ghz', 'suburban');
%       out    = runR23AasEirpCdfGrid(params);
%
%   See also: r23DefaultParams, aasGeometryPreset, runR23AasEirpCdfGrid,
%             imtBandName.

    if nargin < 1 || isempty(band)
        band = '7ghz';
    end
    if nargin < 2 || isempty(environment)
        environment = 'urban';
    end
    if isstring(environment) && isscalar(environment)
        environment = char(environment);
    end

    bandKey = imtBandName(band);

    params = r23DefaultParams(environment);

    if strcmp(bandKey, '7ghz')
        return;
    end

    % ---- 2.7 GHz ------------------------------------------------------
    switch lower(params.deployment.environment)
        case 'urban'
            bsHeight_m   = 20;
            cellRadius_m = 400;
        case 'suburban'
            bsHeight_m   = 25;
            cellRadius_m = 800;
        otherwise
            error('imtBandDefaultParams:unsupportedEnvironment', ...
                ['Environment "%s" is not defined for band ''2p7ghz''. ' ...
                 'Supported: ''urban'', ''suburban''.'], environment);
    end

    eirpDensityLimit_dBmPerMHz = 65;
    channelBandwidth_MHz       = 100;
    numRows    = 4;
    numColumns = 8;
    numElementRowsInSubarray = 3;
    elementGain_dBi = 6.4;
    peakGain_dBi = elementGain_dBi + 10 * log10(numElementRowsInSubarray) + ...
                   10 * log10(numRows * numColumns);
    sectorEirp_dBm = eirpDensityLimit_dBmPerMHz + 10 * log10(channelBandwidth_MHz);
    conducted_dBm  = sectorEirp_dBm - peakGain_dBi;
    numPolarizations = 2;

    % deployment: height and radius only
    params.deployment.bsHeight_m          = bsHeight_m;
    params.deployment.cellRadius_m        = cellRadius_m;
    params.deployment.interSiteDistance_m = sqrt(3) * cellRadius_m;

    % BS power / band
    params.bs.maxEirpPerSector_dBm       = sectorEirp_dBm;
    params.bs.conductedPower_dBm         = conducted_dBm;
    params.bs.peakGain_dBi               = peakGain_dBi;
    params.bs.channelBandwidth_MHz       = channelBandwidth_MHz;
    params.bs.frequency_MHz              = 2750;
    params.bs.frequencyRange_MHz         = [2700 2800];
    params.bs.duplex                     = 'TDD';
    params.bs.eirpDensityLimit_dBmPerMHz = eirpDensityLimit_dBmPerMHz;

    % AAS antenna table (ITU 1 710-4 990 MHz)
    params.aas.elementGain_dBi                          = elementGain_dBi;
    params.aas.numRows                                  = numRows;
    params.aas.numColumns                               = numColumns;
    params.aas.horizontalSpacing_lambda                 = 0.5;
    params.aas.verticalSubarraySpacing_lambda           = 2.1;
    params.aas.numElementRowsInSubarray                 = numElementRowsInSubarray;
    params.aas.verticalElementSeparationInSubarray_lambda = 0.7;
    params.aas.subarrayDowntilt_deg                     = 3;
    params.aas.mechanicalDowntilt_deg                   = 6;
    params.aas.conductedPowerPerSubarrayBeforeOhmic_dBm = conducted_dBm - ...
        10 * log10(numRows * numColumns * numPolarizations);
    params.aas.aasGeometryPreset                        = 'itu_2p7ghz_4x8';

    % metadata / provenance
    params.metadata.band             = '2p7ghz';
    params.metadata.bandLabel        = '2.7 GHz (2700-2800 MHz, TDD)';
    params.metadata.sourceDefault    = ['2.7 GHz macro: ITU-R 5D/716 Annex 4.4 ' ...
        '1 710-4 990 MHz AAS antenna table; 47 CFR Part 27 power ' ...
        '(65 dBm/MHz); ITU 2-3 GHz BS height and cell radius'];
    params.metadata.antennaSource    = ['ITU-R WP 5D Doc. 5D/716 Annex 4.4, ' ...
        'Beamforming antenna characteristics for IMT in 1 710-4 990 MHz'];
    params.metadata.powerBasis       = '47 CFR Part 27, 65 dBm/MHz EIRP';
    params.metadata.deploymentSource = ['ITU 5D/716 Annex 4.4, 2-3 GHz macro ' ...
        '(height, radius); other deployment fields inherited'];
    params.metadata.notes = ['antenna-face EIRP only; ' ...
        'no path loss / no clutter / no receiver / no aggregation; ' ...
        'one-site / one-sector; sector EIRP set by Part 27, not the ' ...
        'ITU table value of 72.28 dBm'];
end
