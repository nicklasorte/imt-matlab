function out = demo_embrss_eirp_cdf_grid()
%DEMO_EMBRSS_EIRP_CDF_GRID End-to-end demo of run_embrss_eirp_cdf_grid.
%
%   OUT = demo_embrss_eirp_cdf_grid()
%
%   Runs a small urban_macro EMBRSS-style EIRP CDF-grid generation,
%   prints a summary near the boresight observation cell, and (when run
%   interactively) plots the mean and median EIRP maps. Uses a coarse
%   grid + 200 Monte Carlo draws so it runs in a few seconds on a laptop.

    here = fileparts(mfilename('fullpath'));
    if exist(here, 'dir') == 7
        addpath(here);   % no-op if already on path
    end

    opts = struct();
    opts.numMc        = 200;
    opts.azGrid       = -60:5:60;
    opts.elGrid       = -30:5:10;
    opts.binEdges     = -80:2:120;
    opts.seed         = 7;
    opts.numBeams     = 1;
    opts.combineBeams = 'max';
    opts.percentiles  = [5 50 95];

    fprintf(['Running EMBRSS urban_macro EIRP CDF-grid: numMc=%d on a ' ...
             '%dx%d az/el grid...\n'], ...
        opts.numMc, numel(opts.azGrid), numel(opts.elGrid));
    out = run_embrss_eirp_cdf_grid('urban_macro', opts);

    stats = out.stats;
    pmaps = out.percentileMaps;

    [~, iAz0] = min(abs(stats.azGrid - 0));
    [~, iEl0] = min(abs(stats.elGrid - 0));

    fprintf('\nCategory: %s\n', out.category);
    fprintf('  BS height          : %g m\n', out.model.bs_height_m);
    fprintf('  Sector radius      : %g m\n', out.model.sector_radius_m);
    fprintf('  UE height range    : [%g %g] m\n', ...
        out.model.ue_height_range_m(1), out.model.ue_height_range_m(2));
    fprintf('  Power mode         : %s\n', out.cfg.powerMode);
    fprintf('  Conducted txPower  : %.2f dBm\n', out.cfg.txPower_dBm);

    fprintf('\nPer-cell summary at observation (az,el)=(0,0):\n');
    fprintf('   mean EIRP (lin->dBm) = %.2f dBm\n', ...
        stats.mean_dBm(iAz0, iEl0));
    fprintf('   min  EIRP            = %.2f dBm\n', ...
        stats.min_dBm(iAz0, iEl0));
    fprintf('   max  EIRP            = %.2f dBm\n', ...
        stats.max_dBm(iAz0, iEl0));
    pIdx = find(pmaps.percentiles == 50, 1);
    if ~isempty(pIdx)
        fprintf('   median (p50)         = %.2f dBm\n', ...
            pmaps.values(iAz0, iEl0, pIdx));
    end
    fprintf('   elapsed              = %.2f s\n', stats.elapsedSeconds);

    if usejava('desktop') && feature('ShowFigureWindows')
        plotSummary(stats, pmaps);
    end
end

function plotSummary(stats, pmaps)
    figure('Name', 'EMBRSS urban_macro EIRP CDF-grid demo');
    tiledlayout(1, 2);

    nexttile;
    imagesc(stats.azGrid, stats.elGrid, stats.mean_dBm.');
    axis xy; colorbar;
    xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title('Mean EIRP (linear-mW averaged) [dBm]');

    pIdx = find(pmaps.percentiles == 50, 1);
    if isempty(pIdx)
        pIdx = ceil(numel(pmaps.percentiles) / 2);
    end
    nexttile;
    imagesc(stats.azGrid, stats.elGrid, pmaps.values(:,:,pIdx).');
    axis xy; colorbar;
    xlabel('Azimuth [deg]'); ylabel('Elevation [deg]');
    title(sprintf('p%02d EIRP [dBm]', round(pmaps.percentiles(pIdx))));
end
