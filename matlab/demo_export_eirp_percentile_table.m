function out = demo_export_eirp_percentile_table()
%DEMO_EXPORT_EIRP_PERCENTILE_TABLE Run a small MC case and export the table.
%
%   OUT = demo_export_eirp_percentile_table()
%
%   1. Runs a small Monte Carlo over a coarse az/el grid using the existing
%      AAS / EIRP pipeline.
%   2. Exports a CSV file (eirp_percentile_table.csv) where each row is one
%      observation (az, el) bin and the columns p000:p100 hold the EIRP at
%      CDF percentiles 0..100.
%   3. Prints the first few rows.
%   4. (Interactive only) plots p050 and p095 heatmaps.
%
%   Returns OUT with fields .stats, .table, and .csvPath.

    cfg = struct();
    cfg.G_Emax        = 5;
    cfg.A_m           = 30;
    cfg.SLA_nu        = 30;
    cfg.phi_3db       = 65;
    cfg.theta_3db     = 65;
    cfg.d_H           = 0.5;
    cfg.d_V           = 0.5;
    cfg.N_H           = 8;
    cfg.N_V           = 8;
    cfg.rho           = 1;
    cfg.k             = 12;
    cfg.txPower_dBm   = 40;
    cfg.feederLoss_dB = 3;

    mcOpts = struct();
    mcOpts.numMc        = 400;
    mcOpts.azGrid       = -90:5:90;
    mcOpts.elGrid       = -30:5:30;
    mcOpts.binEdges     = -10:1:90;
    mcOpts.seed         = 11;
    mcOpts.progressEvery = 100;
    mcOpts.beamSampler  = struct('mode', 'sector', ...
        'sector_az', 0, 'sector_az_width', 120, ...
        'elev_range', [-10, 0], 'numBeams', 1);

    fprintf('Running %d MC draws on a %dx%d az/el grid...\n', ...
        mcOpts.numMc, numel(mcOpts.azGrid), numel(mcOpts.elGrid));
    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    csvPath = 'eirp_percentile_table.csv';
    T = export_eirp_percentile_table(stats, csvPath);

    fprintf('\nExported %s (%d rows, %d cols)\n', ...
        csvPath, height(T), width(T));
    fprintf('First 5 rows:\n');
    disp(head(T, 5));

    if usejava('desktop') && feature('ShowFigureWindows')
        plotPercentileHeatmaps(stats, T);
    end

    out.stats   = stats;
    out.table   = T;
    out.csvPath = csvPath;
end

function plotPercentileHeatmaps(stats, T)
    azGrid = stats.azGrid;
    elGrid = stats.elGrid;
    Naz = numel(azGrid);
    Nel = numel(elGrid);

    P50 = reshape(T.p050, Naz, Nel);
    P95 = reshape(T.p095, Naz, Nel);

    figure('Name', 'EIRP percentile heatmaps');
    tiledlayout(1, 2);

    nexttile;
    imagesc(azGrid, elGrid, P50.');
    axis xy; colorbar;
    xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title('p050: median EIRP [dBm]');

    nexttile;
    imagesc(azGrid, elGrid, P95.');
    axis xy; colorbar;
    xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title('p095: 95th-percentile EIRP [dBm]');
end
