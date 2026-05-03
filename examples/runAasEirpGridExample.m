function runAasEirpGridExample()
%RUNAASEIRPGRIDEXAMPLE End-to-end IMT AAS EIRP grid example.
%
%   runAasEirpGridExample()
%
%   Generates the per-direction EIRP grid for the R23 default IMT AAS
%   sector, plots a heatmap, and saves the figure under
%   examples/output/aas_eirp_grid.png if exportgraphics is available.
%
%   Scenario:
%       - sector boresight at 0 deg azimuth in the sector frame
%       - electronic steering at:
%             (steerAz, steerEl) = (0, -9) deg
%         which aligns with the panel's natural beam direction (3 deg
%         sub-array tilt + 6 deg mechanical tilt), so the composite
%         peak coincides with the sub-array peak and reproduces the R23
%         reference 32.2 dBi peak gain / 78.3 dBm sector EIRP.
%       - this main beam sits inside the R23 vertical coverage envelope
%         (90 deg - 100 deg in global theta, i.e. -10 deg .. 0 deg
%         elevation).
%
%   Run from the repo root:
%       runAasEirpGridExample
%
%   Or, with cd:
%       cd examples
%       runAasEirpGridExample

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    params = imtAasDefaultParams();

    % Azimuth: full panorama; Elevation: full hemisphere with positive up.
    % These match the documented MVP convention (0 deg el = horizon).
    azGridDeg = -180:1:180;
    elGridDeg =  -90:1:90;

    steerAzDeg = 0;
    steerElDeg = -9;

    eirpGridDbm = imtAasEirpGrid(azGridDeg, elGridDeg, ...
        steerAzDeg, steerElDeg, params.sectorEirpDbm, params);

    fig = plotImtAasEirpGrid(azGridDeg, elGridDeg, eirpGridDbm);

    fprintf('AAS EIRP grid: %d az x %d el cells, peak = %.3f dBm/100MHz\n', ...
        numel(azGridDeg), numel(elGridDeg), max(eirpGridDbm(:)));
    fprintf('Steering: az=%.1f deg, el=%.1f deg (sector frame)\n', ...
        steerAzDeg, steerElDeg);
    fprintf('Mechanical downtilt: %.1f deg, sub-array tilt: %.1f deg\n', ...
        params.mechanicalDowntiltDeg, params.subarrayDowntiltDeg);

    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end
    pngPath = fullfile(outDir, 'aas_eirp_grid.png');
    if exist('exportgraphics', 'file') == 2
        try
            exportgraphics(fig, pngPath, 'Resolution', 150);
            fprintf('Saved EIRP heatmap to %s\n', pngPath);
        catch err
            fprintf('Could not save figure (%s).\n', err.message);
        end
    else
        try
            saveas(fig, pngPath);
            fprintf('Saved EIRP heatmap to %s\n', pngPath);
        catch err
            fprintf('Could not save figure (%s).\n', err.message);
        end
    end
end
