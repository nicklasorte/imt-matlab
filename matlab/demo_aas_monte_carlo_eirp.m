function out = demo_aas_monte_carlo_eirp()
%DEMO_AAS_MONTE_CARLO_EIRP End-to-end demo of the IMT AAS Monte Carlo flow.
%
%   OUT = demo_aas_monte_carlo_eirp()
%
%   Builds a representative IMT-2020 base station, runs a small Monte
%   Carlo sweep with uniform sector beam pointing, derives percentile
%   maps and exceedance maps, and (when run interactively) plots
%   summary figures.

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

    mcOpts.numMc        = 500;
    mcOpts.azGrid       = -90:2:90;
    mcOpts.elGrid       = -30:2:30;
    mcOpts.binEdges     = -10:1:90;
    mcOpts.seed         = 1;
    mcOpts.progressEvery = 100;
    mcOpts.beamSampler  = struct('mode', 'sector', ...
        'sector_az', 0, 'sector_az_width', 120, ...
        'elev_range', [-10, 0], 'numBeams', 1);

    fprintf('Running %d Monte Carlo draws on a %dx%d az/el grid...\n', ...
        mcOpts.numMc, numel(mcOpts.azGrid), numel(mcOpts.elGrid));
    stats = run_imt_aas_eirp_monte_carlo(cfg, mcOpts);

    pmaps = eirp_percentile_maps(stats, [5 50 95]);
    emaps = eirp_exceedance_maps(stats, [40 50 60]);

    fprintf('\nPer-cell summary at (az,el) = (0,0):\n');
    [cdf, edges] = eirp_cdf_at_angle(stats, 0, 0);
    [~, iAz] = min(abs(stats.azGrid - 0));
    [~, iEl] = min(abs(stats.elGrid - 0));
    fprintf('   mean EIRP (lin->dBm) = %.2f dBm\n', stats.mean_dBm(iAz,iEl));
    fprintf('   min  EIRP            = %.2f dBm\n', stats.min_dBm(iAz,iEl));
    fprintf('   max  EIRP            = %.2f dBm\n', stats.max_dBm(iAz,iEl));
    fprintf('   median (50%% pctile) = %.2f dBm\n', ...
        pmaps.values(iAz, iEl, 2));
    fprintf('   P(EIRP > 50 dBm)     = %.3f\n', emaps.prob(iAz, iEl, 2));

    if usejava('desktop') && feature('ShowFigureWindows')
        plotSummary(stats, pmaps, emaps, cdf, edges);
    end

    out.stats = stats;
    out.pmaps = pmaps;
    out.emaps = emaps;
end

function plotSummary(stats, pmaps, emaps, cdf, edges)
    figure('Name', 'AAS Monte Carlo EIRP Demo');
    tiledlayout(2, 2);

    nexttile;
    imagesc(stats.azGrid, stats.elGrid, stats.mean_dBm.');
    axis xy; colorbar; xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title('Mean EIRP (linear-mW averaged) [dBm]');

    nexttile;
    imagesc(stats.azGrid, stats.elGrid, pmaps.values(:,:,2).');  % 50%
    axis xy; colorbar; xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title('Median EIRP [dBm]');

    nexttile;
    imagesc(stats.azGrid, stats.elGrid, emaps.prob(:,:,2).');    % 50 dBm
    axis xy; colorbar; xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title('P(EIRP > 50 dBm)');

    nexttile;
    plot(edges(2:end), cdf, 'LineWidth', 1.5);
    grid on; xlabel('EIRP [dBm]'); ylabel('CDF'); title('CDF at (0,0)');
end
