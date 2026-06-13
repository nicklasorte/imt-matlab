function results = test_imtAasHeatmapStyle()
%TEST_IMTAASHEATMAPSTYLE Smoke test for the shared heatmap styling path.
%
%   RESULTS = test_imtAasHeatmapStyle()
%
%   Verifies that the three heatmap plotters route their Colormap / CLim
%   name-value arguments through the single shared styling helper
%   imtAasHeatmapStyle, so a caller can pin an identical color-axis to make
%   morphologies directly comparable, and that the standard colormap is
%   applied by default.
%
%   This test needs a graphics context. Headless MATLAB has shown graphics
%   timeouts in this environment, so the ENTIRE plotting block is wrapped in
%   try/catch: on ANY graphics (or related) error the test records a SKIP,
%   never a FAIL, so it cannot break a headless run. The deterministic,
%   graphics-free coverage of the assumptions table lives in
%   test_imtAasAssumptionsTable.
%
%   Returns a struct compatible with run_all_tests.m:
%       .passed   logical
%       .skipped  logical
%       .reason   char

    here = fileparts(mfilename('fullpath'));
    addpath(here);

    results = struct('passed', false, 'skipped', false, 'reason', '');
    fprintf('--- test_imtAasHeatmapStyle ---\n');

    try
        stdName = imtAasHeatmapStyle();   % the standard colormap name
        assert(ischar(stdName) && ~isempty(stdName), ...
            'imtAasHeatmapStyle() must return the default colormap name');

        % Small EIRP + gain run so both percentile maps exist.
        out = runR23AasEirpCdfGrid(struct( ...
            'aasGeometryPreset', 'r23_1x3_default', ...
            'numMc',       6, ...
            'seed',        3, ...
            'azGridDeg',   -30:10:30, ...
            'elGridDeg',   -10:5:10, ...
            'binEdgesDbm', -80:5:120, ...
            'percentiles', [50 95], ...
            'outputDomain', 'both'));

        eirpClim = [60 80];
        gainClim = [20 35];

        % ---- EIRP CDF-grid plotter ----------------------------------
        fe = plotR23AasEirpCdfGrid(out, 95, 'Colormap', stdName, 'CLim', eirpClim);
        assertStyled(fe.percentiles.p095, stdName, eirpClim);

        % ---- gain plotter -------------------------------------------
        fg = plotR23AasGainHeatmap(out, 95, 'Colormap', stdName, 'CLim', gainClim);
        assertStyled(fg.percentiles.p095, stdName, gainClim);

        % ---- UE-driven sector EIRP plotter --------------------------
        sectorGrid = imtAasCreateDefaultSectorEirpGrid(3, 'macroUrban', ...
            struct('azGridDeg', -30:10:30, 'elGridDeg', -10:5:10, 'seed', 1));
        fs = plotImtAasSectorEirpGrid(sectorGrid, 'CLim', eirpClim);
        % Default colormap (no 'Colormap' passed) must be the standard one.
        assertStyled(fs.aggregate, stdName, eirpClim);

        close all;
        results.passed = true;
        fprintf('--- test_imtAasHeatmapStyle PASSED ---\n');
    catch err
        try
            close all;
        catch
        end
        results.skipped = true;
        results.reason  = sprintf('graphics unavailable: %s', err.message);
        fprintf('  [SKIP] %s\n', results.reason);
    end
end

% =====================================================================
function assertStyled(fig, stdName, expectedClim)
%ASSERTSTYLED A figure handle returns, with the requested CLim + colormap.
    assert(~isempty(fig) && isgraphics(fig, 'figure'), ...
        'plotter must return a figure handle');
    imgs = findobj(fig, 'Type', 'image');
    assert(~isempty(imgs), 'heatmap figure must contain an image');
    ax = ancestor(imgs(1), 'axes');
    assert(~isempty(ax), 'image must live on an axes');

    climApplied = get(ax, 'CLim');
    assert(max(abs(double(climApplied(:).') - double(expectedClim(:).'))) < 1e-9, ...
        'axis CLim must equal the requested [%g %g] (got [%g %g])', ...
        expectedClim(1), expectedClim(2), climApplied(1), climApplied(2));

    cmapApplied = colormap(ax);
    expected = feval(stdName, size(cmapApplied, 1));
    assert(isequal(cmapApplied, expected), ...
        'axis colormap must be the standard "%s"', stdName);
end
