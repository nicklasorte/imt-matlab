function params = r23DefaultParams(environment)
%R23DEFAULTPARAMS Centralized R23 7.125-8.4 GHz IMT AAS parameter builder.
%
%   PARAMS = r23DefaultParams()
%   PARAMS = r23DefaultParams(ENVIRONMENT)
%
%   Returns a nested struct of all parameters for the R23 7.125-8.4 GHz
%   IMT macro Extended-AAS deployment. ENVIRONMENT is one of:
%       'urban'      |  'macroUrban'      (default)
%       'suburban'   |  'macroSuburban'
%
%   Source: ITU-R IMT characteristics for the 7.125-8.4 GHz band /
%   R23 macro reference. Macro urban and macro suburban share the
%   same AAS antenna table; only deployment geometry differs.
%
%   Top-level fields:
%       params.deployment   environment, cell radius, BS height, sectors
%       params.ue           numUesPerSector, height, max output power, ...
%       params.bs           max EIRP / sector, conducted power, peak gain,
%                           channel BW, TDD activity, network loading
%       params.aas          Extended AAS antenna parameters (8 x 16)
%       params.sim          Monte Carlo / grid simulation parameters
%       params.metadata     source / model tags
%
%   Power semantics (R23 macro 7.125-8.4 GHz):
%       params.bs.maxEirpPerSector_dBm = 78.3   sector peak EIRP / 100 MHz
%       params.bs.conductedPower_dBm   = 46.1   conducted power / sector
%       params.bs.peakGain_dBi         = 32.2   composite peak gain
%       46.1 + 32.2 = 78.3
%
%   Element gain (6.4 dBi) already includes the R23 reference 2 dB
%   array ohmic loss; do not subtract it again downstream.
%
%   This is antenna-face EIRP only. There is NO path loss, NO clutter,
%   NO receiver antenna gain, NO I/N, NO multi-site aggregation, and
%   NO 19-site / 57-sector deployment.
%
%   Example:
%       params = r23DefaultParams("suburban");
%       params.ue.numUesPerSector = 10;
%       params.bs.maxEirpPerSector_dBm = 75;
%       result = runR23AasEirpCdfGrid(params);
%
%   See also: runR23AasEirpCdfGrid, imtAasDefaultParams,
%             imtAasSingleSectorParams, plotR23AasPointingHeatmap.

    if nargin < 1 || isempty(environment)
        environment = 'urban';
    end
    if isstring(environment) && isscalar(environment)
        environment = char(environment);
    end
    if ~ischar(environment)
        error('r23DefaultParams:badEnvironment', ...
            'ENVIRONMENT must be a char or scalar string.');
    end

    switch lower(environment)
        case {'urban', 'macrourban'}
            tag                  = 'urban';
            cellRadius_m         = 400;
            bsHeight_m           = 18;
            bsDensityPerKm2      = 10;
            belowRooftopFraction = 0.65;
        case {'suburban', 'macrosuburban'}
            tag                  = 'suburban';
            cellRadius_m         = 800;
            bsHeight_m           = 20;
            bsDensityPerKm2      = 2.4;
            belowRooftopFraction = 0.15;
        otherwise
            error('r23DefaultParams:unknownEnvironment', ...
                ['Unknown environment "%s". Supported: ' ...
                 '''urban'' (''macroUrban''), ''suburban'' (''macroSuburban'').'], ...
                environment);
    end

    params = struct();

    % ---- deployment --------------------------------------------------
    params.deployment = struct();
    params.deployment.environment           = tag;
    params.deployment.cellRadius_m          = cellRadius_m;
    params.deployment.bsHeight_m            = bsHeight_m;
    params.deployment.bsDensityPerKm2       = bsDensityPerKm2;
    params.deployment.belowRooftopFraction  = belowRooftopFraction;
    params.deployment.numSectorsPerSite     = 3;
    params.deployment.sectorAzimuthsDeg     = [0 120 240];
    params.deployment.sectorAzimuthDeg      = 0;          % single-sector MVP
    params.deployment.sectorHalfWidthDeg    = 60;
    params.deployment.minUeDistance_m       = 35;
    % Inter-site distance under hex grid: ISD = sqrt(3) * cellRadius.
    params.deployment.interSiteDistance_m   = sqrt(3) * cellRadius_m;

    % ---- UE ----------------------------------------------------------
    params.ue = struct();
    params.ue.numUesPerSector       = 3;
    params.ue.height_m              = 1.5;
    params.ue.maxOutputPower_dBm    = 23;
    params.ue.antennaGain_dBi       = -4;
    params.ue.bodyLoss_dB           = 4;
    params.ue.indoorFraction        = 0.70;
    params.ue.p0Pusch_dBmPerRb      = -92.2;
    params.ue.alpha                 = 0.8;

    % ---- BS power / band --------------------------------------------
    params.bs = struct();
    params.bs.maxEirpPerSector_dBm  = 78.3;       % sector peak EIRP / 100 MHz
    params.bs.conductedPower_dBm    = 46.1;       % per 100 MHz before AAS
    params.bs.peakGain_dBi          = 32.2;       % composite peak gain
    params.bs.feederLoss_dB         = 0;
    params.bs.channelBandwidth_MHz  = 100;
    params.bs.frequency_MHz         = 8000;
    params.bs.tddActivityFactor     = 0.75;
    params.bs.networkLoadingFactor  = 0.20;
    params.bs.networkLoadingOptions = [0.20, 0.50];

    % ---- Extended AAS antenna table ---------------------------------
    % Same for macro urban and macro suburban at 7.125-8.4 GHz.
    params.aas = struct();
    params.aas.model                                    = 'extended';
    params.aas.elementGain_dBi                          = 6.4;
    params.aas.elementHorizontal3dBBeamwidth_deg        = 90;
    params.aas.elementVertical3dBBeamwidth_deg          = 65;
    params.aas.frontToBackRatio_dB                      = 30;
    params.aas.sideLobeAttenuation_dB                   = 30;
    params.aas.polarization                             = 'linear_pm45';
    params.aas.numRows                                  = 8;          % N_V
    params.aas.numColumns                               = 16;         % N_H
    params.aas.horizontalSpacing_lambda                 = 0.5;        % d_H
    params.aas.verticalSubarraySpacing_lambda           = 2.1;        % d_V
    params.aas.numElementRowsInSubarray                 = 3;
    params.aas.verticalElementSeparationInSubarray_lambda = 0.7;
    params.aas.subarrayDowntilt_deg                     = 3;
    params.aas.mechanicalDowntilt_deg                   = 6;
    params.aas.horizontalCoverage_deg                   = [-60 60];
    params.aas.verticalCoverageGlobal_deg               = [90 100];
    params.aas.k                                        = 12;         % M.2101
    params.aas.rho                                      = 1;
    params.aas.elementGainIncludesOhmicLoss             = true;
    % R23 macro array ohmic loss (already absorbed in elementGain_dBi).
    params.aas.arrayOhmicLoss_dB                        = 2;
    % Conducted power per sub-array / element [dBm] (per source table).
    params.aas.conductedPowerPerSubarrayBeforeOhmic_dBm = 22;

    % ---- simulation / Monte Carlo grid ------------------------------
    params.sim = struct();
    params.sim.numSnapshots             = 1000;
    params.sim.randomSeed               = 1;
    params.sim.azGrid_deg               = -180:1:180;
    params.sim.elGrid_deg               = -90:1:90;
    params.sim.binEdges_dBm             = -100:1:120;
    params.sim.percentiles              = [1 5 10 20 50 80 90 95 99];
    params.sim.splitSectorPower         = true;
    params.sim.computePointingHeatmap   = true;
    params.sim.pointingSummaryStatistic = 'meanAcrossSnapshots';

    % ---- metadata / provenance --------------------------------------
    params.metadata = struct();
    params.metadata.aasModel      = 'extended';
    params.metadata.sourceDefault = ['ITU-R IMT characteristics / ' ...
                                     'R23 7.125-8.4 GHz macro urban/suburban'];
    params.metadata.notes         = ['antenna-face EIRP only; ' ...
        'no path loss / no clutter / no receiver / no aggregation; ' ...
        'one-site / one-sector MVP'];
end
