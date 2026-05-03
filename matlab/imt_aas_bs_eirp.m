function [eirp_dBm, gain_dBi, aux] = imt_aas_bs_eirp(azim, elev, azim_i, elev_i, cfg)
%IMT_AAS_BS_EIRP Conducted-power-to-EIRP for an IMT AAS base station.
%
%   [EIRP, GAIN]      = imt_aas_bs_eirp(AZIM, ELEV, AZIM_I, ELEV_I, CFG)
%   [EIRP, GAIN, AUX] = imt_aas_bs_eirp(AZIM, ELEV, AZIM_I, ELEV_I, CFG)
%
%   Computes per-direction EIRP for an AAS base station whose pointing is
%   (AZIM_I, ELEV_I).
%
%       eirp_dBm = txPower_dBm + gain_dBi - feederLoss_dB
%
%   Pattern model (selected via CFG.patternModel):
%       'm2101' (default, also when the field is missing)
%               Uses imt2020_composite_pattern.m exactly as before.
%               Required fields: G_Emax, A_m, SLA_nu, phi_3db, theta_3db,
%               d_H, d_V, N_H, N_V, rho, k.
%
%       'r23_extended_aas'
%               Uses imt2020_composite_pattern_extended.m: the M.2101
%               horizontal/vertical array factor stacked with a fixed-
%               downtilt vertical sub-array, plus mechanical downtilt.
%               Additional CFG fields: mechanicalDowntiltDeg,
%               subarray.numVerticalElements, subarray.d_V,
%               subarray.downtiltDeg, peakGain_dBi, normalizeToPeakGain.
%
%   Common CFG fields:
%       txPower_dBm     conducted transmit power [dBm]
%       feederLoss_dB   feeder/cable loss [dB] (default 0)
%
%   The conducted txPower_dBm is treated as the total power radiated by
%   the array (consistent with M.2101 Table 4 / 3GPP TR 37.840). The
%   composite pattern returns gain in dBi which already aggregates the
%   array factor; we therefore do NOT add 10*log10(N_H*N_V) on top.
%
%   AUX (optional third output) is populated for the extended pattern:
%       AUX.rawGain_dBi  un-normalized extended gain [dBi]
%       AUX.rawPeak_dBi  raw gain at the beam direction (panel frame)

    if ~isfield(cfg, 'feederLoss_dB') || isempty(cfg.feederLoss_dB)
        cfg.feederLoss_dB = 0;
    end
    if ~isfield(cfg, 'rho') || isempty(cfg.rho); cfg.rho = 1; end
    if ~isfield(cfg, 'k')   || isempty(cfg.k);   cfg.k   = 12; end

    if ~isfield(cfg, 'patternModel') || isempty(cfg.patternModel)
        patternModel = 'm2101';
    else
        patternModel = lower(char(cfg.patternModel));
    end

    aux = struct();

    switch patternModel
        case {'m2101', 'imt2020', 'simple'}
            gain_dBi = imt2020_composite_pattern(azim, elev, azim_i, elev_i, ...
                cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
                cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, cfg.rho, cfg.k);

        case 'r23_extended_aas'
            [gain_dBi, rawGain_dBi, rawPeak_dBi] = ...
                imt2020_composite_pattern_extended( ...
                    azim, elev, azim_i, elev_i, cfg);
            aux.rawGain_dBi = rawGain_dBi;
            aux.rawPeak_dBi = rawPeak_dBi;

        otherwise
            error('imt_aas_bs_eirp:unknownPatternModel', ...
                'Unknown cfg.patternModel "%s".', patternModel);
    end

    eirp_dBm = cfg.txPower_dBm + gain_dBi - cfg.feederLoss_dB;
end
