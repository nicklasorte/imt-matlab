function cfg = imt_r23_aas_defaults(deployment)
%IMT_R23_AAS_DEFAULTS R23 7.125-8.4 GHz IMT macro AAS configuration.
%
%   CFG = imt_r23_aas_defaults()
%   CFG = imt_r23_aas_defaults(DEPLOYMENT)
%
%   Returns a configuration struct populated with the R23 macro-AAS
%   reference parameters for the 7.125-8.4 GHz IMT band. DEPLOYMENT is
%   one of:
%       'macroUrban'     (default)  bsHeight_m = 18
%       'macroSuburban'             bsHeight_m = 20
%
%   The struct uses repo-compatible field names:
%       G_Emax, A_m, SLA_nu, phi_3db, theta_3db,
%       d_H, d_V, N_H, N_V, rho, k, txPower_dBm, feederLoss_dB
%
%   plus R23-specific fields:
%       patternModel             = 'r23_extended_aas'
%       frequencyMHz             = 8000
%       bandwidthMHz             = 100
%       sectorEirp_dBm_per100MHz = 78.3
%       peakGain_dBi             = 32.2
%       normalizeToPeakGain      = true
%       mechanicalDowntiltDeg    = 6
%       subarray.numVerticalElements = 3
%       subarray.d_V                  = 0.7   [wavelengths]
%       subarray.downtiltDeg          = 3
%       deployment, bsHeight_m
%
%   The R23 row x column = 8 x 16 array maps to N_V = 8 (vertical sub-
%   arrays / rows) and N_H = 16 (horizontal columns) in the repo's array
%   factor convention.
%
%   UE / network metadata (not used by the EIRP-grid step) is also
%   attached so downstream steps can reuse a single cfg struct.

    if nargin < 1 || isempty(deployment)
        deployment = 'macroUrban';
    end
    if ~(ischar(deployment) || (isstring(deployment) && isscalar(deployment)))
        error('imt_r23_aas_defaults:badDeployment', ...
            'deployment must be a character vector or string scalar.');
    end
    deployment = char(deployment);

    switch deployment
        case 'macroUrban'
            bsHeight_m = 18;
        case 'macroSuburban'
            bsHeight_m = 20;
        otherwise
            error('imt_r23_aas_defaults:unknownDeployment', ...
                ['Unknown deployment "%s". Supported: ' ...
                 '''macroUrban'', ''macroSuburban''.'], deployment);
    end

    cfg = struct();

    % ---- pattern + band ------------------------------------------------
    cfg.patternModel             = 'r23_extended_aas';
    cfg.frequencyMHz             = 8000;
    cfg.bandwidthMHz             = 100;
    cfg.sectorEirp_dBm_per100MHz = 78.3;
    cfg.peakGain_dBi             = 32.2;
    cfg.normalizeToPeakGain      = true;
    cfg.mechanicalDowntiltDeg    = 6;

    % ---- single element / per-polarization ----------------------------
    % G_Emax already includes the 2 dB ohmic loss (per R23 table).
    cfg.G_Emax    = 6.4;
    cfg.A_m       = 30;
    cfg.SLA_nu    = 30;
    cfg.phi_3db   = 90;
    cfg.theta_3db = 65;

    % ---- sub-array array (R23 row x column = 8 x 16) ------------------
    % Repo convention: N_V = number of vertical sub-arrays (rows),
    %                  N_H = number of horizontal columns.
    cfg.N_V = 8;
    cfg.N_H = 16;
    cfg.d_H = 0.5;     % horizontal sub-array spacing [wavelengths]
    cfg.d_V = 2.1;     % vertical sub-array spacing   [wavelengths]

    % ---- vertical sub-array (within each panel cell) ------------------
    cfg.subarray.numVerticalElements = 3;
    cfg.subarray.d_V                 = 0.7;
    cfg.subarray.downtiltDeg         = 3;

    % ---- M.2101 recombination knobs -----------------------------------
    cfg.rho = 1;
    cfg.k   = 12;

    % ---- EIRP terms ---------------------------------------------------
    % txPower_dBm + peakGain_dBi = sectorEirp_dBm_per100MHz
    cfg.txPower_dBm    = cfg.sectorEirp_dBm_per100MHz - cfg.peakGain_dBi;
    cfg.feederLoss_dB  = 0;

    % ---- deployment metadata ------------------------------------------
    cfg.deployment = deployment;
    cfg.bsHeight_m = bsHeight_m;
    cfg.numSectors = 3;
    cfg.sectorAzimuthsDeg     = [0 120 240];
    cfg.horizontalCoverageDeg = 60;          % +/- 60 deg
    cfg.networkLoadingFactors = [0.20 0.50]; % metadata only
    cfg.bsTddActivityFactor   = 0.75;        % metadata only

    % polarization metadata (linear +/- 45 sub-array)
    cfg.polarization = 'linear_pm45';

    % ---- UE metadata (not used by the EIRP-grid step) -----------------
    cfg.ue = struct( ...
        'numPerSector',       3, ...
        'height_m',           1.5, ...
        'antennaGain_dBi',   -4, ...
        'bodyLoss_dB',        4, ...
        'tddActivityFactor',  0.25, ...
        'pcmax_dBm',         23, ...
        'p0_pusch_dBm_perRB', -92.2, ...
        'alpha',              0.8);
end
