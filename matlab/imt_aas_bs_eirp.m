function [eirp_dBm, gain_dBi] = imt_aas_bs_eirp(azim, elev, azim_i, elev_i, cfg)
%IMT_AAS_BS_EIRP Conducted-power-to-EIRP for an IMT AAS base station.
%
%   [EIRP, GAIN] = imt_aas_bs_eirp(AZIM, ELEV, AZIM_I, ELEV_I, CFG)
%
%   Computes per-direction EIRP for an AAS base station whose pointing is
%   (AZIM_I, ELEV_I) using the M.2101 composite array pattern.
%
%       eirp_dBm = txPower_dBm + gain_dBi - feederLoss_dB
%
%   Required CFG fields:
%       G_Emax, A_m, SLA_nu, phi_3db, theta_3db,
%       d_H, d_V, N_H, N_V, rho, k,
%       txPower_dBm     conducted transmit power [dBm]
%       feederLoss_dB   feeder/cable loss [dB] (default 0)
%
%   The conducted txPower_dBm is treated as the total power radiated by
%   the array (consistent with M.2101 Table 4 / 3GPP TR 37.840). The
%   composite pattern returns gain in dBi which already aggregates the
%   array factor; we therefore do NOT add 10*log10(N_H*N_V) on top.

    if ~isfield(cfg, 'feederLoss_dB') || isempty(cfg.feederLoss_dB)
        cfg.feederLoss_dB = 0;
    end
    if ~isfield(cfg, 'rho') || isempty(cfg.rho); cfg.rho = 1; end
    if ~isfield(cfg, 'k')   || isempty(cfg.k);   cfg.k   = 12; end

    gain_dBi = imt2020_composite_pattern(azim, elev, azim_i, elev_i, ...
        cfg.G_Emax, cfg.A_m, cfg.SLA_nu, cfg.phi_3db, cfg.theta_3db, ...
        cfg.d_H, cfg.d_V, cfg.N_H, cfg.N_V, cfg.rho, cfg.k);

    eirp_dBm = cfg.txPower_dBm + gain_dBi - cfg.feederLoss_dB;
end
