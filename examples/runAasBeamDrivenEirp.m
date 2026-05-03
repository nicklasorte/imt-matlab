function runAasBeamDrivenEirp()
%RUNAASBEAMDRIVENEIRP UE-driven AAS beam steering / EIRP example.
%
%   runAasBeamDrivenEirp()
%
%   End-to-end demo of the UE -> beam-angle -> EIRP-grid pipeline for one
%   macro AAS sector:
%
%       1. Sample 100 UE positions inside a single macroUrban sector.
%       2. Convert each UE to a raw beam steering angle.
%       3. Clamp the raw angles to the sector / R23 steering envelope.
%       4. Render histograms of steerAzDeg and steerElDeg.
%       5. For three representative beams (boresight / sector edge /
%          clipped-elevation or closest UE), compute the per-direction
%          EIRP grid using imtAasEirpGrid and render a heatmap.
%       6. Save figures under examples/output/ when exportgraphics or
%          saveas is available.
%
%   This is geometry only. There is no path loss, no receiver, and no
%   I/N: it produces beam steering angles (and the resulting antenna-face
%   EIRP) for downstream consumers.
%
%   Run from the repo root:
%       runAasBeamDrivenEirp
%
%   Or, with cd:
%       cd examples
%       runAasBeamDrivenEirp

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    matlabDir = fullfile(repoRoot, 'matlab');
    if exist(matlabDir, 'dir') == 7
        addpath(matlabDir);
    end

    params = imtAasDefaultParams();
    sector = imtAasSingleSectorParams('macroUrban', params);
    beams  = imtAasGenerateBeamSet(100, sector, struct('seed', 1));

    fprintf('====================================================\n');
    fprintf('  UE-driven AAS beam set\n');
    fprintf('====================================================\n');
    fprintf('  deployment            : %s\n', sector.deployment);
    fprintf('  N beams               : %d\n', beams.N);
    fprintf('  steerAzDeg range      : [% .2f, % .2f]  (limits [%g, %g])\n', ...
        min(beams.steerAzDeg), max(beams.steerAzDeg), ...
        sector.azLimitsDeg(1), sector.azLimitsDeg(2));
    fprintf('  steerElDeg range      : [% .2f, % .2f]  (limits [%g, %g])\n', ...
        min(beams.steerElDeg), max(beams.steerElDeg), ...
        sector.elLimitsDeg(1), sector.elLimitsDeg(2));
    fprintf('  rawSteerAzDeg range   : [% .2f, % .2f]\n', ...
        min(beams.rawSteerAzDeg), max(beams.rawSteerAzDeg));
    fprintf('  rawSteerElDeg range   : [% .2f, % .2f]\n', ...
        min(beams.rawSteerElDeg), max(beams.rawSteerElDeg));
    fprintf('  clipped (azimuth)     : %d / %d\n', ...
        sum(beams.wasAzClipped), beams.N);
    fprintf('  clipped (elevation)   : %d / %d\n', ...
        sum(beams.wasElClipped), beams.N);

    outDir = fullfile(here, 'output');
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    % ---- Histograms -------------------------------------------------
    figAz = figure('Name', 'AAS beam azimuth histogram', 'Color', 'w');
    histogram(beams.steerAzDeg, 24);
    xlabel('Steering azimuth [deg] (relative to sector boresight)');
    ylabel('Count');
    title(sprintf('UE-driven beam azimuth (N = %d)', beams.N));
    grid on;
    saveFigure(figAz, fullfile(outDir, 'aas_beam_az_histogram.png'));

    figEl = figure('Name', 'AAS beam elevation histogram', 'Color', 'w');
    histogram(beams.steerElDeg, 24);
    xlabel('Steering elevation [deg] (0 = horizon)');
    ylabel('Count');
    title(sprintf('UE-driven beam elevation (N = %d)', beams.N));
    grid on;
    saveFigure(figEl, fullfile(outDir, 'aas_beam_el_histogram.png'));

    % ---- Three representative beams --------------------------------
    [~, idxBore] = min(abs(beams.steerAzDeg));
    [~, idxEdge] = max(abs(beams.steerAzDeg));
    if any(beams.wasElClipped)
        clippedIdx = find(beams.wasElClipped);
        % pick the most extreme raw downtilt (smallest rawSteerElDeg)
        [~, kMin]  = min(beams.rawSteerElDeg(clippedIdx));
        idxThird   = clippedIdx(kMin);
        idxThirdLabel = 'clipped-elevation';
    else
        [~, idxThird] = min(beams.ue.r_m);
        idxThirdLabel = 'closest-UE';
    end

    azGridDeg = -180:1:180;
    elGridDeg =  -90:1:90;

    examples = struct( ...
        'idx',   {idxBore,    idxEdge,         idxThird}, ...
        'label', {'boresight', 'sector-edge',  idxThirdLabel});
    pngNames = { ...
        'aas_beam_driven_eirp_example_1.png', ...
        'aas_beam_driven_eirp_example_2.png', ...
        'aas_beam_driven_eirp_example_3.png'};

    for k = 1:numel(examples)
        idx = examples(k).idx;
        steerAz = beams.steerAzDeg(idx);
        steerEl = beams.steerElDeg(idx);

        eirpGridDbm = imtAasEirpGrid(azGridDeg, elGridDeg, ...
            steerAz, steerEl, params.sectorEirpDbm, params);

        peakDbm = max(eirpGridDbm(:));
        fprintf('  example %d (%s): idx=%d, steerAz=%.2f, steerEl=%.2f, peak EIRP=%.3f dBm/100MHz\n', ...
            k, examples(k).label, idx, steerAz, steerEl, peakDbm);

        figEirp = plotImtAasEirpGrid(azGridDeg, elGridDeg, eirpGridDbm);
        ax = gca;
        title(ax, sprintf( ...
            'UE-driven beam %d (%s): steer (az,el) = (%.2f, %.2f) deg', ...
            k, examples(k).label, steerAz, steerEl));
        saveFigure(figEirp, fullfile(outDir, pngNames{k}));
    end
    fprintf('====================================================\n');
end

% =====================================================================

function saveFigure(fig, pngPath)
    if exist('exportgraphics', 'file') == 2
        try
            exportgraphics(fig, pngPath, 'Resolution', 150);
            fprintf('  saved %s\n', pngPath);
            return;
        catch err
            fprintf('  exportgraphics failed (%s); falling back to saveas\n', ...
                err.message);
        end
    end
    try
        saveas(fig, pngPath);
        fprintf('  saved %s\n', pngPath);
    catch err
        fprintf('  could not save %s (%s)\n', pngPath, err.message);
    end
end
