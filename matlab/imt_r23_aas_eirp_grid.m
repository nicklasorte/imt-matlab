function out = imt_r23_aas_eirp_grid(azGrid, elGrid, cfg, azim_i, elev_i)
%IMT_R23_AAS_EIRP_GRID Deterministic per-direction EIRP for the R23 AAS.
%
%   OUT = imt_r23_aas_eirp_grid(AZGRID, ELGRID, CFG, AZIM_I, ELEV_I)
%
%   Evaluates the R23 7.125-8.4 GHz extended-AAS antenna pattern on a
%   regular azimuth x elevation grid and returns per-cell composite gain,
%   EIRP per 100 MHz, and EIRP spectral density in dBW/Hz, plus the grid
%   metadata. No path loss / clutter / FDR / victim antenna is applied.
%
%   Inputs (all optional):
%       AZGRID   1xNaz vector of observation azimuths [deg].
%                Default: -180:1:180.
%       ELGRID   1xNel vector of observation elevations [deg].
%                Default: -90:1:90.
%       CFG      AAS configuration struct (see imt_r23_aas_defaults).
%                Default: imt_r23_aas_defaults('macroUrban').
%       AZIM_I   beam pointing azimuth [deg]. Default: 0.
%       ELEV_I   beam pointing elevation [deg]. Default places the beam
%                at the combined sub-array + mechanical downtilt:
%                    elev_i = -(cfg.subarray.downtiltDeg
%                              + cfg.mechanicalDowntiltDeg)
%                For R23 defaults this is -9 deg.
%
%   Output struct OUT:
%       .azGrid              1xNaz observation azimuths
%       .elGrid              1xNel observation elevations
%       .AZ                  Naz x Nel ndgrid azimuth array
%       .EL                  Naz x Nel ndgrid elevation array
%       .gain_dBi            Naz x Nel composite gain [dBi]
%       .eirp_dBm_per100MHz  Naz x Nel EIRP per 100 MHz [dBm]
%       .eirp_dBW_perHz      Naz x Nel EIRP spectral density [dBW/Hz]
%       .cfg                 echoed configuration struct
%       .beamAzimDeg         scalar beam pointing azimuth used
%       .beamElevDeg         scalar beam pointing elevation used
%
%   Spectral-density conversion:
%       eirp_dBW_perHz = eirp_dBm_per100MHz - 30 - 10*log10(BW_Hz)
%   with BW_Hz = cfg.bandwidthMHz * 1e6.

    if nargin < 1 || isempty(azGrid); azGrid = -180:1:180; end
    if nargin < 2 || isempty(elGrid); elGrid =  -90:1:90;  end
    if nargin < 3 || isempty(cfg);    cfg    = imt_r23_aas_defaults('macroUrban'); end

    % default beam pointing: combined sub-array + mechanical downtilt
    if nargin < 4 || isempty(azim_i); azim_i = 0; end
    if nargin < 5 || isempty(elev_i)
        subDown  = 0;
        mechDown = 0;
        if isfield(cfg, 'subarray') && isstruct(cfg.subarray) && ...
                isfield(cfg.subarray, 'downtiltDeg')
            subDown = cfg.subarray.downtiltDeg;
        end
        if isfield(cfg, 'mechanicalDowntiltDeg')
            mechDown = cfg.mechanicalDowntiltDeg;
        end
        elev_i = -(subDown + mechDown);
    end

    azGrid = azGrid(:).';
    elGrid = elGrid(:).';

    [AZ, EL] = ndgrid(azGrid, elGrid);

    [eirp_dBm, gain_dBi] = imt_aas_bs_eirp(AZ, EL, azim_i, elev_i, cfg);

    if isfield(cfg, 'bandwidthMHz') && ~isempty(cfg.bandwidthMHz)
        bw_Hz = cfg.bandwidthMHz * 1e6;
    else
        bw_Hz = 100e6;
    end

    eirp_dBW_perHz = eirp_dBm - 30 - 10 .* log10(bw_Hz);

    out = struct();
    out.azGrid             = azGrid;
    out.elGrid             = elGrid;
    out.AZ                 = AZ;
    out.EL                 = EL;
    out.gain_dBi           = gain_dBi;
    out.eirp_dBm_per100MHz = eirp_dBm;
    out.eirp_dBW_perHz     = eirp_dBW_perHz;
    out.cfg                = cfg;
    out.beamAzimDeg        = azim_i;
    out.beamElevDeg        = elev_i;
end
