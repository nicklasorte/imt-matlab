function bs = get_default_bs()
%GET_DEFAULT_BS R23-aligned default base-station input struct.
%
%   BS = get_default_bs()
%
%   Returns the R23 baseline single-site, single-sector base-station
%   description that drives every function in the single-sector EIRP
%   CDF-grid MVP. Callers MUST treat BS as the input contract: pass it
%   through generate_single_sector_layout, sample_ue_positions_in_sector,
%   compute_eirp_grid, and run_monte_carlo_snapshots. No function in the
%   MVP hardcodes BS values internally; overriding BS fields changes
%   simulator behaviour end to end.
%
%   Default field values (R23 7.125-8.4 GHz urban macro):
%       id                       "BS_001"            tag (string)
%       position_m               [0, 0, 18]          (x, y, z) [m]
%       azimuth_deg              0                   sector boresight [deg]
%       sector_width_deg         120                 horizontal coverage [deg]
%       height_m                 18                  redundant z [m]
%       environment              "urban"             tag (string)
%       eirp_dBm_per_100MHz      78.3                sector peak EIRP
%
%   Override example:
%       bs = get_default_bs();
%       bs.height_m       = 25;
%       bs.position_m(3)  = 25;
%       bs.azimuth_deg    = 30;
%
%   The position_m vector and height_m are kept in sync by
%   generate_single_sector_layout (height_m wins when they disagree, and
%   a warning is issued).

    bs = struct();
    bs.id                  = "BS_001";
    bs.position_m          = [0, 0, 18];
    bs.azimuth_deg         = 0;
    bs.sector_width_deg    = 120;
    bs.height_m            = 18;
    bs.environment         = "urban";
    bs.eirp_dBm_per_100MHz = 78.3;
end
